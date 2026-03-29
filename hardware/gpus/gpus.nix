{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  imports = [
    ./nvidia.nix
    ./amd.nix
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages = with pkgs; [
    # Add any additional GPU tools
    nvtopPackages.full
  ];

}
