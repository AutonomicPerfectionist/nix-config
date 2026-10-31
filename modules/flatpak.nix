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

  # Makes sure flathub is available at boot.
  # remote-add fetches flathub.flatpakrepo over HTTPS, so this has to be
  # ordered after the network is actually up -- wants= alone gives no ordering.
  systemd.services.flatpak-repo-setup = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      # Without this the unit is Type=simple, so dependents ordered After= it
      # only wait for the fork, not for the remote to actually exist.
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # NetworkManager can report online before DNS is usable, so retry a few times.
      for attempt in 1 2 3 4 5; do
        if flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
          exit 0
        fi
        echo "flathub remote-add failed (attempt $attempt), retrying in 5s" >&2
        sleep 5
      done
      exit 1
    '';
  };

  # Flatpak packages to install (graphical systems only)
  systemd.services.flatpak-packages =
    lib.mkIf (lib.hasAttrByPath [ "scl" "graphical" "enable" ] config && config.scl.graphical.enable)
      {
        wantedBy = [ "multi-user.target" ];
        after = [
          "flatpak-repo-setup.service"
          "network-online.target"
        ];
        wants = [
          "flatpak-repo-setup.service"
          "network-online.target"
        ];
        path = [ pkgs.flatpak ];
        script = ''
          flatpak install --noninteractive flathub com.discordapp.Discord dev.vencord.Vesktop com.slack.Slack 2>/dev/null || true
        '';
      };
}
