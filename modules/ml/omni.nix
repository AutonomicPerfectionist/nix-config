# omni.nix
#
# NixOS module for LiquidAI's LFM3-Omni-2B served through llama.cpp's
# `/v1/realtime` WebSocket API -- a single model that hears raw audio and
# answers in speech, replacing the STT -> LLM -> TTS chain that
# modules/ml/whisper.nix + modules/ml/tts.nix implement today.
#
# The point of the exercise: in the pipeline, whisper.cpp's transcript is the
# ONLY thing the LLM ever sees, so a mis-hearing is unrecoverable -- the model
# has no way to notice that the words it was handed are not the words that
# were said. An omni model attends to the audio itself, so prosody, proper
# nouns and ambiguous homophones stay available at answer time.
#
# This module deliberately runs ALONGSIDE the existing pipeline rather than
# replacing it: both can be enabled at once (different ports), which is what
# makes an A/B comparison on the same hardware possible.
#
# Two units:
#   omni-server  -- llama-server with the model, serving /v1/realtime
#   omni-client  -- a static file server for a browser client (see below)
#
# On the client: as of llama.cpp 0.8.0 there is NO shipped UI for
# /v1/realtime. llama-server's own web UI can record an audio clip and attach
# it to a chat message (which already beats the pipeline -- the model hears
# the clip), but it has no live-call mode and no playback of generated
# speech. Open WebUI 0.12's Realtime call mode cannot drive llama.cpp either:
# it hardcodes a 24 kHz input rate that llama.cpp rejects for this model, and
# it only requests a response once it has seen a
# `conversation.item.input_audio_transcription.completed` event, which
# llama.cpp emits only in `?intent=transcription` sessions and never in a
# conversation. So the client here is the one the community is actually
# using: a single-file, dependency-free test bench posted in the upstream PR
# that added the endpoint (ggml-org/llama.cpp#31269), fetched at a pinned
# gist revision rather than vendored.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.omni-server;

  useCuda = config.hardware.gpu.nvidia.enable or false;
  useRocm = config.hardware.gpu.amd.enable or false;

  # The llama-cpp-realtime-* attributes come from mkRealtimeOverlay in
  # modules/common/overlays-lib.nix: nixpkgs' llama-cpp variants bumped to
  # 0.8.0, which is the first release carrying tools/server/server-realtime.cpp.
  # Nothing here uses plain `llama-cpp`, so the cluster's existing inference
  # and RPC services stay on the pinned nixpkgs version.
  omniPkg =
    if cfg.preferVulkan then
      pkgs.llama-cpp-realtime-vulkan
    else if useCuda then
      pkgs.llama-cpp-realtime-cuda
    else if useRocm then
      pkgs.llama-cpp-realtime-rocm
    else
      pkgs.llama-cpp-realtime;

  # systemd-tmpfiles needs a real group name here, and "the user's own group"
  # is not a safe guess: branden's primary group on this cluster is `users`
  # and no group called `branden` exists, so naming the user would fail the
  # rule with "Unknown group" at activation and leave the cache directory
  # owned by whoever created it.
  cacheGroup = if cfg.group != null then cfg.group else config.users.users.${cfg.user}.group;

  wsUrl =
    if cfg.wsUrl != null then
      cfg.wsUrl
    else
      "ws://${config.networking.hostName}.local:${toString cfg.port}/v1/realtime";

  # Patched at build time rather than left to the operator: the stock file
  # defaults its sample-rate selector to 24000 Hz, which llama.cpp refuses for
  # this model ("the input audio must be PCM16 at 16000 Hz" -- LFM3-Omni's
  # audio encoder is 16 kHz; only its *output* is 24 kHz). Shipping that
  # default means the first connection every user makes fails.
  realtimeClient =
    pkgs.runCommand "omni-realtime-client"
      {
        src = pkgs.fetchurl {
          url = "https://gist.githubusercontent.com/m18coppola/d68fdb095f6813f91cd3ac7eae625941/raw/832ffa96ebcc048ea83ac0b8bd487ecfeffaf393/realtime_speech_interface.html";
          hash = "sha256-OC4jdE+QXGnu8FPhB+tGQJlRxPaOzzpR0iEdBxmCUYU=";
        };
      }
      ''
        mkdir -p $out
        cp $src $out/index.html
        chmod +w $out/index.html

        substituteInPlace $out/index.html \
          --replace-fail '<option value="24000" selected>' '<option value="24000">' \
          --replace-fail '<option value="16000">' '<option value="16000" selected>' \
          --replace-fail 'value="ws://127.0.0.1:9931/v1/realtime"' ${lib.escapeShellArg ''value="${wsUrl}"''} \
          --replace-fail 'Respond with interleaved text and audio.' ${lib.escapeShellArg cfg.systemPrompt}
      '';

  # See modules/ml/llama.nix's identityServiceConfig for the full rationale:
  # defaults to DynamicUser, but a fixed user is needed to write into a model
  # cache owned by a real account (the same /mnt/cluster share the rest of
  # this repo's ML services use).
  identityServiceConfig =
    if cfg.user != null then
      { User = cfg.user; } // lib.optionalAttrs (cfg.group != null) { Group = cfg.group; }
    else
      {
        DynamicUser = true;
      }
      // lib.optionalAttrs (cfg.preferVulkan || useRocm) {
        SupplementaryGroups = [
          "render"
          "video"
        ];
      };
