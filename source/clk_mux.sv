//==============================================================================
// Author:      Adnan Sami Anirban(adnananirban259@gamil.com)
// Date:        2026-02-22
// Module:      clk_mux
// Description: Robust, Glitch-Free Clock Multiplexer using a single-module
//              RTL approach. Implements 2-stage Posedge D-FF synchronization
//              with cross-coupled feedback to ensure safe clock switching.
//==============================================================================

module clk_mux (
    input  logic arst_ni, // Asynchronous reset, active low
    input  logic sel_i,   // Select signal: 0 selects clk0_i, 1 selects clk1_i
    input  logic clk0_i,  // Primary clock input
    input  logic clk1_i,  // Secondary clock input
    output logic clk_o    // Glitch-free multiplexed output clock
);

    // Internal signals for Path 0 (Top row of the architecture diagram)
    logic q0_ff1;
    logic en0; // Final synchronized enable for Path 0

    // Internal signals for Path 1 (Bottom row of the architecture diagram)
    logic q1_ff1;
    logic en1; // Final synchronized enable for Path 1


    //--------------------------------------------------------------------------
    // Path 0 Synchronization Logic (clk0_i domain)
    //--------------------------------------------------------------------------
    // This implements the first AND gate and the two D-FFs for Path 0.
    // The feedback (!en1) ensures clk0 only starts after clk1 is disabled.
    always_ff @(posedge clk0_i or negedge arst_ni) begin
        if (!arst_ni) begin
            q0_ff1 <= 1'b0;
            en0    <= 1'b0;
        end else begin
            q0_ff1 <= (!sel_i) && (!en1); // Handshake + Select capture
            en0    <= q0_ff1;            // Second stage D-FF
        end
    end

    //--------------------------------------------------------------------------
    // Path 1 Synchronization Logic (clk1_i domain)
    //--------------------------------------------------------------------------
    // This implements the first AND gate and the two D-FFs for Path 1.
    // The feedback (!en0) ensures clk1 only starts after clk0 is disabled.
    always_ff @(posedge clk1_i or negedge arst_ni) begin
        if (!arst_ni) begin
            q1_ff1 <= 1'b0;
            en1    <= 1'b0;
        end else begin
            q1_ff1 <= (sel_i) && (!en0);  // Handshake + Select capture
            en1    <= q1_ff1;            // Second stage D-FF
        end
    end

    //--------------------------------------------------------------------------
    // Final Output Gating and Combination
    //--------------------------------------------------------------------------
    // This stage maps to the final AND gates and the OR gate in the diagram.
    // It creates the "Glitch-Free" output by masking the source clocks.
    assign clk_o = (clk0_i & en0) | (clk1_i & en1);

endmodule

