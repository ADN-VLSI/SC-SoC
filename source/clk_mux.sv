module clk_mux (
    // Asynchronous reset, active low
    input logic arst_ni,
    // Select signal: 0 selects clk0_i, 1 selects clk1_i
    input logic sel_i,

    // First clock input
    input logic clk0_i,
    // Second clock input
    input logic clk1_i,

    // Output clock, selected based on sel_i
    output logic clk_o
);

endmodule
