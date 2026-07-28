{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.scl.monitoring;

  # https://grafana.com/grafana/dashboards/1860-node-exporter-full/
  nodeExporterFullDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/45/download";
    sha256 = "11hrll7fm626ikbva5md4gm0rca537vp4xsxa9sxl1pk15s6nk0q";
  };

  dashboardsDir = pkgs.linkFarm "grafana-dashboards" [
    {
      name = "node-exporter-full.json";
      path = nodeExporterFullDashboard;
    }
    {
      name = "cluster-overview.json";
      path = ./dashboards/cluster-overview.json;
    }
  ];
in
{
  options.scl.monitoring = {
    enable = mkEnableOption "Prometheus node_exporter monitoring agent";

    server = {
      enable = mkEnableOption "Prometheus server and Grafana on this host";
    };

    domain = mkOption {
      type = types.str;
      default = "local";
      description = "DNS domain for hostname resolution (used for mDNS/.local)";
    };
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      exporters.node = {
        enable = true;
        enabledCollectors = [
          "cpu"
          "diskstats"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "stat"
          "systemd"
          "time"
          "uname"
        ];
        port = 9100;
      };
    } // lib.optionalAttrs cfg.server.enable {
      enable = true;
      port = 9090;

      scrapeConfigs = [
        {
          job_name = "node";
          scrape_interval = "20s";
          static_configs = [
            {
              targets = [
                "big-nix.${cfg.domain}:9100"
                "battle-bucket.${cfg.domain}:9100"
                "arid-wind.${cfg.domain}:9100"
                "cursed-steel.${cfg.domain}:9100"
                "fatman-1.${cfg.domain}:9100"
                "fatman-2.${cfg.domain}:9100"
                "fatman-3.${cfg.domain}:9100"
                "fatman-4.${cfg.domain}:9100"
                "thunder-budget-1.${cfg.domain}:9100"
                "thunder-budget-2.${cfg.domain}:9100"
                "thunder-budget-3.${cfg.domain}:9100"
                "thunder-budget-4.${cfg.domain}:9100"
                "king-blue.${cfg.domain}:9100"
                "queen-blue.${cfg.domain}:9100"
              ];
            }
          ];
        }
      ];
    };

    age.secrets.grafana-secret-key = mkIf cfg.server.enable {
      file = ../../secrets/grafana-secret-key.age;
      owner = "grafana";
      group = "grafana";
    };

    # Prometheus does its own DNS resolution and never consults glibc NSS/nss-mdns,
    # so it can't resolve .local scrape targets through Avahi alone. Route it through
    # systemd-resolved's mDNS-aware stub instead; MulticastDNS=resolve keeps resolved
    # as a resolver only, so it doesn't fight Avahi over responding to mDNS queries.
    networking.networkmanager.dns = mkIf cfg.server.enable "systemd-resolved";
    services.resolved = mkIf cfg.server.enable {
      enable = true;
      settings.Resolve.MulticastDNS = "resolve";
    };

    services.grafana = mkIf cfg.server.enable {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
          domain = "big-nix.${cfg.domain}";
        };
        security.secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:${toString config.services.prometheus.port}";
            isDefault = true;
          }
        ];
        dashboards.settings.providers = [
          {
            name = "default";
            options.path = dashboardsDir;
          }
        ];
      };
    };
  };
}