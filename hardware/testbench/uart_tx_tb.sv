module uart_tx_tb;

   // --- Signals ---
   logic       arst_ni;
   logic       clk_i;
   logic [7:0] data_i;
   logic       data_valid_i;
   logic [1:0] data_bits_i;
   logic       parity_en_i;
   logic       parity_type_i;
   logic       extra_stop_i;

   logic       data_ready_o;
   logic       tx_o;

   // --- Verification Variables ---
   logic [7:0] captured_byte;
   int         pass_count = 0;
   int         fail_count = 0;
   
   // --- DUT Instance ---
   uart_tx dut (
       .clk_i        (clk_i),
       .arst_ni      (arst_ni),
       .data_i       (data_i),
       .data_valid_i (data_valid_i),
       .data_bits_i  (data_bits_i),
       .parity_en_i  (parity_en_i),
       .parity_type_i(parity_type_i),
       .extra_stop_i (extra_stop_i),
       .tx_o         (tx_o),
       .data_ready_o (data_ready_o)
   );

// --- Clock Generation ---
   initial clk_i = 0;
   always #5 clk_i = ~clk_i; 

   // IMPROVED MONITOR: Handles Back-to-Back without hanging
   task automatic monitor_and_check(input [7:0] expected_val, input string tc_name);
       captured_byte = 8'h00;
       
       // 1. Wait for Start Bit
       wait(tx_o == 0); 
       
       // 2. Sample bits on the Falling Edge for stability
       @(negedge clk_i); 
       for (int i = 0; i < 8; i++) begin
           @(negedge clk_i);
           captured_byte[i] = tx_o;
       end
       
       // 3. Compare Results
       if (captured_byte === expected_val) begin
           $display("[PASS] %s | Expected: 0x%h, Got: 0x%h", tc_name, expected_val, captured_byte);
           pass_count++;
       end else begin
           $display("[FAIL] %s | Expected: 0x%h, Got: 0x%h", tc_name, expected_val, captured_byte);
           fail_count++;
       end
       
       // 4. FIX: Wait only 1 cycle for the Stop bit, don't wait for "Idle"
       @(posedge clk_i); 
   endtask

   // --- Helper Tasks ---
   task reset_dut();
       arst_ni = 0; data_valid_i = 0;
       #20 arst_ni = 1;
       repeat(5) @(posedge clk_i);
   endtask

   task send_byte(input [7:0] val);
       wait(data_ready_o == 1); 
       @(posedge clk_i);
       data_i = val; data_valid_i = 1;
       @(posedge clk_i);
       data_valid_i = 0;
   endtask

   // --- Watchdog Timer (Prevents infinite hanging) ---
   initial begin
       #5000; // If simulation takes longer than this, kill it
       $display("\n[ERROR] Simulation Timeout! Check for deadlocks.");
       $finish;
   end

   // --- Main Simulation Flow ---
   initial begin
       $dumpfile("uart_tx_tb.vcd");
       $dumpvars(0, uart_tx_tb);
       reset_dut();
       data_bits_i = 3; parity_en_i = 0; extra_stop_i = 0;

       $display("Starting UART TX Full 9-Test Verification...");

       // TC-01 to TC-06
       fork send_byte(8'h00); monitor_and_check(8'h00, "TC-01: All Zeros"); join
       #20; fork send_byte(8'hFF); monitor_and_check(8'hFF, "TC-02: All Ones"); join
       #20; fork send_byte(8'hAA); monitor_and_check(8'hAA, "TC-03: Inverse Checkerboard"); join
       #20; fork send_byte(8'h01); monitor_and_check(8'h01, "TC-04: Walking One - LSB"); join
       #20; fork send_byte(8'h80); monitor_and_check(8'h80, "TC-05: Walking One - MSB"); join
       #20; fork send_byte(8'hF0); monitor_and_check(8'hF0, "TC-06: Nibble Swap"); join

       // TC-07: Back-to-Back (The problematic one)
       $display("\nTC-07: Testing Back-to-Back...");
       fork
           begin 
               send_byte(8'h12); 
               send_byte(8'h34); 
           end
           begin 
               monitor_and_check(8'h12, "TC-07a: Byte 1"); 
               monitor_and_check(8'h34, "TC-07b: Byte 2"); 
           end
       join

       // TC-08: Reset Safety
       $display("\nTC-08: Reset Mid-Send Safety Test");
       send_byte(8'h55);
       repeat(5) @(posedge clk_i);
       arst_ni = 0;
       #15;
       if (tx_o == 1) begin
           $display("[PASS] TC-08: Reset Safety | Line returned to IDLE (1).");
           pass_count++;
       end else begin
           $display("[FAIL] TC-08: Reset Safety | Line stuck at 0!");
           fail_count++;
       end
       arst_ni = 1;
       repeat(5) @(posedge clk_i);

       // TC-09: 8-Bit Integrity
       $display("\nTC-09: 8-Bit Data Integrity Test");
       fork 
           send_byte(8'hC3); 
           monitor_and_check(8'hC3, "TC-09: 8-Bit Integrity"); 
       join

       $display("\n-------------------------------------------");
       $display("FINAL TEST REPORT");
       $display("PASSED: %0d / 9", pass_count);
       $display("-------------------------------------------");
       $finish;
   end
   
endmodule