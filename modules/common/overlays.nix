# overlays.nix
#
# NixOS-only module providing GPU compute overlays for:
#   • Intel Arc/Xe  – SYCL via nixpkgs intel-oneapi-toolkit (sycl-intel, default off)
#   • AMD           – ROCm from nixpkgs             (rocm-amd,   default off)
#
# Also provides the optional rgerganov/llama.cpp fork swap controlled by
# services.llama.useCustomSource.
#
# Overlay implementations live in ./overlays-lib.nix (shared, pure
# constructors with no `config`). Standalone home-manager uses
# ./overlays-hm.nix instead of this file.
#
# IMPORTANT: this module must not reference home-manager-only specialArgs
# such as `userConfiguration`. Referencing a missing specialArg from
# `config.nixpkgs.overlays` forces a `config._module.args` lookup while
# `config` is being computed, which breaks evaluation on every host where
# the niri condition falls through to that branch (i.e. all headless hosts;
# graphical hosts were masked by `||` short-circuiting). See big-nix
# `nh os switch` failure.
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
  overlaysLib = import ./overlays-lib.nix { inherit lib; };

  syclOverlay = overlaysLib.mkSyclOverlay {
    inherit pkgs;
    llamaCppFork = flake-inputs.llama-cpp-fork;
  };

  rocmLlvmOverlay = overlaysLib.mkRocmLlvmOverlay {
    rocmLlvmArch = config.scl.overlays.rocm-llvm-arch;
  };

  customSourceOverlay = overlaysLib.mkCustomSourceOverlay {
    llamaCppFork = flake-inputs.llama-cpp-fork;
  };

  # llama.cpp 0.8.0, for the /v1/realtime audio server used by
  # modules/ml/omni.nix. Adds new attributes only -- see mkRealtimeOverlay.
  realtimeOverlay = overlaysLib.mkRealtimeOverlay {
    version = "0.8.0";
    srcHash = "sha256-WQAtD8Hos6fEtgPQId7nZiLGyP4asAMKJYEXZid1nqc=";
    npmDepsHash = "sha256-XLtEZsSFdk+2SyfXzBp8HQ2e27PQPpDCn1YjePU1/9w=";
    buildNumber = "11960";
    buildCommit = "8642541";
  };

  rocmGpuTargetsOverlay = overlaysLib.mkRocmGpuTargetsOverlay {
    rocmGpuTargets = config.scl.overlays.rocm-gpu-targets;
  };
in
{
  # ── Options ────────────────────────────────────────────────────────────────

  options.scl.overlays = {
    sycl-intel = lib.mkEnableOption "SYCL + Intel GPU overlay stack";
    rocm-amd = lib.mkEnableOption "ROCm  + AMD  GPU overlay stack" // {
      default = false;
    };
    rocm-gpu-targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        ROCm GPU target architectures to build into pkgsRocm.
        gfx1030 = RX 6xxx / W6800, gfx906 = MI50 / MI60 / MI210 / MI250.
        Leave empty to avoid rebuilding rocmPackages.clr when ROCm is not used.
      '';
    };
    rocm-llvm-arch = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
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
    (lib.optionals config.scl.overlays.rocm-amd [
      overlaysLib.rocmOverlay
      rocmLlvmOverlay
    ])

    # ROCm GPU target architectures (restricts clr + downstream pkgsRocm).
    (lib.optionals (config.scl.overlays.rocm-gpu-targets != [ ]) [ rocmGpuTargetsOverlay ])

    # llm-agents nixpkgs overlay from its own flake input (always-on per user request).
    [ flake-inputs.llm-agents.overlays.shared-nixpkgs ]

    # llama.cpp 0.8.0 under llama-cpp-realtime-*, for the /v1/realtime audio
    # server. Safe to apply unconditionally: it only adds attributes, and Nix
    # never evaluates them on hosts that do not use them.
    [ realtimeOverlay ]

    # Source swap: replaces every llama-cpp variant with the rgerganov fork
    # when services.llama.useCustomSource = true.
    (lib.optionals (config.services.llama.useCustomSource or false) [ customSourceOverlay ])

    # niri overlay: needed on NixOS hosts where niri is actually installed,
    # via either the system graphical stack or the branden user config.
    # (Standalone home-manager gating lives in overlays-hm.nix and uses
    # programs.niri.enable instead — never a cross-system specialArg.)
    (lib.optionals (
      (config.scl.graphical.niri.enable or false) || (config.userconfig.branden.graphical or false)
    ) [ flake-inputs.niri.overlays.niri ])
  ];
}
