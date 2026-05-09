{
  # Queen-blue - Cluster compute node with Intel Arc GPU
  # Note: SYCL overlay enabled for llama-cpp-sycl
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    flake-inputs.home-manager.nixosModules.default
    ../../modules/nix-settings.nix
    # NFS cluster mounts
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/distributed.nix
    # GPU drivers
    ../../hardware/gpus/gpus.nix
    ../../modules/common/overlays.nix
    ../../modules/common/base.nix
    ../../users/branden
  ];

  # Enable SYCL + Intel Arc overlay stack for compute workloads
  scl.overlays.sycl-intel = true;

  userconfig.branden = {
    enable = true;
    hostname = "queen-blue";
  };

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.graphics.enable = true;
  hardware.gpu.intel.enable = true;

  networking.hostName = "queen-blue";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.avahi = {
    enable = true;
    nssmdns = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
      addresses = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    micro
    htop
    xclip
    llama-cpp-sycl
  ];

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
