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

  noHaddockOverlay = final: prev: {
    haskellPackages = prev.haskellPackages.override {
      overrides = hfinal: hprev: {
        mkDerivation = args:
          hprev.mkDerivation (args // {
            doHaddock = false;
          });
      };
    };
  };

  # Rebuild ROCm's LLVM fork respecting the host platform's CPU architecture,
  # preventing BMI2/AVX2 instructions from being emitted on hosts that lack them.
  # Uses final.stdenv.hostPlatform to derive march flags so this works generically
  # across any host, not just ivybridge.
  rocmLlvmOverlay = final: prev:
    let
      hostArch =
        final.stdenv.hostPlatform.gcc.arch
          or final.stdenv.hostPlatform.parsed.cpu.name;
  
      marchFlag = "-march=${hostArch}";
  
      noExtensionFlags = lib.optionals
        (!(builtins.elem "avx2" (final.stdenv.hostPlatform.gcc.isa or [ ])))
        [
          "-mno-avx2"
          "-mno-bmi2"
          "-mno-bmi"
          "-mno-movbe"
          "-mno-fma"
          "-mno-lzcnt"
          "-mno-rdrnd"
          "-mno-f16c"
        ];
  
      hostCFlags = lib.concatStringsSep " " ([ marchFlag ] ++ noExtensionFlags);
  
      # Strip hardcoded skylake/znver3 flags from NIX_CFLAGS_COMPILE in env
      # and replace with host-appropriate flags.
      patchCFlags = pkg: pkg.overrideAttrs (old: {
        env = (old.env or { }) // {
          NIX_CFLAGS_COMPILE = lib.pipe (old.env.NIX_CFLAGS_COMPILE or "") [
            (lib.splitString " ")
            (builtins.filter (f:
              f != "-march=skylake" &&
              f != "-mtune=znver3" &&
              f != ""
            ))
            (flags: flags ++ [ hostCFlags ])
            (lib.concatStringsSep " ")
          ];
        };
      });
  
      llvmPackages_22_patched = prev.llvmPackages_22 // {
        override = args:
          let
            base = prev.llvmPackages_22.override args;
            patchedLibstdcxxClang = base.libstdcxxClang.overrideAttrs (old: {
              postFixup = (old.postFixup or "") + ''
                echo "${hostCFlags}" >> $out/nix-support/cc-cflags
              '';
            });
          in
          base // {
            inherit (base) override overrideScope;
            libstdcxxClang = patchedLibstdcxxClang;
          };
      };
    in
    {
      rocmPackages = prev.rocmPackages.overrideScope (scopeFinal: scopePrev: {
        llvm = lib.recurseIntoAttrs (
          let
            base = lib.callPackageWith
              (final // {
                inherit (scopePrev) rocm-device-libs;
                llvmPackages_22 = llvmPackages_22_patched;
              })
              (prev.path + "/pkgs/development/rocm-modules/llvm/default.nix")
              { };
          in
          base // {
            llvm = patchCFlags base.llvm;
            lld = patchCFlags base.lld;
            clang-unwrapped = patchCFlags base.clang-unwrapped;
          }
        );
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
    nixpkgs.overlays = lib.concatLists [
      (lib.optionals config.scl.overlays.sycl-intel [ intelOverlay syclOverlay ])
      (lib.optionals config.scl.overlays.rocm-amd [ rocmOverlay ])
      [ noHaddockOverlay ]
      [ rocmLlvmOverlay  ]
    ];
  };
}
