# tts.nix
#
# NixOS module for speech.cpp (https://github.com/nyosegawa/speech.cpp,
# repo slug qwen3-tts-ggml) -- a standalone C++ TTS/ASR/VAD engine on ggml
# (same family as llama.cpp/whisper.cpp). `speech serve` is a persistent
# server with a NATIVE OpenAI-compatible /v1/audio/speech endpoint, so no
# custom wrapper script is needed here (unlike the Piper setup this
# replaces, which needed one since nothing in nixpkgs exposes Piper that
# way).
#
# Chosen after directly comparing it, by hand, against three other options:
#   - A hobbyist from-scratch Qwen3-TTS C reimplementation: produced
#     degenerate "Ha, ha, ha" output on round-trip verification.
#   - Chatterbox Multilingual (PyTorch): huge/fragile dependency tree
#     (pulls in gradio, diffusers, onnx...), an FHS/libstdc++ issue once
#     installed, then a watermarker init bug after that was fixed.
#   - Mainline llama.cpp's `llama-tts` CLI: correct output, but no
#     persistent-server mode -- the ~GB model reloads from scratch on
#     every single call, costing ~5-10s per request.
# speech.cpp's `speech serve` gave verified-correct German output (via
# round-trip transcription through whisper-server) at ~1.1s per request
# with the model resident, confirmed by hand.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.speech-server;

  # speech.cpp's GPU backends are Metal, Vulkan and CPU (a CUDA build
  # exists but is explicitly "not checked or released" upstream) -- no
  # ROCm. Vulkan is therefore the only GPU path for AMD hardware, same as
  # this repo already uses for llama.cpp/whisper.cpp on this card.
  useVulkan =
    cfg.preferVulkan
    || (config.hardware.gpu.amd.enable or false)
    || (config.hardware.gpu.nvidia.enable or false)
    || (config.hardware.gpu.intel.enable or false);

  speechCppPkg = pkgs.stdenv.mkDerivation {
    pname = "speech-cpp";
    version = "0.8.11";

    src = pkgs.fetchFromGitHub {
      owner = "nyosegawa";
      repo = "qwen3-tts-ggml";
      rev = "d074e1b9d84fe5ec530c959292ffe3d94ffd288b";
      hash = "sha256-e/gHX4KiezIdOsBNKr8HMQEhLRHX1rGqiZX28aZlDyk=";
      fetchSubmodules = true;
    };

    nativeBuildInputs =
      with pkgs;
      [
        cmake
        pkg-config
      ]
      ++ lib.optionals useVulkan [
        shaderc
        glslang
      ];

    buildInputs = lib.optionals useVulkan [
      pkgs.vulkan-headers
      pkgs.vulkan-loader
    ];

    cmakeFlags = [
      (lib.cmakeBool "GGML_VULKAN" useVulkan)
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp speech $out/bin/
      runHook postInstall
    '';

    meta = {
      description = "Speech synthesis, recognition and VAD on ggml (Qwen3-TTS, Qwen3-ASR, Silero VAD)";
      homepage = "https://github.com/nyosegawa/speech.cpp";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "speech";
    };
  };

  # See modules/ml/llama.nix's identityServiceConfig for the full rationale:
  # defaults to DynamicUser, but a fixed user is needed to write into a
  # model cache owned by a real account (same /mnt/cluster share as
  # HF_HOME elsewhere in this repo).
  identityServiceConfig =
    if cfg.user != null then
      { User = cfg.user; } // lib.optionalAttrs (cfg.group != null) { Group = cfg.group; }
    else
      {
        DynamicUser = true;
      }
      // lib.optionalAttrs useVulkan {
        SupplementaryGroups = [
          "render"
          "video"
        ];
      };
in
{
  options.services.speech-server = {
    enable = lib.mkEnableOption "speech.cpp OpenAI-compatible text-to-speech server";

    preferVulkan = lib.mkEnableOption "Vulkan backend (overrides automatic GPU detection)";

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
      default = speechCppPkg;
      defaultText = lib.literalExpression "auto-built speech.cpp (Vulkan when a GPU is present)";
      description = "The speech.cpp package to use.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8091;
      description = "Port on which the speech.cpp OpenAI-compatible API listens.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3-tts-0.6b";
      description = ''
        speech.cpp model name (see `speech models` for the full catalog),
        fetched automatically into modelDir on first start.
      '';
    };

    voice = lib.mkOption {
      type = lib.types.str;
      default = "ryan";
      description = "Default voice preset, used for any request that doesn't specify its own.";
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = "de";
      description = ''
        Default language, used for any request that doesn't specify its
        own. Open WebUI's TTS requests don't include a language field (it
        mimics OpenAI's API, which has none), so this is what actually
        makes German the default.
      '';
    };

    modelDir = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/cluster/data/speech-cpp/models";
      description = "Directory where speech.cpp caches downloaded model files (SPEECH_MODEL_DIR).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.speech-server = {
      description = "speech.cpp OpenAI-compatible text-to-speech server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      # speech.cpp fetches models by shelling out to the system's curl, not
      # a vendored HTTP client (confirmed in its own ADRs) -- curl must be
      # on PATH.
      path = [ pkgs.curl ];

      environment = {
        SPEECH_MODEL_DIR = cfg.modelDir;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = ''
          ${cfg.package}/bin/speech serve ${cfg.model} \
            --port ${toString cfg.port} \
            --voice ${cfg.voice} \
            --language ${cfg.language}
        '';
        Restart = "on-failure";
      }
      // identityServiceConfig;
    };
  };
}
