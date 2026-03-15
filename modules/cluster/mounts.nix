{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true; # needed for NFS

  fileSystems."/mnt/cluster" = {
    device = "cheapskate.local:/mnt/cluster";
    fsType = "nfs";
    options = [
      "nofail"
      "noatime"
      "nolock"
      "intr"
      "tcp"
      "actimeo=1800"
      "rsize=131072"
      "wsize=131072"
      "async"
    ];
  };


}