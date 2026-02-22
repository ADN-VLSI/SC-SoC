# Generic Memory Module
# Author: Md. Samir Hasan(shamirhasan2.0@gmail.com)

# TOP_IO

<img src="./memtop.svg">

# Description

<img src="./memory.svg">
The generic memory module is a parameterized System verilog memory module.It uses demultiplexer, flipflip(storage), multiplexer to control the memory.


# Parameter


|Name|Type|Dimention|Default Value|Description|
|-|-|-|-|-|
|ADDR_WIDTH|int| |16|Address width in bits|
|DATA_WIDTH|int| |32||Data width in bits|

# Port

|Name|Direction|Type|Width|Description|
|-|-|-|-|-|
|clk_i|input|logic|1|clock input|
|addr_i|input|logic|ADDE_WIDTH|Address input (shared for read and write)|
|we_i|input|logic|1|Write enable|
|wdata_i|input|input|logic|DATA_WIDTH|Write data|
|wstrb_i|input|logic|DATA_WIDTH/8|Byte write enable (1 bit per byte)|
|rdata_o|output|logic|DATA_WIDTH|Read data output|

