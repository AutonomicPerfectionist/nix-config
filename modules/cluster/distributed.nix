{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
 

  environment.systemPackages = with pkgs; [
  	mpi
  	prrte
  ];

}
