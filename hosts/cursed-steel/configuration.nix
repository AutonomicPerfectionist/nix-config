{
  config,
  pkgs,
  pkgs-stable,
  flake-inputs,
  ...
}:
let
  hostname = "cursed-steel";

  # XRT (Xilinx Runtime) userspace tools for AMD NPU
  nix-amd-ai-pkgs = flake-inputs.nix-amd-ai.packages.${pkgs.stdenv.hostPlatform.system};
  xrt-combined = pkgs.symlinkJoin {
    name = "xrt-combined";
    paths = [
      nix-amd-ai-pkgs.xrt
      nix-amd-ai-pkgs.xrt-plugin-amdxdna
    ];
  };

  # AMD XDNA NPU out-of-tree kernel module
  amdxdna-module = pkgs.callPackage ../../pkgs/amdxdna-driver {
    kernel = pkgs.linuxPackages_latest.kernel;
  };

  # AMD XDNA NPU firmware from amd-ipu-staging branch
  amdxdna-firmware = pkgs.callPackage ../../pkgs/amdxdna-firmware { };
in
{
  imports = [
    flake-inputs.home-manager.nixosModules.default
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../hardware/gpus/nvidia.nix

    # USERS (make sure there's at least one!!)
    ../../users/branden

    # CUSTOM MODULES
    ../../modules/nix-settings.nix
    ../../modules/distributed-builds.nix
    ../../modules/common/overlays.nix
    ../../modules/avahi.nix
    # ../../modules/amdgpu.nix
    ../../modules/gnome.nix
    # ../../modules/cosmic.nix
    # ../../modules/hyprland.nix
    # ../../modules/gaming.nix
    ../../modules/gnupg.nix
    ../../modules/flatpak.nix
    ../../modules/nix-ld.nix
    ../../modules/ml/llama.nix
    ../../modules/graphical
    ../../modules/graphical/niri.nix
    ../../modules/graphical/noctalia.nix

  ];

  # Graphical desktop
  scl.graphical = {
    enable = true;
    niri.enable = true;
    noctalia.enable = true;
  };

  # Users config
  userconfig.branden = {
    enable = true;
    graphical = true;
    hostname = hostname;
  };

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };
  hardware.gpu.nvidia.enable = true;

  hardware.nvidia.prime = {
    intelBusId = "PCI:6:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };
  hardware.nvidia.modesetting.enable = true;

  # AMD NPU (XDNA 1) — out-of-tree kernel module + firmware + XRT userspace
  boot.extraModulePackages = [ amdxdna-module ];
  boot.kernelModules = [ "amdxdna" ];
  boot.extraModprobeConfig = ''
    install amdxdna ${pkgs.kmod}/bin/insmod /run/booted-system/kernel-modules/lib/modules/${pkgs.linuxPackages_latest.kernel.modDirVersion}/extra/amdxdna.ko
  '';

  hardware.firmware = [ amdxdna-firmware ];

  services.udev.extraRules = ''
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", GROUP="video", MODE="0660"
  '';

  security.pam.loginLimits = [
    {
      domain = "*";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "*";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
  ];

  environment.sessionVariables = {
    XILINX_XRT = "${xrt-combined}/opt/xilinx/xrt";
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

  # cursed-steel only has 16GB DDR5, which is not enough for nix-index
  services.swapspace.enable = true;

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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
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
      # ungoogled-chromium
      vesktop
      # brave
      pavucontrol
      # parsec-bin
      # godot_4
      # wireshark
      qbittorrent
      # rpcs3
      # pcsx2
      libreoffice
      # calibre
      # obs-studio
      networkmanagerapplet
      # pkgs.kdePackages.kdenlive
      # audacity
      nixfmt
      # helvum
      normcap
      gnome-frog
      gImageReader
      cosmic-store
      musescore
      muse-sounds-manager
      # handbrake
      trashy
      # archipelago
      # poptracker

      # system stuff, maybe modularize this later?
      usbutils
      sysfsutils
      libinput
      gnumake
      vulkan-tools
      iputils

      # AMD NPU userspace tools (xrt-smi, xclbinutil, etc.)
      xrt-combined
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
  system.stateVersion = "26.05";
}
