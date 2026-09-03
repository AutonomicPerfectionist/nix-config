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

        hugo-torso = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/hugo-torso/configuration.nix
            inputs.agenix.nixosModules.default
            inputs.comin.nixosModules.comin
            ./modules/comin.nix
          ];
        };
      };

      allHostNames = builtins.attrNames nixosConfigurations;

      # Factory for standalone (non-NixOS) home-manager configurations.
      # Add one entry per machine to homeConfigurations below.
      #
      # Arguments:
      #   graphical   — import niri + noctalia modules and config (default true)
      #   nvidia      — attrset passed to targets.genericLinux.gpu.nvidia, or
      #                 null to skip (default null); set version + sha256 to
      #                 match the driver installed by the host OS
      #   llamaBackend — "cpu" | "cuda" | "rocm" | "sycl" (default "cpu")
      mkHomeConfig =
        {
          graphical ? true,
          nvidia ? null,
          llamaBackend ? "cpu",
        }:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            flake-inputs = inputs // { inherit system; };
            pkgs-stable = import inputs.nixpkgs-stable {
              inherit system;
              config.allowUnfree = true;
            };
            userConfiguration = {
              enable    = true;
              graphical = graphical;
            };
          };

          modules =
            [ ./users/branden/home/home.nix ]
            ++ pkgs.lib.optionals graphical [
              inputs.niri.homeModules.niri
              inputs.noctalia.homeModules.default
            ]
            ++ [
              {
                targets.genericLinux.enable = true;
                nixpkgs.config.allowUnfree = true;
                nixpkgs.config.nvidia.acceptLicense = true;
                services.llama.backend = llamaBackend;
                services.llama.enableHomePackage = true;
              }
            ]
            ++ pkgs.lib.optionals (nvidia != null) [
              { targets.genericLinux.gpu.nvidia = nvidia; }
            ];
        };

    in
    {
      inherit nixosConfigurations;

      lib = {
        nixosHostNames = allHostNames;
      };

      # Standalone home-manager configurations — one entry per non-NixOS machine.
      # Run:  home-manager switch -b backup --flake ~/.nix#"branden@<hostname>"
      homeConfigurations = {
        "branden@ryzen-desktop" = mkHomeConfig {
          graphical    = true;
          llamaBackend = "cuda";
          nvidia = {
            enable  = true;
            version = "595.71.05";
            sha256  = "sha256-NiA7iWC35JyKQva6H1hjzeNKBek9KyS3mK8G3YRva4I=";
          };
        };

        # Template for additional machines — copy, rename, and adjust:
        # "branden@other-machine" = mkHomeConfig {
        #   graphical    = true;
        #   llamaBackend = "cuda";
        #   nvidia = {
        #     enable  = true;
        #     version = "570.xx.xx";
        #     sha256  = "sha256-...";
        #   };
        # };
      };
    };
}
