{
  description = "ogmios";

  inputs = {
    haskell-nix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";

    # TODO: cleanup after cardano-node inputs are fixed
    cardano-node = {
      url = "github:input-output-hk/cardano-node/1.35.4";
      inputs.cardano-node-workbench.follows = "blank";
      inputs.node-measured.follows = "blank";
    };
    blank.url = "github:divnix/blank";

    # TODO: remove after new testnets land in cardano-node
    cardano-configurations = {
      url = "github:input-output-hk/cardano-configurations";
      flake = false;
    };

    iohk-nix = {
      url = "github:input-output-hk/iohk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    CHaP = {
      url = "github:input-output-hk/cardano-haskell-packages?ref=repo";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, haskell-nix, iohk-nix, CHaP, ... }@inputs:
    let
      defaultSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = nixpkgs.lib.genAttrs defaultSystems;

      nixpkgsFor = system: import nixpkgs {
        overlays = [ haskell-nix.overlay iohk-nix.overlays.crypto ];
        inherit (haskell-nix) config;
        inherit system;
      };

      # `static` enables cross-compilation with musl64 to produce a statically
      # linked `ogmios` executable
      projectFor = { system, static ? false }:
        let
          pkgs = nixpkgsFor system;
          src = ./.;
        in
        import ./nix {
          inherit src inputs pkgs system static;
          inputMap = {
            "https://input-output-hk.github.io/cardano-haskell-packages" = CHaP;
          };
        };

    in
    {
      flake = perSystem (system: (projectFor { inherit system; }).flake { });

      flake-static = perSystem (system:
        (projectFor { inherit system; static = true; }).flake { }
      );

      defaultPackage = perSystem (system:
        self.flake.${system}.packages."ogmios:exe:ogmios"
      );

      packages = perSystem (system:
        self.flake.${system}.packages // {
          ogmios-static =
            self.flake-static.${system}.packages."ogmios:exe:ogmios";
        }
      );

      apps = perSystem (system:
        self.flake.${system}.apps // {
          vm = {
            type = "app";
            program = "${self.nixosConfigurations.test.config.system.build.vm}/bin/run-nixos-vm";
          };
        });

      devShell = perSystem (system: self.flake.${system}.devShell);

      # Build all of the project's packages and run the `checks`
      check = perSystem (system:
        (nixpkgsFor system).runCommand "combined-check"
          {
            nativeBuildInputs =
              builtins.attrValues self.checks.${system}
              ++ builtins.attrValues self.flake.${system}.packages;
          } "touch $out"
      );

      # HACK
      # Only include `ogmios:test:unit` and just build/run that
      # We could configure this via haskell.nix, but this is
      # more convenient
      checks = perSystem (system: {
        inherit (self.flake.${system}.checks) "ogmios:test:unit";
      });

      nixosModules.ogmios = { pkgs, ... }: {
        imports = [ ./nix/ogmios-nixos-module.nix ];
        nixpkgs.overlays = [
          (_: _: {
            ogmios = self.flake.${pkgs.system}.packages."ogmios:exe:ogmios";
            inherit (inputs) cardano-configurations;
          })
        ];
      };

      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          inputs.cardano-node.nixosModules.cardano-node
          self.nixosModules.ogmios
          ./nix/test-nixos-configuration.nix
        ];
      };

      hydraJobs = {
        required = (nixpkgsFor "x86_64-linux").stdenv.mkDerivation {
          name = "required";
          buildInputs = [
            self.packages.x86_64-linux.ogmios-static
            self.defaultPackage.x86_64-linux
            self.devShell.x86_64-linux.buildInputs
            self.check.x86_64-linux
            self.nixosConfigurations.test.config.system.build.vm
          ];
          unpackPhase = "true";
          installPhase = "mkdir $out";
        };
      };
    };
}
