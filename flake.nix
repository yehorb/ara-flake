{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            crossSystem = nixpkgs.lib.systems.examples.riscv64-embedded;
            pkgsCross = import nixpkgs {
              inherit system;
              inherit crossSystem;
              config = { };
              overlays = [ self.overlays.default ];
            };
            stdenvCross = pkgsCross.clangStdenv;
          in
          pkgsCross.mkShell.override { stdenv = stdenvCross; } {
            hardeningDisable = [ "all" ];
            env = {
              RISCV_TARGET = crossSystem.config;
              LLVM_INSTALL_DIR = stdenvCross.cc;
              RISCV_PREFIX = "${stdenvCross.cc}/bin/${crossSystem.config}-";
            };
            shellHook = ''
              export PS1="(ara) $PS1"
            '';
          };
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
