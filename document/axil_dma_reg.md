# AXIL DMA Register Description

| Register  | Offset | Type | Description                          |
| --------- | ------ | ---- | ------------------------------------ |
| src_addr  | 0x00   | RW   | Source address for DMA transfer      |
| dst_addr  | 0x04   | RW   | Destination address for DMA transfer |
| num_words | 0x08   | RW   | Number of words to transfer          |
| remaining | 0x0C   | RO   | Remaining words to transfer          |
| ctrl      | 0x10   | RW   | Control register for DMA operation   |
| stat      | 0x14   | RO   | Status register for DMA operation    |

|

## Register Details

### src_addr (0x00)

- **Type**: Read/Write
- **Description**: This register holds the source address from which the DMA will read data. The address should be aligned to the word size of the system.

| Bit  | Name     | Description                     |
| ---- | -------- | ------------------------------- |
| 31:0 | src_addr | Source address for DMA transfer |

### dst_addr (0x04)

- **Type**: Read/Write
- **Description**: This register holds the destination address to which the DMA will write data.

| Bit  | Name     | Description                          |
| ---- | -------- | ------------------------------------ |
| 31:0 | dst_addr | Destination address for DMA transfer |

### num_words (0x08)

- **Type**: Read/Write
- **Description**: This register specifies the number of words to be transferred by the DMA.

| Bit  | Name      | Description                 |
| ---- | --------- | --------------------------- |
| 31:0 | num_words | Number of words to transfer |

### remaining (0x0C)

- **Type**: Read-Only
- **Description**: This register indicates the number of words remaining to be transferred. It is updated by the DMA controller during the transfer process.

| Bit  | Name      | Description                             |
| ---- | --------- | --------------------------------------- |
| 31:0 | remaining | Remaining words to transfer (read-only) |

### ctrl (0x10)

- **Type**: Read/Write
- **Description**: This control register is used to start the DMA transfer and configure its behavior.

| Bit  | Name     | Description                                           |
| ---- | -------- | ----------------------------------------------------- |
| 0    | init     | Start the DMA transfer when set to 1                  |
| 1    | intr_en  | Enable interrupt on transfer completion when set to 1 |
| 31:2 | reserved | Reserved for future use                               |

### stat (0x14)

- **Type**: Read-Only
- **Description**: This status register indicates the current state of the DMA operation.

| Bit  | Name     | Description                                            |
| ---- | -------- | ------------------------------------------------------ |
| 0    | busy     | Indicates if the DMA is currently busy (1) or idle (0) |
| 1    | error    | Indicates if an error occurred during the transfer (1) |
| 31:2 | reserved | Reserved for future use                                |
