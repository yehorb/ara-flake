# Ara

## Preparation

```bash
rm -rf pulp-platform/
make checkout
make hardware-deps
cd pulp-platform/ara/
git apply ../../patches/*
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
