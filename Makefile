# Use bash as the shell for all recipe commands
export SHELL=/bin/bash

####################################################################################################
# PATH EXPORTS
####################################################################################################

# Absolute path to the workspace root
export ROOT_DIR=$(CURDIR)

# Absolute path to the RV32IMF submodule
export RV32IMF=$(ROOT_DIR)/submodule/rv32imf

####################################################################################################
# SIMULATION CONFIGURATION
####################################################################################################

# Read the top-level module name from build/top; default to "hello" if the file does not exist
TOP := $(shell cat build/top &> /dev/null || echo "hello")

# Set GUI=0 for headless simulation, any other value to open the Vivado waveform GUI
GUI ?= 0

# Simulation mode: GUI=0 runs headless (-runall), any other value opens the Vivado waveform GUI
ifeq ($(GUI), 0)
	SIM_ARGS := -runall
else
# Open xsim GUI and auto-load the matching .wcfg waveform configuration file
	SIM_ARGS := -gui --autoloadwcfg --view ../wcfg/$(TOP)_sim.wcfg
endif

# Get RV32IMF submodule commit hash only
RV32IMF_COMMIT := $(shell git submodule status -- $(RV32IMF) | awk '{print $$1}')

# Filter xvlog/xelab/xsim output to highlight only Errors and Warnings
EWHL := | grep -iE "Error:|Warning:|" --color=auto

####################################################################################################
# FILE DISCOVERY AND BUILD CONFIGURATION
####################################################################################################

# Start the file list with the include directory (passed as an include search path to xvlog)
FILE_LIST := -i $(CURDIR)/include

# Append all SystemVerilog source, interface, and testbench files discovered recursively
FILE_LIST += $(shell find $(ROOT_DIR)/source -type f -name "*.sv")
FILE_LIST += $(shell find $(ROOT_DIR)/interface -type f -name "*.sv")
FILE_LIST += $(shell find $(ROOT_DIR)/testbench -type f -name "*.sv")

####################################################################################################
# TOOLS
####################################################################################################

XVLOG ?= xvlog
XELAB ?= xelab
XSIM ?= xsim

####################################################################################################
# MAKE TARGETS
####################################################################################################

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

# Target to compile only the RV32IMF submodule sources, without running simulation. This is useful
# to speed up iterative development when the RV32IMF sources have not changed, as they take a long
# time to compile. The target checks if the RV32IMF submodule commit hash has changed since the last
# compilation, and only recompiles if it has changed. The commit hash is stored in
# build/rv32imf_commit.txt, and a temporary file build/current_rv32imf_commit.txt is used to compare
# the current commit hash with the last compiled one. If the commit hash has not changed, the target
# prints a message and skips recompilation. If it has changed, it compiles the RV32IMF sources with
# xvlog and updates the stored commit hash.
.PHONY: RV32IMF_COMPILE
RV32IMF_COMPILE:
	@make -s build
	@git submodule update --init --depth 1 $(RV32IMF)
	@touch build/rv32imf_commit.txt
	@echo "$(RV32IMF_COMMIT)" > build/current_rv32imf_commit.txt
	@if [ -f build/rv32imf_commit.txt ] && [ -f build/current_rv32imf_commit.txt ] && \
	     [ "$$(cat build/rv32imf_commit.txt)" = "$$(cat build/current_rv32imf_commit.txt)" ]; then \
		echo -e "\033[0;33mRV32IMF is already compiled for commit $(RV32IMF_COMMIT), skipping recompilation.\033[0m"; \
	else \
		cd build && xvlog -sv -f $(ROOT_DIR)/filelist/rv32imf.f $(EWHL); \
		echo -e "\033[0;33mRV32IMF compiled for commit $(RV32IMF_COMMIT).\033[0m"; \
	fi
	@echo "$(RV32IMF_COMMIT)" > build/rv32imf_commit.txt
	@rm -f build/current_rv32imf_commit.txt
