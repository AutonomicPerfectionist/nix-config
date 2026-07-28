{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.cluster.rdma;
  perftest = pkgs.callPackage ../../pkgs/perftest { };

  # DSCP occupies the upper 6 bits of the 8-bit IP Traffic Class / ToS byte, so
  # the value UCX/ibverbs put on the wire is (dscp << 2). Handy to keep next to
  # the module so per-host UCX env can reference it: UCX_IB_TRAFFIC_CLASS=<this>.
  trafficClass = cfg.dscp * 4;
in
{
  options.cluster.rdma = {
    enable = mkEnableOption "RDMA/RoCE support for the Mellanox ConnectX-3 Pro cluster fabric";

    driver = mkOption {
      type = types.str;
      default = "mlx4_en";
      description = ''
        netdev driver (ID_NET_DRIVER / `ethtool -i`) of the RoCE NICs to auto-configure.
        ConnectX-3 / ConnectX-3 Pro Ethernet ports report "mlx4_en". Matching the netdev driver
        (rather than the mlx4_core PCI driver or the presence of an RDMA device) is deliberate:
        it selects only the Ethernet-personality ports and skips IB-mode ports (e.g. ipoib
        "ibp*" links). All matching ports on every host are detected and configured
        automatically, so the wildly inconsistent interface names across the cluster
        (ens1, ens1d1, enp5s0, enp5s0d1, enp45s0d1, ports 1 and 2) don't need to be tracked.
      '';
    };

    interface = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Optional explicit RoCE interface override. When null (the default), every netdev whose
        driver matches `driver` is configured. Set this only if a host has more than one
        `driver` NIC and you want QoS applied to just one of them.
      '';
    };

    pfcPriority = mkOption {
      type = types.int;
      default = 3;
      description = "802.1p priority marked lossless (PFC) for RoCE traffic. Must match the switch-side no-drop qos-group.";
    };

    dscp = mkOption {
      type = types.int;
      default = 24;
      description = ''
        DSCP value RoCEv2 traffic is marked with (RoCEv2 rides IP, so we classify on DSCP, not CoS).
        Mapped to `pfcPriority` on the NIC via `dcb app dscp-prio`, and must match the switch
        classifier (`class-map type qos ... match dscp <this>`). DSCP 24 = the CS3 code point.
      '';
    };

    mtu = mkOption {
      type = types.int;
      default = 9000;
      description = ''
        L2 MTU forced on every matching NIC (applied by driver match, so it survives the
        inconsistent naming). 9000 yields a 4096-byte RoCE active_mtu on ConnectX-3. Must be
        uniform across the fabric: UD has no MTU negotiation, so a 9000/1500 split silently
        drops every oversized datagram at the smaller-MTU receiver. Keep <= the switch no-drop
        class MTU (9216).
      '';
    };
  };

  config = mkIf cfg.enable {
    # Generic RDMA/RoCE stack (rdma-core, ib_uverbs, rdma_ucm, rdma_cm). Needed for RoCE too,
    # not just InfiniBand; the QLogic-specific ib_qib driver just stays idle with no hardware.
    hardware.infiniband.enable = true;

    environment.systemPackages = with pkgs; [
      rdma-core
      iproute2
      ethtool
      mstflint
      perftest
    ];

    # MTU, declaratively, by driver — applied by udev at device appearance, independent of the
    # interface name and independent of whether networkd or NetworkManager owns the link.
    systemd.network.links."30-roce-mtu" = {
      matchConfig.Driver = cfg.driver;
      linkConfig.MTUBytes = toString cfg.mtu;
    };

    # Lossless QoS: map DSCP -> priority (trust dscp) and enable PFC on that priority, plus
    # re-assert MTU so `nixos-rebuild switch` takes effect immediately without a reboot.
    # Discovers the RoCE NIC(s) at runtime instead of hardcoding a name.
    systemd.services.rdma-qos = {
      description = "RoCE lossless QoS (DSCP ${toString cfg.dscp} -> prio ${toString cfg.pfcPriority}, PFC, MTU ${toString cfg.mtu})";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.iproute2 config.systemd.package pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = let
        prioPfc = concatStringsSep " " (map
          (p: "${toString p}:${if p == cfg.pfcPriority then "on" else "off"}")
          (range 0 7));
        # Restrict to one interface if overridden, else every netdev on the RoCE driver.
        selector =
          if cfg.interface != null
          then ''printf '%s\n' ${escapeShellArg cfg.interface}''
          else ''
            for n in $(ls /sys/class/net); do
              d=$(udevadm info --query=property --property=ID_NET_DRIVER --value "/sys/class/net/$n" 2>/dev/null)
              [ "$d" = ${escapeShellArg cfg.driver} ] && printf '%s\n' "$n"
            done'';
      in ''
        set -u
        for dev in $(${selector}); do
          [ -e "/sys/class/net/$dev" ] || continue
          echo "rdma-qos: configuring $dev"
          ip link set dev "$dev" mtu ${toString cfg.mtu} || true
          # trust dscp: map RoCEv2's DSCP to the lossless priority for buffer/PFC selection.
          dcb app flush dev "$dev" dscp-prio 2>/dev/null || true
          dcb app add dev "$dev" dscp-prio ${toString cfg.dscp}:${toString cfg.pfcPriority} || true
          dcb pfc set dev "$dev" prio-pfc ${prioPfc} || true
        done
      '';
    };
  };
}
