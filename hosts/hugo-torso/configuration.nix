{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./common_configuration.nix
  ];

  userconfig.branden = {
    enable = true;
    hostname = "hugo-torso";
  };

  networking.hostName = "hugo-torso";

  system.stateVersion = "25.11";
}
