{
  config,
  pkgs,
  flake-inputs,
  ...
}:
{
  environment.variables = {
    HF_HOME = "/mnt/cluster/data/huggingface";
  };

}
