{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.vlc
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplicationPackages = [
      pkgs.vlc
    ];
  };
}
