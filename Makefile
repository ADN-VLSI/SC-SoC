# Use bash as the shell for all recipe commands
export SHELL=/bin/bash

.DEFAULT_GOAL := help

####################################################################################################
# PATH EXPORTS
####################################################################################################

# Absolute path to the workspace root
export SC_SOC=$(CURDIR)

# Absolute path to the RV32IMF submodule
export APB=$(SC_SOC)/submodule/apb
export AXI=$(SC_SOC)/submodule/axi
export COMMON_CELLS=$(SC_SOC)/submodule/common_cells
export RV32IMF=$(SC_SOC)/submodule/rv32imf
export SOC=$(SC_SOC)/submodule/SoC
export S1=$(SC_SOC)/submodule/S1

# Absolute paths to the build and log output directories. The build directory contains all generated
# simulation snapshots and intermediate files, while the log directory contains all simulation logs.
export BUILD=$(SC_SOC)/build
export LOG=$(SC_SOC)/log
export COVERAGE=$(SC_SOC)/coverage

####################################################################################################
# CONFIGURATION
####################################################################################################

# Set the top-level module to simulate. This should match the name of a testbench module defined in
# the hardware/testbench directory. The default is sc_soc_tb, which is the main SoC testbench that
# instantiates the entire design and runs a suite of tests on it. You can also set TOP to other
# testbench modules for more focused testing of specific components (e.g. bin_2_gray_tb for testing
# the binary to gray code converter). When you run 'make simulate', the Makefile will look for a
# testbench module with the name specified by TOP and simulate it. You can also set TOP when running
# 'make simulate' to override the default. For example, 'make simulate TOP=bin_2_gray_tb' will
# simulate the bin_2_gray_tb testbench instead of sc_soc_tb. Note that the testbench module you
# specify must be defined in the hardware/testbench directory and must be included in the xvlog file
# list for the simulation to work.
TOP := sc_soc_tb

# Sets the test name for the simulation
TEST := default

# Back-door load flag for the testbench, forwarded as +BDL plusarg. Set to 1 to enable the back-door
# loading mechanism in the testbench, which directly loads the program into the simulated RAM
# without going through the normal instruction fetch mechanism. This can speed up simulation for
# larger test programs, but may not be compatible
BDL := 1

# Set GUI=0 for headless simulation, any other value to open the Vivado waveform GUI
GUI := 0

# Set DEBUG to a non-zero value to enable debug print statements in the testbenches (forwarded as
# +DEBUG plusarg)
DEBUG := 0

# Simulation mode: GUI=0 runs headless (-runall), any other value opens the Vivado waveform GUI
ifeq ($(GUI), 0)
	SIM_ARGS += -runall
else
# Open xsim GUI and auto-load the matching .wcfg waveform configuration file
	SIM_ARGS += -gui --autoloadwcfg --view ../wcfg/$(TOP).wcfg
endif

# Set COV=1 to enable functional coverage collection during simulation
COV := 0
# Set CC_COV=1 to also enable code coverage (requires COV=1)
CC_COV := 0

# When both functional and code coverage are enabled, instruct xelab to instrument
# the design for statement/branch/condition coverage using the SBC (SystemVerilog
# Cover Constructs) mode
ifeq ($(COV), 1)
ifeq ($(CC_COV), 1)
	XELAB_FLAGS += --cc_type -sbc
endif
endif

# When both functional and code coverage are enabled, configure xcrg to merge the
# code-coverage database and produce a full-file report under the cc_report directory
ifeq ($(COV), 1)
ifeq ($(CC_COV), 1)
	XCRG_FLAGS += -cc_db $(TOP) -cc_fullfile -cc_report cc_report
endif
endif

# Get APB submodule commit hash only
APB_COMMIT = $(shell git submodule status -- $(APB) | awk '{print $$1}')

# Get AXI submodule commit hash only
AXI_COMMIT = $(shell git submodule status -- $(AXI) | awk '{print $$1}')

