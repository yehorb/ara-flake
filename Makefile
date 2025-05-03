ARA_DIRECTORY ?= pulp-platform/ara

$(ARA_DIRECTORY):
	git clone https://github.com/pulp-platform/ara.git --branch v3.0 --depth=1 $(ARA_DIRECTORY)

checkout: $(ARA_DIRECTORY)

hardware-deps: $(ARA_DIRECTORY)
	cd $(ARA_DIRECTORY); \
		git submodule update --init --recursive -- hardware/deps

prepare-hardware: $(ARA_DIRECTORY) hardware-deps
	cd $(ARA_DIRECTORY); \
		git apply ../../patches/*; \
		cd deps/tech_cells_generic && git apply ../../patches/0001-tech-cells-generic-sram.patch

compile-hardware:
	nix develop .#compileHardware --command bash -c "cd $(ARA_DIRECTORY)/hardware; make compile"

app ?= bin/hello_world

compile-software:
	nix develop .#compileSoftware --command bash -c "cd $(ARA_DIRECTORY)/apps; make $(app)"

simc:
	nix develop .#compileHardware --command bash -c "cd $(ARA_DIRECTORY)/hardware; app=$(app) make simc"

clean: $(ARA_DIRECTORY)
	cd $(ARA_DIRECTORY); \
		rm -rf hardware/deps/*; \
		git clean . --force; \
		git reset HEAD --hard
