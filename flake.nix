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
      crossSystem = nixpkgs.lib.systems.examples.riscv64-embedded // {
        useLLVM = true;
        isStatic = true;
      };
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
      pkgsCross = forEachSystem (
        system:
        import nixpkgs {
          inherit system;
          inherit crossSystem;
          config = {
            replaceCrossStdenv = { buildPackages, baseStdenv }: baseStdenv;
          };
          crossOverlays = [ self.overlays.cross ];
        }
      );

      packages = forEachSystem (
        system:
        let
          pkgs = self.pkgsCross.${system};
        in
        {
          libunwind = pkgs.llvmPackages.libraries.libunwind.override {
            devExtraCmakeFlags = [
              (pkgs.lib.cmakeFeature "LLVM_HOST_TRIPLE" crossSystem.config)
              (pkgs.lib.cmakeFeature "LLVM_DEFAULT_TARGET_TRIPLE" crossSystem.config)
              (pkgs.lib.cmakeBool "LIBUNWIND_IS_BAREMETAL" true)
              (pkgs.lib.cmakeBool "LIBUNWIND_ENABLE_THREADS" false)
            ];
          };
        }
      );

      devShells = forEachSystem (system: {
        default =
          let
            pkgs = self.pkgs.${system};
            pkgsCross = self.pkgsCross.${system};
            stdenvCross = pkgsCross.stdenv;
          in
          pkgsCross.mkShell {
            hardeningDisable = [ "all" ];
            packages = [
              pkgs.spike
            ];
            env = {
              RISCV_TARGET = crossSystem.config;
              LLVM_INSTALL_DIR = stdenvCross.cc;
              RISCV_PREFIX = "${stdenvCross.cc}/bin/${crossSystem.config}-";
              RISCV_SIM = pkgs.lib.meta.getExe' pkgs.spike "spike";
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
      overlays.cross = final: prev: { };
    };
}
