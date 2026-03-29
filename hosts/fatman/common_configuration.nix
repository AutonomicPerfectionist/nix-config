# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  flake-inputs,
  ...
}:

{
  imports = [
    ../../modules/nix-settings.nix
    ../../modules/avahi.nix
    ../../modules/cluster/mounts.nix
    ../../modules/cluster/management.nix
    ../../modules/cluster/distributed.nix

    flake-inputs.home-manager.nixosModules.default

    # Users
    ../../users/branden

  ];

  home-manager = {
    extraSpecialArgs = { inherit flake-inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  users.users.root.openssh.authorizedKeys.keys =
     		[
    		  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB6ErD21kz5qWhGQLJSKO9qlKnH44LU0yS4rAd8+OQkC branden@big-nix"
    		  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC3TrJ+kvtwroS872kcwJBUemgafuQYz2chtStIN08LzCpipDpo+A0aIjvafK83shztlhcqgQwza/4TkhJGBYvikEegTkqG4T8QPjbvL5RQEuNfL8Mbd9UgYKIkb91sF6VHIBujNCSs0D48C16LUyLFYzcQhLETi1DpG3K4t9HSncH5YLrITlW6l0VYUHllo86sW7pSGgTyhHrI09zskxIGE0lVbScOBh5+eHXphcAlEz07rp50feQjWZKwyCYraG31pk9esXhIJ0qAz4znBCcszteUUra9b1nJucWlTRUh3prqkYRJx0gyS7ClclhV6IofbplNKwxow2tl82C1xg88MUzd+sH9tSbslZVpnibeiW9YTBs9j+KbDohkJ5/hTcf1yceswfPVk9uWNMg5J+vQSszZNfKgrnNTTp8BUVPLh2oNKO9TqPmBqpDBeQtuBDOzD9RnfM0sCSOD9TDw4zw2yPPqRTMG3eznfQ9z8hXbLhY35lV/ZI4FpZbqHSk1/+8= branden@trash-can"
    		  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5fdkXww9okIJ/3leprxCkUaoQtwjI8hppcGnihFwscXiYcht0p5UhFq1S4byTl/HdlhHrRX+qnmlFe2Y7eE9As/6BpyYgBkbaZ3e2cdgZ7DUmh9P2o3N9bTImSvLA0UWDy7OzJ5MbYV1VQPhJlJXW/vcpD6MBOBAeFrRIJuB1DQq7tS66tKgAC8JN8ABV6jk9ioc+OVZLyatvcF28QBrFgoErKFwlVXx3VJro2LVD8wvhiddnx/05pv5P4FkmYTyDT7IDcJijMui5MOCQ7nDjtpH602oUQum8E6+mCDGPN51D1Up5vvN+5HbuH0wuzvWW0l3kunJaeGmNpxrn4py0lWOOmA09HYEfbidjZjpXIAA3evPuWPZmwcFRNF9rciuSDx0OW3xwHs0lav64j3nEM8ib9nhoUu1Iz3GssSyMrW8/Fh1KX2r6ISTWU5tjbcqKK2fIS7wTDWOLf7Is90AHIaBeLULQ5EZzraNSIcxDT+ITIQ10RY4iuzm/sZCJmKc= branden@ryzen-desktop"
    		];
   
    swapDevices = [{
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel 6.12 has the ib_qib module needed for the infiniband cards
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  hardware.infiniband.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    git
    micro
    htop
    xclip
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
