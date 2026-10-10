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
    hostname = "fatman-2";
  };

  networking.hostName = "fatman-2";

  hardware.graphics.enable = true;
  hardware.gpu.nvidia.enable = true;
  hardware.gpu.nvidia.cards = [
    "tesla_p40"
    "quadro_m6000"
  ];

  cluster.smfc.enable = true;
  cluster.smfc.gpuType = "nvidia";
  cluster.smfc.settings.Ipmi.platform_name = "generic_x9";
  # Two GPUs: drive the fan controller off whichever card is hottest.
  cluster.smfc.settings.GPU.gpu_device_ids = "0,1";
  cluster.smfc.settings.GPU.temp_calc = 2;

  services.llama.useCustomSource = true;
  services.llama.rpcServer.enable = true;
  hardware.infiniband.guids = [
    "0x0011750000707982"
  ];

  boot.kernelModules = [
    "ib_ipoib"
  ];

  networking.interfaces = {
    ibp4s0 = {
      ipv4.addresses = [
        {
          address = "192.168.3.112";
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
