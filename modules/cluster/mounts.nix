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
