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
  };
}
