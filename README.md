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
cd pulp-platform/ara/
cd hardware/
make apply-patches
make compile
```

### Simulation

```bash
app=hello_world questa_args="-suppress 8386,7033,3009 -ldflags $LDFLAGS" make simc
```
