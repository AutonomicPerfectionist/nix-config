# overlays-hm.nix
#
# Standalone home-manager-only module providing GPU compute overlays for
# non-NixOS machines (see mkHomeConfig in flake.nix).
#
# Overlay implementations live in ./overlays-lib.nix (shared, pure
# constructors with no `config`). NixOS hosts use ./overlays.nix instead.
#
# IMPORTANT: this module must not reference NixOS-only config
# (scl.graphical, userconfig) or NixOS-only specialArgs. Niri gating uses
# `programs.niri.enable`, which users/branden/home/niri.nix sets whenever
# the standalone config is graphical — no cross-system specialArg needed.
#
# This module is imported only from mkHomeConfig in flake.nix, never from
# users/branden/home/home.nix. On NixOS hosts home-manager runs with
# useGlobalPkgs and inherits the system nixpkgs.overlays, so HM must not
# set nixpkgs.overlays there (it also triggers a useGlobalPkgs warning).
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

  rocmGpuTargetsOverlay = overlaysLib.mkRocmGpuTargetsOverlay {
    rocmGpuTargets = config.scl.overlays.rocm-gpu-targets;
  };
in
{
  # ── Options ────────────────────────────────────────────────────────────────
  # Same shape as the NixOS module so per-machine backend selection works
  # the same way; these are HM options here, NixOS options there — the two
  # module systems never share this file.

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

    # Source swap: replaces every llama-cpp variant with the rgerganov fork
    # when services.llama.useCustomSource = true (option defined by
    # modules/ml/llama-hm.nix, always imported by home.nix).
    (lib.optionals (config.services.llama.useCustomSource or false) [ customSourceOverlay ])

    # niri overlay: needed wherever niri is actually installed.
    # users/branden/home/niri.nix references pkgs.niri-unstable from this
    # overlay, and sets programs.niri.enable = true — so gate on that.
    (lib.optionals (config.programs.niri.enable or false) [ flake-inputs.niri.overlays.niri ])
  ];
}
