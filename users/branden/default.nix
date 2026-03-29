{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}:
let
  cfg = config.userconfig.branden;
in
{

  imports = [
    # pending https://discourse.nixos.org/t/services-kanata-attribute-lib-missing/51476
    ../../modules/nix-dev.nix
    flake-inputs.home-manager.nixosModules.default
  ];

  options.userconfig.branden = {
    enable = lib.mkEnableOption "user branden";
    hostname = lib.mkOption {
      defaultText = "hostname of the current system";
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.branden = {
      isNormalUser = true;
      description = "Branden Butler";
      extraGroups = [
        "networkmanager"
        "wheel"
        # "wireshark"
        "docker"
      ];
      shell = pkgs.zsh;

	openssh.authorizedKeys.keys =
 		[
		  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB6ErD21kz5qWhGQLJSKO9qlKnH44LU0yS4rAd8+OQkC branden@big-nix"
		  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC3TrJ+kvtwroS872kcwJBUemgafuQYz2chtStIN08LzCpipDpo+A0aIjvafK83shztlhcqgQwza/4TkhJGBYvikEegTkqG4T8QPjbvL5RQEuNfL8Mbd9UgYKIkb91sF6VHIBujNCSs0D48C16LUyLFYzcQhLETi1DpG3K4t9HSncH5YLrITlW6l0VYUHllo86sW7pSGgTyhHrI09zskxIGE0lVbScOBh5+eHXphcAlEz07rp50feQjWZKwyCYraG31pk9esXhIJ0qAz4znBCcszteUUra9b1nJucWlTRUh3prqkYRJx0gyS7ClclhV6IofbplNKwxow2tl82C1xg88MUzd+sH9tSbslZVpnibeiW9YTBs9j+KbDohkJ5/hTcf1yceswfPVk9uWNMg5J+vQSszZNfKgrnNTTp8BUVPLh2oNKO9TqPmBqpDBeQtuBDOzD9RnfM0sCSOD9TDw4zw2yPPqRTMG3eznfQ9z8hXbLhY35lV/ZI4FpZbqHSk1/+8= branden@trash-can"
		  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5fdkXww9okIJ/3leprxCkUaoQtwjI8hppcGnihFwscXiYcht0p5UhFq1S4byTl/HdlhHrRX+qnmlFe2Y7eE9As/6BpyYgBkbaZ3e2cdgZ7DUmh9P2o3N9bTImSvLA0UWDy7OzJ5MbYV1VQPhJlJXW/vcpD6MBOBAeFrRIJuB1DQq7tS66tKgAC8JN8ABV6jk9ioc+OVZLyatvcF28QBrFgoErKFwlVXx3VJro2LVD8wvhiddnx/05pv5P4FkmYTyDT7IDcJijMui5MOCQ7nDjtpH602oUQum8E6+mCDGPN51D1Up5vvN+5HbuH0wuzvWW0l3kunJaeGmNpxrn4py0lWOOmA09HYEfbidjZjpXIAA3evPuWPZmwcFRNF9rciuSDx0OW3xwHs0lav64j3nEM8ib9nhoUu1Iz3GssSyMrW8/Fh1KX2r6ISTWU5tjbcqKK2fIS7wTDWOLf7Is90AHIaBeLULQ5EZzraNSIcxDT+ITIQ10RY4iuzm/sZCJmKc= branden@ryzen-desktop"
		];

		
		# hashedPasswordFile = config.age.secrets.branden-passwd.path;
    };
    
	# age.secrets."branden-passwd" = {
	# 		file = ../../secrets/branden-passwd.age;
	# 		owner = "branden";
	# 	};
    # TODO these programs.* options are pretty scattered,
    # should reorganize
    programs.zsh.enable = true;
    programs.nix-ld.enable = true; # Needed for foreign dylib programs
        
    home-manager = {
      users.branden = ./home/home.nix;
      extraSpecialArgs = {
        inherit flake-inputs;
        userConfiguration = cfg;
      };
    };
  };
}
