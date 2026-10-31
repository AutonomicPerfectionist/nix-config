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

  # environment.variables only populates /etc/set-environment, which is
  # sourced by login shells (pam_env) -- it is NOT inherited by system
  # systemd services. Services that need HF_HOME must set it explicitly in
  # their own `environment` block, reading config.environment.variables.HF_HOME
  # so there is a single source of truth.
  #
  # This directory already exists on the /mnt/cluster NFS share -- it's
  # branden's own long-lived HF cache (uid 1000, mode 0700), not something
  # created fresh by this module. A systemd.tmpfiles `d` rule here would not
  # help: `d` only sets ownership/mode when it *creates* the path, it doesn't
  # retroactively fix an already-existing directory's permissions (confirmed
  # by hand -- a world-writable `d` rule silently did nothing against this
  # path). Since it's owned by a real account rather than world-writable,
  # any service with hfRepo/auto-download enabled must run `as` that user
  # (services.llama.user / services.whisper-server.user /
  # services.speech-server.user) instead of the default DynamicUser, which
  # gets a fresh ephemeral uid per start with no access to it.
}
