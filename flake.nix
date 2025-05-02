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
            replaceCrossStdenv =
              { buildPackages, baseStdenv }:
              let
                withExtraBuildTools = baseStdenv.override (oldArgs: {
                  extraNativeBuildInputs = oldArgs.extraNativeBuildInputs ++ [
                    buildPackages.llvmPackages.lld
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
          default = pkgsCross.mkShell {
            hardeningDisable = [ "all" ];
            packages = [
              pkgs.spike
              pkgs.verilator
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
          compileHardware = pkgs.mkShell {
            buildInputs = [
              pkgs.verilator
              pkgs.spike
            ];
            env = {
              NIX_CFLAGS_COMPILE = pkgs.lib.strings.concatStringsSep " " [
                "-I${pkgs.verilator}/share/verilator/include/vltstd"
                "-I${pkgs.spike}/include"
                "-std=c++17"
              ];
              questa_cmd = "true;";
            };
            shellHook = ''
              export PS1="(ara-hardware) $PS1"
            '';
          };
        }
      );

      overlays.cross =
        final: prev:
        let
          libunwind = prev.llvmPackages.libraries.libunwind.override {
            devExtraCmakeFlags = [
              (final.lib.strings.cmakeBool "LIBUNWIND_IS_BAREMETAL" true)
              (final.lib.strings.cmakeBool "LIBUNWIND_ENABLE_THREADS" false)
            ];
          };
        in
        {
          llvmPackages = prev.llvmPackages.override {
            targetLlvmLibraries = prev.llvmPackages.libraries // {
              inherit libunwind;
            };
          };
        };
    };
}
