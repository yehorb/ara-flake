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
      crossSystem = {
        config = "riscv64-unknown-none-elf";
        libc = "newlib";
        useLLVM = true;
        isStatic = true;
      };
    in
    {
      pkgs = forEachSystem (
        system:
        import nixpkgs {
          localSystem = {
            inherit system;
          };
          config = { };
        }
      );
      pkgsCross = forEachSystem (
        system:
        import nixpkgs {
          localSystem = {
            inherit system;
          };
          inherit crossSystem;
          config = {
            stdenvRoot = "${nixpkgs}/pkgs/stdenv";
          };
          stdenvStages = import ./pkgs/stdenv/cross;
        }
      );

      devShells = forEachSystem (system: {
        default =
          let
            pkgs = self.pkgs.${system};
            pkgsCross = self.pkgsCross.${system};
            stdenv = pkgsCross.stdenv;
          in
          pkgsCross.mkShell {
            hardeningDisable = [ "all" ];
            packages = [
              pkgs.spike
            ];
            env = {
              RISCV_TARGET = crossSystem.config;
              LLVM_INSTALL_DIR = stdenv.cc;
              RISCV_PREFIX = "${stdenv.cc}/bin/";
              RISCV_SIM = pkgs.lib.meta.getExe' pkgs.spike "spike";
            };
            shellHook = ''
              export PS1="(ara) $PS1"
            '';
          };
      });
    };
}
