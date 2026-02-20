//==============================================================================
// Author:      Adnan Sami Anirban
// Date:        2026-02-20
// Module:      clk_mux
// Standard:    SystemVerilog / Industry RTL
// Description: Glitch-free Clock Multiplexer using only Positive-Edge D-FFs.
//              Uses cross-coupled feedback to prevent clock contention.
//==============================================================================

/**
 * Sub-module: clk_sync_gate
 * Implements a 2-stage positive-edge synchronizer with feedback-based enabling.
 */
module clk_sync_gate (
    input  logic clk_i,        // Clock source
    input  logic arst_ni,      // Asynchronous reset, active low
    input  logic sel_req_i,    // Request for this specific clock
    input  logic other_off_ni, // Feedback: High if the other clock is OFF
    output logic en_o          // Final enable signal for the clock gate
);

    logic q_sync_stage1;
    logic q_sync_stage2;

    // 2-Stage Positive-Edge Synchronizer
    // Stage 1: Captures the select request and the "other clock is off" status.
    // Stage 2: Final synchronized enable signal.
    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            q_sync_stage1 <= 1'b0;
            q_sync_stage2 <= 1'b0;
        end else begin
            q_sync_stage1 <= sel_req_i && other_off_ni;
            q_sync_stage2 <= q_sync_stage1;
        end
    end

    // Output is taken from the second posedge FF
    assign en_o = q_sync_stage2;

endmodule

//==============================================================================

/**
 * Top Module: clk_mux
 * Multiplexes two clocks using the synchronized gate modules.
 */
module clk_mux (
    input  logic arst_ni, // Asynchronous reset, active low
    input  logic sel_i,   // 0: Select clk0_i, 1: Select clk1_i
    input  logic clk0_i,  // First clock input
    input  logic clk1_i,  // Second clock input
    output logic clk_o    // Multiplexed output clock
);

    // Internal enable signals for cross-coupling feedback
    logic en0, en1;

    //--------------------------------------------------------------------------
    // Path 0 Synchronization (Active when sel_i is 0)
    //--------------------------------------------------------------------------
    clk_sync_gate path0_inst (
        .clk_i        (clk0_i),
        .arst_ni      (arst_ni),
        .sel_req_i    (!sel_i), // Request clk0 when sel is 0
        .other_off_ni (!en1),   // Only enable if Path 1 is confirmed OFF
        .en_o         (en0)
    );

    //--------------------------------------------------------------------------
    // Path 1 Synchronization (Active when sel_i is 1)
    //--------------------------------------------------------------------------
    clk_sync_gate path1_inst (
        .clk_i        (clk1_i),
        .arst_ni      (arst_ni),
        .sel_req_i    (sel_i),  // Request clk1 when sel is 1
        .other_off_ni (!en0),   // Only enable if Path 0 is confirmed OFF
        .en_o         (en1)
    );

    //--------------------------------------------------------------------------
    // Final Gating Stage
    //--------------------------------------------------------------------------
    // Logic ensures that only one enable (en0 or en1) is high at any time.
    assign clk_o = (clk0_i & en0) | (clk1_i & en1);

endmodule

