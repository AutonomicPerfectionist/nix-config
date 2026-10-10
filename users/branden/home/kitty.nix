{
  pkgs,
  flake-inputs,
  ...
}:
{
  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    enableGitIntegration = true;
    keybindings = {
      "f1" = "launch --allow-remote-control kitten broadcast --match-tab state:focused";
    };
  };
}
