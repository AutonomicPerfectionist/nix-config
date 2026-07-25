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
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/distributed.nix
    ../../modules/cluster/rdma.nix
    ../../modules/input-methods.nix
    ../../modules/ml/llama.nix
    ../../hardware/gpus/gpus.nix
    ../../modules/common/overlays.nix
    # ../../containers/vllm.nix
    flake-inputs.home-manager.nixosModules.default

    # Users
    ../../users/branden
  ];

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "pci=realloc"
  ];
  hardware.graphics.enable = true;
  # hardware.gpu.intel.enable = true;
  hardware.gpu.nvidia.enable = true;
  # The Titan V has the exact same chip as the V100
  hardware.gpu.nvidia.cards = [ "tesla_v100" ];
  cluster.rdma.enable = true;

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    micro
    htop
    xclip

  ];

  services.openssh.enable = true;
  services.llama.rpcServer.enable = true;
  services.llama.useCustomSource = true;
  # services.vllm-xpu.enable = true;
  # services.vllm-xpu.model = "NousResearch/Hermes-3-Llama-3.1-8B";

  system.stateVersion = "25.11";
}
