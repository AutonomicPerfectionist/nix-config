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
  llamaVersion = "8983"; # example version
  llamaPkg = if useCuda then pkgs.llama-cpp
               else if useRocm then pkgs.llama-cpp-rocm
               else if useSycl then pkgs.llama-cpp-sycl
               else pkgs.llama-cpp;
in
{
  options = {
    services.llama = {
      enable = lib.mkEnableOption "Llama.cpp inference service";
      port = lib.mkOption {
        type = lib.types.int;
        default = 8080;
        description = "Port for the Llama.cpp service";
      };
      model = lib.mkOption {
        type = lib.types.str;
        description = "Path to the ggml model file";
      };
    };
  };

  # make the llama binary available on all machines
  config = {
    environment.systemPackages = [ (llamaPkg.override { version = llamaVersion; }) ];
  } // lib.mkIf config.services.llama.enable {
    systemd.services.llama = {
      description = "Llama.cpp inference server";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript \"llama-run\" ''\
          exec ${llamaPkg}/bin/llama-cli \
            --model ${config.services.llama.model} \
            --port ${toString config.services.llama.port}\
        ''}";
        Restart = "on-failure";
        DynamicUser = true;
      };
    };
  };
}