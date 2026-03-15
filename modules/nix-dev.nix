{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
{

  # nixos-option is good for nix option evaluation,
  # but for some reason does not seem to work with
  # home-manager program options?
  imports = [
    flake-inputs.nixos-cli.nixosModules.nixos-cli
  ];

  programs.nixos-cli.enable = true;

  # nh is better nixos-rebuild and shows actually useful
  # generation diffs
  programs.nh.enable = true;

  environment.systemPackages = with pkgs; [
    nixfmt
    nix-index
    nil
  ];
}
