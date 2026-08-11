# gpus.nix
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.hardware.gpu.nvidia;

  # Metadata for supported GPUs
  #
  # Keep this table declarative so multiple cards can safely coexist.
  # Any conflicting settings are resolved globally below.
  gpuProfiles = {
    quadro_m6000 = {
      # Maxwell-generation cards require the legacy driver branch
      driver = "legacy_580";

      # CUDA compute capability for Quadro M6000
      cudaCapabilities = [ "5.2" ];
    };

    tesla_p40 = {
      # Pascal-generation cards currently also use legacy_580
      driver = "legacy_580";

      # CUDA compute capability for Tesla P40
      cudaCapabilities = [ "6.1" ];
    };

    tesla_v100 = {
      # Volta-generation cards currently also use legacy_580
      driver = "legacy_580";

      # CUDA compute capability for Tesla V100
      cudaCapabilities = [ "7.0" ];
    };

    rtx_3090 = {
      # Ampere-generation cards use the stable driver branch
      driver = "stable";

      # CUDA compute capability for RTX 3090
      cudaCapabilities = [ "8.6" ];
    };
  };

  # Driver preference order.
  #
  # Earlier entries are considered "more compatible".
  #
  # If multiple GPUs request different driver branches,
  # the oldest/common denominator driver is selected.
  #
  # Example:
  #   [ "legacy_580" "stable" ]
  # becomes:
  #   "legacy_580"
  #
  driverPriority = [
    "legacy_470"
    "legacy_535"
    "legacy_580"
    "stable"
    "beta"
  ];

  # Resolve enabled GPU metadata
  enabledProfiles = map (card: gpuProfiles.${card}) (filter (card: gpuProfiles ? ${card}) cfg.cards);

  # Determine the most compatible driver branch across all selected cards
  selectedDriver =
    let
      drivers = unique (map (p: p.driver) enabledProfiles);

      hasDriver = drv: builtins.elem drv drivers;
    in
    findFirst hasDriver "stable" driverPriority;

  # Merge all requested CUDA capabilities so binaries can target all GPUs
  mergedCudaCapabilities = unique (flatten (map (p: p.cudaCapabilities) enabledProfiles));

  # Resolve actual driver package object
  nvidiaPackage =
    if selectedDriver == "stable" then
      config.boot.kernelPackages.nvidiaPackages.stable
    else if selectedDriver == "beta" then
      config.boot.kernelPackages.nvidiaPackages.beta
    else
      config.boot.kernelPackages.nvidiaPackages.${selectedDriver};

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

  config = mkIf cfg.enable {

    # NOTE: For docker passthrough, may need:
    #   --device=nvidia.com/gpu=all
    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia
      cudatoolkit
    ];

    nixpkgs.config = {
      nvidia.acceptLicense = true;

      # Enable CUDA support globally
      cudaSupport = true;

      # Merge CUDA capabilities across all selected cards
      cuda.capabilities = mergedCudaCapabilities;

      # Compatibility alias used by some nixpkgs codepaths
      cudaCapabilities = mergedCudaCapabilities;
    };

    hardware.nvidia = {

      # Selected automatically from all configured cards.
      #
      # If multiple cards require different driver branches,
      # the most compatible branch is selected.
      package = nvidiaPackage;

      # Enable Nvidia settings menu
      # nvidiaSettings = mkIf config.hardware.graphics.enable false;

      # Modesetting is required
      modesetting.enable = false;

      # Nvidia power management.
      # Experimental, and can cause sleep/suspend to fail.
      powerManagement.enable = false;

      # Fine-grained power management.
      # Turns off GPU when not in use.
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module
      # (currently a little buggy so false)
      open = false;

      # Sometimes reduces performance,
      # but helps with TEARING (my mortal enemy)
      # forceFullCompositionPipeline = false;
      nvidiaPersistenced = true;
      gsp.enable = false;
      # datacenter.enable = true;
    };

    # Load Nvidia driver for X and Wayland
    services.xserver.videoDrivers = mkIf config.hardware.graphics.enable [ "nvidia" ];

    boot.kernel.sysctl = {
      "vm.min_free_kbytes" = 1048576; # 1GB; tune to your system
    };
    boot.blacklistedKernelModules = [ "nouveau" ];
    boot.kernelParams = [ "nouveau.modeset=0" ];
    # boot.extraModprobeConfig =
    #   "options nvidia "
    #   + lib.concatStringsSep " " [

    #     # nvidia assume that by default your CPU does not support PAT,
    #     # but this is effectively never the case in 2023
    #     "NVreg_UsePageAttributeTable=1"

    #     # This may be a noop,
    #     # but it's somewhat uncertain
    #     "NVreg_EnablePCIeGen3=1"

    #     # This is sometimes needed for ddc/ci support, see
    #     # https://www.ddcutil.com/nvidia/
    #     #
    #     # Current monitor does not support it,
    #     # but this is useful for the future
    #     "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"

    #     # When (if!) I get another nvidia GPU,
    #     # check for resizeable bar settings
    #   ];

    environment.variables = {

      # Required to run the correct GBM backend
      # for nvidia GPUs on wayland
      GBM_BACKEND = "nvidia-drm";

      # Apparently, without this nouveau may attempt to be used instead
      # (despite it being blacklisted)
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";

      # Hardware cursors are currently broken on nvidia
      WLR_NO_HARDWARE_CURSORS = "1";

      # CUDA runtime library path
      LD_LIBRARY_PATH = "${nvidiaPackage}/lib:${pkgs.cudatoolkit}/lib${
        optionalString (config.system.path != null) ":${config.system.path}/lib"
      }:$LD_LIBRARY_PATH";

      # CUDA toolkit root
      CUDA_PATH = "${pkgs.cudatoolkit}";

      # Linker/compiler flags for CUDA programs
      EXTRA_LDFLAGS = "-L/lib -L${nvidiaPackage}/lib";
      EXTRA_CCFLAGS = "-I/usr/include";
    };
  };
}
