{ src
, inputs
, pkgs
, static
, inputMap
, ...
}:

let
  musl64 = pkgs.pkgsCross.musl64;

  pkgSet = if static then musl64 else pkgs;

  project = {
    inherit src inputMap;

    name = "ogmios";

    compiler-nix-name = "ghc8107";

    shell = {
      inputsFrom = [ pkgs.libsodium-vrf ];

      # Make sure to keep this list updated after upgrading git dependencies!
      additional = ps: with ps; [
        cardano-api
        cardano-binary
        cardano-crypto-class
        cardano-crypto-praos
        cardano-crypto-tests
        cardano-slotting
        strict-containers
        cardano-prelude
        contra-tracer
        iohk-monitoring
        io-classes
        io-sim
        ouroboros-consensus
        ouroboros-consensus-byron
        ouroboros-consensus-byronspec
        ouroboros-consensus-shelley
        ouroboros-consensus-cardano
        ouroboros-consensus-cardano-test
        ouroboros-network
        ouroboros-network-framework
        typed-protocols
        typed-protocols-cborg
        flat
        hjsonpointer
        hjsonschema
        wai-routes
      ];

      withHoogle = true;

      tools = {
        cabal = "latest";
        haskell-language-server = "latest";
      };

      exactDeps = true;

      nativeBuildInputs = [ pkgs.libsodium-vrf ];
    };

    modules = [{
      packages = {
        cardano-crypto-praos.components.library.pkgconfig =
          pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
        cardano-crypto-class.components.library.pkgconfig =
          pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
      } // pkgs.lib.mkIf static {
        ogmios.components.exes.ogmios.configureFlags = pkgs.lib.optionals
          musl64.stdenv.hostPlatform.isMusl [
          "--disable-executable-dynamic"
          "--disable-shared"
          "--ghc-option=-optl=-pthread"
          "--ghc-option=-optl=-static"
          "--ghc-option=-optl=-L${musl64.gmp6.override { withStatic = true; }}/lib"
          "--ghc-option=-optl=-L${musl64.zlib.override { static = true; }}/lib"
        ];
      };
    }];

  };
in
pkgSet.haskell-nix.cabalProject project
