# Use bash as the shell for all recipe commands
export SHELL=/bin/bash

####################################################################################################
# PATH EXPORTS
####################################################################################################

# Absolute path to the workspace root
export SC_SOC=$(CURDIR)

# Absolute path to the RV32IMF submodule
export RV32IMF=$(SC_SOC)/submodule/rv32imf

####################################################################################################
# CONFIGURATION
####################################################################################################

# Read the top-level module name from build/top; default to "hello" if the file does not exist
TOP := $(shell cat build/top &> /dev/null || echo "hello")

# Sets the test name for the simulation
TEST ?= default

# Set GUI=0 for headless simulation, any other value to open the Vivado waveform GUI
GUI ?= 0

# Simulation mode: GUI=0 runs headless (-runall), any other value opens the Vivado waveform GUI
ifeq ($(GUI), 0)
	SIM_ARGS += -runall
else
# Open xsim GUI and auto-load the matching .wcfg waveform configuration file
	SIM_ARGS += -gui --autoloadwcfg --view ../wcfg/$(TOP).wcfg
endif

COV ?= 0
CC_COV ?= 0

ifeq ($(COV), 1)
ifeq ($(CC_COV), 1)
	XELAB_FLAGS += --cc_type -sbc
endif
endif

ifeq ($(COV), 1)
ifeq ($(CC_COV), 1)
	XCRG_FLAGS += -cc_db $(TOP) -cc_fullfile -cc_report cc_report
endif
endif

# Get RV32IMF submodule commit hash only
RV32IMF_COMMIT := $(shell git submodule status -- $(RV32IMF) | awk '{print $$1}')

# Filter xvlog/xelab/xsim output to highlight only Errors and Warnings
EWHL := | grep -iE "Error:|Warning:|" --color=auto

# Define XVLOG_DEFS
XVLOG_DEFS += -d SIMULATION

####################################################################################################
# FILE DISCOVERY AND BUILD CONFIGURATION
####################################################################################################

# Start the file list with the include directory (passed as an include search path to xvlog)
FILE_LIST := -i $(CURDIR)/include

# Append all SystemVerilog source, interface, and testbench files discovered recursively
FILE_LIST += $(shell find $(SC_SOC)/source -type f -name "*.sv")
FILE_LIST += $(shell find $(SC_SOC)/interface -type f -name "*.sv")
FILE_LIST += $(shell find $(SC_SOC)/testbench -type f -name "*.sv")

SHA_ARGS += $$(find include/ -type f)
SHA_ARGS += $$(find interface/ -type f)
SHA_ARGS += $$(find source/ -type f)
# SHA_ARGS += $$(find package/ -type f) # TODO: add package directory if it is used in the future
SHA_ARGS += $$(find testbench/ -type f)

####################################################################################################
# TOOLS
####################################################################################################

XVLOG ?= xvlog
XELAB ?= xelab
XSIM ?= xsim
XCRG ?= xcrg

####################################################################################################
# MAKE TARGETS
####################################################################################################

# Create the build output directory and add a .gitignore so its contents are not tracked by git
build:
	@echo "Creating build directory..."
	@mkdir build
	@echo "*" > build/.gitignore

log:
	@echo "Creating log directory..."
	@mkdir -p log
	@echo "*" > log/.gitignore

coverage_report:
	@mkdir -p coverage_report
	@echo "*" > coverage_report/.gitignore

# Remove the entire build directory and all generated artifacts
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	@rm -rf build

.PHONY: clean_full
clean_full:
	@make -s clean
	@rm -rf log
	@rm -rf coverage_report

##################################################
# SC_SOC
##################################################

.PHONY: match_sha
match_sha:
	@sha256sum ${SHA_ARGS} > build/build_$(TOP)_new
	@touch build/build_$(TOP)
	@diff build/build_$(TOP)_new build/build_$(TOP) || make -s __ENV_BUILD__ TOP=$(TOP)

.PHONY: __COMPILE__
__COMPILE__:
	@make -s build
	@echo -e "\033[3;35mCompiling...\033[0m"
	@make -s RV32IMF_COMPILE
	@echo "-i ${SC_SOC}/include" > build/flist
# 	@$(foreach file, $(PACKAGE_LIST), echo -e $(file) >> build/flist;) # TODO
	@find ${SC_SOC}/interface -type f >> build/flist
	@find ${SC_SOC}/source -type f >> build/flist
	@find ${SC_SOC}/testbench -type f >> build/flist
	@cd build; $(XVLOG) -sv -f flist $(XVLOG_DEFS) --nolog $(EWHL)
	@echo -e "\033[3;35mCompiled\033[0m"

.PHONY: __ELABORATE__
__ELABORATE__:
	@echo -e "\033[3;35mElaborating $(TOP)...\033[0m"
	@cd build; $(XELAB) $(TOP) --O0 $(XELAB_FLAGS) --nolog $(EWHL)
	@echo -e "\033[3;35mElaborated $(TOP)\033[0m"
	@sha256sum ${SHA_ARGS} > build/build_$(TOP)

.PHONY: __ENV_BUILD__
__ENV_BUILD__:
	@make -s __COMPILE__
	@make -s __ELABORATE__

.PHONY: CHK_BUILD
CHK_BUILD:
	@if [ ! -f build/build_$(TOP) ]; then                    \
		echo -e "\033[3;33mEnvironment not built...\033[0m";   \
		make -s __ENV_BUILD__ TOP=$(TOP);                      \
	else                                                     \
		echo -e "\033[3;33mChecking sha256sum...\033[0m";      \
		make -s match_sha TOP=$(TOP);                          \
	fi

.PHONY: common_sim_checks
common_sim_checks:
	@echo "--testplusarg TEST=$(TEST)" > build/xsim_args
	@echo "--testplusarg DEBUG=$(DEBUG)" >> build/xsim_args

.PHONY: simulate
simulate:
	@make -s log
	@make -s CHK_BUILD TOP=$(TOP)
	@make -s common_sim_checks
	@echo -e "\033[3;35mSimulating $(TOP) $(TEST)...\033[0m"
	@$(eval log_file_name := $(shell echo "$(TOP)_$(TEST).txt" | sed "s/\//___/g"))
	@cd build; $(XSIM) $(TOP) -f xsim_args $(SIM_ARGS) -log ../log/$(log_file_name)
	@echo -e "\033[3;35mSimulated $(TOP) $(TEST)\033[0m"
ifeq ($(COV), 1)
	@make -s coverage_report
	@echo -e "\033[3;35mGenerating Coverage Report $(TOP)...\033[0m"
	@cd build; $(XCRG) $(XCRG_FLAGS) -report_format html --nolog -cov_db_name work.$(TOP)
	@echo -e "\033[3;35mGenerated Coverage Report $(TOP)\033[0m"
	@mv build/xsim_coverage_report/functionalCoverageReport coverage_report/$(TOP)_$(TEST)_fc
ifeq ($(CC_COV), 1)
	@mv build/cc_report/codeCoverageReport coverage_report/$(TOP)_$(TEST)_cc
endif
endif

##################################################
# RV32IMF
##################################################

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
		cd build && $(XVLOG) -sv -f $(SC_SOC)/filelist/rv32imf.f $(EWHL); \
		echo -e "\033[0;33mRV32IMF compiled for commit $(RV32IMF_COMMIT).\033[0m"; \
	fi
	@echo "$(RV32IMF_COMMIT)" > build/rv32imf_commit.txt
	@rm -f build/current_rv32imf_commit.txt
