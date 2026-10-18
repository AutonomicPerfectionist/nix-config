{ config, ... }:
{
  age.secrets.attic-push-token.file = ../../secrets/attic-push-token.age;
  cluster.atticClient.push = {
    enable = true;
    tokenFile = config.age.secrets.attic-push-token.path;
  };
}
