ARA_DIRECTORY ?= pulp-platform/ara

$(ARA_DIRECTORY):
	git clone https://github.com/pulp-platform/ara.git --branch v3.0 --depth=1 $(ARA_DIRECTORY)

checkout: $(ARA_DIRECTORY)

hardware-deps: $(ARA_DIRECTORY)
	cd $(ARA_DIRECTORY); \
		git submodule update --init --recursive -- hardware/deps

# Setting the questa_cmd='true;' just suppresses the warning Makefile produces otherwise.
# `vsim` is the following way - `$(questa_cmd) vsim -c ...`.
# If the `questa_cmd` is not found or empty, the Makefile produces a warning.
# `true;` is essentially a noop.
compile-hardware:
	nix develop .#compileHardware --print-build-logs --command bash -c "cd $(ARA_DIRECTORY)/hardware; make compile"
