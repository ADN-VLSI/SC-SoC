# Clock Divider Verification Plan

## Target DUT
The `clk_div` module is a parameterized clock divider that generates a lower-frequency output clock from a higher-frequency reference clock. The division ratio is programmable via an input control signal. The design uses a counter-based toggle mechanism and dual-edge output generation to improve duty-cycle characteristics.

## Parameters
|Parameter| Description|
|-|-|
|`DIV_WIDTH`|Width of the division control input `div_i`. Determines maximum programmable division factor.|

## Ports
|Port Name|Direction|Width|Description|
|-|-|-|-|
|`clk_i`|Input|1|Reference input clock|
|`div_i`|Input|`DIV_WIDTH`|Programmable division factor|
|`arst_ni`|Input|1|Asynchronous active-low reset|
|`clk_o`|Output|1|Divided clock output|

## Challenges and Risks
|Risk|Description|
|-|-|
|`div_i`=0|Illegal Value|
|Small div value|div=1 edge case|
|Reset mid-cycle| Async reset hazards|
|Odd divide values|Non 50% duty cycle|
|Dual edge timing|Glitch posibilities|

## Test Cases
|Test case|Description|Expected Output|
|-|-|-|
|`clkdiv_01` /Reset Behaviour|verify async reset clears counter and output|clk_o=0|
|`clkdiv_02` /Maximum Division|`div_i`=15||

