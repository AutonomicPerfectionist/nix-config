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
  # Same FatTwin chassis as fatman-1 (X9DRFF-iG+, two fans per node); zone 1
  # alone can't reach a useful ceiling on this board, so share zone 0 with
  # the CPU controller instead. See fatman-1's config for the full writeup.
  cluster.smfc.settings.GPU.ipmi_zone = 0;
  # Checked `nvidia-smi -q -d TEMPERATURE` on 2026-10-18: Memory Current Temp
  # is N/A on both the P40 and the M6000 (older Maxwell/Pascal silicon,
  # unlike the V100 on fatman-1). No memory-temp reporting here, so stick
  # with the module default (die temp via nvidia_temp_sensor=0).

  # Observed under a real GPU stress test (2026-10-18, journalctl -u smfc):
  # with smoothing=1 (disabled) + sensitivity=2.0, a GPU temp sitting right on
  # a bucket boundary (e.g. 55/56C) flips the fan level back and forth within
  # single-digit seconds. A 4-sample moving average (8s at polling=2s) rides
  # through that noise while still tracking real, sustained temperature
  # trends over tens of seconds, which is what actually matters for cooling.
  cluster.smfc.settings.GPU.smoothing = 4;
  cluster.smfc.settings.GPU.sensitivity = 3.0;

  # Same flutter was visible on the CPU controller at idle (bouncing between
  # the two lowest buckets as idle temp hovers right at their boundary);
  # same fix.
  cluster.smfc.settings.CPU.smoothing = 4;

  services.llama.useCustomSource = false;
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
