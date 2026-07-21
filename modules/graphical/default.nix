{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.scl.graphical = {
    enable = lib.mkEnableOption "graphical desktop infrastructure";
  };

  config = lib.mkIf config.scl.graphical.enable {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    security.rtkit.enable = true;

    services.printing.enable = true;

    xdg.portal.enable = true;
  };
}
