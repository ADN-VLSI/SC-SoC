// ==================================================================================================
// Module      : fifo_tb
// Author      : Md. Samir Hasan
// Description : Parameterized synchronous Handshake FIFO implemented in Testbench.
//
//               Verification Methodology:
//
//               - Interface-based driving: Uses a Valid-Ready handshake.
//               - Task-oriented stimulus: Encapsulates bus protocols in push/pop tasks.
//               - Corner-case testing: Specifically targets boundary conditions (Full/Empty).
//
//               Test Case Scenarios:
//
//               1. Single Write/Read      : Validates the primary data path and basic flag logic.
//               2. Multiple Write/Read    : Verifies pointer incrementing and FIFO ordering.
//               3. FIFO Full Condition    : Confirms backpressure mechanism (ready_o de-assertion).
//               4. Simultaneous R/W       : Tests concurrent pointer/counter updates in a 
//                                          single clock cycle (Zero-latency turnaround).
//               5. Random Stress Test     : Evaluates stability under non-deterministic traffic 
//                                          patterns using $urandom.
//
// ==================================================================================================

module fifo_tb;

    // Parameters
    parameter int DATA_WIDTH = 8;
    parameter int FIFO_SIZE  = 4;
    localparam int FIFO_DEPTH = 2**FIFO_SIZE;

    // Signals
    logic clk;
    logic arst_ni;
    logic [DATA_WIDTH-1:0] data_i;
    logic data_i_valid_i;
    logic data_i_ready_o;
    logic [DATA_WIDTH-1:0] data_o;
    logic data_o_valid_o;
    logic data_o_ready_i;

    // Clock Generation
    always #5 clk = ~clk;

    // DUT Instantiation using Explicit Named Mapping
    fifo #(
        .DATA_WIDTH (DATA_WIDTH), // Pass parameters
        .FIFO_SIZE  (FIFO_SIZE)
    ) dut (
        .clk_i          (clk),            // Clock
        .arst_ni        (arst_ni),        // Async Reset (Active Low)
        
        // Input Interface
        .data_i         (data_i),         // Data Input
        .data_i_valid_i (data_i_valid_i), // Input Valid
        .data_i_ready_o (data_i_ready_o), // Input Ready (Full status)
        
        // Output Interface
        .data_o         (data_o),         // Data Output
        .data_o_valid_o (data_o_valid_o), // Output Valid (Empty status)
        .data_o_ready_i (data_o_ready_i)  // Output Ready
    );


    // --- Helper Tasks ---

    // Task to push data into FIFO

    task push(input [DATA_WIDTH-1:0] val);
        data_i_valid_i = 1;
        data_i = val;
        wait(data_i_ready_o); // Wait until FIFO is ready
        @(posedge clk);
        data_i_valid_i = 0;
    endtask

    // Task to pop data from FIFO
    task pop(output [DATA_WIDTH-1:0] val);
        data_o_ready_i = 1;
        wait(data_o_valid_o); // Wait until data is available
        val = data_o;
        @(posedge clk);
        data_o_ready_i = 0;
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Initialize
        clk = 0;
        arst_ni = 0;
        data_i = 0;
        data_i_valid_i = 0;
        data_o_ready_i = 0;

        // Reset
        repeat(2) @(posedge clk);
        arst_ni = 1;
        repeat(2) @(posedge clk); //optional for sattle time

        // Single Write and Read
        $display("Test 1: Single Write and Read");
        push(8'hA1);
         $display("Write data 8'hA1 to the memory");
        pop(data_o);
        $display("Read back: %h", data_o);

        // Multiple Write and Read
        $display("Test 2: Multiple Write and Read");
        push(8'hB1);
        push(8'hB2);
        push(8'hB3);
        repeat(3) begin
            pop(data_o);
            $display("Read back: %h", data_o);
        end

        // FIFO Full Condition
        $display("Test 3: Filling FIFO to Capacity (%0d entries)", FIFO_DEPTH);
        for(int i=0; i<FIFO_DEPTH; i++) begin
            push(i[7:0]);
        end
        #1; 
        if(data_i_ready_o == 0) $display("Status: FIFO is FULL (Correct)");
        
        // Empty it
        for(int i=0; i<FIFO_DEPTH; i++) pop(data_o);

        // Simultaneous Read and Write
        // We fill it halfway first, then read and write at the same time
        $display("Test 4: Simultaneous Read and Write");
        push(8'hCC); 
        fork
            push(8'hDD); // Write next value
            pop(data_o);  // Read CC
        join
        $display("Simul-Read got: %h", data_o);
        pop(data_o);
        $display("Final-Read got: %h", data_o);

        // Random Read and Write
        $display("Test 5: Random Stress Test");
        for(int i=0; i<50; i++) begin
            fork
                begin
                    if($urandom_range(0,1)) push($urandom);
                end
                begin
                    if($urandom_range(0,1) && data_o_valid_o) pop(data_o);
                end
            join
            @(posedge clk);
        end

        #50;
        $display("Tests Completed.");
        $finish;
    end

endmodule
