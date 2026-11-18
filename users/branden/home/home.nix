{
  config,
  lib,
  pkgs,
  flake-inputs,
  userConfiguration,
  ...
}:
let
  hostsList =
    if flake-inputs ? nixosConfigurations then
      builtins.concatStringsSep " " (builtins.attrNames flake-inputs.nixosConfigurations)
    else
      "hypergamma goblin aj-framework lucy big-nix thunder-budget-3 thunder-budget-4 arid-wind fatman-3 king-blue queen-blue";
in

{
  imports =
    lib.optionals userConfiguration.graphical [
      ./niri.nix
      ./noctalia.nix
      ./kitty.nix
      ./slack.nix
      ./vscode.nix
      ./vlc.nix
    ]
    ++ [
      # NOTE: GPU/niri nixpkgs overlays are NOT imported here. On NixOS,
      # home-manager uses useGlobalPkgs and inherits the system overlays
      # from modules/common/overlays.nix. Standalone machines get
      # modules/common/overlays-hm.nix via mkHomeConfig in flake.nix.
      ../../../modules/ml/llama-hm.nix
    ];
  services.llama.useCustomSource = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "branden";
  home.homeDirectory = "/home/branden";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # use-xdg-base-directories = true;

  programs.bash.enable = true;
  home.sessionVariables = {
    EDITOR = "hx";
  };

  home.packages = with pkgs; [
    bat
    comma
    eza
    nerd-fonts.comic-shanns-mono
    nerd-fonts.meslo-lg
    nerd-fonts.fira-code
    # nixpkgs' clustershell postPatch loops over tests/* running
    # substituteInPlace on each entry, but the sdist ships a tests/bin
    # *directory*, which substituteInPlace rejects ("file 'tests/bin' does
    # not exist"). Upstream master guards the loop with [ -f ]; reproduce
    # that here until our nixpkgs pin picks the fix up.
    # NOTE: overridePythonAttrs, not overrideAttrs — the latter silently
    # ignores doCheck on buildPythonPackage derivations.
    (python314Packages.clustershell.overridePythonAttrs (old: {
      postPatch =
        builtins.replaceStrings
          [ "substituteInPlace $f" ]
          [
            "[ -f \"$f\" ] || continue\n      substituteInPlace $f"
          ]
          old.postPatch;
      # The sdist's test suite also fails on python 3.14 (relative `.TLib`
      # imports etc.); upstream master disables the affected tests. Skip
      # the suite until our pin catches up (pythonImportsCheck still runs).
      doCheck = false;
    }))
    nix-ld
    devenv
    direnv
    llm-agents.omp
    mosh
    llm-agents.claude-code

    # Nix linting, formatting, and IDE support
    deadnix
    nixfmt-rfc-style
    nil
    # vscodium
    # vscode
    # neovim
    # flatpak
    # obsidian
    # vlc
    # kitty
    # spotify
    # gimp
    # asdf-vm

    # ===== CORE TERMINAL TOOLING =====
    # helix
    glow
    zoxide
    lazygit
    difftastic
    delta
    dust
    procs
    yazi
    ast-grep
    just
    zellij
    chafa
    viu
    timg

    # LSPs / dev tooling
    basedpyright
    ruff
    clang-tools

    # shell UX plugins (installed via nixpkgs)
    zsh-you-should-use
    zsh-fzf-tab
  ];

  fonts.fontconfig.enable = true;

  home.file.".config/nixpkgs/config.nix".text = ''
    	{
    		allowUnfree = true;
    	}
    	'';

  home.file."ssh/config".text = ''
    Host panocular-a100-server
      HostName 100.78.36.28
      User brandenbutler
    Host panocular-h200-server
      HostName 100.121.170.110
      User brandenbutler
  '';

  xdg.enable = true;
  xdg.configFile."clustershell/config.d/sudo.conf".source = ./config/clustersh/sudo.conf;
  xdg.configFile."clustershell/groups.d/groups.yaml".source = ./config/clustersh/groups.yaml;
  xdg.configFile."clustershell/clush.conf".source = ./config/clustersh/clush.conf;
  xdg.configFile."clustershell/groups.conf".source = ./config/clustersh/groups.conf;

  # Git config
  # Delta is a prettier diff tool with good git integration
  programs.delta.enable = true;
  programs.delta.enableGitIntegration = true;

  # Lazygit semantic diff integration config
  xdg.configFile."lazygit/config.yml" = {
    force = true;
    text = ''
      customCommands:
        - key: "D"
          context: "files"
          command: "git diff --ext-diff -- {{.SelectedFile.Name}}"
          output: terminal
          description: "Semantic diff (difftastic)"

        - key: "<c-d>"
          context: "commits"
          command: "git -c diff.external=difft show {{.SelectedCommit.Sha}}"
          output: terminal
          description: "Semantic commit diff"
    '';
  };

  programs.git.enable = true;
  programs.git.settings = {
    user.name = "Branden Butler";
    user.email = "bwtbutler@hotmail.com";

    # Better diff heuristics for refactors/moved code
    diff = {
      algorithm = "histogram";
      colorMoved = "default";
    };

    # Semantic diff aliases using difftastic
    alias = {
      co = "checkout";
      st = "status";
      br = "branch";
      cm = "commit";
      sd = "-c delta.features=side-by-side diff";

      # Semantic diffs
      dft = "-c diff.external=difft diff";
      sft = "-c diff.external=difft show";

      # Ignore whitespace-only changes
      dw = "diff -w";
      sw = "show -w";
    };

    init.defaultBranch = "main";
  };

  programs.helix = {
    enable = true;
    settings = {
      theme = "ao";
    };
  };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  # UV config
  programs.uv.enable = true;

  # Shell config

  # Starship is a zsh theme similar to
  # spaceship but more modern and with
  # better nix support
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      nix_shell = {
        disabled = false;
        # impure_msg = "";
        # symbol = "";
        # format = "[$symbol$state]($style) ";
        heuristic = true;
      };
      shlvl = {
        disabled = false;
        symbol = "λ ";
      };
    };
  };

  # EZA is a better ls
  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # =========================
  # DIRNAV / HISTORY
  # =========================
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableVteIntegration = true;

    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    autosuggestion.highlight = "fg=#663399,standout";

    plugins = [
      {
        name = pkgs.zsh-autopair.pname;
        src = pkgs.zsh-autopair.src;
      }

      {
        name = "you-should-use";
        src = pkgs.zsh-you-should-use.src;
      }

      {
        name = "forgit";
        src = pkgs.zsh-forgit.src;
      }

      {
        name = "zsh-fzf-tab";
        # Upstream ships fzf-tab.plugin.zsh, not zsh-fzf-tab.plugin.zsh.
        file = "fzf-tab.plugin.zsh";
        src = pkgs.zsh-fzf-tab.src;
      }
    ];

    # Probably don't need this anymore
    oh-my-zsh = {
      enable = true;
    };

    shellAliases = {
      #nixswitch = ("nh os switch ~/nixos#" + userConfiguration.hostname);
      ls = "eza --git -F --icons --hyperlink -g";
      lsa = "ls -alh";
      lg = "lazygit";
      zj = "zellij";
      rsync-archive = "rsync -azhP --partial";
    };

    # Prettier help with auto paging
    shellGlobalAliases = {
      "--help" = "--help 2>&1 | bat --language=help --style=plain";
    };

    # NixOS switch function with completion
    initContent = ''
            # =========================
            # CARAPACE (completion fallback)
            # =========================
            # Carapace registers itself for ~800 commands, clobbering the
            # completers zsh/nixpkgs already ship for about a third of them.
            # Its specs for those are often thinner than zsh's: `sed -n 1p <TAB>`
            # stops completing paths at all, and `git checkout <TAB>` only emits
            # fully-qualified refs, so a remote-only branch never completes under
            # its bare DWIM name.
            #
            # So: snapshot the completers compinit set up, let carapace register
            # everything, then hand the overlapping commands back to zsh.
            # Carapace keeps the ~530 commands zsh has no completer for, which is
            # the part that is actually worth having.
            #
            # Add a command here to deliberately leave it with carapace.
            typeset -a carapace_preferred=()

            if (( ''${+_comps} )); then
              typeset -A _zsh_native_comps
              _zsh_native_comps=("''${(@kv)_comps}")

              source <(${lib.getExe config.programs.carapace.finalPackage} _carapace zsh)

              typeset _cmd
              for _cmd in "''${(@k)_zsh_native_comps}"; do
                (( ''${carapace_preferred[(Ie)$_cmd]} )) && continue
                _comps[$_cmd]="''${_zsh_native_comps[$_cmd]}"
              done
              unset _cmd _zsh_native_comps
            else
              source <(${lib.getExe config.programs.carapace.finalPackage} _carapace zsh)
            fi
            unset carapace_preferred

            # =========================
            # DEV CHEATSHEET
            # =========================
            dev-cheatsheet() {
              cat <<'EOF'

      Navigation:
        z <dir>        → smart cd (zoxide)
        zi             → interactive directory jump

      Files:
        y              → file manager (yazi)
        eza            → modern ls

      Search:
        rg <pattern>   → ripgrep
        fd <name>      → fast find
        sg <pattern>   → ast-grep (structural search)

      Git:
        lazygit        → full git UI
        git            → CLI (use sparingly)
        git dft        → semantic diff (difftastic)
        git sft        → semantic show (difftastic)

      System:
        btop           → system monitor
        dust           → disk usage
        procs          → process viewer

      Editor:
        hx             → Helix editor

      Markdown:
        glow file.md   → markdown preview

      Images:
        chafa <file>   → image in terminal (any terminal)
        viu <file>     → image with pixel protocol (kitty/wezterm)
        timg <file>    → image/video/PDF preview

      Session:
        zellij         → terminal multiplexer

      EOF
            }

            # =========================
            # SAFE TOOL SUGGESTIONS
            # =========================
            # Only runs in interactive shells
            if [[ $- == *i* ]]; then

              suggest_tool() {
                local cmd="$1"

                case "$cmd" in
                  cd)
                    echo "[hint] consider: zoxide (z <dir>)" ;;
                  du)
                    echo "[hint] consider: dust (visual disk usage)" ;;
                  ps)
                    echo "[hint] consider: procs (better process view)" ;;
                  find)
                    echo "[hint] consider: fd (faster find)" ;;
                  grep)
                    echo "[hint] consider: rg (ripgrep)" ;;
                  vim|vi|nano)
                    echo "[hint] consider: hx (Helix editor)" ;;
                  git)
                    echo "[hint] consider: lazygit (interactive git UI)" ;;
                esac
              }

              # zsh hook: only for interactive command lines
              preexec() {
                suggest_tool "$1"
              }

            fi

            # =========================
            # NIXOS SWITCH HELPER
            # =========================
            nixos-switch() {
              local host="$1"
              if [[ -z "$host" ]]; then
                echo "Usage: nixos-switch <hostname>"
                echo "Available hosts: ${hostsList}"
                return 1
              fi
              nh os switch ".#''${host}" --target-host="''${host}.local" --build-host="''${host}.local"
            }

            _nixos-switch() {
              local -a hosts
              hosts=(${hostsList})
              _describe 'hosts' hosts
            }

            compdef _nixos-switch nixos-switch
    '';
  };

  # Carapace fills in completions for tools zsh does not know about.
  # Its zsh integration is wired up by hand in programs.zsh.initContent above
  # so that zsh's own completers keep priority -- see the comment there.
  programs.carapace.enable = true;
  programs.carapace.enableZshIntegration = false;

  programs.opencode.enable = true;

  # intelli-shell allows to auto-fix commands (ctrl+x) or look for/create snippets (ctrl+space)
  # TODO: Add API key age file
  programs.intelli-shell = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      ai = {
        enabled = true;
        models = {
          suggest = "main";
          # The alias of the model used to fix or explain a failing command
          fix = "main";
          # The alias of the model to use when importing commands
          "import" = "main";
          # The alias of the model to use when generating a command for a dynamic variable completion
          completion = "main";
          # The alias of a model to use as a fallback if the primary model fails due to rate limits
          fallback = "fallback";
        };
        catalog = {
          main = {
            provider = "openai";
            url = "https://openrouter.ai/api/v1";
            model = "nvidia/nemotron-3-super-120b-a12b:free";
            api_key_env = "OPENROUTER_API_KEY";
          };
          falback = {
            provider = "openai";
            url = "https://openrouter.ai/api/v1";
            model = "nvidia/nemotron-3-nano-30b-a3b:free";
            api_key_env = "OPENROUTER_API_KEY";
          };
        };
      };
    };
  };

  programs.micro.enable = true;
  programs.micro.settings = {
    diffgutter = true;
    keymenu = true;
    mkparents = true;
    savecursor = true;
    clipboard = "external";
    colorscheme = "dukedark-tc";
  };

  programs.less.enable = true;
  programs.less.options = {
    RAW-CONTROL-CHARS = true;
    # quiet = true;
    wheel-lines = 3;
  };

  dconf.settings = lib.mkIf userConfiguration.graphical {
    "org/gnome/shell" = {
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "dash-to-dock@micxgx.gmail.com"
        "burn-my-windows@schneegans.github.com"
        "clipboard-indicator@tudmotu.com"
        "blur-my-shell@aunetx"
        "caffeine@patapon.info"
        "Vitals@CoreCoding.com"
        "fullscreen-avoider@noobsai.github.com"
        "just-perfection-desktop@just-perfection"
      ];
    };

    "org/gnome/desktop/wm/keybindings" = {
      switch-applications = [ "<Alt>Tab" ];
      switch-applications-backward = [ "<Shift><Alt>Tab" ];
      switch-windows = [ "<Super>Tab" ];
      switch-windows-backward = [ "<Shift><Super>Tab" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Toggle Mic Mute";
      command = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      binding = "<Super>c";
    };
  };

}
