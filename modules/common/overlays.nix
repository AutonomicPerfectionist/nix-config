{
  # This module provides GPU compute overlays for Intel SYCL and AMD ROCm stacks.
  # Enable sycl-intel for Intel Arc/Xe GPUs with llama-cpp-sycl, or
  # rocm-amd for AMD GPUs with llama-cpp-rocm.

  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
let
  # Inherit Intel userspace packages at consistent versions across the system closure.
  # This does NOT modify kernel drivers, only Nixpkgs-level packages.
  intelOverlay = final: prev: {
    inherit (prev)
      level-zero
      intel-compute-runtime
      intel-graphics-compiler
      ;
  };

  # Build llama-cpp-sycl against the same pkgs set so it shares Level Zero and
  # compute runtime ABI. Also patches binaries with proper runpaths.
  syclOverlay = final: prev: {
    llama-cpp-sycl = flake-inputs.sycl.packages.${prev.system}.llama-cpp-sycl.overrideAttrs (old: {
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [
        "-DGGML_RPC=ON"
      ];

      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.addDriverRunpath ];

      buildInputs = (old.buildInputs or [ ]) ++ [
        prev.level-zero
        prev.intel-compute-runtime
      ];

      # Add runpath to built binaries so they can find the compute runtime libraries
      postFixup = (old.postFixup or "") + ''
        for bin in $out/bin/*; do
          if [ -x "$bin" ] && file "$bin" | grep -q ELF; then
            addDriverRunpath "$bin"
          fi
        done
      '';
    });
  };

  # Enable RPC support for distributed llama.cpp workloads
  rocmOverlay = final: prev: {
    llama-cpp-rocm = prev.llama-cpp-rocm.overrideAttrs (old: {
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [
        "-DGGML_RPC=ON"
      ];
    });
  };
in
{
  # Enable sycl-intel for Intel GPUs (default), rocm-amd for AMD GPUs
  options.scl.overlays = {
    sycl-intel = lib.mkEnableOption "SYCL + Intel overlay stack" // { default = true; };
    rocm-amd = lib.mkEnableOption "ROCm + AMD overlay stack" // { default = false; };
  };

  config = {
    nixpkgs.overlays = [
      (lib.mkIf config.scl.overlays.sycl-intel intelOverlay)
      (lib.mkIf config.scl.overlays.sycl-intel syclOverlay)
      (lib.mkIf config.scl.overlays.rocm-amd rocmOverlay)
    ];
  };
}
