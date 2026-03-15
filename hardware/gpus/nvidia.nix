# gpus.nix
{ config, lib, ... }:

with lib;

let
  cfg = config;
in
{
  options.hardware.gpu.nvidia = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable NVIDIA GPU support";
    };

    cards = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of NVIDIA GPU cards to enable specific support for";
    };
  };

  config = mkIf cfg.hardware.gpu.nvidia.enable (mkMerge [
    {
      # NOTE: For docker passthrough, may need:  --device=nvidia.com/gpu=all

      # Common NVIDIA configuration
      nixpkgs.config.nvidia.acceptLicense = true;
      hardware.nvidia = {
        # Enable Nvidia settings menu
        nvidiaSettings = mkIf cfg.hardware.graphics.enable true;
        
        # Modesetting is required
        modesetting.enable = true;

        # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
        powerManagement.enable = false;

        # Fine-grained power management. Turns off GPU when not in use.
        powerManagement.finegrained = false;

        # Use the NVidia open source kernel module (currently a little buggy so false)
        open = false;

        # Sometimes reduces performance, but helps with TEARING (my mortal enemy)
        # forceFullCompositionPipeline = false;

      };

      # Load Nvidia driver for X and Wayland
      services.xserver.videoDrivers = mkIf cfg.hardware.graphics.enable [ "nvidia" ];

      boot.extraModprobeConfig =
        "options nvidia "
        + lib.concatStringsSep " " [
          # nvidia assume that by default your CPU does not support PAT,
          # but this is effectively never the case in 2023
          "NVreg_UsePageAttributeTable=1"
          # This may be a noop, but it's somewhat uncertain
          "NVreg_EnablePCIeGen3=1"
          # This is sometimes needed for ddc/ci support, see
          # https://www.ddcutil.com/nvidia/
          #
          # Current monitor does not support it, but this is useful for
          # the future
          "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
          # When (if!) I get another nvidia GPU, check for resizeable bar
          # settings
        ];

      environment.variables = {
        # Required to run the correct GBM backend for nvidia GPUs on wayland
        GBM_BACKEND = "nvidia-drm";
        # Apparently, without this nouveau may attempt to be used instead
        # (despite it being blacklisted)
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        # Hardware cursors are currently broken on nvidia
        WLR_NO_HARDWARE_CURSORS = "1";
      };
    }

    (mkIf (builtins.elem "quadro_m6000" cfg.hardware.gpu.nvidia.cards){


      # Card-specific configurations
      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_390;
      };
    })
  ]);

}
