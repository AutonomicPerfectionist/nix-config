{
  config,
  pkgs,
  pkgs-stable,
  flake-inputs,
  ...
}:
let
  hostname = "cursed-steel";

  nix-amd-ai-pkgs = flake-inputs.nix-amd-ai.packages.${pkgs.stdenv.hostPlatform.system};
  xrt-combined = pkgs.symlinkJoin {
    name = "xrt-combined";
    paths = [
      nix-amd-ai-pkgs.xrt
      nix-amd-ai-pkgs.xrt-plugin-amdxdna
    ];
  };

  amdxdna-module = pkgs.callPackage ../../pkgs/amdxdna-driver {
    kernel = pkgs.linuxPackages_latest.kernel;
  };

  amdxdna-firmware = pkgs.callPackage ../../pkgs/amdxdna-firmware { };
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../hardware/gpus/nvidia.nix

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

  userconfig.branden = {
    enable = true;
    graphical = true;
    hostname = hostname;
  };

  hardware.gpu.nvidia.enable = true;

  hardware.nvidia.prime = {
    intelBusId = "PCI:6:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };
  hardware.nvidia.modesetting.enable = true;

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
  boot.loader.systemd-boot.configurationLimit = 8;

  services.swapspace.enable = true;

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

      xrt-combined
    ]
    ++ [
      flake-inputs.agenix.packages.${flake-inputs.system}.default
    ];

  programs.zoom-us.enable = true;

  services.openssh.settings = {
    X11Forwarding = true;
  };
  virtualisation.docker.enable = true;

  system.stateVersion = "26.05";
}
