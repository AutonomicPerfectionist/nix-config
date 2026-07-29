{
  config,
  pkgs,
  pkgs-stable,
  flake-inputs,
  ...
}:
let
  hostname = "battle-bucket";
in
{
  imports = [
    flake-inputs.nixos-hardware.nixosModules.dell-g3-3779
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../hardware/gpus/nvidia.nix

    ../../modules/battery.nix
    ../../modules/distributed-builds.nix
    ../../modules/gnome.nix
    ../../modules/gnupg.nix
    ../../modules/flatpak.nix
    ../../modules/nix-ld.nix
    ../../modules/ml/llama.nix
    ../../modules/graphical
    ../../modules/graphical/niri.nix
    ../../modules/graphical/noctalia.nix
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/distributed.nix
  ];

  scl.graphical = {
    enable = true;
    niri.enable = true;
    noctalia.enable = true;
  };

  scl.battery = {
    enable = true;
    chargeLimit = 80;
  };

  userconfig.branden = {
    enable = true;
    graphical = true;
    hostname = hostname;
  };

  hardware.gpu.nvidia.enable = true;

  boot.loader.systemd-boot.configurationLimit = 8;

  services.udev.extraRules = ''
    SUBSYSTEM=="usbmon", GROUP="wireshark", MODE="0640"
  '';

  networking.hostName = hostname;

  programs.firefox.enable = true;

  environment.systemPackages =
    with pkgs;
    [
      vim
      wget
      curl
      git
      htop
      btop
      dig
      traceroute
      nmap
      vesktop
      pavucontrol
      qbittorrent
      libreoffice
      networkmanagerapplet
      nixfmt
      normcap
      gnome-frog
      gImageReader
      cosmic-store
      musescore
      muse-sounds-manager
      trashy

      usbutils
      sysfsutils
      libinput
      gnumake
      vulkan-tools
      iputils
    ]
    ++ [
      flake-inputs.agenix.packages.${flake-inputs.system}.default
    ];

  programs.zoom-us.enable = true;

  services.openssh.settings = {
    X11Forwarding = true;
  };
  virtualisation.docker.enable = true;

  system.stateVersion = "23.11";
}
