{
  # Queen-blue - Cluster compute node with Intel Arc GPU
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../common_configuration.nix
  ];

  userconfig.branden = {
    enable = true;
    hostname = "queen-blue";
  };

  networking.hostName = "queen-blue";

  scl.overlays.sycl-intel = true;
}
