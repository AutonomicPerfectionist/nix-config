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
  # V100-PCIE-16GB on driver 580.178.04 reports temperature.memory via nvidia-smi (confirmed:
  # `nvidia-smi -q -d TEMPERATURE` shows a real "Memory Current Temp", not N/A) -- drive the fan
  # curve off memory temp instead of the GPU die, since memory thermal throttling is the problem here.
  cluster.smfc.settings.GPU.nvidia_temp_sensor = 1;
  # DIAGNOSTIC: this board (X9DRFF-iG+, a FatTwin dual-node SKU) only has two populated fans
  # (FAN9/FAN10, per `ipmitool sdr type fan`); zone 1 pinned at 100% only got them to ~5700 RPM
  # under load, which may or may not be their real ceiling. Point the GPU controller at zone 0
  # (same zone as CPU) to test whether FAN9/FAN10 are actually wired to zone 0 and have more
  # headroom than zone 1 can reach. smfc allows two controller types to share a zone (only same-type
  # zone collisions are validated), so CPU and GPU will both drive zone 0 independently -- expect the
  # commanded duty to bounce between whichever last wrote. Revert to a dedicated zone 1 (or whatever
  # zone turns out correct) once we know the real mapping.
  cluster.smfc.settings.GPU.ipmi_zone = 0;

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
