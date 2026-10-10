{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./distributed.nix
    ./management.nix
    ./env.nix
    ./mounts.nix
    ./rdma.nix
    ./attic.nix
  ];

  cluster.atticClient = {
    enable = true;
    endpoint = "http://big-nix.local:8080";
    cache = "main";
    publicKey = "main:68CBhPmqKQZsyCiOOhn247PkST3KwiFNNCREFb8REho=";
  };
  age.secrets.attic-push-token.file = ../../secrets/attic-push-token.age;
  cluster.atticClient.push = {
    enable = true;
    tokenFile = config.age.secrets.attic-push-token.path;
  };
}
