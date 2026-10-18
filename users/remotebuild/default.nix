{
  users.users.remotebuild = {
    isSystemUser = true;
    group = "remotebuild";
    useDefaultShell = true;

    # Single shared key for every dispatcher host; the matching private key
    # is distributed via the remotebuild-key agenix secret (see
    # modules/distributed-builds.nix), so adding a new dispatcher never
    # requires generating or copying in a new keypair.
    openssh.authorizedKeys.keyFiles = [
      ./remotebuild.pub
    ];
  };

  users.groups.remotebuild = {};

  nix = {
      nrBuildUsers = 64;
      settings = {
        trusted-users = [ "remotebuild" ];
  
        min-free = 10 * 1024 * 1024;
        max-free = 200 * 1024 * 1024;
  
        max-jobs = "auto";
        cores = 0;
      };
    };
  
    systemd.services.nix-daemon.serviceConfig = {
      MemoryAccounting = true;
      MemoryMax = "90%";
      OOMScoreAdjust = 500;
    };
}
