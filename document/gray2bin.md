# Gray to Binary
Gray code is a binary numbering system where only one bit changes at a time, and converting it back to binary follows a simple XOR pattern.

## Top IO
![TOP IO](gray2bin_top.svg)

## Description
Gray code is a binary numbering system where only one bit changes between consecutive numbers. Converting Gray code to binary ensures standard binary representation is recovered. The first binary bit is the same as the first Gray bit. Each subsequent binary bit is calculated by XOR-ing the previous binary bit with the current Gray bit. This method is widely used in digital circuits to prevent errors during signal transitions.

![gray2bin](gray2bin.svg)

## Parameter
|Name|Type|Default Value|Description|
|----|----|-------------|-----------|
|DATA_WIDTH|Int||8|width of the data.This is the number of bits in the gray and binary code|


## Ports
|Name|Direction|Type|Description|
|----|---------|----|-----------|
|`gray_i`|input|logic [DATA_WIDTH-1:0]|Gray code input.|
|`bin_o`|output|logic [DATA_WIDTH-1:0]|Binary code output.|