# Get COMMON_CELLS submodule commit hash only
COMMON_CELLS_COMMIT = $(shell git submodule status -- $(COMMON_CELLS) | awk '{print $$1}')

# Get RV32IMF submodule commit hash only
RV32IMF_COMMIT = $(shell git submodule status -- $(RV32IMF) | awk '{print $$1}')

# Get SOC submodule commit hash only
SOC_COMMIT = $(shell git submodule status -- $(SOC) | awk '{print $$1}')

# Get S1 submodule commit hash only
S1_COMMIT = $(shell git submodule status -- $(S1) | awk '{print $$1}')

# Filter xvlog/xelab output to highlight only Errors and Warnings Only
EW_O := | grep -iE "Error:|Warning:" --color=auto || true
# Filter xsim output to highlight only Errors and Warnings
EWHL := | grep -iE "Error:|Warning:|" --color=auto

# Preprocessor defines passed to xvlog; SIMULATION is used to gate simulation-only
# code blocks (e.g. $display, $finish) inside RTL and testbench files
XVLOG_DEFS += -d SIMULATION

####################################################################################################
# FILE DISCOVERY AND BUILD CONFIGURATION
####################################################################################################

# Stream hardware file hashes directly from find so Make does not expand every path into a single
# variable. Sorting the output keeps the snapshot stable across runs.
SHA_FILES_CMD = find "$(SC_SOC)/hardware" -type f -name "*.sv" -exec sha256sum {} + | LC_ALL=C sort

####################################################################################################
# TOOLS
####################################################################################################

# SystemVerilog compiler
XVLOG ?= xvlog

# elaborator / linker
XELAB ?= xelab

# simulator
XSIM ?= xsim

# coverage report generator
XCRG ?= xcrg

# RISC-V GCC toolchain for assembling and compiling test programs
RISCV64_GCC ?= riscv64-unknown-elf-gcc

# RISC-V objcopy for converting compiled test programs into Verilog hex files
RISCV64_OBJCOPY ?= riscv64-unknown-elf-objcopy

# RISC-V nm for inspecting symbol tables of compiled test programs
RISCV64_NM ?= riscv64-unknown-elf-nm

# RISC-V objdump for disassembling compiled test programs
RISCV64_OBJDUMP ?= riscv64-unknown-elf-objdump

# Reference Spike ISA simulator for functional verification of the RV32IMF core
SPIKE ?= spike

# Python interpreter for running utility scripts
PYTHON ?= python

####################################################################################################
# MAKE TARGETS
####################################################################################################

.PHONY: help
help:
	@echo -e "\033[1mSC-SoC Simulation Makefile\033[0m"
	@echo ""
	@echo -e "\033[1mUsage:\033[0m"
	@echo "  make [TARGET] [OPTIONS]"
	@echo ""
	@echo -e "\033[1mMain Targets:\033[0m"
	@echo -e "  \033[0;36msimulate\033[0m         Run simulation for the TOP module"
	@echo -e "  \033[0;36mRV32IMF_COMPILE\033[0m  Compile only the RV32IMF submodule (skips if commit unchanged)"
	@echo -e "  \033[0;36mclean\033[0m            Remove the build directory"
	@echo -e "  \033[0;36mclean_full\033[0m       Remove build/, log/, and coverage_report/ directories"
	@echo -e "  \033[0;36mhelp\033[0m             Show this help message"
	@echo ""
	@echo -e "\033[1mOptions:\033[0m"
	@echo -e "  \033[0;33mTOP=<module>\033[0m     Top-level module to simulate              (default: sc_soc_tb)"
	@echo -e "  \033[0;33mTEST=<name>\033[0m      Test name forwarded as +TEST plusarg      (default: default)"
	@echo -e "  \033[0;33mDEBUG=<value>\033[0m    Value forwarded as +DEBUG plusarg         (default: 0)"
	@echo -e "  \033[0;33mGUI=<0|1>\033[0m        0=headless, 1=open Vivado waveform GUI    (default: 0)"
	@echo -e "  \033[0;33mCOV=<0|1>\033[0m        1=enable functional coverage collection   (default: 0)"
	@echo -e "  \033[0;33mCC_COV=<0|1>\033[0m     1=also enable code coverage (needs COV=1) (default: 0)"
	@echo ""
	@echo -e "\033[1mExamples:\033[0m"
	@echo "  make simulate TOP=bin_2_gray_tb"
	@echo "  make simulate TOP=bin_2_gray_tb TEST=my_test"
	@echo "  make simulate TOP=bin_2_gray_tb GUI=1"
	@echo "  make simulate TOP=bin_2_gray_tb COV=1"
	@echo "  make simulate TOP=bin_2_gray_tb COV=1 CC_COV=1"

