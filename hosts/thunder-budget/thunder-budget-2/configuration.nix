{
  # Thunder-budget-3 - Cluster compute node with InfiniBand
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
    imports = [
    ./disk-config.nix      
    ./hardware-configuration.nix
    ../common_configuration.nix
  ];

  userconfig.branden = {
    enable = true;
    hostname = "thunder-budget-2";
  };

  networking.hostName = "thunder-budget-2";

  hardware.infiniband.guids = [
    "0x00117500006f698c"
  ];

  boot.kernelModules = [
    "ib_ipoib"
  ];

  networking.interfaces = {
    ibs1 = {
      ipv4.addresses = [
        {
          address = "192.168.3.102";
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
