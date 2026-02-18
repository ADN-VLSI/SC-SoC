module bin_2_gray #(
    // Width of the binary input and gray output
    parameter int WIDTH = 8
) (
    // Binary input
    input  logic [WIDTH-1:0] bin_i,

    // Gray code output
    output logic [WIDTH-1:0] gray_o
);

endmodule