# Create the build, log, and coverage directories if they don't exist. Each directory also gets a
# .gitignore file to avoid accidentally committing generated artifacts.
$(BUILD) $(LOG) $(COVERAGE):
	@echo "Creating $@ directory..."
	@mkdir -p $@
	@echo "*" > $@/.gitignore

# Remove the entire build directory and all generated artifacts
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILD)

# Remove the build directory as well as all log and coverage report artifacts
.PHONY: clean_full
clean_full: clean
	@echo "Cleaning log directory..."
	@rm -rf $(LOG)
	@echo "Cleaning coverage directory..."
	@rm -rf $(COVERAGE)

	@make -s clean
	@rm -rf $(LOG)
	@rm -rf coverage_report

##################################################
# SC_SOC
##################################################

# Force a full recompilation of all SC-SoC sources regardless of whether files have changed.
# Removes all per-TOP elaboration stamps so every module is re-elaborated on the next run,
# compiles the RV32IMF submodule (skipped automatically if its commit hash is unchanged),
# assembles an xvlog file-list covering include paths, interfaces, RTL sources, and testbenches,
# then re-runs xvlog and updates the SHA-256 snapshot used by __ENV_BUILD__ for future change detection.
.PHONY: __COMPILE__
__COMPILE__:
	@make -s $(BUILD)
	@rm -rf $(BUILD)/build_*
	@echo -e "\033[3;35mCompiling...\033[0m"
	@make -s APB_COMPILE
	@make -s AXI_COMPILE
	@make -s COMMON_CELLS_COMPILE
	@make -s RV32IMF_COMPILE
	@make -s SOC_COMPILE
	@make -s S1_COMPILE
	@echo "-i ${SC_SOC}/hardware/include" > $(BUILD)/flist
	@echo "-i ${AXI}/include" >> $(BUILD)/flist
	@echo "-i ${APB}/include" >> $(BUILD)/flist
	@echo "-i ${COMMON_CELLS}/include" >> $(BUILD)/flist
	@echo "-i ${SC_SOC}/hardware/testbench" >> $(BUILD)/flist
	@echo "${APB}/src/apb_pkg.sv" >> $(BUILD)/flist
	@echo "${AXI}/src/axi_pkg.sv" >> $(BUILD)/flist
	@find ${SC_SOC}/hardware/interface -maxdepth 1 -name "*" -type f >> $(BUILD)/flist
	@find ${SC_SOC}/hardware/source -maxdepth 1 -name "*" -type f >> $(BUILD)/flist
	@find ${SC_SOC}/hardware/testbench -maxdepth 1 -name "*" -type f >> $(BUILD)/flist
	@cd $(BUILD); $(XVLOG) -sv -f flist $(XVLOG_DEFS) -log $(LOG)/xvlog_sc_soc.log $(EW_O)
	@$(SHA_FILES_CMD) > $(BUILD)/build_sha
	@echo -e "\033[3;35mCompiled\033[0m"

# Stamp file that records a successful xelab elaboration of TOP. Make treats the file as a
# build artifact; if it does not exist (or TOP changes) xelab is re-run to produce a new
# simulation snapshot, then the empty stamp file is written so subsequent runs skip this step.
$(BUILD)/build_$(TOP):
	@echo -e "\033[3;35mElaborating $(TOP)...\033[0m"
	@cd $(BUILD); $(XELAB) $(TOP) -s $(TOP) -debug all --O3 $(XELAB_FLAGS) -log $(LOG)/xelab_$(TOP).log $(EW_O)
	@echo "" > $(BUILD)/build_$(TOP)
	@echo -e "\033[3;35mElaborated $(TOP)\033[0m"

