{
  # King-blue - Cluster compute node with Intel Arc GPU
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
    hostname = "king-blue";
  };

  scl.overlays.sycl-intel = true;
}
