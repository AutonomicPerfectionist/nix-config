{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/distributed.nix
    ../../modules/cluster/rdma.nix
    ../../modules/ml/llama.nix
    ../../hardware/gpus/gpus.nix
    # ../../containers/vllm.nix
  ];

  boot.kernelParams = [
    "pci=realloc"
  ];
  hardware.graphics.enable = true;
  # hardware.gpu.intel.enable = true;
  hardware.gpu.nvidia.enable = true;
  # The Titan V has the exact same chip as the V100
  hardware.gpu.nvidia.cards = [ "tesla_v100" ];
  cluster.rdma.enable = true;

  services.llama.rpcServer.enable = true;
  services.llama.useCustomSource = true;
  # services.vllm-xpu.enable = true;
  # services.vllm-xpu.model = "NousResearch/Hermes-3-Llama-3.1-8B";

  environment.systemPackages = with pkgs; [
    git
    micro
    htop
    xclip
  ];

  system.stateVersion = "25.11";
}
