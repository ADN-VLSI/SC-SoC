export SHELL=/bin/bash

TOP := hello

ROOT_DIR := $(CURDIR)

SRC_LIST := $(shell find $(ROOT_DIR)/source -type f -name "*.sv")
TB_LIST  := $(shell find $(ROOT_DIR)/testbench -type f -name "*.sv")

build:
	@echo "Creating build directory..."
	@mkdir build
	@echo "*" > build/.gitignore

.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	@rm -rf build

.PHONY: all
all:
	@make -s clean
	@make -s build
	@cd build && xvlog -sv $(SRC_LIST) $(TB_LIST)
	@cd build && xelab $(TOP) -s $(TOP)_sim
	@cd build && xsim $(TOP)_sim -runall
