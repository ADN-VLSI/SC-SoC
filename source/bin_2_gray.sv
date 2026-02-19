////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Binary to Gray Code Converter
//
//    Description : This module converts binary input value into its equivalent Gray code output.
//                  Gray code ensures that only one bit changes between consecutive values,
//                  which helps reduce glitches and metastability issues in digital systems.
//
//                  This implementation is parameterized and supports configurable data width.
//                  The conversion rule used is:
//
//                  Gray[MSB] = Binary[MSB]
//                  Gray[i]   = Binary[i] XOR Binary[i+1]
//
//                  ## Functional Description
//
//                  | SIGNAL | TYPE | DESCRIPTION |
//                  |--------|------|-------------|
//                  | bin_i  | IN   | Binary input value |
//                  | gray_o | OUT  | Gray code output value |
//
//    Author      : Shykul Islam
//
//    Date        : February 19, 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////


module bin_2_gray #(
    parameter int WIDTH = 8  // Width of binary input and Gray output
) (

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Input / Output Signals
    ////////////////////////////////////////////////////////////////////////////////////////////////

    input  logic [WIDTH-1:0] bin_i,   // Binary input
    output logic [WIDTH-1:0] gray_o   // Gray code output
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Combinational Logic
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // MSB remains same in Gray code
  assign gray_o[WIDTH-1] = bin_i[WIDTH-1];

  // Remaining bits generated using XOR operation
  assign gray_o[WIDTH-2:0] = bin_i[WIDTH-2:0] ^ bin_i[WIDTH-1:1];

endmodule

