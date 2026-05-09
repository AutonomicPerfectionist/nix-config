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

      # Ensure a single consistent Intel userspace stack across the system closure.
      # This does NOT modify kernel drivers, only Nixpkgs-level packages.
      intelOverlay = final: prev: {
        inherit (prev)
          level-zero
          intel-compute-runtime
          intel-graphics-compiler
          ;
      };

      # Ensure SYCL packages (notably llama-cpp-sycl) are built against the same pkgs set,
      # so they share Level Zero and compute runtime ABI.
      syclOverlay = final: prev: {
        llama-cpp-sycl = inputs.sycl.packages.${prev.system}.llama-cpp-sycl.overrideAttrs (old: {

          cmakeFlags = (old.cmakeFlags or [ ]) ++ [
            "-DGGML_RPC=ON"
          ];

          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.addDriverRunpath ];

          buildInputs = (old.buildInputs or [ ]) ++ [
            prev.level-zero
            prev.intel-compute-runtime
          ];

          postFixup = (old.postFixup or "") + ''
            for bin in $out/bin/*; do
              if [ -x "$bin" ] && file "$bin" | grep -q ELF; then
                addDriverRunpath "$bin"
              fi
            done
          '';
        });
      };

    in
    {
      nixosConfigurations = {

        hypergamma = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/hypergamma/configuration.nix
            inputs.agenix.nixosModules.default

            # Global pkgs consistency for SYCL + Intel stack
            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        goblin = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/goblin/configuration.nix
            inputs.agenix.nixosModules.default

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        aj-framework = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/aj-framework/configuration.nix
            inputs.nixos-hardware.nixosModules.framework-12th-gen-intel

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        lucy = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/lucy/configuration.nix
            inputs.agenix.nixosModules.default

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        big-nix = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/big-nix/configuration.nix
            inputs.agenix.nixosModules.default

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        thunder-budget-3 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-3/configuration.nix
            inputs.agenix.nixosModules.default

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        thunder-budget-4 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/thunder-budget/thunder-budget-4/configuration.nix
            inputs.agenix.nixosModules.default

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        arid-wind = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/arid-wind/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            (
              { ... }:
              {
                nixpkgs.overlays = [
                  (final: prev: {
                    llama-cpp-rocm = prev.llama-cpp-rocm.overrideAttrs (old: {
                      cmakeFlags = (old.cmakeFlags or [ ]) ++ [
                        "-DGGML_RPC=ON"
                      ];
                    });
                  })
                ];
              }
            )

          ];
        };

        fatman-3 = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/fatman/fatman-3/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        king-blue = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/blue/king-blue/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default

            # Required for SYCL + Intel stack coherence in system closure
            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };

        queen-blue = mkConfiguration {
          system = "x86_64-linux";
          modules = [
            ./hosts/blue/queen-blue/configuration.nix
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default

            (
              { ... }:
              {
                nixpkgs.overlays = [
                  intelOverlay
                  syclOverlay
                ];
              }
            )
          ];
        };
      };
    };
}
