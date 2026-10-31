{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/676e3d90-fbd8-4a95-a886-668acfff6cfc";
    fsType = "ext4";
    neededForBoot = true;
    options = [ "noatime" ];
  };

  scl.overlays.rocm-llvm-arch = "ivybridge";

  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../common_configuration.nix
    ../../../modules/cluster/push.nix
    ../../../modules/distributed-builds.nix
  ];

  userconfig.branden = {
    enable = true;
    hostname = "fatman-3";
  };

  networking.hostName = "fatman-3";

  hardware.graphics.enable = true;
  hardware.gpu.amd.enable = true;
  enableRocmSupport = true;

  cluster.smfc.enable = true;
  cluster.smfc.gpuType = "amd";
  cluster.smfc.settings.Ipmi.platform_name = "generic_x9";
  # Same FatTwin chassis as fatman-1 (X9DRFF-iG+, two fans per node); zone 1
  # alone can't reach a useful ceiling on this board, so share zone 0 with
  # the CPU controller instead. See fatman-1's config for the full writeup.
  cluster.smfc.settings.GPU.ipmi_zone = 0;
  # MI60 exposes edge/junction/mem via hwmon, all reading real values
  # (confirmed 2026-10-18). A prior revision of this config tried to run
  # junction and memory as two separate controllers ([GPU] + [GPU:1]) both
  # on zone 0, on the assumption that smfc would apply the max requested
  # level across controllers sharing a zone. That assumption was wrong:
  # smfc's config validator (src/smfc/config.py, _validate_no_duplicate_zones)
  # tracks zone ownership *per controller type*, independent of the ":N"
  # suffix, and rejects any two GPU-family sections on the same zone
  # outright ("[GPU:1] IPMI zone 0 is already used by [GPU]", exit
  # NOTCONFIGURED). That had smfc crash-looping on every start (restart
  # counter in the tens of thousands), meaning the GPU was never being
  # temperature-controlled at all -- which is why it kept overheating even
  # with smfc "enabled". Only CPU+GPU (different controller types) can
  # share a zone, same as fatman-1.
  #
  # Until smfc supports reading more than one sensor per controller, drive
  # the single [GPU] controller off the module's junction-temp default
  # (sensor 0), NOT memory. Verified with a real stress test (llama-bench,
  # 2026-10-22, ~60s pp512 run) while smfc was still crash-looping (see
  # above) and therefore not touching the fans at all: junction rose from
  # ~40C idle to a 104C peak -- both faster and higher than memory (40C ->
  # 90C peak) or edge (39C -> 84C peak). Unlike fatman-1's V100, memory is
  # NOT the hot sensor on this MI60; junction is, and by a wide margin.
  # Driving fans off memory here would have the curve still idling while
  # the die is already near its throttle point.
  cluster.smfc.settings.GPU.amd_temp_sensor = 0;

  scl.overlays.rocm-amd = true;
  scl.overlays.rocm-gpu-targets = [ "gfx906" ];
  services.llama.useCustomSource = false;
  services.llama.rpcServer.enable = true;
  services.llama.preferVulkan = true;

  # ── German voice assistant PoC ─────────────────────────────────────────
  # Open WebUI frontend + whisper.cpp (STT) + speech.cpp (TTS) on this MI60
  # host; the chat LLM itself moved to fatman-1 (Tesla V100) -- CUDA on a
  # real compute-capability-7.0 card is dramatically less fraught than
  # Vulkan on gfx906 (see hosts/fatman/fatman-1/configuration.nix for that
  # setup and the model-quality writeup), and frees the MI60 to run just
  # STT/TTS. Open WebUI's OPENAI_API_BASE_URLS below points at fatman-1
  # over the cluster's InfiniBand network instead of 127.0.0.1.
  #
  # Models auto-download on first start into the cluster-wide HF cache
  # (HF_HOME, set in modules/cluster/env.nix). That cache directory
  # (/mnt/cluster/data/huggingface) turned out to already exist, owned by
  # branden (uid 1000, mode 0700) -- not an empty dir a DynamicUser's
  # ephemeral per-start uid could write into. Run these as branden instead
  # so they can actually write the downloaded models.
  # ROCm/HIP on gfx906 is EOL upstream and already caused enough trouble that
  # the RPC server above was switched to Vulkan; match that choice here too
  # rather than assume whisper.cpp's HIP backend fares better.
  services.whisper-server = {
    enable = true;
    preferVulkan = true;
    user = "branden";
  };
  # speech.cpp: replaced the earlier Piper setup (modules/ml/tts.nix has
  # the full comparison writeup). Native OpenAI-compatible /v1/audio/speech,
  # so Open WebUI's AUDIO_TTS_* vars point straight at it -- no wrapper
  # script needed, unlike Piper.
  services.speech-server = {
    enable = true;
    user = "branden";
  };

  # LFM3-Omni-2B on llama.cpp's /v1/realtime: the model hears the audio
  # itself instead of being handed whisper-server's transcript, which is the
  # one thing the pipeline above cannot recover from when the STT mis-hears.
  # Deliberately left running next to whisper-server/speech-server so the two
  # can be compared on the same card rather than one replacing the other
  # untested. Vulkan for the same gfx906 reason as the services above.
  services.omni-server = {
    enable = true;
    preferVulkan = true;
    user = "branden";
    # The realtime client is a browser page that opens the WebSocket to this
    # server directly, so unlike whisper/speech it cannot stay on localhost.
    host = "0.0.0.0";
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 3000;
    environment = {
      ENABLE_OPENAI_API = "True";
      # fatman-1 (Tesla V100), over the cluster's 40GbE network -- see
      # hosts/fatman/fatman-1/configuration.nix for the LLM itself. Uses the
      # mDNS name rather than a hardcoded IP since these hosts are on DHCP
      # (addresses aren't stable) -- NOT the old 192.168.3.x InfiniBand
      # address either, that hardware was physically removed from these
      # hosts (confirmed 2026-10-26: `ip addr show ibp4s0` reports "Device
      # does not exist" on both fatman-1 and fatman-3). mDNS resolution
      # confirmed working from fatman-3 with no resolver changes needed.
      OPENAI_API_BASE_URLS = "http://fatman-1.local:8080/v1";
      OPENAI_API_KEYS = "not-needed"; # llama-server requires no auth
      AUDIO_STT_ENGINE = "openai";
      AUDIO_STT_OPENAI_API_BASE_URL = "http://127.0.0.1:${toString config.services.whisper-server.port}/v1";
      AUDIO_STT_MODEL = "whisper-1"; # ignored by whisper-server, but required non-empty
      AUDIO_TTS_ENGINE = "openai";
      AUDIO_TTS_OPENAI_API_BASE_URL = "http://127.0.0.1:${toString config.services.speech-server.port}/v1";
      AUDIO_TTS_VOICE = "ryan";
      # Unlike whisper-server (which ignores AUDIO_STT_MODEL entirely),
      # speech.cpp strictly validates the "model" field and 404s on
      # anything it doesn't serve -- Open WebUI's default "tts-1" gets
      # rejected with "The model 'tts-1' is not served here; this server
      # serves 'Qwen3-TTS-12Hz-0.6B-CustomVoice'." Confirmed by hand via
      # live log tail during a real Open WebUI TTS attempt.
      AUDIO_TTS_MODEL = "Qwen3-TTS-12Hz-0.6B-CustomVoice";

      # Root cause of the "severe stall on the second response": llama.cpp's
      # prefix cache (the "LCP similarity" slot-reuse logged by llama-server)
      # matches strictly from token 0. Open WebUI's background title/tags/
      # autocomplete tasks each wrap the same conversation history in their
      # OWN distinct instruction prompt (confirmed against its task-router
      # source), so the prefix differs from token 0 and the match always
      # misses -- forcing a full redundant reprocessing of the entire
      # multi-thousand-token history for each one. With several of these
      # firing concurrently against the same GPU, whichever slot is actually
      # streaming the user-facing reply gets starved (observed by hand: one
      # decode step dropped to 0.70 tokens/s while two other slots were
      # mid-reprocessing the same history). None of these three features are
      # useful for a voice-only assistant anyway.
      ENABLE_TITLE_GENERATION = "False";
      ENABLE_TAGS_GENERATION = "False";
      ENABLE_AUTOCOMPLETE_GENERATION = "False";
    };
  };
  # Belt-and-suspenders: firewall is currently disabled cluster-wide, but
  # only open-webui and the omni realtime pair are meant to be LAN-reachable
  # (whisper-server and speech-server stay on 127.0.0.1, since only
  # open-webui ever calls them), so scope those explicitly.
  networking.firewall.allowedTCPPorts = [
    3000
    config.services.omni-server.port
    config.services.omni-server.clientPort
  ];

  hardware.infiniband.guids = [
    "0x001175000073bbd6"
  ];

  boot.kernelModules = [
    "ib_ipoib"
  ];

  networking.interfaces = {
    ibp4s0 = {
      ipv4.addresses = [
        {
          address = "192.168.3.113";
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
