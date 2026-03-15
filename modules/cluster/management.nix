{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    pciutils
  ];
}