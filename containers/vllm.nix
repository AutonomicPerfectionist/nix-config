# vllm-xpu.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.vllm-xpu;
  imageName = "vllm-xpu-local";
  imageTag = cfg.vllmRef;  # use the commit/tag as the image tag for cache-busting

  # Runtime shim, auto-imported at interpreter startup via PYTHONPATH.
  #
  # Consumer Intel Arc GPUs (Alchemist A-series, Battlemage B-series) do not
  # implement torch.xpu.mem_get_info() — it raises "doesn't support querying
  # the available free memory", which crashes vLLM's memory profiler
  # (MemorySnapshot -> current_platform.mem_get_info) before the engine starts.
  # We wrap it to synthesize free memory as (total - reserved), which is
  # accurate enough for KV-cache sizing on a dedicated GPU.
  memPatchDir = pkgs.writeTextDir "sitecustomize.py" ''
    try:
        import torch
        if hasattr(torch, "xpu"):
            _orig = torch.xpu.mem_get_info

            def _safe_mem_get_info(device=None):
                try:
                    return _orig(device)
                except Exception:
                    idx = 0 if device is None else (
                        device if isinstance(device, int)
                        else (torch.device(device).index or 0)
                    )
                    total = torch.xpu.get_device_properties(idx).total_memory
                    try:
                        reserved = torch.xpu.memory_reserved(idx)
                    except Exception:
                        reserved = 0
                    return (total - reserved, total)

            torch.xpu.mem_get_info = _safe_mem_get_info
    except Exception:
        pass
  '';
