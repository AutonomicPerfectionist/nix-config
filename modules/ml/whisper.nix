# whisper.nix
#
# NixOS module exposing whisper.cpp's `whisper-server` as an OpenAI-compatible
# STT endpoint (whisper-server already implements /v1/audio/transcriptions
# natively via --inference-path -- no custom server code needed). GPU backend
# selection mirrors modules/ml/llama.nix: CUDA -> ROCm -> CPU fallback.
#
# whisper.cpp's model loading has no `-hf`-style auto-download (only the old
# download-ggml-model.sh script, which bypasses the HF cache). So the service
# shells out to `hf download -q` first (the `huggingface-cli` it replaces no
# longer runs at all as of huggingface_hub 1.x) -- which DOES respect
# HF_HOME, caching under $HF_HOME/hub like every other HF download here --
# and feeds the resolved local path to whisper-server.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.whisper-server;

  useCuda = config.hardware.gpu.nvidia.enable or false;
  useRocm = config.hardware.gpu.amd.enable or false;

  # Same rationale as modules/ml/llama.nix: DynamicUser's transient uid needs
  # render/video to open /dev/dri/renderD* for the ROCm backend.
  gpuServiceConfig = lib.optionalAttrs useRocm {
    SupplementaryGroups = [
      "render"
      "video"
    ];
  };

  # See modules/ml/llama.nix's identityServiceConfig for the full rationale:
  # defaults to DynamicUser, but a fixed user is needed to write into a
  # HF_HOME cache owned by a real account.
  identityServiceConfig =
    if cfg.user != null then
      { User = cfg.user; } // lib.optionalAttrs (cfg.group != null) { Group = cfg.group; }
    else
      { DynamicUser = true; } // gpuServiceConfig;

  pkgsCuda = import pkgs.path {
    inherit (pkgs) system;
    config = pkgs.config // {
      cudaSupport = true;
    };
    overlays = config.nixpkgs.overlays;
  };

  pkgsRocm = import pkgs.path {
    inherit (pkgs) system;
    config = pkgs.config // {
      rocmSupport = true;
    };
    overlays = config.nixpkgs.overlays;
  };

  whisperPkg =
    if cfg.preferVulkan then
      pkgs.whisper-cpp-vulkan
    else if useCuda then
      pkgsCuda.whisper-cpp
    else if useRocm then
      pkgsRocm.whisper-cpp
    else
      pkgs.whisper-cpp;

  hfHub = pkgs.python314Packages.huggingface-hub;
in
{
  options.services.whisper-server = {
    enable = lib.mkEnableOption "whisper.cpp OpenAI-compatible speech-to-text server";

    preferVulkan = lib.mkEnableOption "Vulkan backend for whisper.cpp (overrides automatic GPU backend detection)";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Run as this user instead of a DynamicUser (needed to write into a HF_HOME cache owned by a real account).";
    };

    group = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Group to run as when user is set. Defaults to that user's primary group when null.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = whisperPkg;
      defaultText = lib.literalExpression "auto-selected whisper-cpp variant";
      description = "The whisper-cpp package to use. Auto-selects CUDA/ROCm based on hardware.gpu.*.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = "Port on which the whisper-server OpenAI-compatible API listens.";
    };

    modelRepo = lib.mkOption {
      type = lib.types.str;
      default = "ggerganov/whisper.cpp";
      description = "Hugging Face repo holding the ggml whisper model file.";
    };

    modelFile = lib.mkOption {
      type = lib.types.str;
      default = "ggml-large-v3-turbo.bin";
      description = ''
        ggml model filename within modelRepo. large-v3-turbo is the
        latency-conscious default; use ggml-large-v3.bin for max accuracy.
      '';
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = "de";
      description = "Language code forced on the transcription (whisper-server --language).";
    };

    vadModelRepo = lib.mkOption {
      type = lib.types.str;
      default = "ggml-org/whisper-vad";
      description = "Hugging Face repo holding the ggml Silero VAD model file.";
    };

    vadModelFile = lib.mkOption {
      type = lib.types.str;
      default = "ggml-silero-v5.1.2.bin";
      description = ''
        Confirmed to exist in vadModelRepo by hand (small download).
        Without VAD, Whisper is well known to hallucinate fixed stock phrases
        on silence/low-energy audio -- in German this is overwhelmingly
        "Vielen Dank" (the German equivalent of the equally famous English
        "Thank you for watching" hallucination, both learned from
        video-caption training data). Voice Mode's auto-send-after-silence
        behavior means every clip legitimately ends with a couple of seconds
        of trailing silence, which triggers this reliably without VAD to
        strip it before it reaches the model.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.whisper-server = {
      description = "whisper.cpp OpenAI-compatible speech-to-text server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        HF_HOME = config.environment.variables.HF_HOME or "";
      };

      path = [ hfHub ];

      script = ''
        set -euo pipefail
        # `huggingface-cli` is deprecated/removed as of huggingface_hub 1.x;
        # `hf download -q` is its replacement and prints the bare resolved
        # cache path on stdout (verified by hand -- the old `huggingface-cli`
        # no longer runs at all).
        model_path="$(hf download -q ${cfg.modelRepo} ${cfg.modelFile})"
        vad_model_path="$(hf download -q ${cfg.vadModelRepo} ${cfg.vadModelFile})"
        exec ${cfg.package}/bin/whisper-server \
          --model "$model_path" \
          --host 127.0.0.1 \
          --port ${toString cfg.port} \
          --inference-path /v1/audio/transcriptions \
          --language ${cfg.language} \
          --convert \
          --tmp-dir /tmp \
          --vad \
          --vad-model "$vad_model_path" \
          --suppress-nst
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
      }
      // identityServiceConfig;
    };
  };
}
