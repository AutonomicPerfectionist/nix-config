{
  description = "Minimal NixOS installation media";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = self.nixosConfigurations.x86Iso.config.system.build.isoImage;
    nixosConfigurations = {
      x86Iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ pkgs, modulesPath, ... }: {
            imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
            environment.systemPackages = with pkgs; [ 
            	
           	];

           	services.avahi = {
           	    enable = true;
           	    nssmdns = true;
           	    openFirewall = true;
           	    publish = {
           	      enable = true;
           	      userServices = true;
           	      addresses = true;
           	    };
           	  };

           	  services.openssh.enable = true;
           	  networking.hostName = "nixos-installer";

           	  nix.settings = {
           	  	experimental-features = [
           	  	      "nix-command"
           	  	      "flakes"
           	  	    ];
           	  };
          })
        ];
      };
    };
  };
}
