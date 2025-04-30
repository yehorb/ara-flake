{
  inputs = {
    pulpissimo.url = "github:yehorb/pulpissimo-flake";
    nixpkgs.follows = "pulpissimo/nixpkgs";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      pkgs = forEachSystem (
        system:
        import nixpkgs {
          inherit system;
          config = { };
          overlays = [ self.overlays.default ];
        }
      );

      packages = forEachSystem (system: { });

      devShells = forEachSystem (system: {
        default =
          let
            pkgs = self.pkgs.${system};
            pkgsCross = import nixpkgs {
              inherit system;
              crossSystem = nixpkgs.lib.systems.examples.riscv64-embedded;
              config = { };
              overlays = [ self.overlays.default ];
            };
            stdenvCross = pkgsCross.clangStdenv;
          in
          pkgsCross.mkShell.override { stdenv = stdenvCross; } { };
      });

      overlays.default = final: prev: {
        ccacheWrapper = prev.ccacheWrapper.override {
          extraConfig = ''
            export CCACHE_COMPRESS=1
            export CCACHE_DIR=/var/cache/ccache
            export CCACHE_UMASK=007
          '';
        };
      };
    };
}
