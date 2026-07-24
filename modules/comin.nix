{ ... }:
{
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        # HTTPS so machines can pull without provisioning a deploy key per host -
        # the repo is public, so anonymous read access is sufficient.
        url = "https://github.com/AutonomicPerfectionist/nix-config.git";
        branches.main.name = "main";
      }
    ];
  };
}
