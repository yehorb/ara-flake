{
  lib,
  localSystem,
  crossSystem,
  config,
  overlays,
  crossOverlays ? [ ],
}:

# As the `../.` in the flake context does not actually lead to the
# `pkgs/stdenv/default.nix`, we need to pass it as an argument, which actually
# points to the relevant directory. So the whole initialization makes a detour
# into this flake, and then returns to the `nixpkgs`
#
# ```text
# +-------+                                               +---------------+                               +---------+
# | flake |                                               | stdenvStages  |                               | nixpkgs |
# +-------+                                               +---------------+                               +---------+
#     |                                                           |                                            |
#     | The location of the nixpkgs/pkgs/stdenv directory         |                                            |
#     |---------------------------------------------------------->|                                            |
#     |                                                           |                                            |
#     | import nixpkgs { config = { ... } }                       |                                            |
#     |------------------------------------------------------------------------------------------------------->|
#     |                                                           |                                            |
#     |                                                           |                  Use provided stdenvStages |
#     |                                                           |<-------------------------------------------|
#     |                                                           |                                            |
#     |                                                           | Use the nixpkgs/pkgs/stdenv directory      |
#     |                                                           |------------------------------------------->|
#     |                                                           |                                            |
#     |                                                          nixpkgs initialized using custom stdenvStages |
#     |<-------------------------------------------------------------------------------------------------------|
#     |                                                           |                                            |
# ```

let
  # config.stdenvRoot is the location of the `pkgs/stdenv` directory
  bootStages = import config.stdenvRoot {
    inherit lib localSystem overlays;

    crossSystem = localSystem;
    crossOverlays = [ ];

    # Ignore custom stdenvs when cross compiling for compatibility
    # Use replaceCrossStdenv instead.
    config = builtins.removeAttrs config [ "replaceStdenv" ];
  };
  llvmSystem = localSystem // {
    useLLVM = true;
    linker = "lld";
  };
in
lib.init bootStages
++ [

  # Regular native packages
  (
    somePrevStage:
    lib.last bootStages somePrevStage
    // {
      # It's OK to change the built-time dependencies
      allowCustomOverrides = true;
    }
  )

  # Inject LLVM build environment to build Build tool Packages with
  (
    nativePkgs:
    let
    in
    {
      inherit config overlays;
      selfBuild = true; # Target build platform
      stdenv =
        assert nativePkgs.stdenv.buildPlatform == localSystem;
        assert nativePkgs.stdenv.hostPlatform == localSystem;
        assert nativePkgs.stdenv.targetPlatform == localSystem;
        nativePkgs.stdenv.override {
          buildPlatform = llvmSystem;
          hostPlatform = llvmSystem;
          targetPlatform = llvmSystem;
        };
    }
  )

  # Build tool Packages
  (vanillaPackages: {
    inherit config overlays;
    selfBuild = false;
    stdenv = vanillaPackages.stdenv.override { targetPlatform = crossSystem; };
    # It's OK to change the built-time dependencies
    allowCustomOverrides = true;
  })

  # Run Packages
  (
    buildPackages:
    let
      adaptStdenv = if crossSystem.isStatic then buildPackages.stdenvAdapters.makeStatic else lib.id;
      stdenvNoCC = adaptStdenv (
        buildPackages.stdenv.override (old: rec {
          buildPlatform = llvmSystem;
          hostPlatform = crossSystem;
          targetPlatform = crossSystem;

          # Prior overrides are surely not valid as packages built with this run on
          # a different platform, and so are disabled.
          overrides = _: _: { };
          extraBuildInputs = [ ]; # Old ones run on wrong platform
          allowedRequisites = null;

          cc = null;
          hasCC = false;

          extraNativeBuildInputs =
            old.extraNativeBuildInputs
            ++ lib.optionals (hostPlatform.isLinux && !buildPlatform.isLinux) [ buildPackages.patchelf ]
            ++ lib.optional (
              let
                f =
                  p:
                  !p.isx86
                  || builtins.elem p.libc [
                    "musl"
                    "wasilibc"
                    "relibc"
                  ]
                  || p.isiOS
                  || p.isGenode;
              in
              f hostPlatform && !(f buildPlatform)
            ) buildPackages.updateAutotoolsGnuConfigScriptsHook;
        })
      );
    in
    {
      inherit config;
      overlays = overlays ++ crossOverlays;
      selfBuild = false;
      inherit stdenvNoCC;
      stdenv =
        let
          inherit (stdenvNoCC) hostPlatform targetPlatform;
          baseStdenv = stdenvNoCC.override {
            # Old ones run on wrong platform
            extraBuildInputs = lib.optionals hostPlatform.isDarwin [
              buildPackages.targetPackages.apple-sdk
            ];

            hasCC = !stdenvNoCC.targetPlatform.isGhcjs;

            cc =
              if crossSystem.useiOSPrebuilt or false then
                buildPackages.darwin.iosSdkPkgs.clang
              else if crossSystem.useAndroidPrebuilt or false then
                buildPackages."androidndkPkgs_${crossSystem.androidNdkVersion}".clang
              else if
                targetPlatform.isGhcjs
              # Need to use `throw` so tryEval for splicing works, ugh.  Using
              # `null` or skipping the attribute would cause an eval failure
              # `tryEval` wouldn't catch, wrecking accessing previous stages
              # when there is a C compiler and everything should be fine.
              then
                throw "no C compiler provided for this platform"
              else if crossSystem.isDarwin then
                buildPackages.llvmPackages.libcxxClang
              else if crossSystem.useLLVM or false then
                buildPackages.llvmPackages.clang
              else if crossSystem.useZig or false then
                buildPackages.zig.cc
              else if crossSystem.useArocc or false then
                buildPackages.arocc
              else
                buildPackages.gcc;

          };
        in
        if config ? replaceCrossStdenv then
          config.replaceCrossStdenv { inherit buildPackages baseStdenv; }
        else
          baseStdenv;
    }
  )

]
