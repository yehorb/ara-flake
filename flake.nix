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

      packages = forEachSystem (system: {
        riscv-gnu-toolchain-source = self.pkgs.${system}.fetchgit {
          url = "https://github.com/riscv-collab/riscv-gnu-toolchain";
          rev = "a33dac0251d17a7b74d99bd8fd401bfce87d2aed";
          hash = "sha256-aCCjuQreHThX9UwaObvx8HS60TOxf8codqJRJhThxe8=";
          fetchSubmodules = true;
        };
      });

      devShells = forEachSystem (system: { });

      overlays.default = final: prev: {
        ccacheWrapper = prev.ccacheWrapper.override {
          extraConfig = ''
            export CCACHE_COMPRESS=1
            export CCACHE_DIR=/var/cache/ccache
            export CCACHE_UMASK=007
          '';
        };
        gcc9CcacheStdenv = final.ccacheStdenv.override { stdenv = prev.gcc9Stdenv; };
      };
    };
}
