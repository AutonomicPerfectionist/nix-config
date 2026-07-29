{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.scl.battery;
in
{
  options.scl.battery = {
    enable = lib.mkEnableOption "battery charge limiting";

    chargeLimit = lib.mkOption {
      type = lib.types.int;
      default = 80;
      description = "Battery charge limit percentage (0-100). Sets charge_control_end_threshold on supported hardware.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.battery-charge-limit = {
      description = "Set battery charge limit";
      wantedBy = [ "multi-user.target" ];
      after = [ "sysinit.target" ];
      script = ''
        for bat in /sys/class/power_supply/BAT*; do
          [ -w "$bat/charge_control_end_threshold" ] && echo ${toString cfg.chargeLimit} > "$bat/charge_control_end_threshold"
        done
      '';
      serviceConfig.Type = "oneshot";
    };

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="power_supply", ATTR{type}=="Battery", ATTR{charge_control_end_threshold}="${toString cfg.chargeLimit}"
    '';
  };
}
