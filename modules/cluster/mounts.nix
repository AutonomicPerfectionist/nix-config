{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true; # needed for NFS

  boot.swraid.enable = true;

  environment.systemPackages = with pkgs; [
    parted
  ];

  # This share lives across the same link NetworkManager owns, so any switch
  # that restarts NetworkManager takes the server away mid-flight. With the
  # default hard semantics the mount then blocks forever, and systemd's
  # generator sandbox blocks with it on the following daemon-reexec: PID 1
  # gives up after 91s ("Failed to fork off sandboxing environment for
  # executing generators: Protocol error") and freezes, which takes the whole
  # machine down until a hard reboot (systemd#44396). battle-bucket hit this on
  # every attempt to switch across the systemd 260 -> 261 bump.
  #
  # soft + a bounded timeo/retrans makes I/O fail with EIO instead of hanging;
  # _netdev and x-systemd.automount keep the mount out of the boot critical
  # path and let it drop while idle. nofail alone only covered boot-time
  # failure, and intr has been a kernel no-op for years ("nfs: Deprecated
  # parameter 'intr'").
  fileSystems."/mnt/cluster" = {
    device = "cheapskate.local:/mnt/cluster";
    fsType = "nfs";
    options = [
      "nofail"
      "noatime"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10"
      "soft"
      "softreval"
      "timeo=50"
      "retrans=2"
      "nolock"
      "tcp"
      "rsize=131072"
      "wsize=131072"
      "async"
      "acregmin=5"
      "acregmax=30"
      "acdirmin=1"
      "acdirmax=5"
    ];
  };

}
