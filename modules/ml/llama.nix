{
  config,
  lib,
  pkgs,
  ...
}:
let
  useCuda = config.hardware.gpu.nvidia.enable or false;
  useRocm = config.hardware.gpu.amd.enable or false;
  useSycl = config.hardware.gpu.intel.enable or false;

  llamaVersion = "8983";

  llamaBasePkg =
    if useCuda then pkgs.llama-cpp
    else if useRocm then pkgs.llama-cpp-rocm
    else if useSycl then pkgs.llama-cpp-sycl
    else pkgs.llama-cpp;

  llamaPkg = llamaBasePkg.override {
    version = llamaVersion;
  };
in
{
  options = {
    services.llama = {
      enable = lib.mkEnableOption "Llama.cpp inference service";

      port = lib.mkOption {
        type = lib.types.int;
        default = 8080;
      };

      model = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = {
    # always install the correct variant/version
    environment.systemPackages = [ llamaPkg ];
  }
  // lib.mkIf config.services.llama.enable {
    systemd.services.llama = {
      description = "Llama.cpp inference server";

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = pkgs.writeShellScript "llama-run" ''
          exec ${llamaPkg}/bin/llama-cli \
            --model ${config.services.llama.model} \
            --port ${toString config.services.llama.port}
        '';

        Restart = "on-failure";
        DynamicUser = true;
      };
    };
  };
}
