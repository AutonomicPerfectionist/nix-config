{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ../../modules/nix-settings.nix
    ../../modules/avahi.nix
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/distributed.nix
    ../../modules/input-methods.nix
    ../../modules/ml/llama.nix
    ../../hardware/gpus/gpus.nix
    ../../modules/common/overlays.nix
    flake-inputs.home-manager.nixosModules.default

    # Users
    ../../users/branden
  ];

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

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    micro
    htop
    xclip

  ];

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
