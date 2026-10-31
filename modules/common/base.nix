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
    ./network-metrics.nix
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
  # Several hosts have both a fast (10/40Gb) data NIC and a slow (1Gb)
  # management NIC on the same subnet; NetworkManager assigns route metrics
  # by activation order, not speed, which has left the 1Gb link winning the
  # default route on fatman-1 and all four thunder-budget hosts. This pins
  # metric to actual link speed everywhere instead.
  networking.preferFastestRoute.enable = true;
  services.resolved = {
    enable = true;
    settings.Resolve.MulticastDNS = "resolve";
  };
  # glibc's default address-selection policy (RFC 6724) ranks any native
  # IPv6 answer -- including a link-local fe80:: one, which isn't carved
  # out separately in the default table -- above plain IPv4. Combined with
  # systemd-resolved's mDNS resolution answering both A and AAAA, a plain
  # lookup of a *.local name picks the IPv6 link-local address first even
  # though an IPv4 address (the one actually wanted for cross-host service
  # URLs in this repo) resolves fine too. This is the standard documented
  # fix (see `man gai.conf`'s own example) to make IPv4 win when both are
  # available, without disabling IPv6 itself.
  environment.etc."gai.conf".text = ''
    precedence ::ffff:0:0/96  100
  '';

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
  services.tailscale.enable = true;

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
  };
}
