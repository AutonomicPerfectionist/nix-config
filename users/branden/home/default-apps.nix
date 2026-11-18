# Default applications: which app opens which kind of file/URL.
#
# Desktop-file IDs below were verified against each package's
# share/applications (note helix ships "Helix.desktop", capital H).
# Video/audio defaults are established by vlc.nix via
# xdg.mimeApps.defaultApplicationPackages; entries here are prepended to
# those, so explicit choices below always win.
{
  config,
  pkgs,
  ...
}:
let
  browser = "firefox.desktop";
  guiEditor = "com.system76.CosmicEdit.desktop"; # COSMIC Text
  terminalEditor = "Helix.desktop";
  pdfViewer = "org.gnome.Papers.desktop";
  imageViewer = "org.gnome.Loupe.desktop";
  fileManager = "org.gnome.Nautilus.desktop";
in
{
  home.packages = [
    pkgs.cosmic-edit
  ];

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      # Web pages and links -> Firefox
      "text/html" = browser;
      "application/xhtml+xml" = browser;
      "x-scheme-handler/http" = browser;
      "x-scheme-handler/https" = browser;
      "x-scheme-handler/about" = browser;
      "x-scheme-handler/unknown" = browser;

      # Text and source code -> COSMIC Text. The text/* glob covers
      # plain/markdown/css/x-python/x-shellscript/...; exact keys take
      # precedence over globs, so text/html above still goes to Firefox.
      "text/*" = guiEditor;
      "application/json" = guiEditor;
      "application/xml" = guiEditor;
      "application/javascript" = guiEditor;
      "application/x-shellscript" = guiEditor;
      "application/yaml" = guiEditor;
      "application/toml" = guiEditor;
      "application/x-zerosize" = guiEditor;

      # Documents and media
      "application/pdf" = pdfViewer;
      "image/*" = imageViewer;
      "inode/directory" = fileManager;
    };

    # "Open with" menu entries: helix for anything textual, COSMIC Text
    # for the structured formats it does not declare itself.
    associations.added = {
      "text/*" = terminalEditor;
      "application/json" = terminalEditor;
      "application/xml" = terminalEditor;
      "application/yaml" = terminalEditor;
      "application/toml" = terminalEditor;
      "application/x-shellscript" = terminalEditor;
    };
  };

  # Default terminal for xdg-terminal-exec (used by niri & friends).
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "kitty.desktop" ];
  };

  # Nautilus only shows its right-click "New Document" menu when the
  # Templates dir is non-empty; each file there becomes a menu entry.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    templates = "${config.home.homeDirectory}/Templates";
  };
  home.file."Templates/Empty File".text = "";
  home.file."Templates/Markdown.md".text = "";
  home.file."Templates/Shell Script.sh".text = ''
    #!/usr/bin/env bash

  '';
}
