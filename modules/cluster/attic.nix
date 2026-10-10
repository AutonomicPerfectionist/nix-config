# modules/attic-client.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.cluster.atticClient;

  # Config dir for the push service; the token is read from a systemd credential
  pushConfigDir = pkgs.writeTextDir "attic/config.toml" ''
    default-server = "cluster"

    [servers.cluster]
    endpoint = "${cfg.endpoint}"
    token-file = "/run/credentials/attic-watch-store.service/token"
  '';
in
{
  options.cluster.atticClient = {
    enable = lib.mkEnableOption "use of the cluster attic binary cache";

    endpoint = lib.mkOption {
      type = lib.types.str;
      example = "http://big-nix:8080";
      description = "Base URL of the atticd server.";
    };

    cache = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Attic cache name.";
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      example = "main:AbCd...=";
      description = "Public signing key, from `attic cache info <cache>`.";
    };

    push = {
      enable = lib.mkEnableOption "automatically pushing newly built store paths (attic watch-store)";
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing a push-capable attic token (e.g. an agenix/sops secret).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = !cfg.push.enable || cfg.push.tokenFile != null;
      message = "cluster.atticClient.push.enable requires push.tokenFile.";
    }];

    # These lists merge with the NixOS defaults, so cache.nixos.org stays in place.
    nix.settings = {
      substituters = [ "${cfg.endpoint}/${cfg.cache}" ];
      trusted-public-keys = [ cfg.publicKey ];
      connect-timeout = 3;   # don't hang if the cache host is down
      fallback = true;       # build locally if a substitution fails
    };

    environment.systemPackages = [ pkgs.attic-client ];

    systemd.services.attic-watch-store = lib.mkIf cfg.push.enable {
      description = "Push new store paths to the attic cache";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment.XDG_CONFIG_HOME = "${pushConfigDir}";
      serviceConfig = {
        ExecStart = "${pkgs.attic-client}/bin/attic watch-store cluster:${cfg.cache}";
        LoadCredential = "token:${toString cfg.push.tokenFile}";
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
