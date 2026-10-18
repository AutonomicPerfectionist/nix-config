{ config, pkgs, ... }:
{
  age.secrets.remotebuild-key.file = ../secrets/remotebuild-key.age;

  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

  nix.buildMachines = [
    # {
    #   hostName = "thunder-budget-3.local";
    #   sshUser = "remotebuild";
    #   sshKey = config.age.secrets.remotebuild-key.path;
    #   system = pkgs.stdenv.hostPlatform.system;
    #   maxJobs = 8;
    #   supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "gccarch-ivybridge"];
    #   publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU9XOUxzL3RhOXJ1YWZGekRXT0J2OUxRRGk0UG15VFBySnpJbmRrVHFvYTAK";
    # }

    {
      hostName = "thunder-budget-1.local";
      sshUser = "remotebuild";
      sshKey = config.age.secrets.remotebuild-key.path;
      system = pkgs.stdenv.hostPlatform.system;
      maxJobs = 16;
      speedFactor = 3;
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "gccarch-ivybridge"];
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU11RFpxOHIwT1hZUUJza2Rzc0tqNjZVL2o1SXVuZFU3Tlh2YlBORUhzV2gK";
    }

    {
      hostName = "thunder-budget-2.local";
      sshUser = "remotebuild";
      sshKey = config.age.secrets.remotebuild-key.path;
      system = pkgs.stdenv.hostPlatform.system;
      maxJobs = 16;
      speedFactor = 4;
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "gccarch-ivybridge"];
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUQ4LytselNrbVpTdHM5YmFBRWJRdG1waGtFWVpQbmpBelFHQnJzRXg4MVQK";
    }
    {
      hostName = "thunder-budget-4.local";
      sshUser = "remotebuild";
      sshKey = config.age.secrets.remotebuild-key.path;
      system = pkgs.stdenv.hostPlatform.system;
      maxJobs = 16;
      speedFactor = 3;
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "gccarch-ivybridge"];
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUZMWnA4QStMNU5IcXRTZ1lRaDJRQ0NBeDE4ZHlYckpVMW0zcFZUZFF4VSsK";
    }
    # {
    #   hostName = "fatman-2.local";
    #   sshUser = "remotebuild";
    #   sshKey = config.age.secrets.remotebuild-key.path;
    #   system = pkgs.stdenv.hostPlatform.system;
    #   maxJobs = 8;
    #   speedFactor = 1;
    #   supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "gccarch-ivybridge"];
    # }
  ];
}
