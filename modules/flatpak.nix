{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Enable the FLATPAK
  services.flatpak.enable = true;

  # Add a nice software browser to grab flatpak packages
  environment.systemPackages = [
    pkgs.cosmic-store
  ];

  # Makes sure flathub is available at boot
  systemd.services.flatpak-repo-setup = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Flatpak packages to install (graphical systems only)
  systemd.services.flatpak-packages = lib.mkIf (lib.hasAttrByPath [ "scl" "graphical" "enable" ] config && config.scl.graphical.enable) {
    wantedBy = [ "multi-user.target" ];
    after = [ "flatpak-repo-setup.service" "network-online.target" ];
    wants = [ "flatpak-repo-setup.service" "network-online.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak install --noninteractive flathub com.discordapp.Discord dev.vencord.Vesktop com.slack.Slack 2>/dev/null || true
    '';
  };
}
