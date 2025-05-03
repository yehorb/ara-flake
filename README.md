# Ara

## Preparation

```bash
rm -rf pulp-platform/
make checkout
make hardware-deps
make prepare-hardware
```

## Build Applications

```bash
nix develop .#
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
app=hello_world questa_args="-suppress 8386,7033,3009 -ldflags $LDFLAGS" make simc
```

## Notes

Setting the `questa_cmd='true;'` just suppresses the warning Makefile produces otherwise.
`vsim` is invoked in the following way - `$(questa_cmd) vsim -c ...`. If the `questa_cmd` is not found or empty, the Makefile produces a warning.
`true;` is essentially a noop.
