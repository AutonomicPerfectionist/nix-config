{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    enableCudaSupport = lib.mkEnableOption "Enable CUDA support in nixpkgs";
    enableRocmSupport = lib.mkEnableOption "Enable ROCm (AMD GPU) support in nixpkgs";
  };

  config = lib.mkMerge [
    (lib.mkIf config.enableCudaSupport {
      nixpkgs.config.cudaSupport = true;
    })
    (lib.mkIf config.enableRocmSupport {
      nixpkgs.config.rocmSupport = true;
    })
  ];
}
