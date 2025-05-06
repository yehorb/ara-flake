ARA_DIRECTORY ?= pulp-platform/ara

$(ARA_DIRECTORY):
	git clone https://github.com/pulp-platform/ara.git --branch v3.0 --depth=1 $(ARA_DIRECTORY)

checkout: $(ARA_DIRECTORY)

checkout-deps: $(ARA_DIRECTORY)
	cd $(ARA_DIRECTORY); \
	git submodule update --init --recursive -- hardware/deps

apply-patches: $(ARA_DIRECTORY) checkout-deps
	cd $(ARA_DIRECTORY); \
	git apply ../../patches/*; \
	cd hardware; \
	cd deps/tech_cells_generic && git apply ../../patches/0001-tech-cells-generic-sram.patch

compile:
	nix develop .#vsim --command bash -c "cd $(ARA_DIRECTORY)/hardware; make compile"

verilate:
	nix develop .#verilator --command bash -c "cd $(ARA_DIRECTORY)/hardware; make verilate"

app ?= hello_world

apps:
	nix develop .#apps --command bash -c "cd $(ARA_DIRECTORY)/apps; make $(app)"

simc:
	app=$(app) $(MAKE) -C $(ARA_DIRECTORY)/hardware simc

simv:
	app=$(app) $(MAKE) -C $(ARA_DIRECTORY)/hardware simv

.PHONY: clean
clean: $(ARA_DIRECTORY)
	cd $(ARA_DIRECTORY); \
	rm -rf hardware/deps/*; \
	rm -rf hardware/build/*; \
	git clean . --force; \
	git reset HEAD --hard
