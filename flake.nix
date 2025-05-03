{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    pulpissimo.url = "github:yehorb/pulpissimo-flake";
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
            replaceCrossStdenv =
              { buildPackages, baseStdenv }:
              let
                withExtraBuildTools = baseStdenv.override (oldArgs: {
                  extraNativeBuildInputs = oldArgs.extraNativeBuildInputs ++ [
                    buildPackages.llvmPackages.bintoolsNoLibc
                  ];
                });
                withBasicCC = buildPackages.overrideCC withExtraBuildTools buildPackages.llvmPackages.clangWithLibcAndBasicRt;
              in
              withBasicCC;
          };
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = self.pkgs.${system};
          pkgsCross = self.pkgsCross.${system};
        in
        {
          default = self.devShells.${system}.compileSoftware;
          compileSoftware = pkgsCross.mkShell {
            hardeningDisable = [ "all" ];
            packages = [
              pkgs.spike
              (pkgs.python312.withPackages (pythonPkgs: [ pythonPkgs.numpy ]))
            ];
            env = {
              RISCV_TARGET = crossSystem.config;
              RISCV_PREFIX = "${crossSystem.config}-";
              RISCV_SIM = pkgs.lib.meta.getExe' pkgs.spike "spike";
              questa_cmd = "true;";
            };
            shellHook = ''
              export PS1="(ara) $PS1"
            '';
          };
          compileHardware =
            let
              bender = inputs.pulpissimo.packages.${system}.bender;
              stdenv = pkgs.gcc10Stdenv;
            in
            pkgs.mkShell.override { inherit stdenv; } {
              hardeningDisable = [ "all" ];
              buildInputs = [
                pkgs.verilator
                pkgs.spike
                stdenv.cc.libc_lib
              ];
              packages = [
                bender
              ];
              env = {
                NIX_CFLAGS_COMPILE = pkgs.lib.strings.concatStringsSep " " [
                  "-I${pkgs.verilator}/share/verilator/include/vltstd"
                  "-I${pkgs.spike}/include"
                  "-std=c++17"
                ];
                BENDER = pkgs.lib.meta.getExe bender;
                questa_cmd = "true;";
                questa_args = "-cpppath ${pkgs.lib.meta.getExe stdenv.cc} -suppress 8386,7033,3009";
              };
              shellHook = ''
                export PS1="(ara-hardware) $PS1"
              '';
            };
        }
      );
    };
}
