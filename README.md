# Ara

## Nix : the package manager

The environment for compilation and simulation is set up using the Nix package manager.

Please refer to <https://nixos.org/download/> for installation instructions.

You will also need to enable flakes. The `nix` command will notify you if flakes are not enabled. Please refer to <https://nixos.wiki/wiki/Flakes> for instructions.

## One Line

You can prepare and run the Questa RTL simulation in one command:

```bash
make clean checkout-deps apply-patches compile apps simc
```

To select the specific app set the `app=<name>` variable before `make` invocation:

```bash
app=dotproduct make clean checkout-deps apply-patches compile apps simc
```

## Preparation

```bash
rm -rf pulp-platform/
make checkout
make checkout-deps
make apply-patches
```

## Build Applications

```bash
nix develop .#apps
cd pulp-platform/ara/apps/
make bin/hello_world
```

## RTL Simulation

### Preparation

```bash
nix develop .#vsim
cd pulp-platform/ara/hardware/
make compile
```

### Simulation

```bash
nix develop .#vsim
cd pulp-platform/ara/hardware/
app=hello_world make simc
```

### Verilator

#### Preparation

```bash
nix dvelop .#verilator
cd pulp-platform/ara/hardware/
make verilate
```

Or:

```bash
make clean checkout-deps apply-patches verilate
```

#### Simulation

```bash
app=dotproduct make apps simv
```

## Notes

Setting the `questa_cmd='true;'` just suppresses the warning Makefile produces otherwise.
`vsim` is invoked in the following way - `$(questa_cmd) vsim -c ...`. If the `questa_cmd` is not found or empty, the Makefile produces a warning.
`true;` is essentially a noop.
