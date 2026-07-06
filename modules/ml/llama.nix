# llama-service.nix
#
# NixOS module that exposes an inference server, an optional RPC server
# (for distributed inference), and an optional embeddings server backed
# by llama.cpp.  GPU backend selection is automatic: CUDA → ROCm → SYCL
# → CPU fallback.  The corresponding per-GPU overlays live in overlays.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) cmakeBool;
  cfg = config.services.llama;

  # ── GPU backend detection ────────────────────────────────────────────────
  # Read hardware.gpu.* so this module stays self-contained; any of these
  # can be false when the matching hardware module isn't imported.
  useCuda = config.hardware.gpu.nvidia.enable or false;
  useRocm = config.hardware.gpu.amd.enable   or false;
  useSycl = config.hardware.gpu.intel.enable or false;

  # ── CUDA pkgs re-instantiation ───────────────────────────────────────────
   # We need a pkgs set with cudaSupport=true to pull llama-cpp's CUDA variant.
   # Inheriting cudaCapabilities from the host config keeps capability-gated
   # flags (e.g. flash-attention) consistent with the rest of the system.
   pkgsCuda = import pkgs.path {
     inherit (pkgs) system;

     config = pkgs.config // {
       cudaSupport = true;
     };

     overlays = config.nixpkgs.overlays;
   };

   # ── ROCm pkgs re-instantiation ───────────────────────────────────────────
   # We need a pkgs set with rocmSupport=true to pull pkgsRocm.llama-cpp
   # (which picks up rocmPackages overlays like rocm-gpu-targets).
   pkgsRocm = import pkgs.path {
     inherit (pkgs) system;

     config = pkgs.config // {
       rocmSupport = true;
     };

     overlays = config.nixpkgs.overlays;
   };

  # ── Backend package selection ────────────────────────────────────────────
  # Priority: preferVulkan > CUDA > ROCm > SYCL > CPU.
  # llama-cpp-rocm is nixpkgs' ROCm variant; llama-cpp-sycl is injected
  # by the syclOverlay in overlays.nix.
  llamaBasePkg =
    if      cfg.preferVulkan then pkgs.llama-cpp-vulkan
    else if useCuda          then pkgsCuda.llama-cpp   # CUDA variant from re-instantiated set
    else if useRocm          then pkgsRocm.llama-cpp   # ROCm variant from pkgsRocm (picks up rocmGpuTargetsOverlay)
    else if useSycl          then pkgs.llama-cpp-sycl   # SYCL/Intel variant (syclOverlay + fork swap)
    else                           pkgs.llama-cpp;      # CPU-only fallback

  # ── Host ISA probe ───────────────────────────────────────────────────────
  # gcc.isa is a list of ISA extensions the host platform advertises
  # (e.g. ["avx" "avx2" "fma" "bmi2" "f16c"]).  We use this instead of
  # GGML_NATIVE so the build is still portable across machines with the
  # same feature set rather than baking in a single march= string.
  hostIsa = pkgs.stdenv.hostPlatform.gcc.isa or [];
  hasIsa  = feat: builtins.elem feat hostIsa;

  # ── cmake flag override ──────────────────────────────────────────────────
  # Applied on top of whatever the upstream derivation already sets.
  llamaPkg = llamaBasePkg.overrideAttrs (old: {
    # cmakeBuildType = "RelWithDebInfo";
    cmakeFlags = (old.cmakeFlags or []) ++ [
      # Disable auto-detection; we control every flag explicitly below so
      # the derivation is reproducible across identical hardware classes.
      (cmakeBool "GGML_NATIVE" false)

      # AVX is the x86-64-v2 baseline; only disable when the host truly lacks it.
      (cmakeBool "GGML_AVX"  (hasIsa "avx"))

      # Extensions absent on Ivy Bridge and similar; gate on ISA advertisement.
      (cmakeBool "GGML_AVX2" (hasIsa "avx2"))
      (cmakeBool "GGML_BMI2" (hasIsa "bmi2"))
      (cmakeBool "GGML_FMA"  (hasIsa "fma"))
      (cmakeBool "GGML_F16C" (hasIsa "f16c"))

      # Build CPU backend variants as dynamic plugins so the runtime picks
      # the best one for the executing CPU at load time.
      #
      # Disabled for the SYCL build: GGML_CPU_ALL_VARIANTS also compiles the
      # Sapphire Rapids AMX backend (ggml-cpu/amx/mmq.cpp), whose AMX intrinsics
      # the Intel DPC++ clang pathologically hangs on — one core pinned at 100%
      # for 30+ minutes. The GPU does the compute here, so a single host CPU
      # fallback backend (GGML_NATIVE-gated below) is sufficient. CUDA/ROCm
      # builds use gcc, which compiles the AMX kernel fine, so they keep it.
      (cmakeBool "GGML_CPU_ALL_VARIANTS" (!useSycl))
      (cmakeBool "GGML_BACKEND_DL"       (!useSycl))

      # CUDA flash-attention requires compute capability ≥ 7.5 (Turing+).
      (cmakeBool "GGML_CUDA_FA" (
        useCuda && lib.any
          (c: lib.versionAtLeast c "7.5")
          (pkgsCuda.config.cudaCapabilities or [])
      ))

      # RPC transport for multi-host / multi-GPU distributed inference.
      (cmakeBool "GGML_RPC" true)
    ] ++ lib.optionals useSycl [
      # CPU fallback ISA for the SYCL host. With GGML_CPU_ALL_VARIANTS off we
      # build a single CPU backend, and because gcc.isa is empty on the generic
      # x86_64-linux platform the hasIsa-gated flags above would leave it at
      # baseline SSE. big-nix — the only SYCL host — is a Broadwell Xeon
      # (E5-2640 v4): AVX2/FMA/F16C/BMI2, but NO AVX512 and NO AMX. Force that
      # feature set so CPU offload is fast, staying below AVX512 (would SIGILL
      # on this CPU) and AMX (hangs the DPC++ compile). These come last, so they
      # override the hasIsa defaults above.
      (cmakeBool "GGML_AVX"  true)
      (cmakeBool "GGML_AVX2" true)
      (cmakeBool "GGML_FMA"  true)
      (cmakeBool "GGML_F16C" true)
      (cmakeBool "GGML_BMI2" true)
    ];
  });
