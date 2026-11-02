# HP Victus 15-fb2xxx (board 8C2F): lift the 30 W GPU cap left behind by an AC
# unplug/replug.
#
# Unplugging the adapter caps the RTX 4060 at 30 W (half its 60 W TGP, reported
# as "SW Power Cap" + "SW Thermal Slowdown"). Replugging does not lift it; the
# EC's WMI dstate reads 1 throughout. Restarting nvidia-powerd does not lift it
# either; until this module, only a reboot did. hp-wmi has no thermal-profile
# entry for board 8C2F, so nothing on Linux talks to the EC's GPU modes.
#
# Measured 2026-11-01: a SET_GPU_THERMAL_MODES call (dstate 2, then 1) makes the
# EC re-send the GPU's limits, and the cap lifted (30 -> 60/70 W) without a
# reboot, but only right after a manual replug. A cap the adapter raises by
# itself under load (no unplug) only ever came back at 35 W, through 140 kicks
# in a row. The watch loop therefore kicks at most MAX_KICKS times per cap. It
# tries again only once the limit recovers or the adapter goes offline (the
# replug is a fresh episode), and it also holds the EC's dstate at 1.
#
# This uses the same HP WMI calls hp-wmi makes for Victus-S boards
# (HPWMI_GM 0x20008, GET/SET_GPU_THERMAL_MODES 0x21/0x22; struct
# victus_gpu_power_modes = ctgp_enable, ppab_enable, dstate, gpu_slowdown_temp),
# issued through acpi_call. It only rewrites dstate and preserves the other three
# bytes as the EC reports them.
{ config, pkgs, ... }:
let
  hpGpuMode = pkgs.writeShellApplication {
    name = "hp-gpu-mode";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
      config.hardware.nvidia.package.bin
    ];
    text = ''
      call=/proc/acpi/call
      wmi='\_SB.WMID.WMAA'
      declare -a b=()
      ctgp=0 ppab=0 dstate=0 slow=0
      max_kicks=3

      [[ -w $call ]] || { echo "no writable $call (acpi_call not loaded?)" >&2; exit 2; }

      # $1 WMI method id (0x2: 4-byte reply, 0x1: none), $2 commandtype byte, $3 four data bytes.
      # struct bios_args, little-endian: "SECU", HPWMI_GM, commandtype, datasize 4, 128 data bytes.
      query() {
        local hex reply rc
        hex="53454355""08000200""$2""000000""04000000""$3""$(printf '%0248d' 0)"
        printf '%s 0x0 %s b%s' "$wmi" "$1" "$hex" > "$call"
        reply=$(tr -d '\0' < "$call")
        mapfile -t b < <(grep -oE '0x[0-9a-fA-F]+' <<< "$reply" || true)
        if (( ''${#b[@]} < 8 )); then
          echo "WMI query 0x$2 failed: $reply" >&2
          return 2
        fi
        rc=$(( b[4] | b[5] << 8 | b[6] << 16 | b[7] << 24 ))
        if (( rc != 0 )); then
          echo "BIOS rejected WMI query 0x$2 with return code $rc" >&2
          return 2
        fi
      }

      get() {
        query 0x2 21 00000000 || return
        if (( ''${#b[@]} < 12 )); then
          echo "GET_GPU_THERMAL_MODES reply too short: ''${b[*]}" >&2
          return 2
        fi
        ctgp=$(( b[8] )) ppab=$(( b[9] )) dstate=$(( b[10] )) slow=$(( b[11] ))
      }

      set_dstate() {
        get || return
        query 0x1 22 "$(printf '%02x%02x%02x%02x' "$ctgp" "$ppab" "$1" "$slow")"
      }

      show() { echo "ctgp=$ctgp ppab=$ppab dstate=$dstate gpu_slowdown_temp=$slow"; }

      # Integer watts of the GPU's "Current" or "Default" power limit (empty if N/A).
      gpu_limit() {
        nvidia-smi -q -d POWER | awk -v k="$1 Power Limit" '$0 ~ k { split($0, f, ":"); if (f[2] ~ /[0-9]/) print int(f[2]); exit }'
      }

      ac_online() { cat /sys/class/power_supply/ACAD/online; }

      # A SET makes the EC re-send the GPU's limits; 2 -> 1 is the measured sequence.
      kick() {
        set_dstate 2
        sleep 2
        set_dstate 1
        sleep 3
      }

      case "''${1:-}" in
        get)
          get
          show
          ;;
        set-dstate)
          set_dstate "''${2:?usage: hp-gpu-mode set-dstate N}"
          get
          show
          ;;
        kick)
          kick
          get
          echo "$(show), GPU limit $(gpu_limit Current) W"
          ;;
        watch)
          get || exit 2
          default=$(gpu_limit Default)
          [[ $default =~ ^[0-9]+$ ]] || { echo "no default GPU power limit from nvidia-smi: '$default'" >&2; exit 2; }
          echo "start: $(show), GPU limit $(gpu_limit Current) W (default $default W), AC online $(ac_online), at most $max_kicks kicks per cap"
          kicks=0  # kicks spent on the current cap; max_kicks + 1 = gave up
          while sleep 5; do
            get
            if (( dstate != 1 )); then
              echo "EC dropped the GPU to dstate $dstate ($(show)); restoring dstate 1"
              set_dstate 1
              get
              echo "after restore: $(show)"
            fi
            limit=$(gpu_limit Current)
            if [[ $(ac_online) != 1 ]]; then
              if (( kicks > 0 )); then
                echo "adapter offline; the next cap on AC is a fresh episode"
                kicks=0
              fi
            elif [[ $limit =~ ^[0-9]+$ ]] && (( limit < default )); then
              if (( kicks < max_kicks )); then
                kicks=$(( kicks + 1 ))
                echo "GPU capped at $limit W on AC power (default $default W, $(show)); setting dstate 2 -> 1 (kick $kicks of $max_kicks)"
                kick
                get
                echo "after kick: GPU limit $(gpu_limit Current) W, $(show)"
              elif (( kicks == max_kicks )); then
                kicks=$(( kicks + 1 ))
                echo "GPU still capped at $limit W after $max_kicks kicks; giving up until the limit recovers or the adapter is replugged"
              fi
            elif [[ $limit =~ ^[0-9]+$ ]] && (( kicks > 0 )); then
              echo "GPU limit back to $limit W (default $default W)"
              kicks=0
            fi
          done
          ;;
        *)
          echo "usage: hp-gpu-mode get | set-dstate N | kick | watch" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];
  boot.kernelModules = [ "acpi_call" ];
  environment.systemPackages = [ hpGpuMode ];

  systemd.services.hp-gpu-dstate-guard = {
    description = "Lift the HP EC's 30 W GPU cap after an AC replug";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      ExecStart = "${hpGpuMode}/bin/hp-gpu-mode watch";
      Restart = "on-failure";
      RestartSec = 10;
      # Exit 2 = the BIOS or acpi_call refused the interface: stay down, don't loop.
      RestartPreventExitStatus = 2;
    };
  };
}
