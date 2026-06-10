{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
{

  environment.systemPackages = with pkgs;  [
   llm-agents.hermes-agent 
  ];
}
