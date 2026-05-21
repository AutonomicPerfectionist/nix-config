{
  # Big-nix - Cluster compute node with NVIDIA GPU and NFS mounts
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/nix-settings.nix
    ../../modules/avahi.nix
    ../../modules/compute.nix
    ../../modules/common/overlays.nix
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/distributed.nix
    ../../hardware/gpus/gpus.nix
    flake-inputs.home-manager.nixosModules.default
    ../../modules/ml/llama.nix
    ../../modules/distributed-builds.nix
    # ../../modules/ml/ai-agent/ai-agent.nix
    # ../../modules/ml/ai-agent/omp.nix
    # ../../modules/ml/ai-agent/vector-memory.nix

    # ({ pkgs, ... }: {
    #   services.aiAgent.ompPackage =
    #     flake-inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
    # })
    # Users
    
    ../../users/branden
  ];

  userconfig.branden = {
    enable = true;
    hostname = "big-nix";
  };

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel 6.12 has patches for nvidia driver 390,
  # newer kernels don't
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Additional hardware and driver configuration
  hardware.graphics.enable = true;
  hardware.gpu.nvidia.enable = true;
  hardware.gpu.nvidia.cards = [
    "quadro_m6000"
  ];

  enableCudaSupport = true;

  networking.hostName = "big-nix";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    git
    micro
    htop
    xclip
    opencode
    llm-agents.omp
  ];


  # services.aiAgent = {
  #   enable            = true;
  #   orchestratorUrl   = "http://192.168.1.10:8080";
  #   orchestratorModel = "minimax-m2-7";
  #   codingAgentUrl    = "http://192.168.1.10:8081";
  #   codingAgentModel  = "qwen2.5-coder-32b-Q4_K_M";
  #   users             = [ "branden" ];
  #   memory.projectRoots = [ "/mnt/cluster/dev/git/SuperScalar-PipeInfer" ];
  # };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings = {
    X11Forwarding = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
