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
      packages = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { };
            overlays = [ self.overlays.default ];
          };
        in
        {
          pulp-riscv-gnu-toolchain =
            let
              base = inputs.pulpissimo.packages.${system}.pulp-riscv-gnu-toolchain.override {
                stdenv = pkgs.gcc9CcacheStdenv;
              };
            in
            base.overrideAttrs {
              configureFlags = [
                "--with-arch=rv64gcv"
                "--with-cmodel=medlow"
                "--enable-multilib"
              ];
            };
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { };
            overlays = [ self.overlays.default ];
          };
        in
        {
          default = { };
        }
      );

      overlays.default = final: prev: {
        ccacheWrapper = prev.ccacheWrapper.override {
          extraConfig = ''
            export CCACHE_COMPRESS=1
            export CCACHE_DIR=/nix/var/cache/ccache
            export CCACHE_UMASK=007
          '';
        };
        gcc9CcacheStdenv = final.ccacheStdenv.override { stdenv = prev.gcc9Stdenv; };
      };
    };
}
