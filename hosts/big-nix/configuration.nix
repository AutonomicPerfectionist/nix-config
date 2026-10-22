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
    ../../modules/cluster
    ../../modules/cluster/atticd.nix
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

  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true; # needed for NFS

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export/archive    *(sec=sys,rw,no_subtree_check,crossmnt)
  '';
  boot.kernelPackages = zfs.selectZfsCompatibleKernel { };
  boot.zfs.extraPools = [
    "archive"
    "cache"
  ];

  fileSystems."/export/archive" = {
    device = "/archive";
    fsType = "none";
    # rbind (not bind): archive/movies, archive/photos, etc. are each their
    # own zfs mount nested under /archive, and a plain bind mount does not
    # carry nested mounts over into the bind target.
    options = [
      "rbind"
      "x-systemd.requires=zfs-mount.service"
      "x-systemd.after=zfs-mount.service"
    ];
  };

  # NFS must not start until the bind mount above is actually backed by the
  # mounted zfs dataset, otherwise it exports the empty underlying directory.
  systemd.services.nfs-server = {
    requires = [ "export-archive.mount" ];
    after = [ "export-archive.mount" ];
  };

  # age.secrets.attic-env.file = ../secrets/attic-env.age;
  # services.atticd.environmentFile = config.age.secrets.attic-env.path;
  hardware.graphics.enable = true;
  hardware.gpu.intel.enable = true;
  cluster.rdma.enable = true;

  scl.overlays.sycl-intel = true;

  services.llama.useCustomSource = false;
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
