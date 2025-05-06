{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    pulpissimo.url = "github:yehorb/pulpissimo-flake";
    nixpkgs-verilator_5_012.url = "github:nixos/nixpkgs/9957cd48326fe8dbd52fdc50dd2502307f188b0d";
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
          bender = inputs.pulpissimo.packages.${system}.bender;
        in
        {
          default = self.devShells.${system}.apps;
          apps = pkgsCross.mkShell {
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
              export PS1="(ara-cross) $PS1"
            '';
          };
          vsim =
            let
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
                export PS1="(ara-vsim) $PS1"
              '';
            };
          verilator =
            let
              # Grab an older version of Verilator, as the current one has breaking changes
              verilator =
                (import inputs.nixpkgs-verilator_5_012 {
                  localSystem = {
                    inherit system;
                  };
                  config = { };
                }).verilator;
              stdenv = pkgs.llvmPackages.stdenv;
            in
            pkgs.mkShell.override { inherit stdenv; } {
              hardeningDisable = [ "all" ];
              packages = [
                bender
                verilator
              ];
              env = {
                BENDER = pkgs.lib.meta.getExe bender;
                questa_cmd = "true;";
                veril_path = "${verilator}/bin";
                # Make Verilator aware of Verilator? For some reason it does not work otherwise
                VERILATOR_BIN = pkgs.lib.meta.getExe' verilator "verilator";
              };
              shellHook = ''
                export PS1="(ara-verilator) $PS1"
              '';
            };
        }
      );
    };
}
