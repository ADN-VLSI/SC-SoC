# Use bash as the shell for all recipe commands
export SHELL=/bin/bash

.DEFAULT_GOAL := help

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

# Set COV=1 to enable functional coverage collection during simulation
COV ?= 0
# Set CC_COV=1 to also enable code coverage (requires COV=1)
CC_COV ?= 0

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

# Get RV32IMF submodule commit hash only
RV32IMF_COMMIT := $(shell git submodule status -- $(RV32IMF) | awk '{print $$1}')

# Filter xvlog/xelab/xsim output to highlight only Errors and Warnings
EWHL := | grep -iE "Error:|Warning:|" --color=auto

# Preprocessor defines passed to xvlog; SIMULATION is used to gate simulation-only
# code blocks (e.g. $display, $finish) inside RTL and testbench files
XVLOG_DEFS += -d SIMULATION

####################################################################################################
# FILE DISCOVERY AND BUILD CONFIGURATION
####################################################################################################

# List of all tracked source files whose SHA-256 checksums are used to detect
# changes and trigger incremental recompilation / elaboration only when needed
SHA_FILES += $$(find include/ -type f)
SHA_FILES += $$(find interface/ -type f)
SHA_FILES += $$(find source/ -type f)
SHA_FILES += $$(find testbench/ -type f)

####################################################################################################
# TOOLS
####################################################################################################

# Xilinx Vivado toolchain binaries (override on the command line to point at a
# specific installation, e.g. XVLOG=/opt/Xilinx/Vivado/2023.2/bin/xvlog)

# SystemVerilog compiler
XVLOG ?= xvlog  

# elaborator / linker
XELAB ?= xelab  

# simulator
XSIM  ?= xsim   

# coverage report generator
XCRG  ?= xcrg   

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
	@echo -e "  \033[0;33mTOP=<module>\033[0m     Top-level module to simulate              (default: hello)"
	@echo -e "  \033[0;33mTEST=<name>\033[0m      Test name forwarded as +TEST plusarg      (default: default)"
	@echo -e "  \033[0;33mDEBUG=<value>\033[0m    Value forwarded as +DEBUG plusarg         (default: unset)"
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

# Create the build output directory and add a .gitignore so its contents are not tracked by git
build:
	@echo "Creating build directory..."
	@mkdir build
	@echo "*" > build/.gitignore

# Create the log output directory and add a .gitignore so simulation logs are not tracked by git
log:
	@echo "Creating log directory..."
	@mkdir -p log
	@echo "*" > log/.gitignore

# Create the coverage report output directory and exclude its contents from git
coverage_report:
	@mkdir -p coverage_report
	@echo "*" > coverage_report/.gitignore

# Remove the entire build directory and all generated artifacts
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	@rm -rf build

# Remove the build directory as well as all log and coverage report artifacts
.PHONY: clean_full
clean_full:
	@make -s clean
	@rm -rf log
	@rm -rf coverage_report

##################################################
# SC_SOC
##################################################

# Compute a fresh SHA-256 digest of all tracked source files and compare it against
# the digest saved after the last successful elaboration. If any file has changed,
# trigger a full recompile + re-elaborate cycle; otherwise do nothing.
.PHONY: match_sha
match_sha:
	@sha256sum ${SHA_FILES} > build/build_$(TOP)_new
	@touch build/build_$(TOP)
	@diff build/build_$(TOP)_new build/build_$(TOP) || make -s __ENV_BUILD__ TOP=$(TOP)

# Compile all SC-SoC SystemVerilog sources (includes, interfaces, RTL, and testbenches).
# Builds the file list (build/flist) on-the-fly from the directory tree, then
# invokes xvlog in SystemVerilog mode with the preprocessor defines in XVLOG_DEFS.
# The RV32IMF submodule is compiled first via RV32IMF_COMPILE.
.PHONY: __COMPILE__
__COMPILE__:
	@make -s build
	@echo -e "\033[3;35mCompiling...\033[0m"
	@make -s RV32IMF_COMPILE
	@echo "-i ${SC_SOC}/include" > build/flist
	@find ${SC_SOC}/interface -type f >> build/flist
	@find ${SC_SOC}/source -type f >> build/flist
	@find ${SC_SOC}/testbench -type f >> build/flist
	@cd build; $(XVLOG) -sv -f flist $(XVLOG_DEFS) --nolog $(EWHL)
	@echo -e "\033[3;35mCompiled\033[0m"

# Elaborate the compiled design rooted at $(TOP).
# --O0 disables xelab optimizations to keep elaboration fast during development.
# On success the SHA-256 digest of all tracked sources is written to build/build_$(TOP)
# so that subsequent match_sha checks can detect stale builds.
.PHONY: __ELABORATE__
__ELABORATE__:
	@echo -e "\033[3;35mElaborating $(TOP)...\033[0m"
	@cd build; $(XELAB) $(TOP) --O0 $(XELAB_FLAGS) --nolog $(EWHL)
	@echo -e "\033[3;35mElaborated $(TOP)\033[0m"
	@sha256sum ${SHA_FILES} > build/build_$(TOP)

# Full environment build: compile then elaborate. Called by match_sha when sources
# have changed, or by CHK_BUILD when no prior build stamp exists.
.PHONY: __ENV_BUILD__
__ENV_BUILD__:
	@make -s __COMPILE__
	@make -s __ELABORATE__

# Guard target called before every simulation run.
# If no build stamp exists for $(TOP) the entire environment is built from scratch.
# Otherwise the SHA-256 digest is compared to detect source changes and rebuild
# only if necessary, avoiding unnecessary recompilation.
.PHONY: CHK_BUILD
CHK_BUILD:
	@if [ ! -f build/build_$(TOP) ]; then                    \
		echo -e "\033[3;33mEnvironment not built...\033[0m";   \
		make -s __ENV_BUILD__ TOP=$(TOP);                      \
	else                                                     \
		echo -e "\033[3;33mChecking sha256sum...\033[0m";      \
		make -s match_sha TOP=$(TOP);                          \
	fi

# Write the xsim plusarg file used by all simulation runs.
# TEST selects the test case inside the testbench; DEBUG enables verbose logging
# when set to a non-zero value. Both are forwarded as +TEST=... / +DEBUG=... at runtime.
.PHONY: common_sim_checks
common_sim_checks:
	@echo "--testplusarg TEST=$(TEST)" > build/xsim_args
	@echo "--testplusarg DEBUG=$(DEBUG)" >> build/xsim_args

# Top-level simulation target.
# Usage examples:
#   make simulate TOP=bin_2_gray_tb             – headless run, default test
#   make simulate TOP=bin_2_gray_tb TEST=foo    – headless run, named test
#   make simulate TOP=bin_2_gray_tb GUI=1       – open Vivado waveform viewer
#   make simulate TOP=bin_2_gray_tb COV=1       – collect functional coverage
#   make simulate TOP=bin_2_gray_tb COV=1 CC_COV=1 – functional + code coverage
#
# Steps:
#   1. Ensure the log directory exists.
#   2. Check / rebuild the compiled + elaborated environment for $(TOP).
#   3. Write the xsim plusarg file.
#   4. Run xsim; forward slashes in TEST are replaced with ___ to build a safe log filename.
#   5. (COV=1) Generate an HTML coverage report and move it to coverage_report/.
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
