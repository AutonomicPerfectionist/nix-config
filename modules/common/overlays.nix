# overlays.nix
#
# NixOS module providing GPU compute overlays for:
#   • Intel Arc/Xe  – SYCL via flake-inputs.sycl   (sycl-intel, default on)
#   • AMD           – ROCm from nixpkgs             (rocm-amd,   default off)
#
# Also provides the optional rgerganov/llama.cpp fork swap controlled by
# services.llama.useCustomSource.
#
# IMPORTANT – custom source setup:
#   Add the fork to your flake.nix inputs so Nix pins and hashes it for you:
#
#     inputs.llama-cpp-fork = {
#       url   = "github:rgerganov/llama.cpp/rpc-async";
#       flake = false;   # it's a plain source tree, not a flake
#     };
#
#   Then pass it through to this module via specialArgs / extraModules so
#   flake-inputs.llama-cpp-fork is available here.
{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
let
  # ── Intel overlay ────────────────────────────────────────────────────────
  # Re-export Level Zero and the Intel compute runtime from prev so all
  # packages in the closure share the same ABI.  Does NOT touch kernel
  # drivers — only Nixpkgs-level userspace packages.
  intelOverlay = final: prev: {
    inherit (prev)
      level-zero
      intel-compute-runtime
      intel-graphics-compiler
      ;
  };

  # ── SYCL overlay ─────────────────────────────────────────────────────────
  # Builds llama-cpp-sycl from flake-inputs.sycl against the same Level Zero
  # and compute-runtime versions pinned by intelOverlay, then patches the
  # resulting ELF binaries so they can find the runtime libraries at runtime.
  syclOverlay = final: prev: {
    llama-cpp-sycl = flake-inputs.sycl.packages.${prev.system}.llama-cpp-sycl.overrideAttrs (old: {
      cmakeFlags = (old.cmakeFlags or []) ++ [
        "-DGGML_RPC=ON"
      ];

      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        prev.addDriverRunpath
      ];

      buildInputs = (old.buildInputs or []) ++ [
        prev.level-zero
        prev.intel-compute-runtime
      ];

      # Stamp runpaths on every ELF binary so the loader finds the compute
      # runtime libraries without requiring LD_LIBRARY_PATH.
      postFixup = (old.postFixup or "") + ''
        for bin in $out/bin/*; do
          if [ -x "$bin" ] && file "$bin" | grep -q ELF; then
            addDriverRunpath "$bin"
          fi
        done
      '';
    });
  };

  # ── ROCm overlay ─────────────────────────────────────────────────────────
  # Enables the RPC transport in the upstream nixpkgs ROCm build.
  rocmOverlay = final: prev: {
    llama-cpp-rocm = prev.llama-cpp-rocm.overrideAttrs (old: {
      cmakeFlags = (old.cmakeFlags or []) ++ [
        "-DGGML_RPC=ON"
      ];
    });
  };

  # ── Haddock overlay ──────────────────────────────────────────────────────
  # Disabling Haddock documentation generation shaves significant build time
  # from any Haskell packages pulled in transitively (e.g. by pandoc).
  noHaddockOverlay = final: prev: {
    haskellPackages = prev.haskellPackages.override {
      overrides = hfinal: hprev: {
        mkDerivation = args:
          hprev.mkDerivation (args // { doHaddock = false; });
      };
    };
  };

  # ── ROCm LLVM overlay ────────────────────────────────────────────────────
  # ROCm ships its own LLVM fork.  The upstream nixpkgs derivation hard-codes
  # march=skylake / mtune=znver3 which emits AVX2/BMI2 instructions that crash
  # on Ivy Bridge and similar hosts.
  #
  # This overlay is only active when scl.overlays.rocm-llvm-arch is set.
  # It rebuilds ONLY ROCm's LLVM using the specified arch, leaving all other
  # nixpkgs packages untouched so binary cache hits are preserved.
  #
  # NOTE: do NOT set nixpkgs.hostPlatform.gcc.arch on the host — that would
  # cause every package to be rebuilt from source, defeating the cache.
  # Instead, set scl.overlays.rocm-llvm-arch = "ivybridge" (or similar) and
  # leave hostPlatform as plain "x86_64-linux".
  rocmLlvmOverlay =
    if config.scl.overlays.rocm-llvm-arch == null
    then (_: _: {})
    else
      final: prev:
        let
          hostArch = config.scl.overlays.rocm-llvm-arch;

          marchFlag = "-march=${hostArch}";

          # Suppress all post-AVX extensions that ivybridge (and similar) lack.
          # Since hostPlatform is left as plain x86_64-linux, gcc.isa will be
          # empty — so these flags are always appended when an arch is set,
          # which is the safe/correct behaviour for pre-AVX2 hosts.
          noExtensionFlags = [
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

          # Strip hard-coded march/mtune flags from a derivation's
          # NIX_CFLAGS_COMPILE and replace them with the host-appropriate ones.
          patchCFlags = pkg: pkg.overrideAttrs (old: {
            env = (old.env or {}) // {
              NIX_CFLAGS_COMPILE = lib.pipe (old.env.NIX_CFLAGS_COMPILE or "") [
                (lib.splitString " ")
                (builtins.filter (f:
                  f != "-march=skylake" &&
                  f != "-mtune=znver3"  &&
                  f != ""
                ))
                (flags: flags ++ [ hostCFlags ])
                (lib.concatStringsSep " ")
              ];
            };
          });

          # Patch the libstdcxxClang wrapper so the host flags propagate into
          # all downstream compilations that use this compiler.
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
                  {};
              in
              base // {
                llvm              = patchCFlags base.llvm;
                lld               = patchCFlags base.lld;
                clang-unwrapped   = patchCFlags base.clang-unwrapped;
              }
            );
          });
        };

  # ── Custom source overlay ─────────────────────────────────────────────────
  # When services.llama.useCustomSource is true, replace every llama-cpp
  # variant's src with the rgerganov fork.  Using a flake input means Nix
  # pins the exact commit and hash in flake.lock — no manual sha256 needed
  # and pure evaluation works correctly.
  #
  # builtins.fetchGit was used here previously but has two problems:
  #   1. It does NOT accept a `sha256` argument (that's fetchFromGitHub).
  #   2. Passing a branch name as `rev` fails in --pure-eval / flake mode.
  #
  # The fix: declare the fork in flake.nix (see comment at the top of this
  # file) and reference flake-inputs.llama-cpp-fork as the src below.
  customSourceOverlay = final: prev:
  let
    forkSrc = flake-inputs.llama-cpp-fork;

    overrideFork = pkg: pkg.overrideAttrs (_: {
      src = forkSrc;

      npmDepsHash =
        "sha256-pjdbI6NcZRlJVd62xhgbLhWrwFYwgsIwjORqvo1+VD8=";
    });

  in
  lib.optionalAttrs config.services.llama.useCustomSource {

    llama-cpp =
      overrideFork prev.llama-cpp;

    llama-cpp-rocm =
      overrideFork prev.llama-cpp-rocm;

    llama-cpp-vulkan =
      overrideFork prev.llama-cpp-vulkan;

    # IMPORTANT:
    # sycl package comes from flake-inputs.sycl, so override THAT package
    # directly rather than rebuilding from plain llama-cpp.
    llama-cpp-sycl =
      overrideFork prev.llama-cpp-sycl;
  };

 # ── ROCm GPU targets overlay ───────────────────────────────────────────────
  # Restricts rocmPackages.clr to only build for the specified GPU
  # architectures.  Changes to rocmPackages propagate to pkgsRocm (the
  # nixpkgs set with rocmSupport=true), so pkgsRocm.llama-cpp picks up
  # the restricted target set automatically.
  rocmGpuTargetsOverlay =
    lib.optionalAttrs (config.scl.overlays.rocm-gpu-targets != [])
      (final: prev: {
        rocmPackages = prev.rocmPackages.overrideScope (scopeFinal: scopePrev: {
          clr = scopePrev.clr.override {
            localGpuTargets = config.scl.overlays.rocm-gpu-targets;
          };
        });
      });

in
{
  # ── Options ────────────────────────────────────────────────────────────────

  options.scl.overlays = {
    sycl-intel = lib.mkEnableOption "SYCL + Intel GPU overlay stack" // { default = true;  };
    rocm-amd   = lib.mkEnableOption "ROCm  + AMD  GPU overlay stack" // { default = false; };
    rocm-gpu-targets = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [ "gfx906" ];
      description = ''
        ROCm GPU target architectures to build into pkgsRocm.
        gfx1030 = RX 6xxx / W6800, gfx906 = MI50 / MI60 / MI210 / MI250.
      '';
    };
    rocm-llvm-arch = lib.mkOption {
      type        = lib.types.nullOr lib.types.str;
      default     = null;
      description = ''
        When set, overrides the march used when building ROCm's LLVM,
        replacing the upstream hardcoded skylake/znver3 flags.  Set this
        to your host CPU architecture (e.g. "ivybridge") to avoid illegal
        instruction crashes on older hardware.

        Critically, this only affects ROCm's internal LLVM scope — all
        other nixpkgs packages are left untouched, preserving binary cache
        hits.  Do NOT set nixpkgs.hostPlatform.gcc.arch to achieve this;
        doing so rebuilds everything from source.
      '';
    };
  };

  # ── Config ─────────────────────────────────────────────────────────────────

  config.nixpkgs.overlays = lib.concatLists [
    # Intel SYCL stack (Level Zero ABI pin + llama-cpp-sycl build).
    (lib.optionals config.scl.overlays.sycl-intel [ intelOverlay syclOverlay ])

    # AMD ROCm stack (llama-cpp-rocm with RPC + patched LLVM).
    # rocmLlvmOverlay is a no-op when rocm-llvm-arch is null, so it is safe
    # to include unconditionally; the guard lives inside the overlay itself.
    (lib.optionals config.scl.overlays.rocm-amd  [ rocmOverlay rocmLlvmOverlay ])

    # ROCm GPU target architectures (restricts clr + downstream pkgsRocm).
    (lib.optionals (config.scl.overlays.rocm-gpu-targets != []) [ rocmGpuTargetsOverlay ])

    # Global overlays applied regardless of GPU selection.
    [ noHaddockOverlay ]

    # llm-agents nixpkgs overlay from its own flake input.
    [ flake-inputs.llm-agents.overlays.default ]

    # Source swap: replaces every llama-cpp variant with the rgerganov fork
    # when services.llama.useCustomSource = true.
    [ customSourceOverlay ]
  ];
}

