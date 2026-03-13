# SC-SoC

![Single Core System on Chip Architecture](document/arch.svg)

SC-SoC is a design and verification repository for a single-core System on Chip built around an RV32IMF RISC-V CPU and a set of reusable SystemVerilog building blocks. The repository combines RTL design, unit-level verification environments, software test programs, and project documentation in one place so the same codebase can support block bring-up, interface verification, and SoC integration work.

## Overview

This repository is organized to support both sides of hardware development:

- RTL design of reusable digital blocks such as FIFOs, memories, clocking utilities, and AXI4-Lite peripherals
- verification of those blocks through dedicated SystemVerilog testbenches
- software-side bring-up using small RISC-V assembly and C programs
- integration of an RV32IMF core through the `submodule/rv32imf` submodule

The build flow is driven by the top-level `Makefile` and targets Xilinx simulation tools (`xvlog`, `xelab`, `xsim`) for compilation, elaboration, simulation, and optional coverage reporting.

## Repository Goals

- Develop and verify reusable hardware IP for a single-core SoC
- provide a structured verification flow for unit and subsystem testbenches
- support software-driven validation with simple RISC-V programs
- keep design files, testbenches, and module documentation aligned

## Repository Layout

| Path | Purpose |
| --- | --- |
| `hardware/source/` | Synthesizable RTL modules for the SoC building blocks |
| `hardware/interface/` | SystemVerilog interfaces used by RTL and testbenches |
| `hardware/include/` | Shared type definitions, packages, and verification headers |
| `hardware/testbench/` | Unit and subsystem testbenches |
| `hardware/filelist/` | Compilation file lists, including the RV32IMF submodule file list |
| `software/source/` | RISC-V assembly and C test programs |
| `software/include/` | Startup code and small support headers/source files |
| `software/linkers/` | Linker scripts for software test builds |
| `document/` | Design notes, verification notes, and block-level documentation |
| `submodule/rv32imf/` | RV32IMF core and related sources brought in as a git submodule |
| `wcfg/` | Waveform configuration files for GUI simulation |

## Key Hardware Blocks

The current repository includes, among others, the following reusable modules:

- `fifo`: synchronous valid-ready FIFO
- `mem` and `dual_port_mem`: basic storage blocks
- `axi4l_mem` and `axi4l_mem_ctrlr`: AXI4-Lite accessible memory subsystem
- `clk_div` and `clk_mux`: clock generation and clock selection utilities
- `delay_gen`: programmable delay generation logic
- `dual_edge_reg`: dual-edge capture/register utility
- `bin_2_gray` and `gray_2_bin`: data conversion utilities

Each major block is paired with a matching testbench and markdown documentation under `document/`.

## Tool Requirements

The checked-in build flow assumes the following tools are available in your environment:

- GNU Make
- Bash-compatible shell
- Xilinx Vivado simulation tools: `xvlog`, `xelab`, `xsim`
- Xilinx coverage tool: `xcrg` for coverage report generation
- RISC-V GNU toolchain: `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-objcopy`, `riscv64-unknown-elf-nm`, `riscv64-unknown-elf-objdump`
- `git` with submodule support
- optional: `spike` for ISA-level reference work

On Windows, run the flow from a Unix-like environment such as Git Bash, MSYS2, or WSL so that `make`, `find`, `grep`, `sed`, `awk`, and other POSIX utilities used by the Makefile are available.

## Getting Started

Clone the repository with submodules:

```bash
git clone --recurse-submodules <repo-url>
cd SC-SoC
```

If the repository was already cloned without submodules, initialize them before simulation:

```bash
git submodule update --init --depth 1
```

To see the available build targets:

```bash
make help
```

## Simulation Flow

The main entry point is:

```bash
make simulate TOP=<testbench>
```

Examples:

```bash
make simulate TOP=bin_2_gray_tb
make simulate TOP=fifo_tb
make simulate TOP=axi4l_mem_tb GUI=1
make simulate TOP=clk_div_tb COV=1
make simulate TOP=clk_mux_tb COV=1 CC_COV=1
```

### Supported Simulation Options

| Option | Description | Default |
| --- | --- | --- |
| `TOP=<module>` | Top-level module or testbench to elaborate and simulate | `hello` |
| `TEST=<name>` | Forwarded to simulation as a `+TEST` plusarg | `default` |
| `DEBUG=<value>` | Forwarded to simulation as a `+DEBUG` plusarg | unset |
| `GUI=0|1` | Run headless or open the waveform GUI | `0` |
| `COV=0|1` | Enable functional coverage collection | `0` |
| `CC_COV=0|1` | Enable code coverage instrumentation when `COV=1` | `0` |

### Generated Outputs

- `build/`: compilation, elaboration, generated plusargs, and software artifacts
- `log/`: simulation logs named by top module and test name
- `coverage_report/`: functional and optional code coverage HTML reports

## Software Test Flow

The repository also supports building small RISC-V test programs from `software/source/`.

Build a software program with:

```bash
make test TEST=hello
```

The `test` target:

- finds the matching source file in `software/source/`
- compiles it for `rv32imf`
- links it with `software/linkers/core.ld`
- emits a Verilog hex image and debug artifacts into `build/`

Generated software artifacts include:

- `build/prog.elf`
- `build/prog.hex`
- `build/prog.sym`
- `build/prog.dis`

Example source programs currently include:

- `software/source/hello.c`
- `software/source/addi.S`

## Incremental Build Behavior

The top-level flow is set up to reduce unnecessary recompilation:

- hardware source changes are tracked with SHA-256 snapshots under `build/`
- elaboration is cached per selected `TOP`
- the RV32IMF submodule is only recompiled when its submodule commit changes

This keeps iteration faster when working on block-level verification or when switching among testbenches.

## Documentation

Block-level design and verification notes are stored in `document/`. Useful starting points include:

- `document/axi4l_mem.md`
- `document/axi4l_mem_ctrlr.md`
- `document/fifo.md`
- `document/mem.md`
- `document/clk_div.md`
- `document/clk_mux.md`
- `document/delay_gen.md`
- `document/dual_edge_reg.md`
- `document/bin_2_gray.md`
- `document/gray_2_bin.md`

Verification-oriented documents are also available for several blocks, for example:

- `document/axi4l_mem_tb.md`
- `document/fifo_tb.md`
- `document/mem_tb.md`
- `document/clk_div_tb.md`
- `document/bin_2_gray_tb.md`

The template `document/test_plan_template.md` can be used to standardize future verification plans.

## Typical Development Workflow

1. Implement or update RTL under `hardware/source/`
2. add or update a matching testbench under `hardware/testbench/`
3. run `make simulate TOP=<tb_name>` until the block is stable
4. enable coverage when needed with `COV=1` or `COV=1 CC_COV=1`
5. document the block behavior and verification strategy under `document/`
6. build software tests with `make test TEST=<program>` when software-driven validation is required

## Cleaning Generated Files

Remove only the build directory:

```bash
make clean
```

Remove build products, logs, and coverage reports:

```bash
make clean_full
```

## RV32IMF Submodule

The CPU implementation is maintained in `submodule/rv32imf/` and is compiled through the top-level flow using `hardware/filelist/rv32imf.f`. The Makefile automatically initializes the submodule when required and skips recompiling it when the recorded submodule commit has not changed.

## License

This project is licensed under the terms in `LICENSE`.

