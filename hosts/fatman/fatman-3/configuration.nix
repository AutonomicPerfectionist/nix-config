{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/676e3d90-fbd8-4a95-a886-668acfff6cfc";
    fsType = "ext4";
    neededForBoot = true;
    options = [ "noatime" ];
  };

  scl.overlays.rocm-llvm-arch = "ivybridge";

  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../common_configuration.nix
    ../../../modules/cluster/push.nix
    ../../../modules/distributed-builds.nix
  ];

  userconfig.branden = {
    enable = true;
    hostname = "fatman-3";
  };

  networking.hostName = "fatman-3";

  hardware.graphics.enable = true;
  hardware.gpu.amd.enable = true;
  enableRocmSupport = true;

  cluster.smfc.enable = true;
  cluster.smfc.gpuType = "amd";
  cluster.smfc.settings.Ipmi.platform_name = "generic_x9";
  # Same FatTwin chassis as fatman-1 (X9DRFF-iG+, two fans per node); zone 1
  # alone can't reach a useful ceiling on this board, so share zone 0 with
  # the CPU controller instead. See fatman-1's config for the full writeup.
  cluster.smfc.settings.GPU.ipmi_zone = 0;
  # MI60 exposes edge/junction/mem via hwmon, all reading real values
  # (confirmed 2026-10-18). A prior revision of this config tried to run
  # junction and memory as two separate controllers ([GPU] + [GPU:1]) both
  # on zone 0, on the assumption that smfc would apply the max requested
  # level across controllers sharing a zone. That assumption was wrong:
  # smfc's config validator (src/smfc/config.py, _validate_no_duplicate_zones)
  # tracks zone ownership *per controller type*, independent of the ":N"
  # suffix, and rejects any two GPU-family sections on the same zone
  # outright ("[GPU:1] IPMI zone 0 is already used by [GPU]", exit
  # NOTCONFIGURED). That had smfc crash-looping on every start (restart
  # counter in the tens of thousands), meaning the GPU was never being
  # temperature-controlled at all -- which is why it kept overheating even
  # with smfc "enabled". Only CPU+GPU (different controller types) can
  # share a zone, same as fatman-1.
  #
  # Until smfc supports reading more than one sensor per controller, drive
  # the single [GPU] controller off the module's junction-temp default
  # (sensor 0), NOT memory. Verified with a real stress test (llama-bench,
  # 2026-10-22, ~60s pp512 run) while smfc was still crash-looping (see
  # above) and therefore not touching the fans at all: junction rose from
  # ~40C idle to a 104C peak -- both faster and higher than memory (40C ->
  # 90C peak) or edge (39C -> 84C peak). Unlike fatman-1's V100, memory is
  # NOT the hot sensor on this MI60; junction is, and by a wide margin.
  # Driving fans off memory here would have the curve still idling while
  # the die is already near its throttle point.
  cluster.smfc.settings.GPU.amd_temp_sensor = 0;

  scl.overlays.rocm-amd = true;
  scl.overlays.rocm-gpu-targets = [ "gfx906" ];
  services.llama.useCustomSource = false;
  services.llama.rpcServer.enable = true;
  services.llama.preferVulkan = true;
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
