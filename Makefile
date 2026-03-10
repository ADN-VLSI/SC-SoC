# Use bash as the shell for all recipe commands
export SHELL=/bin/bash

# Absolute path to the workspace root
ROOT_DIR := $(CURDIR)

# Read the top-level module name from build/top; default to "hello" if the file does not exist
TOP := $(shell cat build/top || echo "hello")

# Simulation mode: GUI=0 runs headless (-runall), any other value opens the Vivado waveform GUI
ifeq ($(GUI), 0)
	SIM_ARGS := -runall
else
# Open xsim GUI and auto-load the matching .wcfg waveform configuration file
	SIM_ARGS := -gui --autoloadwcfg --view ../wcfg/$(TOP)_sim.wcfg
endif

# Start the file list with the include directory (passed as an include search path to xvlog)
FILE_LIST := -i $(CURDIR)/include

# Append all SystemVerilog source, interface, and testbench files discovered recursively
FILE_LIST += $(shell find $(ROOT_DIR)/source -type f -name "*.sv")
FILE_LIST += $(shell find $(ROOT_DIR)/interface -type f -name "*.sv")
FILE_LIST += $(shell find $(ROOT_DIR)/testbench -type f -name "*.sv")

# Filter xvlog/xelab/xsim output to highlight only Errors and Warnings
EWHL := | grep -iE "Error:|Warning:|" --color=auto

# Create the build output directory and add a .gitignore so its contents are not tracked by git
build:
	@echo "Creating build directory..."
	@mkdir build
	@echo "*" > build/.gitignore

# Remove the entire build directory and all generated artifacts
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	@rm -rf build

# Full build-and-simulate flow:
#   1. Clean any previous build artifacts
#   2. Re-create the build directory
#   3. Persist the target top module name
#   4. Compile all SV sources with xvlog
#   5. Elaborate the design with xelab (optimisation off, full debug info)
#   6. Simulate with xsim (headless or GUI depending on the GUI variable)
.PHONY: all
all:
	@make -s clean
	@make -s build
	@echo "$(TOP)" > build/top
	@cd build && xvlog -sv $(FILE_LIST) $(EWHL)
	@cd build && xelab $(TOP) -s $(TOP)_sim --O0 -debug all $(EWHL)
	@cd build && xsim $(TOP)_sim $(SIM_ARGS) $(EWHL)
