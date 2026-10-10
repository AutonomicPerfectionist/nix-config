{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ../../modules/ml/llama.nix
    ../../modules/cluster

    ../../users/remotebuild
  ];

  nix.settings.system-features = [
    "nixos-test"
    "benchmark"
    "big-parallel"
    "kvm"
    "gccarch-ivybridge"
  ];

  services.swapspace.enable = true;
  hardware.infiniband.enable = true;
  cluster.rdma.enable = true;

  environment.systemPackages = with pkgs; [
    git
    micro
    htop
    xclip
  ];

  system.stateVersion = "25.11";
}
