{ pkgs, ... }:
{
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

  nix.buildMachines = [
    # {
    #   hostName = "thunder-budget-3.local";
    #   sshUser = "remotebuild";
    #   sshKey = "/root/.ssh/remotebuild";
    #   system = pkgs.stdenv.hostPlatform.system;
    #   maxJobs = 8;
    #   supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "gccarch-ivybridge"];
    # }

    {
      hostName = "thunder-budget-4.local";
      sshUser = "remotebuild";
      sshKey = "/root/.ssh/remotebuild";
      system = pkgs.stdenv.hostPlatform.system;
      maxJobs = 8;
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "gccarch-ivybridge"];
    }
  ];
}
