{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.scl.graphical.niri = {
    enable = lib.mkEnableOption "niri Wayland compositor support";
  };

  config = lib.mkIf config.scl.graphical.niri.enable {
    environment.systemPackages = [ pkgs.niri-unstable ];
    services.displayManager.sessionPackages = [ pkgs.niri-unstable ];
    systemd.packages = [ pkgs.niri-unstable ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    xdg.portal.extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    xdg.portal.configPackages = [ pkgs.niri-unstable ];
  };
}
