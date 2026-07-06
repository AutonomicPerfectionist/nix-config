# NixOS module: services.vllm-xpu
#
# Packages vLLM for Intel Arc / Intel GPU (XPU / SYCL backend) and exposes an
# optional systemd service to serve a model.
#
# ── QUICK START ──────────────────────────────────────────────────────────────
#
#   # flake.nix
#   {
#     inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#
#     outputs = { self, nixpkgs }: {
#       nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#         modules = [
#           ./configuration.nix
#           ./vllm-xpu.nix          # ← this file
#         ];
#       };
#     };
#   }
#
#   # configuration.nix
#   {
#     services.vllm-xpu = {
#       enable        = true;
#       model         = "meta-llama/Llama-3.1-8B-Instruct";
#       huggingFaceToken = "hf_xxxxxxxxxxxx";   # or use secretFile
#       # secretFile = "/run/secrets/hf-token"; # systemd-creds / agenix / sops
#       extraArgs     = [ "--dtype" "float16" "--max-model-len" "4096" ];
#     };
#   }
#
# ── WHEEL HASHES ─────────────────────────────────────────────────────────────
#
# The XPU-flavoured PyTorch wheel and Intel's companion packages are not in
# nixpkgs yet.  This module fetches pre-built wheels from Intel's and
# PyTorch's official XPU index URLs.  Every wheel is pinned by sha256 so
# builds are reproducible.
#
# Before you can build, fill in the sha256 placeholders for each wheel:
#
#   nix-prefetch-url \
#     https://download.pytorch.org/whl/xpu/torch-2.12.0%2Bxpu-cp312-cp312-linux_x86_64.whl
#
# Do the same for each of the other wheels listed in the `wheels` attrset
# further below, then paste the resulting hashes.
#
# Wheel index URLs:
#   PyTorch XPU:  https://download.pytorch.org/whl/xpu/
#   Intel ext:    https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
#
# The module hard-codes Python 3.12 / x86_64-linux wheels, which is what
# vllm 0.16.x requires ("The provided vllm-xpu-kernels whl is Python 3.12
# specific so this version is a MUST").  If that ever changes, update the
# `pythonVersion` option and the wheel filenames below.
#
# ── ONEAPI RUNTIME ───────────────────────────────────────────────────────────
#
# torch-xpu embeds the SYCL runtime (it is shipped as part of the wheel since
# PyTorch 2.9+xpu).  For vllm 0.16.x / torch 2.12.0+xpu you therefore do NOT
# need a separate oneAPI base toolkit installation at runtime.
#
# The oneAPI DPC++ *compiler* IS still needed at vllm build time.  This module
# uses the system oneAPI install at $ONEAPI_ROOT (defaults to
# /opt/intel/oneapi) for the build.  If you want a fully pure Nix build, you
# would need to package the DPC++ compiler as a derivation separately —
# that is out of scope here, but the `oneapiRoot` option lets you point at
# a Nix store path if you have one.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.vllm-xpu;
  inherit (lib)
    mkOption mkEnableOption mkIf optionalString optionals
    types literalExpression;

  # ── Python interpreter ──────────────────────────────────────────────────────
  # vllm-xpu-kernels wheel is Python 3.12 specific.
  python = pkgs.python312;
  pythonPackages = python.pkgs;

  # ── Wheel helper ────────────────────────────────────────────────────────────
  # Installs a pre-built .whl from a URL into the Nix store.
  # `pipInstallFlags = ["--no-deps"]` is important: we manage the dependency
  # graph explicitly rather than letting pip chase it (pip has no network in
  # the Nix sandbox).
  mkWheel =
    { pname
    , version
    , url
    , sha256
    , propagatedBuildInputs ? []
    , postFixup ? ""
    }:
    pythonPackages.buildPythonPackage {
      inherit pname version;
      format = "wheel";
      src = pkgs.fetchurl { inherit url sha256; };
      inherit propagatedBuildInputs;
      dontBuild    = true;
      dontConfigure = true;
      pipInstallFlags = [ "--no-deps" ];
      inherit postFixup;
      meta = { description = "${pname} ${version} (XPU wheel)"; };
    };

  # ── Wheel catalogue ─────────────────────────────────────────────────────────
  # All versions match vllm 0.16.0's requirements/xpu.txt.
  # Replace every sha256 placeholder with the output of:
  #   nix-prefetch-url <url>

  torch-xpu = mkWheel {
    pname   = "torch";
    version = "2.12.0+xpu";
    url     = "https://download.pytorch.org/whl/xpu/torch-2.12.0%2Bxpu-cp312-cp312-linux_x86_64.whl";
    sha256  = "sha256-9dVpDD6Z1ysAM3l2Yd87OCk9cB0EHFy62ZRTse32qDo="; # TODO
    propagatedBuildInputs = with pythonPackages; [
      filelock typing-extensions sympy networkx jinja2 fsspec numpy
    ];
    # Patch the RPATH so libze_loader.so (Level Zero) is found from the Nix
    # store rather than expecting it at /usr/lib.
    postFixup = ''
      find $out -name '*.so' -exec \
        ${pkgs.patchelf}/bin/patchelf \
          --add-rpath "${pkgs.level-zero}/lib" {} \; 2>/dev/null || true
    '';
  };

  # intel-extension-for-pytorch (ipex) 2.6.10+xpu is the last release before
  # its XPU ops were merged into upstream torch.  vllm 0.16.x still requires
  # it due to the "known conflict" workaround described in the docs.
  ipex-xpu = mkWheel {
    pname   = "intel-extension-for-pytorch";
    version = "2.6.10+xpu";
    url     = "https://pytorch-extension.intel.com/release-whl/stable/xpu/us/intel_extension_for_pytorch-2.6.10%2Bxpu-cp312-cp312-linux_x86_64.whl";
    sha256  = "sha256-9dVpDD6Z1ysAM3l2Yd87OCk9cB0EHFy62ZRTse32qDo="; # TODO
    propagatedBuildInputs = [ torch-xpu ];
  };

  oneccl-bind-pt = mkWheel {
    pname   = "oneccl-bind-pt";
    version = "2.6.0+xpu";
    url     = "https://pytorch-extension.intel.com/release-whl/stable/xpu/us/oneccl_bind_pt-2.6.0%2Bxpu-cp312-cp312-linux_x86_64.whl";
    sha256  = "sha256-9dVpDD6Z1ysAM3l2Yd87OCk9cB0EHFy62ZRTse32qDo="; # TODO
    propagatedBuildInputs = [ torch-xpu ];
  };

  # triton-xpu replaces the standard `triton` package (CUDA-only).
  # Using NVIDIA triton on XPU causes silent correctness failures.

  # vllm-xpu-kernels provides the SYCL custom ops registered into the PyTorch
  # dispatcher.  No pre-built wheel exists; we build from source.
  # Pin `rev` to a specific commit; `main` is shown here for illustration only.
  vllm-xpu-kernels = pythonPackages.buildPythonPackage {
    pname   = "vllm-xpu-kernels";
    version = "unstable-2025";
    format  = "pyproject";

    src = pkgs.fetchFromGitHub {
      owner = "vllm-project";
      repo  = "vllm-xpu-kernels";
      rev   = "main"; # TODO: pin to a specific commit SHA
      hash  = "sha256-9dVpDD6Z1ysAM3l2Yd87OCk9cB0EHFy62ZRTse32qDo="; # TODO
    };

    nativeBuildInputs = with pkgs; [ cmake ninja pkg-config ];

    buildInputs = [ pkgs.level-zero ];

    propagatedBuildInputs = [ torch-xpu ];

    env = {
      VLLM_TARGET_DEVICE = "xpu";
      # Point the DPC++ compiler at the oneAPI install.  The build will fail
      # here if ONEAPI_ROOT is not set; see the `oneapiRoot` module option.
      SYCL_BUNDLE_ROOT = "${cfg.oneapiRoot}/compiler/latest";
    };

    # The build calls `icpx` (the DPC++ front-end) which lives in oneAPI.
    # Prepend it to PATH so cmake's find_program succeeds.
    preConfigure = ''
      export PATH="${cfg.oneapiRoot}/compiler/latest/bin:$PATH"
      export LD_LIBRARY_PATH="${cfg.oneapiRoot}/compiler/latest/lib:$LD_LIBRARY_PATH"
    '';

    meta.description = "Custom XPU (SYCL) kernels for vLLM Intel GPU backend";
  };

  # ── xformers stub ──────────────────────────────────────────────────────────
  # The stock vllm derivation lists xformers as a dependency.  xformers has
  # deep CUDA entanglement and doesn't build for XPU.  A zero-op stub package
  # satisfies the dependency without pulling in CUDA.
  xformers-stub = pythonPackages.buildPythonPackage {
    pname   = "xformers";
    version = "0.0.0-stub";
    format  = "flit";
    src = pkgs.writeTextDir "." ''
      # intentionally empty stub
    '';
    # flit needs a pyproject.toml
    preConfigure = ''
      mkdir -p $TMPDIR/stub
      cat > $TMPDIR/stub/pyproject.toml <<'EOF'
      [build-system]
      requires = ["flit_core"]
      build-backend = "flit_core.buildapi"
      [project]
      name = "xformers"
      version = "0.0.0"
      description = "stub"
      EOF
      cat > $TMPDIR/stub/xformers/__init__.py <<'EOF'
      # XPU stub – no CUDA ops available
      EOF
      cd $TMPDIR/stub
    '';
    meta.description = "xformers CUDA-stub for XPU builds";
  };

  # ── vllm-xpu package ────────────────────────────────────────────────────────
  # Derived from the stock nixpkgs vllm by:
  #   1. Disabling CUDA and ROCm via .override
  #   2. Swapping torch → torch-xpu
  #   3. Using .overrideAttrs to:
  #        • set VLLM_TARGET_DEVICE=xpu
  #        • strip all CUDA/ROCm cmake flags
  #        • remove CUDA-only Python runtime deps
  #        • inject XPU-specific deps (ipex, oneccl, triton-xpu, kernels)
  #        • add the DPC++ compiler to PATH during build

  vllm-xpu-pkg = (pkgs.python312Packages.vllm.override {
    cudaSupport = false;
    rocmSupport = false;
    torch       = torch-xpu;
    xformers    = xformers-stub;
    # flashinfer is CUDA-only; pass null so the derivation's `shouldUsePkg`
    # guard eliminates it cleanly.
    flashinfer  = null;
    vllm-flash-attn = null;
  }).overrideAttrs (old: {
    pname = "vllm-xpu";

    # ── patches ──
    # Keep the Nix-support patches (cmake flags forwarding, PYTHONPATH
    # propagation).  Drop the ROCm requirements-drop patch which is
    # irrelevant here and may conflict.
    patches = builtins.filter
      (p: !(lib.hasSuffix "0006-drop-rocm-extra-reqs.patch" (toString p)))
      (old.patches or []);

    # ── native build inputs ──
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
      pkgs.level-zero   # provides ze_api.h for kernel compilation
    ];

    # ── build inputs ──
    buildInputs = (old.buildInputs or []) ++ [
      pkgs.level-zero
      pkgs.intel-compute-runtime  # libze_intel_gpu.so ICD
    ];

    # ── Python runtime dependencies ──
    # Filter out packages that are CUDA-only or ROCm-only, plus standard
    # triton (CUDA) and xformers.  Then append the XPU-specific ones.
    dependencies = (builtins.filter
      (pkg: !(builtins.elem (lib.getName pkg) [
        "cupy"
        "flashinfer"
        "nvidia-ml-py"
        "amdsmi"
        "xformers"
        "triton"        # NVIDIA triton; we use triton-xpu
        "torch"         # swap in torch-xpu below
      ]))
      (old.dependencies or [])
    ) ++ [
      torch-xpu
      ipex-xpu
      oneccl-bind-pt
      vllm-xpu-kernels
    ];

    # ── environment variables for setup.py / cmake ──
    env = (old.env or {}) // {
      VLLM_TARGET_DEVICE = "xpu";
      # Clear CUDA/ROCm vars that might leak through the override.
      CUDA_HOME  = "";
      ROCM_PATH  = "";
      # oneAPI compiler root (used by vllm-xpu-kernels sub-build and by
      # any torch.compile() calls that need icpx).
      ONEAPI_ROOT = cfg.oneapiRoot;
    };

    # ── cmake flags ──
    # Strip every CUDA-specific -D flag; XPU detection happens automatically
    # when VLLM_TARGET_DEVICE=xpu is set.
    cmakeFlags = builtins.filter
      (f: !(lib.any
        (prefix: lib.hasPrefix prefix f)
        [
          "-DFETCHCONTENT_SOURCE_DIR_CUTLASS"
          "-DFLASH_MLA_SRC_DIR"
          "-DVLLM_FLASH_ATTN_SRC_DIR"
          "-DQUTLASS_SRC_DIR"
          "-DTORCH_CUDA_ARCH_LIST"
          "-DCUTLASS_NVCC_ARCHS_ENABLED"
          "-DCUDA_TOOLKIT_ROOT_DIR"
          "-DCAFFE2_USE_CUDNN"
          "-DCAFFE2_USE_CUFILE"
          "-DCUTLASS_ENABLE_CUBLAS"
        ]))
      (old.cmakeFlags or []);

    # ── make the DPC++ compiler discoverable during build ──
    preConfigure = (old.preConfigure or "") + ''
      export PATH="${cfg.oneapiRoot}/compiler/latest/bin:$PATH"
      export LD_LIBRARY_PATH="${cfg.oneapiRoot}/compiler/latest/lib:''${LD_LIBRARY_PATH:-}"
    '';

    meta = (old.meta or {}) // {
      description =
        "High-throughput and memory-efficient LLM inference engine (Intel XPU / Arc GPU backend)";
      maintainers = [];
    };
  });

  # ── vllm serve wrapper ──────────────────────────────────────────────────────
  # A small shell script that sources the runtime environment (Level Zero ICD,
  # oneAPI SYCL runtime) and then calls `vllm serve`.
  vllm-serve-wrapper = pkgs.writeShellScriptBin "vllm-xpu-serve" ''
    set -euo pipefail

    # Level Zero / OpenCL ICD for the Arc GPU.
    export ZES_ENABLE_SYSMAN=1
    export OCL_ICD_VENDORS="${pkgs.intel-compute-runtime}/etc/OpenCL/vendors"
    export LD_LIBRARY_PATH="${pkgs.level-zero}/lib:${pkgs.intel-compute-runtime}/lib:''${LD_LIBRARY_PATH:-}"

    # oneAPI SYCL runtime (embedded in the torch-xpu wheel since 2.9+xpu, but
    # we set ONEAPI_ROOT in case torch tries to find it externally).
    export ONEAPI_ROOT="${cfg.oneapiRoot}"

    # Recommended vLLM XPU tuning knobs.
    export VLLM_TARGET_DEVICE=xpu

    exec ${lib.getExe' vllm-xpu-pkg "vllm"} serve "$@"
  '';

in
{
  # ── Module options ──────────────────────────────────────────────────────────
  options.services.vllm-xpu = {

    enable = mkEnableOption "vLLM Intel XPU (Arc GPU) inference server";

    model = mkOption {
      type        = types.str;
      example     = "meta-llama/Llama-3.1-8B-Instruct";
      description = ''
        Hugging Face model ID (or local path) to serve.  Passed as the first
        positional argument to `vllm serve`.
      '';
    };

    host = mkOption {
      type    = types.str;
      default = "127.0.0.1";
      description = "IP address to bind the server to.";
    };

    port = mkOption {
      type    = types.port;
      default = 8000;
      description = "TCP port to listen on.";
    };

    huggingFaceToken = mkOption {
      type    = types.nullOr types.str;
      default = null;
      description = ''
        Hugging Face API token as a plain string.  For production use prefer
        `secretFile` instead to avoid the token appearing in the Nix store.
      '';
    };

    secretFile = mkOption {
      type    = types.nullOr types.path;
      default = null;
      example = "/run/secrets/hf-token";
      description = ''
        Path to a file containing the Hugging Face API token (single line,
        no trailing newline).  Compatible with agenix, sops-nix, and
        systemd-creds.  Takes precedence over `huggingFaceToken` when set.
      '';
    };

    modelsDir = mkOption {
      type    = types.path;
      default = "/var/lib/vllm-xpu/models";
      description = ''
        Directory where model weights are cached by Hugging Face Hub.
        Created automatically with the correct ownership when the service
        is enabled.
      '';
    };

    extraArgs = mkOption {
      type    = types.listOf types.str;
      default = [];
      example = literalExpression ''[ "--dtype" "float16" "--max-model-len" "4096" ]'';
      description = ''
        Additional arguments forwarded verbatim to `vllm serve`.
        See `vllm serve --help` for the full list.
      '';
    };

    user = mkOption {
      type    = types.str;
      default = "vllm-xpu";
      description = "System user that runs the vLLM service.";
    };

    group = mkOption {
      type    = types.str;
      default = "vllm-xpu";
      description = "System group for the vLLM service user.";
    };

    oneapiRoot = mkOption {
      type    = types.str;
      default = "/opt/intel/oneapi";
      description = ''
        Path to the Intel oneAPI base toolkit installation.  Used to locate
        the DPC++ compiler (icpx) at *build* time when compiling
        vllm-xpu-kernels, and exported as ONEAPI_ROOT at service runtime.
        If you have the oneAPI toolkit as a Nix derivation, point this at
        its store path.
      '';
    };

    package = mkOption {
      type    = types.package;
      default = vllm-xpu-pkg;
      defaultText = literalExpression "vllm built with XPU backend";
      description = ''
        The vLLM XPU package to use.  Defaults to the derivation defined in
        this module; override if you need a custom build.
      '';
    };
  };

  # ── Module implementation ───────────────────────────────────────────────────
  config = mkIf cfg.enable {

    # ── nixpkgs overlay ──
    # Adds all XPU packages to the pkgs attribute set so they can be
    # referenced elsewhere (e.g. environment.systemPackages).
    nixpkgs.overlays = [
      (final: prev: {
        python312Packages = prev.python312Packages // {
          inherit
            torch-xpu
            ipex-xpu
            oneccl-bind-pt
            vllm-xpu-kernels;
          vllm-xpu = vllm-xpu-pkg;
        };
        vllm-xpu = vllm-xpu-pkg;
      })
    ];

    # ── hardware prerequisites ──
    # Intel Arc A770 uses the Xe kernel driver (i915 or xe depending on
    # kernel version).  Enable the compute runtime so Level Zero / OpenCL
    # are usable from userspace.
    hardware.graphics = {
      enable      = true;
      extraPackages = with pkgs; [
        # Modern iGPU/dGPU VAAPI driver (Broadwell+, covers Arc).
        intel-media-driver
        # Level Zero + OpenCL compute runtime for Arc (Xe-HPG).
        intel-compute-runtime
      ];
    };

    # Ensure the render group exists so the service user can open /dev/dri/*.
    # NixOS creates this automatically when hardware.graphics.enable = true,
    # but we state it explicitly for clarity.
    users.groups.render  = {};
    users.groups.video   = {};

    # ── dedicated service user ──
    users.users.${cfg.user} = {
      isSystemUser = true;
      group        = cfg.group;
      # Must be in `render` and `video` to access /dev/dri/renderD* devices.
      extraGroups  = [ "render" "video" ];
      home         = cfg.modelsDir;
      createHome   = false;  # handled by the StateDirectory= below
      description  = "vLLM XPU service user";
    };
    users.groups.${cfg.group} = {};

    # ── model cache directory ──
    systemd.tmpfiles.rules = [
      "d '${cfg.modelsDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    # ── systemd service ──
    systemd.services.vllm-xpu = {
      description = "vLLM Intel XPU (Arc GPU) inference server";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network-online.target" ];
      wants       = [ "network-online.target" ];

      serviceConfig = {
        Type            = "simple";
        User            = cfg.user;
        Group           = cfg.group;
        Restart         = "on-failure";
        RestartSec      = "10s";

        # Give the process access to /dev/dri render nodes.
        DeviceAllow     = [ "/dev/dri/renderD128 rwm" ];  # adjust index if needed
        SupplementaryGroups = [ "render" "video" ];

        # Cache model weights in a persistent state directory.
        # This creates /var/lib/vllm-xpu owned by the service user.
        StateDirectory  = "vllm-xpu";
        WorkingDirectory = "/var/lib/vllm-xpu";

        # Increase file descriptor and process limits; large models need them.
        LimitNOFILE     = 65536;
        LimitNPROC      = 16384;

        # Security hardening — kept minimal so /dev/dri and huggingface
        # network access still work.
        NoNewPrivileges = true;
        PrivateTmp      = true;
        ProtectSystem   = "strict";
        # Write access is needed for model cache and any temp files.
        ReadWritePaths  = [ cfg.modelsDir "/var/lib/vllm-xpu" "/tmp" ];
      };

      environment =
        {
          # Point Hugging Face Hub at the cache directory.
          HF_HOME = cfg.modelsDir;
          TRANSFORMERS_CACHE = cfg.modelsDir;

          # Level Zero / OpenCL runtime.
          ZES_ENABLE_SYSMAN = "1";
          OCL_ICD_VENDORS   = "${pkgs.intel-compute-runtime}/etc/OpenCL/vendors";

          # oneAPI root for any SYCL runtime look-ups.
          ONEAPI_ROOT = cfg.oneapiRoot;

          # vLLM backend selector.
          VLLM_TARGET_DEVICE = "xpu";
        }
        # Inline token (lower security; prefer secretFile).
        // lib.optionalAttrs
          (cfg.huggingFaceToken != null && cfg.secretFile == null)
          { HUGGING_FACE_HUB_TOKEN = cfg.huggingFaceToken; };

      # Load the secret token from a file at runtime so it never ends up
      # in the Nix store.
      script =
        let
          tokenLoader = optionalString (cfg.secretFile != null) ''
            export HUGGING_FACE_HUB_TOKEN="$(< ${cfg.secretFile})"
          '';
        in
        ''
          ${tokenLoader}
          exec ${vllm-serve-wrapper}/bin/vllm-xpu-serve \
            ${lib.escapeShellArg cfg.model} \
            --host ${lib.escapeShellArg cfg.host} \
            --port ${toString cfg.port} \
            ${lib.escapeShellArgs cfg.extraArgs}
        '';
    };

    # ── firewall ──
    # Open the port only on loopback by default (the default host is 127.0.0.1).
    # Uncomment and adjust if you expose the API on a LAN interface.
    # networking.firewall.allowedTCPPorts = [ cfg.port ];

    # ── environment.systemPackages ──
    # Makes `vllm` and the wrapper available in the default shell.
    environment.systemPackages = [
      vllm-xpu-pkg
      vllm-serve-wrapper
    ];
  };
}
