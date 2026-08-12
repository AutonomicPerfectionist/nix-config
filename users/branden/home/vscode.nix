{
  pkgs,
  ...
}:
{
  programs.vscode = {
    enable = true;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;
    extensions = with pkgs.vscode-extensions; [
      ms-python.python
      # ms-python.pylance
      ms-python.debugpy
      rust-lang.rust-analyzer
      ms-vscode.cpptools
      ms-vscode.cpptools-extension-pack
      # ms-vscode.cpptools-themes
      ms-azuretools.vscode-docker
      vscodevim.vim
      eamodio.gitlens
      usernamehw.errorlens
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint
      streetsidesoftware.code-spell-checker
      bungcip.better-toml
      redhat.vscode-yaml
      # wayou.vscode-todo-highlight
      # davidanson.vscode-markdownlint
      # Gruntfuggly.todo-tree
      vscode-icons-team.vscode-icons

      # Remote development
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-ssh-edit
      ms-vscode-remote.remote-containers
      ms-vscode-remote.vscode-remote-extensionpack
      ms-vscode.remote-explorer

      # Themes: deep black backgrounds with vibrant high-contrast highlighting
      johnpapa.winteriscoming
      enkia.tokyo-night
      dracula-theme.theme-dracula
      sainnhe.gruvbox-material
      jdinhlife.gruvbox
      catppuccin.catppuccin-vsc
      github.github-vscode-theme
    ];

    userSettings = {
      editor.fontFamily = "'FiraCode Nerd Font', 'JetBrainsMono Nerd Font', monospace";
      editor.fontLigatures = true;
      editor.fontSize = 14;
      editor.mouseWheelZoom = true;
      workbench.editor.enablePreview = false;
      explorer.autoReveal = false;
      terminal.integrated.fontFamily = "'FiraCode Nerd Font', 'JetBrainsMono Nerd Font', monospace";
      terminal.integrated.fontLigatures = true;
      workbench.colorTheme = "Winter is Coming (Dark Blue)";
      workbench.iconTheme = "vscode-icons";
      editor.minimap.renderCharacters = false;
    };
  };
}
