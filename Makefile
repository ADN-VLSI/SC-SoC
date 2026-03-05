export SHELL=/bin/bash

TOP := hello

ROOT_DIR := $(CURDIR)

FILE_LIST := -i $(CURDIR)/include

FILE_LIST += $(shell find $(ROOT_DIR)/source -type f -name "*.sv")
FILE_LIST += $(shell find $(ROOT_DIR)/interface -type f -name "*.sv")
FILE_LIST += $(shell find $(ROOT_DIR)/testbench -type f -name "*.sv")

EWHL := | grep -iE "Error:|Warning:|" --color=auto

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
	@cd build && xvlog -sv $(FILE_LIST) $(EWHL)
	@cd build && xelab $(TOP) -s $(TOP)_sim --O0 -debug all $(EWHL)
	@cd build && xsim $(TOP)_sim -runall $(EWHL)
