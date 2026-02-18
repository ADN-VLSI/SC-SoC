module gray_2_bin #(
    // Width of the gray input and binary output
    parameter int WIDTH = 8
) (
    // Gray code input
    input  logic [WIDTH-1:0] gray_i,

    // Binary output
    output logic [WIDTH-1:0] bin_o
);

endmodule