in
{
  # ── Options ───────────────────────────────────────────────────────────────

  options.services.llama = {

    # When enabled, every llama-cpp variant is replaced by the
    # rgerganov/llama.cpp rpc-async fork.  The actual source substitution
    # is performed by an overlay in overlays.nix that reads this flag;
    # see the note there about adding the fork as a flake input.
    useCustomSource = lib.mkEnableOption "custom llama.cpp source (rgerganov/llama.cpp rpc-async fork)";

    preferVulkan = lib.mkEnableOption "Vulkan backend for llama.cpp (overrides automatic GPU backend detection)";

    enable = lib.mkEnableOption "llama.cpp inference server";

    package = lib.mkOption {
      type        = lib.types.package;
      default     = llamaPkg;
      defaultText = lib.literalExpression "auto-selected llama.cpp variant";
      description = ''
        The llama.cpp package to use.  Automatically selects the CUDA, ROCm,
        or SYCL variant based on the hardware.gpu.* flags, falling back to a
        plain CPU build.  Override this to pin a specific derivation.
      '';
    };

    port = lib.mkOption {
      type        = lib.types.port;
      default     = 8080;
      description = "Port on which the llama.cpp inference server listens.";
    };

    model = lib.mkOption {
      type        = lib.types.path;
      default     = "";
      description = "Path to the GGUF model file for the inference server.";
    };

    # ── RPC server ──────────────────────────────────────────────────────────
    rpcServer = {
      enable = lib.mkEnableOption "llama.cpp RPC server (for distributed / multi-GPU inference)";
    };

    # ── Embeddings server ───────────────────────────────────────────────────
    embeddingsServer = {
      enable = lib.mkEnableOption "llama.cpp embeddings server (for vector memory / RAG)";

      model = lib.mkOption {
        type        = lib.types.path;
        default     = "";
        description = "Path to the GGUF embedding model file.";
      };

      port = lib.mkOption {
        type        = lib.types.port;
        default     = 8082;
        description = "Port on which the embeddings server listens.";
      };
    };
  };

  # ── Config ────────────────────────────────────────────────────────────────

  config = lib.mkMerge [

    # Always add the selected package to the system PATH so the llama-cli
    # and other binaries are available without enabling any service.
    {
      environment.systemPackages = [ llamaPkg ];
    }

    # ── Inference server ─────────────────────────────────────────────────
    (lib.mkIf cfg.enable {
      assertions = [{
        assertion = cfg.model != "";
        message   = "services.llama.model must be set when services.llama.enable is true.";
      }];

      systemd.services.llama = {
        description = "llama.cpp inference server";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network.target" ];

        serviceConfig = {
          Type      = "simple";
          ExecStart = ''
            ${cfg.package}/bin/llama-server \
              --model ${cfg.model} \
              --port ${toString cfg.port}
          '';
          Restart     = "on-failure";
          # Runs as a transient user; no home directory or persistent UID needed.
          DynamicUser = true;
        };
      };
    })

    # ── RPC server ───────────────────────────────────────────────────────
    # Listens on all interfaces so remote workers can connect.
    # Firewall rules are the caller's responsibility.
    (lib.mkIf cfg.rpcServer.enable {
      systemd.services.llama-rpc = {
        description = "llama.cpp RPC server";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network.target" ];

        serviceConfig = {
          Type        = "simple";
          ExecStart   = "${cfg.package}/bin/rpc-server --host 0.0.0.0";
          Restart     = "on-failure";
          DynamicUser = true;
        };
      };
    })

    # ── Embeddings server ────────────────────────────────────────────────
    (lib.mkIf cfg.embeddingsServer.enable {
      assertions = [{
        assertion = cfg.embeddingsServer.model != "";
        message   = "services.llama.embeddingsServer.model must be set when the embeddings server is enabled.";
      }];

      systemd.services.llama-embeddings = {
        description = "llama.cpp embeddings server";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network.target" ];

        serviceConfig = {
          Type      = "simple";
          ExecStart = ''
            ${cfg.package}/bin/llama-server \
              --model ${cfg.embeddingsServer.model} \
              --port ${toString cfg.embeddingsServer.port} \
              --embedding
          '';
          Restart     = "on-failure";
          DynamicUser = true;
        };
      };
    })
  ];
}
