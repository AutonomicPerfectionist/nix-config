{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Determine which GPU backend is enabled
  useCuda = config.hardware.gpu.nvidia.enable or false;
  useRocm = config.hardware.gpu.amd.enable or false;
  useSycl = config.hardware.gpu.intel.enable or false;
  # Centralized Llama.cpp version (same for all variants)
  llamaVersion = "8983"; 
  # Choose the appropriate package based on GPU backend
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

  # Install the appropriate llama package regardless of service enablement
  environment.systemPackages = [ (llamaPkg.override { version = llamaVersion; }) ];

  config = lib.mkIf config.services.llama.enable {
    # Simple systemd service to run llama.cpp server
    systemd.services.llama = {
      description = "Llama.cpp inference server";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "llama-run" ''
          exec ${llamaPkg}/bin/llama-cli \
            --model ${config.services.llama.model} \
            --port ${toString config.services.llama.port}
        ''}";
        Restart = "on-failure";
        DynamicUser = true;
      };
    };
  };
}
