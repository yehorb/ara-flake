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
            replaceCrossStdenv =
              { baseStdenv, ... }:
              baseStdenv.override (prevArgs: {
                cc = prevArgs.cc.overrideAttrs {
                  buildPhase = ''
                    echo "mark" > $out/myMark
                    echo "So, guys, we did it!" >> $out/nix-support/cc-cflags
                  '';
                };
              });
          };
          overlays = [ self.overlays.cross ];
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
      overlays.cross =
        final: prev:
        let
          withLlvmTargetLibraries = prev.llvmPackages.override {
            targetLlvmLibraries = prev.llvmPackages.libraries // {
              libunwind = "";
            };
          };
        in
        {
          llvmPackages = withLlvmTargetLibraries;
        };
    };
}
