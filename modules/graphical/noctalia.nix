{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
{
  options.scl.graphical.noctalia = {
    enable = lib.mkEnableOption "noctalia wallpaper daemon support";
  };

  config = lib.mkIf config.scl.graphical.noctalia.enable {
    environment.systemPackages = [
      flake-inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
