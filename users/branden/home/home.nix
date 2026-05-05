{
  config,
  pkgs,
  ...
}:
{
  imports = [
    
  ];

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
    EDITOR = "micro";
  };

  
  home.packages = with pkgs; [
    bat
    comma
    eza
    nerd-fonts.comic-shanns-mono
    nerd-fonts.meslo-lg
    nerd-fonts.fira-code
    ansible
    python314Packages.clustershell
    nix-ld
    devenv
    # vscodium
    # vscode
    # zed-editor
    # neovim
    # flatpak
    # obsidian
    # vlc
    # kitty
    # spotify
    # gimp
    # asdf-vm
  ];

  
  fonts.fontconfig.enable = true;

  
  home.file.".config/nixpkgs/config.nix".text = ''
    	{
    		allowUnfree = true;
    	}
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
  programs.git.enable = true;
  programs.git.settings = {
    user.name = "Branden Butler";
    user.email = "bwtbutler@hotmail.com";
    alias = {
      co = "checkout";
      st = "status";
      br = "branch";
      cm = "commit";
      sd = "-c delta.features=side-by-side diff";
    };
    init.defaultBranch = "main";
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
        # symbol = "";
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

    ];

    # Probably don't need this anymore
    oh-my-zsh = {
      enable = true;
    };

    shellAliases = {
      #nixswitch = ("nh os switch ~/nixos#" + userConfiguration.hostname);
      ls = "eza --git -F --icons --hyperlink -g";
      lsa = "ls -alh";
    };

    # Prettier help with auto paging
    shellGlobalAliases = {
      "--help" = "--help 2>&1 | bat --language=help --style=plain";
    };
  };

  # Carapace is a better tab-completion manager
  programs.carapace.enable = true;
  programs.carapace.enableZshIntegration = true;

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

}
