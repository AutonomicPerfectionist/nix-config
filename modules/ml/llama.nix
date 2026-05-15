{
  config,
  lib,
  pkgs,
  ...
}:

let
	inherit (lib)
	   cmakeBool
	   cmakeFeature
	   optionals
	   optionalString
	   ;
  cfg = config.services.llama;

  useCuda = config.hardware.gpu.nvidia.enable or false;
  useRocm = config.hardware.gpu.amd.enable or false;
  useSycl = config.hardware.gpu.intel.enable or false;

  llamaVersion = "8983";

  # Select the correct backend variant
  llamaBasePkg =
    if useCuda then pkgs.llama-cpp
    else if useRocm then pkgs.llama-cpp-rocm
    else if useSycl then pkgs.llama-cpp-sycl
    else pkgs.llama-cpp;

  # Pin/override the package version
#   llamaPkg = llamaBasePkg.overrideAttrs (old: rec {
#     version = llamaVersion;
# 
#     src = pkgs.fetchFromGitHub {
#       owner = "ggml-org";
#       repo = "llama.cpp";
# 
#       # adjust if your target revision/tag differs
#       rev = "b${version}";
# 
#       # MUST be updated with the real hash after first build
#       hash = "sha256-rHyHkqA8YLKTY/YTzqiR9wfLAtMBLJyqV+BJ/ChrKKM=";
#     };
#   });
    llamaPkg = llamaBasePkg.overrideAttrs (old: {
      cmakeFlags =
        (old.cmakeFlags or [])
        ++ [
          (cmakeBool "GGML_NATIVE" false)
      
          (cmakeBool "GGML_AVX" true)
          (cmakeBool "GGML_AVX2" false)
          (cmakeBool "GGML_BMI2" false)
          (cmakeBool "GGML_FMA" false)
          (cmakeBool "GGML_F16C" false)
      
          (cmakeBool "GGML_CPU_ALL_VARIANTS" false)
      
          (cmakeBool "GGML_BACKEND_DL" true)
        ];
    });

in
{
  options.services.llama = {
    enable = lib.mkEnableOption "Llama.cpp inference service";

    package = lib.mkOption {
      type = lib.types.package;
      default = llamaPkg;
      defaultText = lib.literalExpression "auto-selected llama.cpp variant";
      description = ''
        The llama.cpp package to install and use.
        Automatically selects CUDA/ROCm/SYCL variants based on hardware config.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for the llama.cpp server.";
    };

    model = lib.mkOption {
      type = lib.types.path;
      default = "";
      description = "Path to the GGUF model file.";
    };
  };

  
  config = lib.mkMerge [
    {
      environment.systemPackages = [
        llamaPkg
      ];
    }
  
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.model != "";
          message = "services.llama.model must be set when enabling the service.";
        }
      ];
  
      systemd.services.llama = {
        description = "llama.cpp inference server";
  
        wantedBy = [ "multi-user.target" ];
  
        after = [ "network.target" ];
  
        serviceConfig = {
          Type = "simple";
  
          ExecStart = ''
            ${cfg.package}/bin/llama-server \
              --model ${cfg.model} \
              --port ${toString cfg.port}
          '';
  
          Restart = "on-failure";
  
          DynamicUser = true;
        };
      };
    })
  ];
}
