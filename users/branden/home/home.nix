{
  config,
  pkgs,
  flake-inputs,
  userConfiguration,
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

  programs.bash.enable = true;
  home.sessionVariables = {
    EDITOR = "micro";
  };

  
  home.file.".config/nixpkgs/config.nix".text = ''
    	{
    		allowUnfree = true;
    	}
    	'';

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
      nixswitch = ("nh os switch ~/nixos#" + userConfiguration.hostname);
      ls = "eza --git -F --icons --hyperlink -g";
      lsa = "ls -alh";
    };

    # Prettier help with auto paging
    shellGlobalAliases = {
      "--help" = "--help 2>&1 | bat --language=help --style=plain";
    };
  };

}
