# gpus.nix
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config;
in
{
  options.hardware.gpu.intel = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Intel GPU support";
    };

    cards = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of Intel GPU cards to enable specific support for";
    };
  };

  config = mkIf cfg.hardware.gpu.intel.enable (mkMerge [
    {
      services.xserver.videoDrivers = [ "modesetting" ];

      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          # Required for modern Intel GPUs (Xe iGPU and ARC)
          intel-media-driver # VA-API (iHD) userspace
          vpl-gpu-rt # oneVPL (QSV) runtime

          # Optional (compute / tooling):
          intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
          intel-compute-runtime.drivers
          level-zero
          intel-graphics-compiler

          # NOTE: 'intel-ocl' also exists as a legacy package; not recommended for Arc/Xe.
          # libvdpau-va-gl       # Only if you must run VDPAU-only apps
        ];
      };

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD"; # Prefer the modern iHD backend
        # VDPAU_DRIVER = "va_gl";      # Only if using libvdpau-va-gl

        # Make the Intel GPU compute stack discoverable to *foreign* (non-Nix)
        # dynamically-linked programs — most importantly pip/uv-installed
        # PyTorch XPU wheels.
        #
        # The torch-xpu wheel bundles the whole oneAPI/SYCL runtime EXCEPT the
        # Level Zero loader: its Unified Runtime adapter dlopen()s
        # "libze_loader.so.1" at runtime, which in turn loads the Intel Level
        # Zero driver "libze_intel_gpu.so.1". Both live in /run/opengl-driver/lib
        # (populated by hardware.graphics + intel-compute-runtime below).
        #
        # nix-ld alone is NOT sufficient here: it seeds the initial binary's
        # search path via NIX_LD_LIBRARY_PATH but does not export
        # LD_LIBRARY_PATH, so a runtime dlopen() by name still fails. Exporting
        # LD_LIBRARY_PATH makes
        #   uv sync && python -c 'import torch; assert torch.xpu.is_available()'
        # work with no per-project setup.
        #
        # Placed in sessionVariables (not environment.variables) so it is set
        # for both interactive login shells (/etc/set-environment) and
        # non-interactive ssh sessions (/etc/pam/environment via pam_env). The
        # ''${LD_LIBRARY_PATH} reference is braced so it expands in *both* the
        # shell-sourced file and the pam_env file (pam_env only understands the
        # braced form; a bare $VAR would be treated as literal text). This
        # directory contains only GPU driver libraries (no libc/libstdc++/etc.),
        # so it is safe to prepend globally.
        LD_LIBRARY_PATH = "/run/opengl-driver/lib:\${LD_LIBRARY_PATH}";
      };

      environment.systemPackages = with pkgs; [
        intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
        intel-compute-runtime.drivers
        level-zero
        intel-graphics-compiler
        clinfo
        nvtopPackages.intel
      ];

      # May help if FFmpeg/VAAPI/QSV init fails (esp. on Arc with i915):
      hardware.enableRedistributableFirmware = true;
      boot.kernelParams = [
        "xe.force_probe=*"
        "i915.force_probe=!56a0"
      ];

      boot.blacklistedKernelModules = [ "i915" ];

    }

    (mkIf (builtins.elem "a770" cfg.hardware.gpu.intel.cards) {

      # Card-specific configurations

    })
  ]);

}