# Incremental build gate: computes a fresh SHA-256 digest of all tracked source files and
# compares it against the digest saved from the last successful compilation. If the digests
# differ, __COMPILE__ is invoked to recompile; otherwise compilation is skipped. Elaboration
# is then checked separately via the build/build_$(TOP) stamp file.
.PHONY: __ENV_BUILD__
__ENV_BUILD__:
	@make -s $(BUILD)
	@make -s $(LOG)
	@$(SHA_FILES_CMD) > $(BUILD)/build_sha_new
	@touch $(BUILD)/build_sha
	@diff $(BUILD)/build_sha_new $(BUILD)/build_sha &> /dev/null || make -s __COMPILE__
	@make -s $(BUILD)/build_$(TOP)

# Write the xsim plusarg file consumed by every simulation run. TEST selects the named
# test case inside the testbench, and DEBUG passes an optional verbosity/debug level.
.PHONY: common_sim_checks
common_sim_checks:
	@echo "--testplusarg TEST=$(TEST)" > $(BUILD)/xsim_args
	@echo "--testplusarg DEBUG=$(DEBUG)" >> $(BUILD)/xsim_args
	@echo "--testplusarg BDL=$(BDL)" >> $(BUILD)/xsim_args
ifeq ($(TOP), sc_soc_tb)
	@make -s test TEST=$(TEST)
endif

# Top-level simulation entry point. Ensures the build and log directories exist, persists
# the TOP name to build/top (so subsequent bare 'make simulate' invocations remember the last
# used module), triggers an incremental compile+elaborate if sources have changed, writes the
# xsim plusarg file, then launches xsim. The log file name is derived from TOP and TEST
# (forward slashes in TEST are replaced with ___ to produce a valid filename). When COV=1,
# xcrg is used to produce an HTML functional coverage report; when CC_COV=1 as well, the
# code coverage report is also moved into the coverage_report directory.
.PHONY: simulate
simulate:
	@make -s LOGO
	@make -s $(BUILD)
	@make -s $(LOG)
	@echo "$(TOP)" > $(BUILD)/top
	@make -s __ENV_BUILD__ TOP=$(TOP)
	@make -s common_sim_checks TEST=$(TEST) DEBUG=$(DEBUG)
	@echo -e "\033[3;35mSimulating $(TOP) $(TEST)...\033[0m"
	@$(eval log_file_name := $(shell echo "xsim_$(TOP)_$(TEST).log" | sed "s/\//___/g"))
	@cd $(BUILD); $(XSIM) $(TOP) -f xsim_args $(SIM_ARGS) -log $(LOG)/$(log_file_name) $(EWHL)
	@echo -e "\033[3;35mSimulated $(TOP) $(TEST)\033[0m"
ifeq ($(COV), 1)
	@make -s coverage_report
	@echo -e "\033[3;35mGenerating Coverage Report $(TOP)...\033[0m"
	@cd $(BUILD); $(XCRG) $(XCRG_FLAGS) -report_format html --nolog -cov_db_name work.$(TOP)
	@echo -e "\033[3;35mGenerated Coverage Report $(TOP)\033[0m"
	@mv $(BUILD)/xsim_coverage_report/functionalCoverageReport coverage_report/$(TOP)_$(TEST)_fc
