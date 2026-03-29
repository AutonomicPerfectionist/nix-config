{ pkgs, lib, config, ... }:
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

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
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
    in [
      "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
    ];
    }
    ]);
}
