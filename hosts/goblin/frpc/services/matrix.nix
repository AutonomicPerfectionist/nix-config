# IMPORTANT
# BEFORE ENABLING THIS MODULE, make sure to setup the db with collation:
# ```sql
# CREATE ROLE "matrix-synapse";
# CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
#   TEMPLATE template0
#   LC_COLLATE = "C"
#   LC_CTYPE = "C";
# ```
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.goblin-frpc.services.matrix;
  inherit (lib) mkOption types;
  assertPropsSet =
    { cfg, props }:
    builtins.map (prop: {
      assertion = cfg.${prop} != null;
      message = "${prop} must be set.";
    }) props;
in
{
  imports = [
    ./postgresql.nix
  ];

  options.goblin-frpc.services.matrix = {
    enable = lib.mkEnableOption "Enable the matrix service";
    hostname = mkOption {
      type = types.str;
    };
    passFile = mkOption {
      type = types.str;
    };
    internalHTTPPort = mkOption {
      type = types.int;
    };
  };

  config =
    let
      baseUrl = "https://${cfg.hostname}/";
    in
    lib.mkIf cfg.enable {
      # assertions = [
      #   {
      #     assertion = config.goblin-frpc.enable == true;
      #     message = "goblin-frpc must be enabled to use this service proxy";
      #   }
      # ]
      # ++ (assertPropsSet {
      #   cfg = cfg;
      #   props = [
      #     "package"
      #     "extraApps"
      #     "hostname"
      #     "datadir"
      #     "dbPassFile"
      #     "internalHTTPPort"
      #   ];
      # });

      environment.systemPackages = with pkgs; [
        matrix-synapse
      ];

      services.matrix-synapse = {
        enable = true;
        settings.server_name = cfg.hostname;
        settings.public_baseurl = baseUrl;
        settings.listeners = [
          {
            port = 8008;
            bind_addresses = [ "::1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = [
                  "client"
                  "federation"
                ];
                compress = true;
              }
            ];
          }
        ];
        extraConfigFiles = [ cfg.passFile ];
      };

      # Override the nextcloud service's nginx entry so it listens on our custom port.
      services.nginx =
        let
          serverConfig = {
            "m.server" = "${baseUrl}:443";
          };
          clientConfig = {
            "m.homeserver" = {
              base_url = baseUrl;
            };
          };
          mkWellKnown = data: ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON data}';
          '';
        in
        {
          enable = true;
          virtualHosts."${cfg.hostname}" = {
            locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
            locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
            listen = [
              {
                addr = "127.0.0.1";
                port = cfg.internalHTTPPort;
                ssl = false;
              }
            ];
            locations."/".extraConfig = ''
              return 404;
            '';

            locations."/_matrix".proxyPass = "http://[::1]:8008";
            locations."/_synapse/client".proxyPass = "http://[::1]:8008";
          };
        };

      goblin-frpc.proxies = [
        {
          name = "matrix";
          type = "http";
          localIP = "127.0.0.1";
          localPort = cfg.internalHTTPPort;
          customDomains = [ cfg.hostname ];
          hostHeaderRewrite = "";
          requestHeaders.set.x-from-where = "frp";
          responseHeaders.set.foo = "bar";
          # healthCheck = {
          #   type = "http";
          #   # frpc will send a GET http request '/status' to local http service
          #   # http service is alive when it return 2xx http response code
          #   path = "/status.php";
          #   intervalSeconds = 60;
          #   maxFailed = 3;
          #   timeoutSeconds = 5;
          #   # set health check headers
          #   httpHeaders = [
          #     {
          #       name = "User-Agent";
          #       value = "FRP-Healthcheck";
          #     }
          #     {
          #       name = "x-from-where";
          #       value = "frp";
          #     }
          #   ];
          # };
        }
      ];

      services.postgresql = {
        ensureDatabases = [
          "matrix-synapse"
        ];
        ensureUsers = [
          {
            name = "matrix-synapse";
            ensureDBOwnership = true;
          }
        ];
      };

    };
}
