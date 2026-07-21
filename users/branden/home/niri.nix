{
  pkgs,
  ...
}:
{
  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;

    settings = {
      input = {
        keyboard = {
          xkb = {
            layout = "us";
            variant = "";
            options = "ctrl:nocaps";
          };
        };
        touchpad = {
          tap = true;
          "click-method" = "clickfinger";
          "natural-scroll" = true;
        };
      };

      cursor = {
        theme = "Adwaita";
        size = 16;
        hide-after-inactive-ms = 5000;
      };

      layout = {
        gaps = 8;
        focus-ring = {
          enable = true;
          width = 4;
        };
        border = {
          enable = true;
          width = 3;
        };
        preset-column-widths = [
          { proportion = 1.0 / 2.0; }
          { proportion = 1.0 / 3.0; }
          { proportion = 2.0 / 3.0; }
        ];
        preset-window-heights = [
          { proportion = 1.0 / 2.0; }
          { proportion = 1.0 / 3.0; }
          { proportion = 2.0 / 3.0; }
        ];
      };

      spawn-at-startup = [
        {
          argv = [
            "niriusd"
          ];
        }
        {
          argv = [
            "noctalia-shell"
          ];
        }
      ];

      window-rules = [
        {
          matches = [
            { app-id = "mpv"; }
            { app-id = "swayimg"; }
          ];
          open-floating = true;
        }
        {
          matches = [
            { app-id = "org.keepassxc.KeePassXC"; }
          ];
          block-out-from = "screen-capture";
        }
      ];

      screenshot-path = "~/Pictures/Screenshots/%Y-%m-%d %H-%M-%S.png";

      hotkey-overlay.skip-at-startup = true;

      layer-rules = [
        {
          matches = [
            { namespace = "noctalia-wallpaper*"; }
          ];
          place-within-backdrop = true;
        }
      ];

      binds = {
        "Mod+Shift+Slash" = {
          action."show-hotkey-overlay" = [ ];
        };

        "Mod+1" = { action."focus-workspace" = 1; };
        "Mod+2" = { action."focus-workspace" = 2; };
        "Mod+3" = { action."focus-workspace" = 3; };
        "Mod+4" = { action."focus-workspace" = 4; };
        "Mod+5" = { action."focus-workspace" = 5; };
        "Mod+6" = { action."focus-workspace" = 6; };
        "Mod+7" = { action."focus-workspace" = 7; };
        "Mod+8" = { action."focus-workspace" = 8; };
        "Mod+9" = { action."focus-workspace" = 9; };

        "Mod+Shift+1" = { action."move-column-to-workspace" = 1; };
        "Mod+Shift+2" = { action."move-column-to-workspace" = 2; };
        "Mod+Shift+3" = { action."move-column-to-workspace" = 3; };
        "Mod+Shift+4" = { action."move-column-to-workspace" = 4; };
        "Mod+Shift+5" = { action."move-column-to-workspace" = 5; };
        "Mod+Shift+6" = { action."move-column-to-workspace" = 6; };
        "Mod+Shift+7" = { action."move-column-to-workspace" = 7; };
        "Mod+Shift+8" = { action."move-column-to-workspace" = 8; };
        "Mod+Shift+9" = { action."move-column-to-workspace" = 9; };

        "Mod+Q" = { action."close-window" = [ ]; };
        "Mod+F" = { action."maximize-column" = [ ]; };
        "Mod+Shift+F" = { action."fullscreen-window" = [ ]; };
        "Mod+V" = { action."toggle-window-floating" = [ ]; };
        "Mod+Shift+V" = { action."switch-focus-between-floating-and-tiling" = [ ]; };
        "Mod+W" = { action."toggle-column-tabbed-display" = [ ]; };
        "Mod+C" = { action."center-column" = [ ]; };
        "Mod+R" = { action."switch-preset-column-width" = [ ]; };
        "Mod+Shift+R" = { action."switch-preset-window-height" = [ ]; };

        "Mod+Minus" = { action."set-column-width" = "-10%"; };
        "Mod+Equal" = { action."set-column-width" = "+10%"; };
        "Mod+Shift+Minus" = { action."set-window-height" = "-10%"; };
        "Mod+Shift+Equal" = { action."set-window-height" = "+10%"; };

        "Mod+H" = { action."focus-column-left" = [ ]; };
        "Mod+J" = { action."focus-window-or-workspace-down" = [ ]; };
        "Mod+K" = { action."focus-window-or-workspace-up" = [ ]; };
        "Mod+L" = { action."focus-column-right" = [ ]; };
        "Mod+Left" = { action."focus-column-left" = [ ]; };
        "Mod+Down" = { action."focus-window-or-workspace-down" = [ ]; };
        "Mod+Up" = { action."focus-window-or-workspace-up" = [ ]; };
        "Mod+Right" = { action."focus-column-right" = [ ]; };

        "Mod+Ctrl+H" = { action."focus-monitor-left" = [ ]; };
        "Mod+Ctrl+J" = { action."focus-monitor-down" = [ ]; };
        "Mod+Ctrl+K" = { action."focus-monitor-up" = [ ]; };
        "Mod+Ctrl+L" = { action."focus-monitor-right" = [ ]; };
        "Mod+Ctrl+Left" = { action."focus-monitor-left" = [ ]; };
        "Mod+Ctrl+Down" = { action."focus-monitor-down" = [ ]; };
        "Mod+Ctrl+Up" = { action."focus-monitor-up" = [ ]; };
        "Mod+Ctrl+Right" = { action."focus-monitor-right" = [ ]; };

        "Mod+Shift+H" = { action."move-column-left" = [ ]; };
        "Mod+Shift+J" = { action."move-window-down-or-to-workspace-down" = [ ]; };
        "Mod+Shift+K" = { action."move-window-up-or-to-workspace-up" = [ ]; };
        "Mod+Shift+L" = { action."move-column-right" = [ ]; };
        "Mod+Shift+Left" = { action."move-column-left" = [ ]; };
        "Mod+Shift+Down" = { action."move-window-down-or-to-workspace-down" = [ ]; };
        "Mod+Shift+Up" = { action."move-window-up-or-to-workspace-up" = [ ]; };
        "Mod+Shift+Right" = { action."move-column-right" = [ ]; };

        "Mod+Ctrl+Shift+H" = { action."move-column-to-monitor-left" = [ ]; };
        "Mod+Ctrl+Shift+J" = { action."move-column-to-monitor-down" = [ ]; };
        "Mod+Ctrl+Shift+K" = { action."move-column-to-monitor-up" = [ ]; };
        "Mod+Ctrl+Shift+L" = { action."move-column-to-monitor-right" = [ ]; };
        "Mod+Ctrl+Shift+Left" = { action."move-column-to-monitor-left" = [ ]; };
        "Mod+Ctrl+Shift+Down" = { action."move-column-to-monitor-down" = [ ]; };
        "Mod+Ctrl+Shift+Up" = { action."move-column-to-monitor-up" = [ ]; };
        "Mod+Ctrl+Shift+Right" = { action."move-column-to-monitor-right" = [ ]; };

        "Mod+U" = { action."focus-workspace-down" = [ ]; };
        "Mod+I" = { action."focus-workspace-up" = [ ]; };
        "Mod+Shift+U" = { action."move-column-to-workspace-down" = [ ]; };
        "Mod+Shift+I" = { action."move-column-to-workspace-up" = [ ]; };

        "Print" = { action."screenshot-screen"."show-pointer" = false; };
        "Shift+Print" = { action."screenshot" = [ ]; };
        "Ctrl+Print" = { action."screenshot-window"."show-pointer" = true; };

        "Mod+Space" = { action.spawn = [ "noctalia-shell" "msg" "launcher" "toggle" ]; };
        "Mod+Return" = { action.spawn = [ "ghostty" ]; };

        "Mod+Tab" = { action."toggle-overview" = [ ]; };

        "Mod+Backspace" = { action.spawn = [ "nirius" "scratchpad-show" ]; };
        "Mod+Shift+Backspace" = { action.spawn = [ "nirius" "scratchpad-toggle" ]; };
        "Mod+Ctrl+Backspace" = { action.spawn = [ "nirius" "scratchpad-show-all" ]; };
        "Mod+Ctrl+Space" = { action.spawn = [ "nirius" "toggle-follow-mode" ]; };
      };
    };
  };
}
