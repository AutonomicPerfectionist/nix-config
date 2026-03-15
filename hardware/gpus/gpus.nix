{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ./nvidia.nix
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

}