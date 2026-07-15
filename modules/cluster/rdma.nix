{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.cluster.rdma;
  perftest = pkgs.callPackage ../../pkgs/perftest { };
in
{
  options.cluster.rdma = {
    enable = mkEnableOption "RDMA/RoCE support for the Mellanox ConnectX-3 Pro cluster fabric";

    interface = mkOption {
      type = types.str;
      default = "ens1";
      description = "Network interface name of the RDMA-capable NIC.";
    };

    pfcPriority = mkOption {
      type = types.int;
      default = 3;
      description = "802.1p priority marked lossless (PFC) for RoCE traffic. Must match the switch-side no-drop qos-group.";
    };

    mtu = mkOption {
      type = types.int;
      default = 9000;
      description = "MTU for the RDMA interface. Should be <= the switch's no-drop class MTU (9216) minus overhead.";
    };

    gidIndex = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        RoCE v2 GID index to prefer for raw ibverbs tools on this host (e.g. ibv_rc_pingpong -g).
        Purely informational/documentation here — not consumed by any perftest/librdmacm tooling,
        since RDMA-CM auto-negotiates this. Set per-host if you need to remember which port is live.
      '';
    };
  };

  config = mkIf cfg.enable {
    hardware.infiniband.enable = true;

    environment.systemPackages = with pkgs; [
      rdma-core
      iproute2
      mstflint
      perftest
    ];

    networking.interfaces.${cfg.interface}.mtu = cfg.mtu;

    systemd.services."rdma-pfc-${cfg.interface}" = {
      description = "Enable Priority Flow Control on ${cfg.interface} for RoCE (priority ${toString cfg.pfcPriority})";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          prioList = lib.concatStringsSep " " (map
            (p: "${toString p}:${if p == cfg.pfcPriority then "on" else "off"}")
            (lib.range 0 7));
        in "${pkgs.iproute2}/bin/dcb pfc set dev ${cfg.interface} prio-pfc ${prioList}";
      };
    };
  };
}
