# Ara

## Nix : the package manager

The environment for compilation and simulation is set up using the Nix package manager.

Please refer to <https://nixos.org/download/> for installation instructions.

## One Line

You can prepare and run the Questa RTL simulation in one command:

```bash
make clean prepare-hardware compile-hardware compile-software simc
```

To select the specific app set the `app=<name>` variable before `make` invocation:

```bash
app=dotproduct make clean prepare-hardware compile-hardware compile-software simc
```

## Preparation

```bash
rm -rf pulp-platform/
make checkout
make hardware-deps
make prepare-hardware
```

## Build Applications

```bash
nix develop .#compileSoftware
cd pulp-platform/ara/apps/
make bin/hello_world
```

## RTL Simulation

### Preparation

```bash
nix develop .#compileHardware
cd pulp-platform/ara/hardware/
make apply-patches
make compile
```

### Simulation

```bash
nix develop .#compileHardware
cd pulp-platform/ara/hardware/
app=hello_world make simc
```

## Notes

Setting the `questa_cmd='true;'` just suppresses the warning Makefile produces otherwise.
`vsim` is invoked in the following way - `$(questa_cmd) vsim -c ...`. If the `questa_cmd` is not found or empty, the Makefile produces a warning.
`true;` is essentially a noop.
