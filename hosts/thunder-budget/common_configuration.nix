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
    ../../modules/ml/llama.nix
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/distributed.nix
    ../../modules/input-methods.nix
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

  # Kernel 6.12 has the ib_qib module needed for the infiniband cards
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  hardware.infiniband.enable = true;

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
