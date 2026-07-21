{
  pkgs,
  flake-inputs,
  ...
}:
{
  programs.noctalia-shell = {
    enable = true;
    # systemd service is deprecated — noctalia is spawned
    # by niri via spawn-at-startup in users/branden/home/niri.nix
    systemd.enable = false;

    settings = {
      general = {
        animationSpeed = 1.5;
      };

      shell = {
        niri_overview_type_to_launch_enabled = true;
      };

      colorSchemes = {
        darkMode = true;
        syncGsettings = true;
        predefinedScheme = "Noctalia (default)";
      };
    };
    plugins = {
        sources = [
          {
            enabled = true;
            name = "Official Noctalia Plugins";
            url = "https://github.com/noctalia-dev/noctalia-plugins";
          }
        ];
        states = {
          catwalk = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
        version = 2;
      };
  };
  
}
