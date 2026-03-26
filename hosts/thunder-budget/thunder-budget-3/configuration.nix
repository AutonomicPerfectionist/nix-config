# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  flake-inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common_configuration.nix

  ];

  userconfig.branden = {
    enable = true;
    hostname = "thunder-budget-3";
  };

  networking.hostName = "thunder-budget-3"; # Define your hostname.
  hardware.infiniband.guids = [
    "0x00117500006f67be"
  ];

  boot.kernelModules = [
    "ib_ipoib"
  ];
  networking.interfaces = {
    ibs1 = {
      ipv4.addresses = [
        {
          address = "192.168.3.103";
          prefixLength = 24;
        }
      ];
      mtu = 65520;
      useDHCP = false;

    };
  };
  networking.localCommands = ''
    echo connected > /sys/class/net/ibs1/mode
  '';

}
