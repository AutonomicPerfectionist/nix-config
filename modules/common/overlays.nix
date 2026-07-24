# overlays.nix
#
# NixOS module providing GPU compute overlays for:
#   • Intel Arc/Xe  – SYCL via nixpkgs intel-oneapi-toolkit (sycl-intel, default on)
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
  # ── SYCL toolkit (Intel oneAPI, from nixpkgs) ─────────────────────────────
  # nixpkgs' intel-oneapi-toolkit ships the DPC++ compiler (icpx), oneMKL and
  # TBB from a single 2026 release — all sharing ONE libsycl.so.9. Building
  # llama's SYCL backend and linking oneMKL from the same toolkit therefore
  # avoids the dual-libsycl ABI crash that occurs when an intel/llvm-nightly
  # llama (libsycl.so.9) is linked against an oneAPI-release oneMKL
  # (libsycl.so.8): the loader interposes __sycl_register_lib across versions
  # and segfaults at static-init. We only install the components we need to
  # keep the closure down (this is a ~unfree binary toolkit, built locally).
  syclToolkit = pkgs.intel-oneapi-toolkit.override {
    components = [
      "intel.oneapi.lin.dpcpp-cpp-compiler"
      "intel.oneapi.lin.mkl.devel"
      "intel.oneapi.lin.tbb.devel"
    ];
  };

  # ── SYCL overlay ─────────────────────────────────────────────────────────
  # Hand-written llama-cpp-sycl: nixpkgs' llama-cpp has no SYCL backend, so we
  # compile the sredman rpc-pipeline-parallelism fork (same source as the other
  # llama.cpp services, for RPC wire-compatibility) with the toolkit's icpx
  # stdenv and its bundled oneMKL. The generic cmake flags (single CPU backend,
  # Broadwell ISA, GGML_RPC) are layered on by modules/ml/llama.nix.
  syclOverlay = final: prev: {
    llama-cpp-sycl = syclToolkit.stdenv.mkDerivation (finalAttrs: {
      pname = "llama-cpp-sycl";
      version = "b0-rpc-pp-fork"; # sredman rpc-pipeline-parallelism branch

      src = flake-inputs.llama-cpp-fork;

      # nixpkgs' stdenv injects -D_FORTIFY_SOURCE, and icpx forwards it to the
      # SYCL *device* (SPIR-V) compilation too. Fortified memcpy emits calls to
      # __memcpy_chk, which does not exist in the GPU device runtime — the JIT
      # then fails at kernel link time ("Unresolved Symbol <__memcpy_chk>") and
      # the first matmul aborts. Disable fortify so device code uses plain
      # memcpy. (Host-side impact is negligible; the GPU does the work.)
      hardeningDisable = [ "fortify" "fortify3" ];

      nativeBuildInputs = [
        prev.cmake
        prev.ninja
        prev.pkg-config
        prev.git
        prev.autoAddDriverRunpath
      ];

      buildInputs = [
        syclToolkit        # DPC++ runtime + oneMKL (find_package(MKL))
        prev.level-zero    # ze_loader for GGML_SYCL_SUPPORT_LEVEL_ZERO
        prev.ocl-icd
        prev.opencl-headers
        prev.curl
      ];

      # find_package(MKL) reads MKLROOT to locate MKLConfig.cmake + libraries.
      MKLROOT = "${syclToolkit}/mkl/latest";

      cmakeFlags = [
        (lib.cmakeBool "GGML_SYCL" true)
        "-DGGML_SYCL_TARGET=INTEL"
        (lib.cmakeBool "GGML_SYCL_F16" true)

        # oneDNN is not in our component set; the fork gates it on GGML_SYCL_DNN.
        (lib.cmakeBool "GGML_SYCL_DNN" false)

        (lib.cmakeBool "BUILD_SHARED_LIBS"    true)
        (lib.cmakeBool "LLAMA_BUILD_SERVER"   true)

        # Headless, offline build: the fork's Svelte web UI provisioning
        # defaults to an npm build + HuggingFace download (impossible/slow in
        # the sandbox). The OpenAI/completion API is unaffected.
        (lib.cmakeBool "LLAMA_BUILD_UI"        false)
        (lib.cmakeBool "LLAMA_USE_PREBUILT_UI" false)

        # Tests/examples pull jinja/minja-heavy TUs that stall the compile and
        # aren't needed for a server node.
        (lib.cmakeBool "LLAMA_BUILD_TESTS"    false)
        (lib.cmakeBool "LLAMA_BUILD_EXAMPLES" false)

        # oneMKL host threading is irrelevant here (BLAS runs on the GPU);
        # sequential drops the TBB/libiomp5 discovery that otherwise fails.
        "-DMKL_THREADING=sequential"
        "-DMKL_SYCL_THREADING=sequential"
      ];

      postInstall = ''
        ln -sf $out/bin/llama-cli $out/bin/llama
        mkdir -p $out/include
        cp $src/include/llama.h $out/include/ || true
      '';

      # Stamp the GPU driver runpath (/run/opengl-driver/lib) onto every ELF so
      # the Level Zero loader and UR adapters resolve at runtime.
      postFixup = ''
        for f in "$out"/bin/* "$out"/lib/*.so*; do
          if [ -f "$f" ] && head -c4 "$f" | grep -q ELF; then
            addDriverRunpath "$f" || true
          fi
        done
      '';

      meta = {
        description = "llama.cpp with Intel oneAPI SYCL backend (rpc fork)";
        mainProgram = "llama-server";
      };
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

    # NOTE: llama-cpp-sycl is defined by syclOverlay directly from the fork
    # source (nixpkgs has no SYCL llama-cpp to override), so it is intentionally
    # absent here.
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
    sycl-intel = lib.mkEnableOption "SYCL + Intel GPU overlay stack";
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
    # Intel SYCL stack (llama-cpp-sycl built against nixpkgs intel-oneapi-toolkit).
    (lib.optionals config.scl.overlays.sycl-intel [ syclOverlay ])

    # AMD ROCm stack (llama-cpp-rocm with RPC + patched LLVM).
    # rocmLlvmOverlay is a no-op when rocm-llvm-arch is null, so it is safe
    # to include unconditionally; the guard lives inside the overlay itself.
    (lib.optionals config.scl.overlays.rocm-amd  [ rocmOverlay rocmLlvmOverlay ])

    # ROCm GPU target architectures (restricts clr + downstream pkgsRocm).
    (lib.optionals (config.scl.overlays.rocm-gpu-targets != []) [ rocmGpuTargetsOverlay ])

    # Global overlays applied regardless of GPU selection.
    [ noHaddockOverlay ]

    # llm-agents nixpkgs overlay from its own flake input.
    [ flake-inputs.llm-agents.overlays.shared-nixpkgs ]

    # Source swap: replaces every llama-cpp variant with the rgerganov fork
    # when services.llama.useCustomSource = true.
    [ customSourceOverlay ]

    [ flake-inputs.niri.overlays.niri ]
  ];
}

