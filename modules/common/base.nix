{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    flake-inputs.home-manager.nixosModules.default
    flake-inputs.agenix.nixosModules.default
    ./overlays.nix
    ../nix-settings.nix
    ../avahi.nix
    ../../users/branden
    ../monitoring
    ../cluster/attic.nix
  ];

  scl.monitoring.enable = true;

  # Every host pulls from the shared cache by default; pushing to it is a
  # separate opt-in (see modules/cluster/push.nix and modules/cluster/default.nix)
  # since it requires the attic-push-token secret, which not every host has.
  cluster.atticClient = {
    enable = true;
    endpoint = "http://big-nix.local:8080";
    cache = "main";
    publicKey = "main:68CBhPmqKQZsyCiOOhn247PkST3KwiFNNCREFb8REho=";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  services.resolved = {
    enable = true;
    settings.Resolve.MulticastDNS = "resolve";
  };

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

  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
  };
}
