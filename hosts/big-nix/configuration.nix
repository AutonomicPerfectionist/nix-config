{
  config,
  pkgs,
  flake-inputs,
  zfs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/compute.nix
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/rdma.nix
    ../../modules/cluster/distributed.nix
    ../../hardware/gpus/gpus.nix
    ../../modules/ml/llama.nix
    ../../modules/ml/hermes.nix
    ../../containers/vllm.nix
    ../../modules/distributed-builds.nix
    ../../modules/zfs.nix
  ];

  scl.monitoring.server.enable = true;

  userconfig.branden = {
    enable = true;
    hostname = "big-nix";
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  boot.kernelPackages = zfs.selectZfsCompatibleKernel { };
  boot.zfs.extraPools = [ "archive" ];

  hardware.graphics.enable = true;
  hardware.gpu.intel.enable = true;
  cluster.rdma.enable = true;

  scl.overlays.sycl-intel = true;

  services.llama.useCustomSource = true;
  services.llama.rpcServer.enable = true;

  services.vllm-xpu = {
    enable = false;
    model = "Qwen/Qwen3-4B-Instruct-2507";
  };

  networking.hostName = "big-nix";
  networking.hostId = "f036b686";

  services.openssh.settings = {
    X11Forwarding = true;
  };

  environment.systemPackages = with pkgs; [
    git
    micro
    htop
    xclip
    opencode
    llm-agents.omp
  ];

  system.stateVersion = "25.11";
}
