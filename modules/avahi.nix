{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
{

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    # publish.{enable,userServices,addresses} are obsolete; the settings.*
    # options map directly onto avahi-daemon.conf's [publish] section.
    settings.publish = {
      disable-publishing = false;
      disable-user-service-publishing = false;
      publish-addresses = true;
    };
  };
}
