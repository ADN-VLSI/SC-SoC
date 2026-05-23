# Control Register Map and Bit-Field Definitions

This document defines the Control register map and bit-field assignments. All register offsets are relative to the Control base address.

## Register Map

| Offset  | Register       | Type | Reset Value | Description                                |
| ------- | -------------- | ---- | ----------- | ------------------------------------------ |
| `0x000` | SOC_ID         | RO   | 0x44670931  | SoC Identifier Register                    |
| `0x004` | REV_ID         | RO   | 0x00000001  | SoC Revision Identifier Register           |
| `0x020` | CORE_BOOT_ADDR | RW   | 0x40000000  | Core Boot Address Configuration            |
| `0x024` | CORE_HART_ID   | RW   | 0x00000000  | Core Hardware Thread ID                    |
| `0x028` | CORE_CLK_RST   | RW   | 0x00000000  | Core Clock and Reset Control               |
| `0x040` | PLL_CFG        | RO   | 0x00000C90  | PLL Configuration Register                 |
| `0x060` | TOHOST         | RW   | 0x00000000  | Host Communication Register (Core to Host) |
| `0x068` | FROMHOST       | RW   | 0x00000000  | Host Communication Register (Host to Core) |
| `0x080` | BOOTMODE       | RO   | -           | Boot Mode Configuration                    |
| `0x0A0` | GPIO_IN        | RO   | -           | GPIO Input Value Status                    |
| `0x0A4` | GPIO_OUT       | RW   | 0x00000000  | GPIO Output Value Control                  |
| `0x0A8` | GPIO_DIR       | RW   | 0x00000000  | GPIO Direction Control                     |
| `0x0AC` | GPIO_PULL      | RW   | 0x00000000  | GPIO Pull Control                          |

## SOC_ID

`Offset:0x000` `Type:RO`

The SOC_ID register contains a fixed value that uniquely identifies the SoC. This value can be used by software to verify that it is running on the expected hardware platform.

| Bits   | Reset Value | Field | Description                   |
| ------ | ----------- | ----- | ----------------------------- |
| `31:0` | 0x44670931  | ID    | Unique identifier for the SoC |

## REV_ID

`Offset:0x004` `Type:RO`

The REV_ID register contains a fixed value that indicates the revision of the SoC. This value can be used by software to determine the specific version of the hardware it is running on, which may be important for compatibility and feature support.

| Bits   | Reset Value | Field | Description                     |
| ------ | ----------- | ----- | ------------------------------- |
| `31:0` | 0x00000001  | ID    | Revision identifier for the SoC |

## CORE_BOOT_ADDR

`Offset:0x020` `Type:RW`

The CORE_BOOT_ADDR register defines the boot address used by the core during startup. Software can program this register to select the address from which the core begins execution.

| Bits   | Reset Value | Field | Description                        |
| ------ | ----------- | ----- | ---------------------------------- |
| `31:0` | 0x40000000  | ADDR  | Boot address presented to the core |

## CORE_HART_ID

`Offset:0x024` `Type:RW`

The CORE_HART_ID register holds the hardware thread identifier exposed by the core. Software can update this register when a specific hart identification value is required by the platform.

| Bits   | Reset Value | Field | Description                             |
| ------ | ----------- | ----- | --------------------------------------- |
| `31:0` | 0x00000000  | ID    | Hardware thread identifier for the core |

## CORE_CLK_RST

`Offset:0x028` `Type:RW`

The CORE_CLK_RST register controls core clocking and reset-related behavior. Software can use this register to manage the core operating state through a single control word.

| Bits   | Reset Value | Field       | Description                        |
| ------ | ----------- | ----------- | ---------------------------------- |
| `0`    | 0x00000000  | CORE_RST_EN | Core clock and reset control value |
| `1`    | 0x00000000  | CORE_CLK_EN | Core clock and reset control value |
| `31:2` | 0x00000000  | RESERVED    | Core clock and reset control value |

## PLL_CFG

`Offset:0x040` `Type:RO`

The PLL_CFG register provides a read-only view of the PLL configuration settings. Software can use this register to determine the current PLL configuration, including reference and feedback dividers.

| Bits    | Reset Value | Field    | Description                               |
| ------- | ----------- | -------- | ----------------------------------------- |
| `4:0`   | 0x00000010  | REF_DIV  | PLL reference clock divider configuration |
| `18:5`  | 0x000003E8  | FB_DIV   | PLL feedback clock divider configuration  |
| `31:19` | 0x00000000  | RESERVED | PLL configuration settings                |

## TOHOST

`Offset:0x060` `Type:RW`

The TOHOST register provides a software-visible path for core-to-host communication. Software can write status or message values here for external observation or testbench interaction.

| Bits   | Reset Value | Field | Description                            |
| ------ | ----------- | ----- | -------------------------------------- |
| `31:0` | 0x00000000  | DATA  | Host communication value from the core |

## FROMHOST

`Offset:0x068` `Type:RW`

The FROMHOST register provides a software-visible path for host-to-core communication. Software can read or update this value as part of a simple host interaction mechanism.

| Bits   | Reset Value | Field | Description                          |
| ------ | ----------- | ----- | ------------------------------------ |
| `31:0` | 0x00000000  | DATA  | Host communication value to the core |

## BOOTMODE

`Offset:0x080` `Type:RO`

The BOOTMODE register reports the boot mode configuration observed by the SoC. Software can read this register to determine which boot selection was applied at startup.

| Bits   | Reset Value | Field    | Description                    |
| ------ | ----------- | -------- | ------------------------------ |
| `0`    | -           | DATA     | Boot mode configuration status |
| `31:1` | -           | RESERVED | Boot mode configuration status |

## GPIO_DIR

`Offset:0x0A0` `Type:RW`

The GPIO_DIR register controls the direction setting for the GPIO interface. Software can use this register to select whether each GPIO signal operates as an input or an output.

| Bits   | Reset Value | Field | Description                  |
| ------ | ----------- | ----- | ---------------------------- |
| `31:0` | 0x00000000  | DATA  | GPIO direction control value |

## GPIO_OUT

`Offset:0x0A4` `Type:RW`

The GPIO_OUT register holds the output values driven onto the GPIO interface. Software can write this register to control the state of GPIO signals configured as outputs.

| Bits   | Reset Value | Field | Description               |
| ------ | ----------- | ----- | ------------------------- |
| `31:0` | 0x00000000  | DATA  | GPIO output value control |

## GPIO_IN

`Offset:0x0A8` `Type:RO`

The GPIO_IN register reports the sampled input values from the GPIO interface. Software can read this register to observe the current state of GPIO signals configured as inputs.

| Bits   | Reset Value | Field | Description             |
| ------ | ----------- | ----- | ----------------------- |
| `31:0` | -           | DATA  | GPIO input value status |
