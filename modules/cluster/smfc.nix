# smfc.nix
#
# Wires up petersulyok/smfc (Supermicro Fan Control) as a systemd service:
# an IPMI fan daemon that drives zone duty cycles from CPU/HD/NVMe/GPU
# temperatures instead of leaving the board firmware's own thermal loop in
# charge. Package lives at ../../pkgs/smfc (not yet in nixpkgs).
#
# This module only ships conservative, CPU-only defaults (matching
# upstream's own sample config/smfc.conf). Anything host-specific --
# platform_name on X9 boards, GPU device IDs when a host has more than one
# card, HD/NVMe monitoring -- is left to `settings` overrides in the host's
# own configuration, since getting IPMI fan floors wrong can starve cooling
# on real hardware.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cluster.smfc;
  iniFormat = pkgs.formats.ini { };

  nvidiaSmiPath = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
  rocmSmiPath = "${pkgs.rocmPackages.rocm-smi}/bin/rocm-smi";

  # Every value this module contributes to `settings` is a *default*: hosts
  # routinely override individual leaf keys (e.g. platform_name,
  # gpu_device_ids), and since `settings` is a plain attrsOf-of-attrsOf
  # option, two same-priority definitions of the same leaf (ours and the
  # host's) would otherwise be a hard conflict rather than an override.
  # mkDefault drops this module's contributions to the lowest priority so
  # any host-level `cluster.smfc.settings.<section>.<key> = ...;` wins.
  mkDefaults = lib.mapAttrs (_: section: lib.mapAttrs (_: lib.mkDefault) section);

  # Mirrors upstream's config/smfc.conf [Ipmi]/[CPU] defaults, except for
  # tool paths (which must point into the Nix store, not /usr/bin) and
  # platform_name (left as "auto" here -- override per host on X9 boards,
  # see the `settings` option doc below).
  #
  # Every other controller ([HD], [NVME], [GPU], [NPU], [PCI], [CONST],
  # [Exporter]) is simply left out of the generated file: smfc treats an
  # absent section as "no fan controller configured for this", the same
  # end state as `enabled=false` (confirmed against smfc's own
  # _get_sections()/getboolean(..., fallback=False) handling), without
  # risking a `cluster.smfc.settings.GPU.enabled` conflict between this
  # default and the gpuType-derived [GPU] section below.
  defaultSettings = mkDefaults {
    Ipmi = {
      command = "${pkgs.ipmitool}/bin/ipmitool";
      fan_mode_delay = 10;
      fan_level_delay = 2;
      platform_name = "auto";
      enforce_fan_mode = true;
      exit_level = 100;
    };
    CPU = {
      enabled = true;
      ipmi_zone = 0;
      temp_calc = 1;
      sensitivity = 3.0;
      polling = 2;
      steps = 6;
      min_temp = 30.0;
      max_temp = 60.0;
      min_level = 35;
      max_level = 100;
      smoothing = 1;
      error_tolerance = 3;
    };
  };

  # Conservative [GPU] defaults, lifted from upstream's sample config, with
  # only the *-smi path and gpu_type wired to the chosen backend. Zone,
  # thresholds and device IDs can still be tuned via `settings.GPU`.
  gpuBaseSettings = {
    enabled = true;
    ipmi_zone = 1;
    temp_calc = 1;
    sensitivity = 2.0;
    polling = 2;
    steps = 5;
    min_temp = 40.0;
    max_temp = 70.0;
    min_level = 35;
    max_level = 100;
    smoothing = 1;
    error_tolerance = 3;
    gpu_device_ids = "0";
  };

  gpuSettings =
    if cfg.gpuType == "nvidia" then
      mkDefaults {
        GPU = gpuBaseSettings // {
          gpu_type = "nvidia";
          nvidia_smi_path = nvidiaSmiPath;
        };
      }
    else if cfg.gpuType == "amd" then
      mkDefaults {
        GPU = gpuBaseSettings // {
          gpu_type = "amd";
          rocm_smi_path = rocmSmiPath;
          amd_temp_sensor = 0;
        };
      }
    else
      { };
in
{
  options.cluster.smfc = {
    enable = lib.mkEnableOption "smfc (Supermicro Fan Control) IPMI fan daemon, driven by CPU/GPU temperatures";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/smfc { };
      description = "smfc package to run.";
    };

    gpuType = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "nvidia"
          "amd"
        ]
      );
      default = null;
      description = ''
        Enables the [GPU] fan controller and wires up the matching *-smi tool:
        "nvidia" uses `nvidia-smi` from `hardware.nvidia.package`, "amd" uses
        `rocm-smi` from `pkgs.rocmPackages.rocm-smi`. Leave null to disable
        GPU-driven fan control entirely.
      '';
    };

    settings = lib.mkOption {
      type = iniFormat.type;
      default = { };
      description = ''
        smfc.conf contents as Nix attrs, one attrset per INI section.
        Deep-merged over this module's conservative defaults (CPU-only fan
        control; HD/NVMe/NPU/PCI/CONST/Exporter all disabled) and the
        gpuType-derived [GPU] section. See upstream's config/smfc.conf for
        the full key reference: https://github.com/petersulyok/smfc

        IMPORTANT: platform_name defaults to "auto". On Supermicro X9
        boards, set `settings.Ipmi.platform_name = "generic_x9";` explicitly
        rather than relying on BMC autodetection.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.gpuType != "nvidia" || (config.hardware.gpu.nvidia.enable or false);
        message = "cluster.smfc.gpuType = \"nvidia\" requires hardware.gpu.nvidia.enable = true;";
      }
      {
        assertion = cfg.gpuType != "amd" || (config.hardware.gpu.amd.enable or false);
        message = "cluster.smfc.gpuType = \"amd\" requires hardware.gpu.amd.enable = true;";
      }
    ];

    cluster.smfc.settings = lib.mkMerge [
      defaultSettings
      gpuSettings
    ];

    environment.etc."smfc/smfc.conf".source = iniFormat.generate "smfc.conf" cfg.settings;

    systemd.services.smfc = {
      description = "Supermicro Fan Control";
      after = [ "syslog.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        # -o 1: log to stderr, captured by journald (no syslog daemon running).
        # -l 3: INFO -- keep fan-level/temperature decisions visible in the journal.
        ExecStart = "${lib.getExe cfg.package} -c /etc/smfc/smfc.conf -l 3 -o 1";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
