{
  # Big-nix - Cluster compute node with NVIDIA GPU and NFS mounts
  config,
  pkgs,
  flake-inputs,
  zfs,
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
    ../../modules/ml/hermes.nix
    # vLLM on the Intel Arc A770 via the official docker/Dockerfile.xpu build.
    # Opt-in: does nothing until services.vllm-xpu.enable = true (see below).
    ../../containers/vllm.nix
    ../../modules/distributed-builds.nix
    ../../modules/zfs.nix
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

  boot.kernelPackages = zfs.selectZfsCompatibleKernel { };

  # Additional hardware and driver configuration
  hardware.graphics.enable = true;
  hardware.gpu.intel.enable = true;

  services.llama.useCustomSource = true;
  services.llama.rpcServer.enable = true;

  # vLLM (Intel Arc A770 / XPU). Enabling this turns on docker and, on first
  # activation, builds vllm from source via the pinned tag's docker/Dockerfile.xpu
  # (a long, one-time, multi-GB build). It then serves an OpenAI-compatible API.
  # There is no working pip/uv wheel path for vllm-XPU: the PyPI vllm wheel is
  # CUDA-only (pins torch==2.11.0 + nvidia-cuda-*), so docker-from-source is the
  # supported route. Uncomment and set a model to use it:
  #
  # Verified serving Qwen3-4B on the A770. The service enables docker itself and
  # (on first activation) builds vllm from source via the pinned tag's
  # docker/Dockerfile.xpu — a long, one-time, multi-GB build. Comment out to
  # disable. Two Arc-specific fixes are baked into ../../containers/vllm.nix:
  # a mem_get_info shim (consumer Arc can't report free VRAM) and
  # --attention-backend TRITON_ATTN (A770/Alchemist can't use the Xe2/Xe3-only
  # flash-attn cutlass kernel).
  services.vllm-xpu = {
    enable = true;
    model  = "Qwen/Qwen3-4B-Instruct-2507";
    # huggingFaceToken = "hf_..."; # for gated models (prefer agenix)
  };

  networking.hostName = "big-nix";
  # Needs to be unique among machines, used
  # for zfs to prevent accidental imports
  # on wrong machines
  networking.hostId = "f036b686";


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
