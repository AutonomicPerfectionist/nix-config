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
  ];

  userconfig.branden = {
    enable = true;
    hostname = "fatman-1";
  };

  networking.hostName = "fatman-1";

  hardware.graphics.enable = true;
  hardware.gpu.nvidia.enable = true;
  hardware.gpu.nvidia.cards = [ "tesla_v100" ];

  cluster.smfc.enable = true;
  cluster.smfc.gpuType = "nvidia";
  cluster.smfc.settings.Ipmi.platform_name = "generic_x9";

  services.llama.useCustomSource = true;
  services.llama.rpcServer.enable = true;
  hardware.infiniband.guids = [
    "0x00117500007090a2"
  ];

  boot.kernelModules = [
    "ib_ipoib"
  ];

  networking.interfaces = {
    ibp4s0 = {
      ipv4.addresses = [
        {
          address = "192.168.3.111";
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
