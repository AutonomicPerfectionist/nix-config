# llama-hm.nix — Home Manager module for llama.cpp
#
# Home Manager variant of modules/ml/llama.nix.  Installs the binary via
# home.packages; has no system services.  GPU backend is selected via the
# services.llama.backend option (hardware.gpu.* is not available in the HM
# module system).  Set services.llama.backend in your per-machine module block
# in homeConfigurations to pick the right GPU stack.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) cmakeBool;
  cfg = config.services.llama;

  useCuda = cfg.backend == "cuda";
  useRocm = cfg.backend == "rocm";
  useSycl = cfg.backend == "sycl";

  # ── CUDA pkgs re-instantiation ───────────────────────────────────────────
  pkgsCuda = import pkgs.path {
    inherit (pkgs) system;
    config = pkgs.config // { cudaSupport = true; };
    overlays = config.nixpkgs.overlays;
  };

  # ── ROCm pkgs re-instantiation ───────────────────────────────────────────
  pkgsRocm = import pkgs.path {
    inherit (pkgs) system;
    config = pkgs.config // { rocmSupport = true; };
    overlays = config.nixpkgs.overlays;
  };

  # ── Backend package selection ────────────────────────────────────────────
  llamaBasePkg =
    if      cfg.preferVulkan then pkgs.llama-cpp-vulkan
    else if useCuda          then pkgsCuda.llama-cpp
    else if useRocm          then pkgsRocm.llama-cpp
    else if useSycl          then pkgs.llama-cpp-sycl
    else                          pkgs.llama-cpp;        # CPU-only fallback

  # ── Host ISA probe ───────────────────────────────────────────────────────
  hostIsa = pkgs.stdenv.hostPlatform.gcc.isa or [];
  hasIsa  = feat: builtins.elem feat hostIsa;

  # ── cmake flag override ──────────────────────────────────────────────────
  llamaPkg = llamaBasePkg.overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or []) ++ [
      (cmakeBool "GGML_NATIVE" false)
      (cmakeBool "GGML_AVX"  (hasIsa "avx"))
      (cmakeBool "GGML_AVX2" (hasIsa "avx2"))
      (cmakeBool "GGML_BMI2" (hasIsa "bmi2"))
      (cmakeBool "GGML_FMA"  (hasIsa "fma"))
      (cmakeBool "GGML_F16C" (hasIsa "f16c"))
      (cmakeBool "GGML_CPU_ALL_VARIANTS" (!useSycl))
      (cmakeBool "GGML_BACKEND_DL"       (!useSycl))
      (cmakeBool "GGML_CUDA_FA" (
        useCuda && lib.any
          (c: lib.versionAtLeast c "7.5")
          (pkgsCuda.config.cudaCapabilities or [])
      ))
      (cmakeBool "GGML_RPC" true)
    ] ++ lib.optionals useSycl [
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

    useCustomSource = lib.mkEnableOption "custom llama.cpp source (rgerganov/llama.cpp rpc-async fork)";

    preferVulkan = lib.mkEnableOption "Vulkan backend for llama.cpp (overrides backend selection)";

    backend = lib.mkOption {
      type    = lib.types.enum [ "cpu" "cuda" "rocm" "sycl" ];
      default = "cpu";
      description = ''
        GPU backend for llama.cpp.  Set this per machine in your
        homeConfigurations entry since hardware.gpu.* is not available
        in the home-manager module system.
      '';
    };

    package = lib.mkOption {
      type        = lib.types.package;
      default     = llamaPkg;
      defaultText = lib.literalExpression "auto-selected llama.cpp variant";
      description = ''
        The llama.cpp package to use.  Automatically selects the CUDA, ROCm,
        SYCL, or Vulkan variant based on services.llama.backend, falling back
        to a plain CPU build.  Override this to pin a specific derivation.
      '';
    };

    enableHomePackage = lib.mkEnableOption "adding llama.cpp to home.packages" // {
      description = ''
        Whether to install the llama.cpp package via home.packages.  Set this
        to true on standalone (non-NixOS) machines.  On NixOS hosts where
        llama.cpp is already in environment.systemPackages via the system-level
        llama.nix module, leave this false to avoid a duplicate installation.
      '';
    };
  };

  # ── Config ────────────────────────────────────────────────────────────────

  config = lib.mkIf cfg.enableHomePackage {
    home.packages = [ cfg.package ];
  };
}
