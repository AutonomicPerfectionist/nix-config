{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
let
  cfg = config.userconfig.branden;
in
{

  imports = [
    # pending https://discourse.nixos.org/t/services-kanata-attribute-lib-missing/51476
    ../../modules/nix-dev.nix
    flake-inputs.home-manager.nixosModules.default
  ];

  options.userconfig.branden = {
    enable = lib.mkEnableOption "user branden";
    hostname = lib.mkOption {
      defaultText = "hostname of the current system";
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.branden = {
      isNormalUser = true;
      description = "Branden Butler";
      extraGroups = [
        "networkmanager"
        "wheel"
        # "wireshark"
        "docker"
      ];
      shell = pkgs.zsh;
      packages = with pkgs; [
        bat
        eza
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
    };
    fonts.packages = with pkgs; [
      nerd-fonts.comic-shanns-mono
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
    ];

    # TODO these programs.* options are pretty scattered,
    # should reorganize
    programs.zsh.enable = true;
    programs.nix-ld.enable = true; # Needed for foreign dylib programs
    home-manager = {
      users.branden = ./home/home.nix;
      extraSpecialArgs = {
        inherit flake-inputs;
        userConfiguration = cfg;
      };
    };
  };
}
