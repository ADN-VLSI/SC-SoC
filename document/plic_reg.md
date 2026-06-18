# PLIC Register Map

| Register Name         | Address Offset | Description                    |
| --------------------- | -------------- | ------------------------------ |
| RESERVED              | 0x000000       | RESERVED                       |
| intr_src_01_prio      | 0x000004       | Interrupt Source 01 Priority   |
| intr_src_02_prio      | 0x000008       | Interrupt Source 02 Priority   |
| intr_src_03_prio      | 0x00000C       | Interrupt Source 03 Priority   |
| intr_src_04_prio      | 0x000010       | Interrupt Source 04 Priority   |
| intr_src_05_prio      | 0x000014       | Interrupt Source 05 Priority   |
| intr_src_06_prio      | 0x000018       | Interrupt Source 06 Priority   |
| intr_src_07_prio      | 0x00001C       | Interrupt Source 07 Priority   |
| intr_src_08_prio      | 0x000020       | Interrupt Source 08 Priority   |
| intr_src_09_prio      | 0x000024       | Interrupt Source 09 Priority   |
| intr_src_10_prio      | 0x000028       | Interrupt Source 10 Priority   |
| intr_src_11_prio      | 0x00002C       | Interrupt Source 11 Priority   |
| intr_src_12_prio      | 0x000030       | Interrupt Source 12 Priority   |
| intr_src_13_prio      | 0x000034       | Interrupt Source 13 Priority   |
| intr_src_14_prio      | 0x000038       | Interrupt Source 14 Priority   |
| intr_src_15_prio      | 0x00003C       | Interrupt Source 15 Priority   |
| intr_src_16_prio      | 0x000040       | Interrupt Source 16 Priority   |
| intr_src_17_prio      | 0x000044       | Interrupt Source 17 Priority   |
| intr_src_18_prio      | 0x000048       | Interrupt Source 18 Priority   |
| intr_src_19_prio      | 0x00004C       | Interrupt Source 19 Priority   |
| intr_src_20_prio      | 0x000050       | Interrupt Source 20 Priority   |
| intr_src_21_prio      | 0x000054       | Interrupt Source 21 Priority   |
| intr_src_22_prio      | 0x000058       | Interrupt Source 22 Priority   |
| intr_src_23_prio      | 0x00005C       | Interrupt Source 23 Priority   |
| intr_src_24_prio      | 0x000060       | Interrupt Source 24 Priority   |
| intr_src_25_prio      | 0x000064       | Interrupt Source 25 Priority   |
| intr_src_26_prio      | 0x000068       | Interrupt Source 26 Priority   |
| intr_src_27_prio      | 0x00006C       | Interrupt Source 27 Priority   |
| intr_src_28_prio      | 0x000070       | Interrupt Source 28 Priority   |
| intr_src_29_prio      | 0x000074       | Interrupt Source 29 Priority   |
| intr_src_30_prio      | 0x000078       | Interrupt Source 30 Priority   |
| intr_src_31_prio      | 0x00007C       | Interrupt Source 31 Priority   |
| intr_src_32_prio      | 0x000080       | Interrupt Source 32 Priority   |
| ---                   | ---            | ---                            |
| enable_src3100_core_0 | 0x002000       | Enable Source 31-00 for Core 0 |
| enable_src6332_core_0 | 0x002004       | Enable Source 63-32 for Core 0 |
| ---                   | ---            | ---                            |
| enable_src3100_core_1 | 0x002080       | Enable Source 31-00 for Core 1 |
| enable_src6332_core_1 | 0x002084       | Enable Source 63-32 for Core 1 |
| ---                   | ---            | ---                            |
| core_0_threshold      | 0x200000       | Core 0 Threshold               |
| claim_id_core_0       | 0x200004       | Core 0 Claim ID                |
| ---                   | ---            | ---                            |
| core_1_threshold      | 0x201000       | Core 1 Threshold               |
| claim_id_core_1       | 0x201004       | Core 1 Claim ID                |
