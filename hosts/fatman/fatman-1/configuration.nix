{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../common_configuration.nix
    ../../../modules/cluster/push.nix
    ../../../modules/distributed-builds.nix
  ];

  userconfig.branden = {
    enable = true;
    hostname = "fatman-1";
  };

  networking.hostName = "fatman-1";

  hardware.graphics.enable = true;
  hardware.gpu.nvidia.enable = true;
  hardware.gpu.nvidia.cards = [ "tesla_v100" ];

  cluster.smfc.enable = true;
  cluster.smfc.gpuType = "nvidia";
  cluster.smfc.settings.Ipmi.platform_name = "generic_x9";
  # V100-PCIE-16GB on driver 580.178.04 reports temperature.memory via nvidia-smi (confirmed:
  # `nvidia-smi -q -d TEMPERATURE` shows a real "Memory Current Temp", not N/A) -- drive the fan
  # curve off memory temp instead of the GPU die, since memory thermal throttling is the problem here.
  cluster.smfc.settings.GPU.nvidia_temp_sensor = 1;
  # DIAGNOSTIC: this board (X9DRFF-iG+, a FatTwin dual-node SKU) only has two populated fans
  # (FAN9/FAN10, per `ipmitool sdr type fan`); zone 1 pinned at 100% only got them to ~5700 RPM
  # under load, which may or may not be their real ceiling. Point the GPU controller at zone 0
  # (same zone as CPU) to test whether FAN9/FAN10 are actually wired to zone 0 and have more
  # headroom than zone 1 can reach. smfc allows two controller types to share a zone (only same-type
  # zone collisions are validated), so CPU and GPU will both drive zone 0 independently -- expect the
  # commanded duty to bounce between whichever last wrote. Revert to a dedicated zone 1 (or whatever
  # zone turns out correct) once we know the real mapping.
  cluster.smfc.settings.GPU.ipmi_zone = 0;

  services.llama.useCustomSource = false;
  services.llama.rpcServer.enable = true;

  # ── German voice assistant: chat LLM ────────────────────────────────────
  # Moved here from fatman-3 (MI60): CUDA on a real compute-capability-7.0
  # card is far less fraught than Vulkan on gfx906, and this frees the MI60
  # for just STT/TTS. See hosts/fatman/fatman-3/configuration.nix for the
  # rest of the pipeline (Open WebUI, whisper.cpp, speech.cpp) -- it reaches
  # this host over the cluster's 40GbE network.
  #
  # Qwen3.5-9B replaces Mistral Nemo 12B. Verified by hand against the real
  # V100 (2026-10-25): contrary to this repo's earlier assumption, it does
  # NOT default to non-thinking at 9B -- a request with no reasoning flag
  # burned its entire token budget on `reasoning_content` chain-of-thought
  # and returned an EMPTY `content` field. `--reasoning off` below forces it
  # off server-side regardless of what Open WebUI sends per-request, which
  # also fixes the original "wall of text into TTS" concern. With it off,
  # German replies are fluent and natural (verified with both a direct ask
  # and a short-story generation). Q8_0 rather than Q4_K_M this
  # time -- the V100's 16GB gives far more headroom than the MI60 ever did
  # (~9.5GB model weights vs. the card's 16GB, instead of sharing 32GB
  # three ways with whisper+speech), so there's no reason to quantize this
  # aggressively; the complaint that the old setup felt "kind of stupid"
  # may partly have been Q4 quantization loss as well as model choice.
  services.llama.enable = true;
  services.llama.hfRepo = "bartowski/Qwen_Qwen3.5-9B-GGUF:Q8_0";
  services.llama.user = "branden";
  # --host 0.0.0.0: llama-server defaults to 127.0.0.1 only, which would be
  # unreachable from fatman-3 -- matches the RPC server above, which already
  # binds 0.0.0.0 on this same trusted internal network (firewall disabled
  # cluster-wide). --ctx-size pinned defensively: llama-server's automatic
  # context-size fitting produced an absurd n_ctx and crashed on the MI60
  # (full writeup on fatman-3); pinning a sane value avoids that path
  # entirely regardless of GPU -- verified safe on CUDA too.
  #
  # --no-mmproj was the fix for a severe, non-obvious perf bug found by hand
  # on the real V100 (2026-10-26): this GGUF ships a vision tower (mmproj),
  # and llama-server's auto layer-fit (-ngl auto / --fit on) was reserving
  # VRAM headroom for that vision graph, which pushed some LLM layers onto
  # the CPU to compensate. Measured effect: only 16.5 tok/s at ~16% GPU
  # utilization. Forcing `-ngl 999` "fixed" the speed (70 tok/s, 93% util)
  # but then OOM'd allocating the vision graph's own compute buffer
  # (irrelevant anyway -- a voice-only assistant never sends images).
  # `--no-mmproj` drops the vision tower entirely, which lets auto-fit put
  # every LLM layer on the V100 correctly with no manual override and no
  # error: confirmed 69.8 tok/s, 93% GPU util, and VRAM dropped to
  # 10.8GB/16GB used (vs. 14.8GB with the vision tower loaded) -- a much
  # healthier margin too.
  services.llama.extraArgs = [
    "--host"
    "0.0.0.0"
    "--ctx-size"
    "32768"
    "--reasoning"
    "off"
    "--no-mmproj"
  ];

  hardware.infiniband.guids = [
    "0x00117500007090a2"
  ];

  boot.kernelModules = [
    "ib_ipoib"
  ];

  networking.interfaces = {
    ibp4s0 = {
      ipv4.addresses = [
        {
          address = "192.168.3.111";
          prefixLength = 24;
        }
      ];
      mtu = 65520;
      useDHCP = false;
    };
  };

  networking.localCommands = ''
    echo connected > /sys/class/net/ibp4s0/mode
  '';
}
