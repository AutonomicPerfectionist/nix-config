{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    gnome-extension-manager
    gnome-tweaks
    dconf-editor
    # System tray (appindicators)
    gnomeExtensions.appindicator
    # Dock
    gnomeExtensions.dash-to-dock
    # Window open/close animations
    gnomeExtensions.burn-my-windows
    # Clipboard history in the top bar
    gnomeExtensions.clipboard-indicator
    # Blur the overview/shell
    gnomeExtensions.blur-my-shell
    # Prevent the screen from sleeping on demand
    gnomeExtensions.caffeine
    # System monitoring in the panel
    gnomeExtensions.vitals
    # Move the top bar to a secondary monitor when the primary is fullscreen
    gnomeExtensions.fullscreen-avoider
    # Fine-grained control over the GNOME UI
    gnomeExtensions.just-perfection
  ];

  services.udev.packages = with pkgs; [
    gnome-settings-daemon
  ];

  environment.gnome.excludePackages = with pkgs; [
    epiphany # gnome web browser
    totem # video player
    yelp # help menu
    geary # text editor
    gnome-text-editor
    gnome-contacts
    gnome-maps
    gnome-music
    gnome-tour
  ];
}
