{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.networking.preferFastestRoute;
in
{
  options.networking.preferFastestRoute = {
    enable = mkEnableOption ''
      pinning NetworkManager's per-connection route metric to each interface's
      link speed, so the fastest NIC always wins the default route instead of
      NetworkManager's activation-order-based automatic metric (which hands
      out 100, 101, 102... in whatever order the drivers happen to come up,
      with no regard for speed)
    '';

    base = mkOption {
      type = types.int;
      default = 65535;
      description = ''
        Every managed interface's metric is computed as
        `base - linkSpeedMbps`, clamped to a minimum of 1. Faster links get a
        lower (= preferred) metric automatically. Hosts with only one active
        interface are unaffected either way.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Runtime discovery instead of hardcoding interface names: this fleet has
    # wildly inconsistent NIC naming (eno1, eth0, eth1, enp45s0d1, ...), same
    # as the RoCE NICs in modules/cluster/rdma.nix. Only interfaces NM has an
    # active connection on are touched; statically-addressed links (e.g. the
    # IPoIB fabric interfaces) have no NM connection and are left alone.
    systemd.services.prefer-fastest-route = {
      description = "Pin NetworkManager route metrics so the fastest NIC wins the default route";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.networkmanager
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -u
        attempt=0
        while [ "$attempt" -lt 10 ]; do
          pending=0
          for dev in $(ls /sys/class/net); do
            [ "$dev" = "lo" ] && continue
            state=$(cat "/sys/class/net/$dev/operstate" 2>/dev/null || echo down)
            [ "$state" = "up" ] || continue

            speed=$(cat "/sys/class/net/$dev/speed" 2>/dev/null || echo "")
            case "$speed" in
              "") continue ;;
              *[!0-9]*) continue ;;
            esac
            [ "$speed" -gt 0 ] || continue

            conn=$(nmcli -t -g GENERAL.CONNECTION device show "$dev" 2>/dev/null || echo "")
            if [ -z "$conn" ] || [ "$conn" = "--" ]; then
              pending=1
              continue
            fi

            metric=$(( ${toString cfg.base} - speed ))
            [ "$metric" -lt 1 ] && metric=1

            current=$(nmcli -t -g ipv4.route-metric connection show "$conn" 2>/dev/null || echo "")
            if [ "$current" != "$metric" ]; then
              echo "prefer-fastest-route: $dev (''${speed}Mb/s) -> metric $metric via '$conn'"
              nmcli connection modify "$conn" ipv4.route-metric "$metric" ipv6.route-metric "$metric"
              nmcli connection up "$conn" >/dev/null 2>&1 || true
            fi
          done
          [ "$pending" -eq 0 ] && break
          attempt=$((attempt + 1))
          sleep 2
        done
      '';
    };
  };
}
