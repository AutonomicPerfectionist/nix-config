# modules/ai-agent.nix
#
# Top-level NixOS module for the self-hosted AI coding agent stack.
#
# This module is the single configuration surface for the whole system.
# All other modules (vector-memory, omp) read their settings from the
# options declared here, so the user only needs to touch this file.
#
# Enabled sub-systems:
#   - Qdrant vector store           (services.aiAgent.memory.enable)
#   - Codebase indexer service      (always on when memory is enabled)
#   - omp (oh-my-pi) coding agent   (per-user, via services.aiAgent.users)
#
# llama.cpp RPC setup is intentionally OUT OF SCOPE here.
# The orchestrator and coding-agent backend URLs are plain string options
# so they can point at whatever llama-server endpoints you already run.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.aiAgent;
in
{
  # ─────────────────────────────────────────────────────────────────────────
  # Option declarations
  # ─────────────────────────────────────────────────────────────────────────
  options.services.aiAgent = {

    enable = lib.mkEnableOption "self-hosted multi-model AI coding agent stack";

    # ── LLM backend endpoints ──────────────────────────────────────────────
    # These point at your llama-server instances serving MiniMax and Qwen.
    # They are passed directly into omp's models.yml config file.

    orchestratorUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080";
      description = ''
        Base URL of the orchestrator llama-server (MiniMax or equivalent).
        Must expose an OpenAI-compatible /v1 API (llama-server --port 8080).
        Example for a remote node: "http://192.168.1.10:8080"
      '';
      example = "http://192.168.1.10:8080";
    };

    orchestratorModel = lib.mkOption {
      type = lib.types.str;
      default = "minimax-m2";
      description = ''
        Model ID to send in API requests to the orchestrator backend.
        llama-server ignores this field, but omp uses it for display and
        routing rules. Set it to any string that identifies the model.
      '';
      example = "minimax-m2-Q4_K_M";
    };

    codingAgentUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8081";
      description = ''
        Base URL of the coding sub-agent llama-server (Qwen2.5-Coder or
        equivalent). omp delegates file-editing tasks to this endpoint to
        preserve orchestrator context budget.
        Example for a remote node: "http://192.168.1.11:8081"
      '';
      example = "http://192.168.1.11:8081";
    };

    codingAgentModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen2.5-coder";
      description = ''
        Model ID for the coding sub-agent backend.
      '';
      example = "qwen2.5-coder-32b-Q4_K_M";
    };

    # ── Per-user agent installation ────────────────────────────────────────
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        List of local user names for whom the agent config files (models.yml,
        settings.json) will be written to ~/.omp/agent/.
        omp itself is installed system-wide; this only controls config
        file generation.
      '';
      example = [
        "alice"
        "bob"
      ];
    };

    # ── Vector memory sub-system ───────────────────────────────────────────
    memory = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable the vector memory sub-system (Qdrant + indexer).
          When enabled, the codebase indexer service runs on a schedule and
          omp's before_agent_start hook injects relevant snippets into context.
          Disable if you only want omp with no persistent semantic memory.
        '';
      };

      qdrantHttpPort = lib.mkOption {
        type = lib.types.port;
        default = 6333;
        description = "Port for the Qdrant HTTP/REST API.";
      };

      qdrantGrpcPort = lib.mkOption {
        type = lib.types.port;
        default = 6334;
        description = "Port for the Qdrant gRPC API (used by the indexer).";
      };

      # Paths to index, relative to each user's home.
      # The indexer service runs as each user and reads these paths.
      projectRoots = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "~/projects"
          "~/src"
          "~/code"
        ];
        description = ''
          Directories to scan for source code to index into Qdrant.
          Paths are expanded relative to the user's home directory.
          Subdirectories are walked recursively; files matching
          `indexer.excludePatterns` are skipped.
        '';
        example = [
          "~/projects/my-distributed-app"
          "~/src"
        ];
      };

      excludePatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "*.lock"
          "*.sum"
          "node_modules"
          ".git"
          "target"
          "_build"
          "__pycache__"
          "*.min.js"
          "*.min.css"
          "dist"
          "build"
        ];
        description = ''
          Glob patterns for files and directories to skip when indexing.
          Matched against file names (not full paths).
        '';
      };

      embeddingsPort = lib.mkOption {
        type = lib.types.port;
        default = 8082;
        description = "Port for the llama.cpp embeddings server.";
      };

      indexSchedule = lib.mkOption {
        type = lib.types.str;
        default = "hourly";
        description = ''
          Systemd calendar expression for the indexer timer.
          Use "hourly", "daily", or a full OnCalendar expression.
          The indexer is incremental; only changed files are re-embedded.
        '';
        example = "*:0/30"; # every 30 minutes
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "~/.local/share/ai-agent";
        description = ''
          Directory in which the indexer stores its SQLite state database
          (indexer.db).  Follows the XDG Base Directory specification by
          default ($XDG_DATA_HOME/ai-agent, where $XDG_DATA_HOME defaults
          to ~/.local/share).

          Use ~ to refer to the user's home directory; it is expanded to the
          home path declared in users.users.<name>.home (falling back to
          /home/<name>) so that Nix-evaluated values such as ReadWritePaths
          and systemd-tmpfiles rules receive a concrete absolute path rather
          than a shell glob.

          The directory is created automatically by a systemd-tmpfiles rule
          before the indexer service starts, so you do not need to create it
          manually.
        '';
        example = "~/.local/share/ai-agent";
      };
    };

    # ── omp package ────────────────────────────────────────────────────────
    # Set this to the omp derivation from numtide/llm-agents.nix.
    # Because modules cannot read flake inputs directly, you must pass the
    # package in from your flake's outputs.  The recommended pattern is:
    #
    #   services.aiAgent.ompPackage =
    #     inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
    #
    # If you prefer an overlay, apply llm-agents.overlays.default to your
    # nixpkgs and set:
    #   services.aiAgent.ompPackage = pkgs.llm-agents.omp;
    ompPackage = lib.mkOption {
      type = lib.types.package;
      description = ''
        The omp (oh-my-pi) package to install.
        Must be set explicitly — recommended source is numtide/llm-agents.nix:

          inputs.llm-agents.url = "github:numtide/llm-agents.nix";
          # then in your module or configuration.nix:
          services.aiAgent.ompPackage =
            inputs.llm-agents.packages.''${pkgs.stdenv.hostPlatform.system}.omp;
      '';
      example = lib.literalExpression "inputs.llm-agents.packages.''${pkgs.stdenv.hostPlatform.system}.omp";
    };

    # ── omp agent settings ─────────────────────────────────────────────────
    agent = {
      contextWindowFraction = lib.mkOption {
        type = lib.types.float;
        default = 0.75;
        description = ''
          Fraction of the orchestrator's context window to use before omp
          triggers compaction (summarisation of older messages).
          0.75 leaves headroom for tool outputs and injected memory snippets.
        '';
      };

      memorySnippets = lib.mkOption {
        type = lib.types.int;
        default = 8;
        description = ''
          Number of top-K vector search results to inject into context at
          session start. Higher values give the model more codebase context
          at the cost of context budget.
        '';
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Additional key-value pairs merged into omp's settings.json.
          Use this to set themes, keybindings, or any other omp option
          not exposed as a dedicated NixOS option here.
          See https://pi.dev/docs/latest/configuration for the full schema.
        '';
        example = {
          theme = "catppuccin-mocha";
          "editor.autoApprove" = false;
        };
      };
    };
  };

  # ─────────────────────────────────────────────────────────────────────────
  # Config: pass options down to sub-modules via config assertions
  # ─────────────────────────────────────────────────────────────────────────
  config = lib.mkIf cfg.enable {
    # Sanity checks surfaced at nixos-rebuild time.
    assertions = [
      {
        assertion = cfg.users != [ ];
        message = "services.aiAgent.users must list at least one local user.";
      }
      {
        assertion = lib.all (u: config.users.users ? ${u}) cfg.users;
        message = ''
          services.aiAgent.users contains a name not present in
          users.users: ${lib.concatStringsSep ", " cfg.users}
        '';
      }
    ];

    # Surface useful info on rebuild.
    warnings = lib.optional (cfg.orchestratorUrl == "http://127.0.0.1:8080") ''
      services.aiAgent.orchestratorUrl is set to localhost (127.0.0.1:8080).
      Make sure your llama-server is actually running on this machine.
      For a remote cluster, set orchestratorUrl to the node's address.
    '';
  };
}
