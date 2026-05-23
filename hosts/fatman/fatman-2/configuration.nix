{
  # Fatman-3 - Cluster compute node with AMD GPU and InfiniBand
  config,
  pkgs,
  flake-inputs,
  ...
}:
{

 nix.settings.system-features = ["nixos-test" "benchmark" "big-parallel" "kvm" "gccarch-ivybridge"];
       # nixpkgs.hostPlatform = {
       #   gcc.arch = "ivybridge";
       #   gcc.tune = "ivybridge";
       #   system = "x86_64-linux";
       # };
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
  hardware.gpu.nvidia.cards = [ "tesla_p40" ];
  # enableRocmSupport = true;

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