ifeq ($(CC_COV), 1)
	@mv $(BUILD)/cc_report/codeCoverageReport coverage_report/$(TOP)_$(TEST)_cc
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
	@make -s $(BUILD)
	@git submodule update --init --depth 1 $(RV32IMF)
	@touch $(BUILD)/rv32imf_commit.txt
	@echo "$(RV32IMF_COMMIT)" > $(BUILD)/current_rv32imf_commit.txt
	@if [ -f $(BUILD)/rv32imf_commit.txt ] && [ -f $(BUILD)/current_rv32imf_commit.txt ] && \
	     [ "$$(cat $(BUILD)/rv32imf_commit.txt)" = "$$(cat $(BUILD)/current_rv32imf_commit.txt)" ]; then \
		echo -n ""; \
	else \
		cd $(BUILD) && $(XVLOG) -sv -f $(SC_SOC)/hardware/filelist/rv32imf.f -log $(LOG)/xvlog_rv32imf.log $(EW_O); \
	fi
	@echo "$(RV32IMF_COMMIT)" > $(BUILD)/rv32imf_commit.txt
	@rm -f $(BUILD)/current_rv32imf_commit.txt

##################################################
# SOC
##################################################

.PHONY: SOC_COMPILE
SOC_COMPILE:
	@make -s $(BUILD)
	@git submodule update --init --depth 1 $(SOC)
	@touch $(BUILD)/soc_commit.txt
	@echo "$(SOC_COMMIT)" > $(BUILD)/current_soc_commit.txt
	@if [ -f $(BUILD)/soc_commit.txt ] && [ -f $(BUILD)/current_soc_commit.txt ] && \
	     [ "$$(cat $(BUILD)/soc_commit.txt)" = "$$(cat $(BUILD)/current_soc_commit.txt)" ]; then \
		echo -n ""; \
	else \
		cd $(BUILD) && $(XVLOG) -sv -f $(SC_SOC)/hardware/filelist/SOC.f -log $(LOG)/xvlog_soc.log $(EW_O); \
	fi
	@echo "$(SOC_COMMIT)" > $(BUILD)/soc_commit.txt
	@rm -f $(BUILD)/current_soc_commit.txt

##################################################
# S1
##################################################

.PHONY: S1_COMPILE
S1_COMPILE:
	@make -s $(BUILD)
	@git submodule update --init --depth 1 $(S1)
	@touch $(BUILD)/s1_commit.txt
	@echo "$(S1_COMMIT)" > $(BUILD)/current_s1_commit.txt
	@if [ -f $(BUILD)/s1_commit.txt ] && [ -f $(BUILD)/current_s1_commit.txt ] && \
	     [ "$$(cat $(BUILD)/s1_commit.txt)" = "$$(cat $(BUILD)/current_s1_commit.txt)" ]; then \
		echo -n ""; \
	else \
		cd $(BUILD) && $(XVLOG) -sv -f $(SC_SOC)/hardware/filelist/S1.f -log $(LOG)/xvlog_s1.log $(EW_O); \
	fi
	@echo "$(S1_COMMIT)" > $(BUILD)/s1_commit.txt
	@rm -f $(BUILD)/current_s1_commit.txt

##################################################
# AXI
##################################################

.PHONY: AXI_COMPILE
AXI_COMPILE:
	@make -s $(BUILD)
	@git submodule update --init --depth 1 $(AXI)
	@touch $(BUILD)/axi_commit.txt
	@echo "$(AXI_COMMIT)" > $(BUILD)/current_axi_commit.txt
	@if [ -f $(BUILD)/axi_commit.txt ] && [ -f $(BUILD)/current_axi_commit.txt ] && \
	     [ "$$(cat $(BUILD)/axi_commit.txt)" = "$$(cat $(BUILD)/current_axi_commit.txt)" ]; then \
		echo -n ""; \
	else \
		cd $(BUILD) && $(XVLOG) -sv -f $(SC_SOC)/hardware/filelist/axi.f -log $(LOG)/xvlog_axi.log $(EW_O); \
	fi
	@echo "$(AXI_COMMIT)" > $(BUILD)/axi_commit.txt
	@rm -f $(BUILD)/current_axi_commit.txt

##################################################
# APB
##################################################

