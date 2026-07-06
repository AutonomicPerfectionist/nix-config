{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config;
in
{

  options.hardware.gpu.amd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable AMD GPU support";
    };

    cards = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of AMD GPU cards to enable specific support for";
    };
  };

  # TODO Add quirk for 6700xt: export HSA_OVERRIDE_GFX_VERSION=10.3.0
  config = mkIf cfg.hardware.gpu.amd.enable (mkMerge [
    {

      environment.systemPackages = with pkgs; [
      	nvtopPackages.amd
      ];

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      # Make the AMD ROCm/OpenCL compute stack discoverable to *foreign*
      # (non-Nix) dynamically-linked programs — e.g. pip/uv-installed PyTorch
      # ROCm wheels, which dlopen() driver libraries by name at runtime.
      #
      # nix-ld seeds the initial binary's search path via NIX_LD_LIBRARY_PATH
      # but does not export LD_LIBRARY_PATH, so a runtime dlopen() by name still
      # fails. /run/opengl-driver/lib (populated by hardware.graphics) holds the
      # GPU driver libraries; exporting it on LD_LIBRARY_PATH lets foreign
      # wheels find them with no per-project setup.
      #
      # Placed in sessionVariables so it is set for both interactive login
      # shells (/etc/set-environment) and non-interactive ssh sessions
      # (/etc/pam/environment via pam_env). The ''${LD_LIBRARY_PATH} reference is
      # braced so it expands in both files (pam_env only understands the braced
      # form). This directory contains only GPU driver libraries, so it is safe
      # to prepend globally.
      environment.sessionVariables = {
        LD_LIBRARY_PATH = "/run/opengl-driver/lib:\${LD_LIBRARY_PATH}";
      };

      systemd.tmpfiles.rules =
        let
          rocmEnv = pkgs.symlinkJoin {
            name = "rocm-combined";
            paths = with pkgs.rocmPackages; [
              rocblas
              hipblas
              clr
            ];
          };
        in
        [
          "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
        ];
    }
  ]);
}