in
{
  options.services.omni-server = {
    enable = lib.mkEnableOption "LFM3-Omni speech-to-speech server (llama.cpp /v1/realtime)";

    preferVulkan = lib.mkEnableOption "Vulkan backend (overrides automatic GPU backend detection)";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Run as this user instead of a DynamicUser (needed to write into a model cache owned by a real account).";
    };

    group = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Group to run as when user is set. Defaults to that user's primary group when null.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = omniPkg;
      defaultText = lib.literalExpression "auto-selected llama-cpp-realtime variant";
      description = "The llama.cpp 0.8.0+ package to use. Auto-selects CUDA/ROCm/Vulkan based on hardware.gpu.*.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address llama-server listens on. Unlike the pipeline's whisper/speech
        services -- which only ever talk to Open WebUI on localhost -- the
        realtime client is a *browser* page that opens the WebSocket itself,
        so this has to be reachable from wherever that page is loaded.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8092;
      description = "Port for the llama-server API (8090 and 8091 are whisper-server and speech-server).";
    };

    clientPort = lib.mkOption {
      type = lib.types.port;
      default = 8093;
      description = "Port for the static realtime browser client. Set serveClient = false to skip it.";
    };

    clientPackage = lib.mkOption {
      type = lib.types.package;
      default = realtimeClient;
      defaultText = lib.literalExpression "the pinned upstream-PR realtime client, patched for this host";
      description = ''
        Directory served by omni-client; its index.html is the page. Exposed
        so it can be built and inspected on its own
        (`nix build .#nixosConfigurations.<host>.config.services.omni-server.clientPackage`)
        and swapped for a different client without touching this module.
      '';
    };

    serveClient = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Serve the single-file realtime browser client. Disabling it leaves
        llama-server's own web UI (text chat plus recorded-audio attachments)
        as the only interface, which cannot hold a live call.
      '';
    };

    wsUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalExpression ''"ws://''${config.networking.hostName}.local:''${port}/v1/realtime"'';
      description = ''
        WebSocket URL baked into the client's address field as its default.
        The mDNS name is used rather than an IP because these hosts are on
        DHCP -- same reasoning as the Open WebUI config on fatman-3.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "LiquidAI/LFM3-Omni-2B-GGUF:Q4_K_M";
      description = ''
        Hugging Face repo and quant passed to llama-server's -hf. The
        multimodal projector (which carries both the audio encoder and the
        speech decoder) is downloaded alongside it automatically.
        Q4_K_M is ~1.1 GB; Q8_0 is ~1.85 GB.
      '';
    };

    systemPrompt = lib.mkOption {
      type = lib.types.str;
      default = "Respond with interleaved text and audio. Antworte immer auf Deutsch, kurz und natürlich klingend.";
      description = ''
        Default `session.instructions` baked into the client.

        The leading sentence is the exact string LFM3-Omni's model card
        documents for spoken chat -- the card drives task selection from the
        system prompt ("Perform ASR in <language>.", "Perform TTS in
        <language> using a <gender> voice.", and this one for interleaved
        text and audio) -- so it is kept verbatim and the German steering is
        appended after it. Measured honestly, swapping it for a plain German
        persona prompt changed nothing in either direction: on clean input
        both answer, on badly-heard input both echo. It is here because it is
        documented, not because it was observed to fix anything.

        The realtime session has no --language flag equivalent: unlike
        whisper-server, which is forced to German on the command line, the
        omni model picks its output language from the conversation, so this
        is what makes German the default.
      '';
    };

    cacheDir = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/cluster/data/llama.cpp/models";
      description = ''
        Where llama.cpp caches -hf downloads (LLAMA_CACHE). Note this is
        llama.cpp's own cache, NOT the HF_HOME hub cache that whisper.nix
        uses -- llama-server's downloader does not share it.
      '';
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--ctx-size"
        "8192"
      ];
      description = "Additional flags appended to the llama-server command line.";
    };
  };

  config = lib.mkIf cfg.enable {
    # llama.cpp creates this directory itself on first download, but it would
    # land owned by whoever started first, with whatever umask was in effect.
    # modules/cluster/env.nix documents the same class of problem for HF_HOME
    # on this share: a pre-existing 0700 directory owned by another account is
    # exactly what forced these ML services off DynamicUser. Declare the
    # ownership instead of inheriting it by accident.
    systemd.tmpfiles.rules = lib.optionals (cfg.user != null) [
      "d ${cfg.cacheDir} 0755 ${cfg.user} ${cacheGroup} - -"
    ];

    systemd.services.omni-server = {
      description = "LFM3-Omni speech-to-speech server (llama.cpp /v1/realtime)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        LLAMA_CACHE = cfg.cacheDir;
      };

      serviceConfig = {
        # Type=simple, not notify: the first start downloads ~1.1 GB (model
        # plus the audio projector) before it binds the port, and llama-server
        # has no readiness protocol to report that with. Anything waiting on
        # this should poll /health rather than the unit state.
        Type = "simple";
        ExecStart = lib.concatStringsSep " " (
          [
            "${cfg.package}/bin/llama-server"
            "-hf"
            cfg.model
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
            # LFM3-Omni is not trained to reason; upstream's server README
            # says to run it with reasoning off so its turns open with an
            # empty think block instead of the model talking to itself.
            "--reasoning"
            "off"
            # Speech quality. llama.cpp drives text and audio tokens with one
            # sampler (server-realtime.cpp:240 hands every response the
            # server's own `deps.sampling`), so the audio decoder inherits
            # whatever --temp the command line sets -- and the default, 0.80,
            # is twice what LiquidAI documents for speech. Left alone the
            # voice comes out slurred and unstable. These are the model
            # card's audio figures (temperature 0.4, repetition penalty 1.2
            # over a 64-token window); the card's own --temp 0 suggestion is
            # for text-only serving and is wrong here, since silence has no
            # greedy equivalent. extraFlags is appended after these, so a
            # host can still override any of them.
            "--temp"
            "0.4"
            "--repeat-penalty"
            "1.2"
            "--repeat-last-n"
            "64"
          ]
          ++ cfg.extraFlags
        );
        Restart = "on-failure";
      }
      // identityServiceConfig;
    };

    systemd.services.omni-client = lib.mkIf cfg.serveClient {
      description = "Static browser client for the LFM3-Omni realtime API";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.darkhttpd}/bin/darkhttpd"
          cfg.clientPackage
          "--addr"
          cfg.host
          "--port"
          (toString cfg.clientPort)
          "--no-listing"
        ];
        Restart = "on-failure";
        DynamicUser = true;
        # Serving one read-only file out of the nix store needs nothing else.
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
      };
    };
  };
}