.PHONY: APB_COMPILE
APB_COMPILE:
	@make -s $(BUILD)
	@git submodule update --init --depth 1 $(APB)
	@touch $(BUILD)/apb_commit.txt
	@echo "$(APB_COMMIT)" > $(BUILD)/current_apb_commit.txt
	@if [ -f $(BUILD)/apb_commit.txt ] && [ -f $(BUILD)/current_apb_commit.txt ] && \
	     [ "$$(cat $(BUILD)/apb_commit.txt)" = "$$(cat $(BUILD)/current_apb_commit.txt)" ]; then \
		echo -n ""; \
	else \
		cd $(BUILD) && $(XVLOG) -sv -f $(SC_SOC)/hardware/filelist/apb.f -log $(LOG)/xvlog_apb.log $(EW_O); \
	fi
	@echo "$(APB_COMMIT)" > $(BUILD)/apb_commit.txt
	@rm -f $(BUILD)/current_apb_commit.txt

##################################################
# COMMON CELLS
##################################################

.PHONY: COMMON_CELLS_COMPILE
COMMON_CELLS_COMPILE:
	@make -s $(BUILD)
	@git submodule update --init --depth 1 $(COMMON_CELLS)
	@touch $(BUILD)/common_cells_commit.txt
	@echo "$(COMMON_CELLS_COMMIT)" > $(BUILD)/current_common_cells_commit.txt
	@if [ -f $(BUILD)/common_cells_commit.txt ] && [ -f $(BUILD)/current_common_cells_commit.txt ] && \
	     [ "$$(cat $(BUILD)/common_cells_commit.txt)" = "$$(cat $(BUILD)/current_common_cells_commit.txt)" ]; then \
		echo -n ""; \
	else \
		cd $(BUILD) && $(XVLOG) -sv -f $(SC_SOC)/hardware/filelist/common_cells.f -log $(LOG)/xvlog_common_cells.log $(EW_O); \
	fi
	@echo "$(COMMON_CELLS_COMMIT)" > $(BUILD)/common_cells_commit.txt
	@rm -f $(BUILD)/current_common_cells_commit.txt

####################################################################################################
# RISC V
####################################################################################################

# Compile and prepare test program using RISC-V GCC tools
.PHONY: test
test:
	@$(eval TEST_PATH := $(shell find software/source -type f -name "*${TEST}*"))
	@if [ -z "${TEST_PATH}" ]; then echo -e "\033[1;31mTest file ${TEST} not found!\033[0m"; exit 1; fi
	@if [ $$(echo "${TEST_PATH}" | wc -w) -gt 1 ]; then echo -e "\033[1;31mMultiple test files found for ${TEST}:\n${TEST_PATH}\033[0m"; exit 1; fi
	@echo -e "\033[3;35mCompiling test program ${TEST_PATH}...\033[0m"
	@make -s $(BUILD)
	@${RISCV64_GCC} -march=rv32imf -mabi=ilp32f -nostdlib -nostartfiles -T software/linkers/core.ld -o build/prog.elf software/include/startup.S software/include/uart.c software/include/gpio.c ${TEST_PATH} -I software/include
	@${RISCV64_OBJCOPY} -O verilog build/prog.elf build/prog.hex
	@${RISCV64_NM} -n build/prog.elf > build/prog.sym
	@${RISCV64_OBJDUMP} -d build/prog.elf > build/prog.dis


.PHONY: LOGO
LOGO:
	@clear
	@echo "     _   ___  _  _   ___ ___ __  __ ___ ___ ___  _  _ ___  _   _  ___ _____ ___  ___  ___   "
	@echo "    /_\ |   \| \| | / __| __|  \/  |_ _/ __/ _ \| \| |   \| | | |/ __|_   _/ _ \| _ \/ __|  "
	@echo "   / _ \| |) | .\` | \__ \ _|| |\/| || | (_| (_) | .\` | |) | |_| | (__  | || (_) |   /\__ \  "
	@echo "  /_/ \_\___/|_|\_| |___/___|_|  |_|___\___\___/|_|\_|___/ \___/ \___| |_| \___/|_|_\|___/  "
	@echo "                                                                                            "
