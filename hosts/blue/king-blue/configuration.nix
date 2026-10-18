{
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
    ../../../modules/cluster/push.nix
    ../../../modules/distributed-builds.nix
  ];

  userconfig.branden = {
    enable = true;
    hostname = "king-blue";
  };

  networking.hostName = "king-blue";
}
