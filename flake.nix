{
  description = "A very basic flake";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixpkgs-stable = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-cli.url = "github:nix-community/nixos-cli";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    llm-agents.url = "github:numtide/llm-agents.nix";
    llama-cpp-fork = {
      url = "github:sredman/llama.cpp/work/sredman/rpc-pipeline-parallelism-support";
      flake = false;
    };
    mlnx-ofed-nixos = {
      url = "github:codgician/mlnx-ofed-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia/legacy-v4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri.url = "github:sodiboo/niri-flake";

    nix-amd-ai.url = "github:noamsto/nix-amd-ai";
  };

  outputs =
    { ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      mkConfiguration =
        { system, modules }:
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./modules/common/base.nix ] ++ modules;

          specialArgs = {
            pkgs-stable = import inputs.nixpkgs-stable {
              inherit system;
              allowUnfree = true;
            };

            flake-inputs = inputs // {
              inherit system;
            };
          };
        };

      nixosConfigurations = {

        battle-bucket = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/battle-bucket/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        big-nix = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/big-nix/configuration.nix
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };
        hot-rod = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/hot-rod/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        thunder-budget-1 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-1/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        thunder-budget-2 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-2/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };
        thunder-budget-3 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-3/configuration.nix
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        thunder-budget-4 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-4/configuration.nix
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        arid-wind = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/arid-wind/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        fatman-1 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-1/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };
        fatman-2 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-2/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
            # Add packages from this repo and set up binary cache
            inputs.mlnx-ofed-nixos.nixosModules.setupCacheAndOverlays
          ];
        };

        fatman-3 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-3/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };
        fatman-4 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-4/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        king-blue = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/blue/king-blue/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        queen-blue = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/blue/queen-blue/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };

        cursed-steel = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/cursed-steel/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.nixos-hardware.nixosModules.common-cpu-amd
            inputs.nixos-hardware.nixosModules.common-gpu-nvidia
            inputs.nixos-hardware.nixosModules.common-pc-laptop
            inputs.nixos-hardware.nixosModules.common-pc-ssd
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };
      };

      allHostNames = builtins.attrNames nixosConfigurations;

    in
    {
      inherit nixosConfigurations;

      lib = {
        nixosHostNames = allHostNames;
      };
      homeConfigurations = {
        branden = inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            flake-inputs = inputs // {
              inherit system;
            };
            pkgs-stable = import inputs.nixpkgs-stable {
              inherit system;
              config.allowUnfree = true;
            };
          };

          modules = [
            ./users/branden/home/home.nix
            {
              targets.genericLinux.enable = true;

              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.nvidia.acceptLicense = true;
              targets.genericLinux.gpu.nvidia = {
                enable = true;
                version = "595.71.05";
                sha256 = "sha256-NiA7iWC35JyKQva6H1hjzeNKBek9KyS3mK8G3YRva4I=";
              };
            }
          ];
        };
      };
    };
}
