{ config, lib, pkgs, ... }:
{
  users.users.atticd = { isSystemUser = true; group = "atticd"; };
  users.groups.atticd = {};

  systemd.tmpfiles.rules = [ "d /srv/attic 0750 atticd atticd -" ];
  age.secrets.attic-env.file = ../../secrets/attic-env.age;
  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets.attic-env.path;
    settings = {
      listen = "[::]:8080";
      # default is sqlite in /var/lib/atticd (small, fine on the NVMe)
      storage = {
        type = "local";
        path = "/srv/attic";
      };
      chunking = {
        nar-size-threshold = 64 * 1024;
        min-size = 16 * 1024;
        avg-size = 64 * 1024;
        max-size = 256 * 1024;
      };
      compression.type = "zstd";
      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "3 months";
      };
    };
  };

  # Module uses DynamicUser by default; switch to the static user so it can own /srv/attic
  systemd.services.atticd.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "atticd";
    Group = "atticd";
    ReadWritePaths = [ "/srv/attic" ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
