{
  # Hypergamma - Desktop workstation with AMD GPU, multiple DE support
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
    flake-inputs.home-manager.nixosModules.default
    ./hardware-configuration.nix
    ./disk-config.nix

    # USERS (make sure there's at least one!!)
    ../../users/branden

    # CUSTOM MODULES
    ../../modules/nix-settings.nix
    ../../modules/avahi.nix
    ../../modules/amdgpu.nix
    ../../modules/gnome.nix
    ../../modules/cosmic.nix
    ../../modules/hyprland.nix
    ../../modules/gaming.nix
    ../../modules/gnupg.nix
    ../../modules/flatpak.nix
    ../../modules/nix-ld.nix

    # local modules
    ./tailscale.nix
    ./frpc.nix
  ];

  # Users config
  userconfig.branden = {
    enable = true;
    hostname = hostname;
  };

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 8;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # set kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # set kernel module params
  # boot.extraModprobeConfig = ''
  # options usbhid mousepoll=8 jspoll=8 quirks=0x045e:0x028e:0x0400
  # '';

  # get wireshark workin
  programs.wireshark.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="usbmon", GROUP="wireshark", MODE="0640"
  '';

  networking.hostName = hostname;

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
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


  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Use GDM even if we're not on Gnome
  services.displayManager.gdm.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
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
      ungoogled-chromium
      vesktop
      brave
      pavucontrol
      parsec-bin
      godot_4
      wireshark
      qbittorrent
      rpcs3
      pcsx2
      libreoffice
      calibre
      obs-studio
      networkmanagerapplet
      pkgs.kdePackages.kdenlive
      audacity
      nixfmt
      # helvum
      normcap
      gnome-frog
      gImageReader
      cosmic-store
      musescore
      muse-sounds-manager
      handbrake
      trashy
      archipelago
      poptracker

      # system stuff, maybe modularize this later?
      usbutils
      sysfsutils
      libinput
      gnumake
      vulkan-tools
      iputils
    ]
    ++ [
      ### packages from flakes ###
      flake-inputs.agenix.packages.${flake-inputs.system}.default
    ];
  programs.zoom-us.enable = true;

  # Services

  services.openssh.enable = true;
  virtualisation.docker.enable = true;




  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11";
}