in {
  options.services.vllm-xpu = {
    enable = lib.mkEnableOption "vLLM Intel XPU inference server";

    model = lib.mkOption {
      type = lib.types.str;
      example = "meta-llama/Llama-3.2-3B-Instruct";
      description = "HuggingFace model ID to serve.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port to expose the OpenAI-compatible API on.";
    };

    dtype = lib.mkOption {
      type = lib.types.str;
      default = "float16";
      description = "Inference dtype (float16 recommended for Arc).";
    };

    attentionBackend = lib.mkOption {
      type = lib.types.str;
      default = "TRITON_ATTN";
      example = "FLASH_ATTN";
      description = ''
        vLLM attention backend (passed as --attention-backend).

        Defaults to TRITON_ATTN, which is REQUIRED on Alchemist (Arc A-series,
        e.g. A770 = Xe1): the bundled vllm-xpu-kernels flash-attention cutlass
        kernel only supports Xe2/Xe3 (Battlemage B-series and newer) and errors
        with "Only XE2/XE3 cutlass kernel is supported currently.". On a
        Battlemage or newer card you may set this to FLASH_ATTN for better perf.
      '';
    };

    gpuMemoryUtilization = lib.mkOption {
      type = lib.types.float;
      default = 0.9;
      description = "Fraction of GPU memory to use.";
    };

    huggingFaceToken = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HuggingFace Hub token for gated models. Prefer sops-nix/agenix + environmentFiles.";
    };

    modelCacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vllm/models";
      description = "Host path to mount as the HuggingFace model cache.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra arguments passed to vllm-server.";
    };

    vllmRef = lib.mkOption {
      type = lib.types.str;
      default = "v0.24.0";
      example = "v0.24.0";
      description = ''
        Git ref (tag, branch, or commit SHA) of vllm-project/vllm to build from.
        Pin to a release tag rather than "main" — main frequently breaks the XPU
        build. The image is built from that ref's docker/Dockerfile.xpu, whose
        final stage has ENTRYPOINT ["vllm", "serve"].
      '';
    };

    buildDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vllm/build";
      description = "Directory used to clone the vllm repo for the Docker build.";
    };

    pciDeviceId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "56a0";
      description = ''
        PCI device ID of the Arc GPU (short hex, e.g. "56a0" from lspci -nn).
        When set, adds i915.force_probe=!<id> to kernel params so xe claims
        the device instead of i915.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # --- Host-side Intel Arc prerequisites (xe driver) ---
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-compute-runtime
      ];
    };

    hardware.enableRedistributableFirmware = true;
    boot.kernelModules = [ "xe" ];
    boot.kernelParams = lib.mkIf (cfg.pciDeviceId != null) [
      "i915.force_probe=!${cfg.pciDeviceId}"
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.modelCacheDir} 0755 root root -"
      "d ${cfg.buildDir}      0755 root root -"
    ];

    # --- Image build service ---
    # Runs before the container service. Builds the image only if an image
    # with this tag doesn't already exist in Docker, so repeated rebuilds
    # on nixos-rebuild switch are cheap.
    systemd.services.vllm-xpu-build = {
      description = "Build vLLM XPU Docker image from source";
      wantedBy = [ "docker-vllm-xpu.service" ];
      before    = [ "docker-vllm-xpu.service" ];
      requires  = [ "docker.service" ];
      wants     = [ "network-online.target" ];
      after     = [ "docker.service" "network-online.target" ];

      # Only rebuild if the tagged image is absent
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Give it plenty of time — first build takes a while
        TimeoutStartSec = "3600";
      };

      path = with pkgs; [ docker git coreutils ];

      script = ''
        set -euo pipefail

        IMAGE="${imageName}:${imageTag}"

        if docker image inspect "$IMAGE" > /dev/null 2>&1; then
          echo "Image $IMAGE already exists, skipping build."
          exit 0
        fi

        echo "Cloning vllm @ ${cfg.vllmRef} into ${cfg.buildDir}..."
        rm -rf "${cfg.buildDir}/vllm"
        git clone --depth 1 --branch ${lib.escapeShellArg cfg.vllmRef} \
          https://github.com/vllm-project/vllm.git \
          "${cfg.buildDir}/vllm"

        echo "Building Docker image $IMAGE ..."
        docker build \
          --file "${cfg.buildDir}/vllm/docker/Dockerfile.xpu" \
          --tag "$IMAGE" \
          --shm-size=4g \
          "${cfg.buildDir}/vllm"

        echo "Build complete: $IMAGE"
      '';
    };

    # --- Container ---
    virtualisation.docker.enable = true;

    virtualisation.oci-containers = {
      backend = "docker";
      containers.vllm-xpu = {
        image = "${imageName}:${imageTag}";

        # The image's ENTRYPOINT is ["vllm", "serve"], so cmd is *args only*.
        # The model is the positional argument. NOTE: the old "--device xpu"
        # flag was REMOVED in modern vllm (the platform is auto-detected on the
        # XPU image; specific GPUs are chosen with --device-ids). Passing it
        # makes `vllm serve` exit with an "unrecognized arguments" error.
        cmd = [
          cfg.model
          "--dtype" cfg.dtype
          "--attention-backend" cfg.attentionBackend
          "--enforce-eager"
          "--port" (toString cfg.port)
          "--gpu-memory-utilization" (toString cfg.gpuMemoryUtilization)
        ] ++ cfg.extraArgs;

        environment = lib.filterAttrs (_: v: v != null) {
          HUGGING_FACE_HUB_TOKEN = cfg.huggingFaceToken;
          HF_HOME = "/models";
          TRANSFORMERS_CACHE = "/models";
          # Required for Level Zero sysman (device memory/utilization queries)
          # that vLLM's XPU platform uses during init.
          ZES_ENABLE_SYSMAN = "1";
          # Auto-import the mem_get_info shim (see memPatchDir above).
          PYTHONPATH = "/opt/patch";
        };

        volumes = [
          "${cfg.modelCacheDir}:/models"
          # Mount the mem_get_info shim read-only; PYTHONPATH points here.
          "${memPatchDir}:/opt/patch:ro"
        ];

        extraOptions = [
          "--device=/dev/dri:/dev/dri"
          "-v" "/dev/dri/by-path:/dev/dri/by-path"
          # "--group-add=${toString config.users.groups.render.gid}"
          # "--group-add=${toString config.users.groups.video.gid}"
          "--ipc=host"
          "--shm-size=10g"
          "--net=host"
          "--privileged"
        ];

        autoStart = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
