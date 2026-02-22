module dual_edge_ff (
    input  logic clk,
    input  logic enable,
    input  logic d,
    input  logic arst_ni,
    output logic q
);

logic q_p, q_n;

always_ff @(posedge clk or negedge arst_ni) begin
    if (!arst_ni)
        q_p <= 0;
    else if (enable)
        q_p <= d;
end

always_ff @(negedge clk or negedge arst_ni) begin
    if (!arst_ni)
        q_n <= 0;
    else if (enable)
        q_n <= d;
end

assign q = clk ? q_p : q_n;

endmodule