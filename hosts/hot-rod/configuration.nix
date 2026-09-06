{
  config,
  pkgs,
  pkgs-stable,
  flake-inputs,
  ...
}:
let
  hostname = "hot-rod";
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./tailscale.nix
    ../../hardware/gpus/nvidia.nix

    ../../modules/distributed-builds.nix
    ../../modules/gnome.nix
    ../../modules/gnupg.nix
    ../../modules/flatpak.nix
    ../../modules/nix-ld.nix
    ../../modules/ml/llama.nix
    ../../modules/ml/tools.nix
    ../../modules/graphical
    ../../modules/graphical/niri.nix
    ../../modules/graphical/noctalia.nix
    ../../modules/cluster
    ../../modules/gaming.nix
  ];

  scl.graphical = {
    enable = true;
    niri.enable = true;
    noctalia.enable = true;
  };


  userconfig.branden = {
    enable = true;
    graphical = true;
    hostname = hostname;
  };

  hardware.gpu.nvidia.enable = true;
  hardware.gpu.nvidia.cards = [
    "rtx_3090"
  ];

  boot.loader.systemd-boot.configurationLimit = 8;


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
  fileSystems."/nix" = {
     device = "/dev/disk/by-uuid/ad2dc486-7ca9-4e67-958a-02652be5cdf6";
     fsType = "ext4";
     neededForBoot = true;
     options = [ "noatime" ];
   };

  system.stateVersion = "23.11";
}
