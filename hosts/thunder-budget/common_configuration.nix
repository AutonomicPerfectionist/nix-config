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
    ../../modules/cluster/rdma.nix
    ../../modules/input-methods.nix
    ../../modules/common/overlays.nix
    flake-inputs.home-manager.nixosModules.default

    # Users
    ../../users/branden
    ../../users/remotebuild
  ];

  nix.settings.system-features = ["nixos-test" "benchmark" "big-parallel" "kvm" "gccarch-ivybridge"];

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.swapspace.enable = true;
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  hardware.infiniband.enable = true;
  cluster.rdma.enable = true;

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
