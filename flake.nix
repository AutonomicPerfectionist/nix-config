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

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-cli.url = "github:nix-community/nixos-cli";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    sycl.url = "github:MordragT/nixos";
    llm-agents.url = "github:numtide/llm-agents.nix";
    llama-cpp-fork = {
      url = "github:rgerganov/llama.cpp/rpc-async";
      flake = false;
    };
  };

  outputs =
    { ... }@inputs:
    let
      mkConfiguration =
        { system, modules }:
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          inherit modules;

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

        hypergamma = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/hypergamma/configuration.nix
            inputs.agenix.nixosModules.default
          ];
        };

        goblin = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/goblin/configuration.nix
            inputs.agenix.nixosModules.default
          ];
        };

        aj-framework = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/aj-framework/configuration.nix
            inputs.nixos-hardware.nixosModules.framework-12th-gen-intel
          ];
        };

        lucy = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/lucy/configuration.nix
            inputs.agenix.nixosModules.default
          ];
        };

        battle-bucket = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/battle-bucket/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };

        big-nix = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/big-nix/configuration.nix
            inputs.agenix.nixosModules.default
          ];
        };

        thunder-budget-1 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-1/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };

        thunder-budget-2 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-2/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };
        thunder-budget-3 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-3/configuration.nix
            inputs.agenix.nixosModules.default
          ];
        };

        thunder-budget-4 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-4/configuration.nix
            inputs.agenix.nixosModules.default
          ];
        };

        arid-wind = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/arid-wind/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };

        fatman-1 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-1/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };
        fatman-2 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-2/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };

        fatman-3 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-3/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };
        fatman-4 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-4/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };

        king-blue = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/blue/king-blue/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
          ];
        };

        queen-blue = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/blue/queen-blue/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
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
    };
}
