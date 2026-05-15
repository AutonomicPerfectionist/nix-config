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
    if useCuda then pkgs.pkgsCuda.llama-cpp
    else if useRocm then pkgs.llama-cpp-rocm
    else if useSycl then pkgs.llama-cpp-sycl
    else pkgs.llama-cpp;

  # Probe the host platform's ISA feature set once
  hostIsa = pkgs.stdenv.hostPlatform.gcc.isa or [ ];
  hasIsa = feat: builtins.elem feat hostIsa;

  llamaPkg = llamaBasePkg.overrideAttrs (old: {
    cmakeFlags =
      (old.cmakeFlags or [])
      ++ [
        (cmakeBool "GGML_NATIVE" false)

        # AVX is baseline for x86-64; only disable it if the host truly lacks it
        (cmakeBool "GGML_AVX"   (hasIsa "avx"))

        # These extensions are absent on Ivy Bridge and similar; enable only
        # when the host platform advertises them.
        (cmakeBool "GGML_AVX2"  (hasIsa "avx2"))
        (cmakeBool "GGML_BMI2"  (hasIsa "bmi2"))
        (cmakeBool "GGML_FMA"   (hasIsa "fma"))
        (cmakeBool "GGML_F16C"  (hasIsa "f16c"))

        (cmakeBool "GGML_CPU_ALL_VARIANTS" true)
        (cmakeBool "GGML_BACKEND_DL"       true)
        (cmakeBool "GGML_RPC"       true)
        
        
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
