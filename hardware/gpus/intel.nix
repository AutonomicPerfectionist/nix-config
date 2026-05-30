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
      };

      environment.systemPackages = with pkgs; [
        intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
        intel-compute-runtime.drivers
        level-zero
        intel-graphics-compiler
        sycl-info
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
