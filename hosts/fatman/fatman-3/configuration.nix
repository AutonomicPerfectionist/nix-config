{
  # Fatman-3 - Cluster compute node with AMD GPU and InfiniBand
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
    hostname = "fatman-3";
  };

  networking.hostName = "fatman-3";

  hardware.graphics.enable = true;
  hardware.gpu.amd.enable = true;
  enableRocmSupport = true;

  hardware.infiniband.guids = [
    "0x001175000073bbd6"
  ];

  boot.kernelModules = [
    "ib_ipoib"
  ];

  networking.interfaces = {
    ibp4s0 = {
      ipv4.addresses = [
        {
          address = "192.168.3.113";
          prefixLength = 24;
        }
      ];
      mtu = 65520;
      useDHCP = false;
    };
  };

  networking.localCommands = ''
    echo connected > /sys/class/net/ibp4s0/mode
  '';
}
