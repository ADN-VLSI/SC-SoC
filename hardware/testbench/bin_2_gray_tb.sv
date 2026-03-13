////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Testbench for Binary to Gray Code Converter
//
//    Description : This testbench verifies the functionality of the bin_2_gray converter module.
//                  It uses an up counter to generate sequential binary values from 0 to 2^WIDTH-1.
//                  Each binary value is converted to its Gray code equivalent and verified.
//                  The testbench parameter WIDTH is parameterized and initially set to 8.
//
//    Test Flow   :
//                  1. Reset the system
//                  2. Initialize counter to 0
//                  3. For each cycle:
//                     - Apply current counter value to DUT binary input (bin_i)
//                     - Read Gray code output (gray_o)
//                     - Compare with expected Gray code value
//                     - Increment counter
//                  4. Continue until counter overflows (completes full range)
//
//    Author      : Motasim Faiyaz
//
//    Date        : February 26, 2026
//
///////////////////////////////////////////////////////////////////////////////////////////////////


module bin_2_gray_tb;

  localparam int WIDTH = 8;  // Width of binary input and Gray output

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Testbench Signals
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic [WIDTH-1:0] bin_stimulus;  // Binary input stimulus from up counter
  logic [WIDTH-1:0] gray_response;  // Gray code output from DUT
  int               test_count;  // Counter for number of test cases
  int               pass_count;  // Counter for passed test cases
  int               fail_count;  // Counter for failed test cases

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Function to calculate expected Gray code
  ////////////////////////////////////////////////////////////////////////////////////////////////

  function logic [WIDTH-1:0] binary_to_gray(logic [WIDTH-1:0] binary_val);
    return binary_val ^ (binary_val >> 1);
  endfunction

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Instantiate the Device Under Test (DUT)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  bin_2_gray #(
      .WIDTH(WIDTH)
  ) dut_instance (
      .bin_i (bin_stimulus),
      .gray_o(gray_response)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Verification Task
  ////////////////////////////////////////////////////////////////////////////////////////////////

  task verify_gray_output();
    if (gray_response == binary_to_gray(bin_stimulus)) begin
      pass_count++;
      $display("[PASS] Binary: %0d (0x%h) → Gray: %0d (0x%h)", bin_stimulus, bin_stimulus,
               gray_response, gray_response);
    end else begin
      fail_count++;
      $display("[FAIL] Binary: %0d (0x%h) → Gray: %0d (0x%h) | Expected: %0d (0x%h)",
               bin_stimulus, bin_stimulus, gray_response, gray_response, binary_to_gray(
               bin_stimulus), binary_to_gray(bin_stimulus));
    end
  endtask

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Test Stimulus and Verification
  ////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    $display("\n");
    $display("================================================================================");
    $display("           Binary to Gray Code Converter Testbench");
    $display("           WIDTH = %0d bits", WIDTH);
    $display("================================================================================");
    $display("\n");

    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    // Test all possible binary values from 0 to 2^WIDTH-1
    for (int i = 0; i < (1 << WIDTH); i++) begin
      // Apply binary stimulus to DUT
      bin_stimulus <= i;

      // // forced error injection for testing purposes (uncomment to test failure cases)
      // if (i == 3) force dut_instance.bin_i = 0;
      // else release dut_instance.bin_i;

      // Wait one time unit for combinational logic to settle
      #1;

      // Verify the Gray code output
      verify_gray_output();
      test_count++;
    end

    // Display final test results
    $display("\n");
    $display("================================================================================");
    $display("                         Test Summary");
    $display("================================================================================");
    $display("Total Test Cases : %0d", test_count);
    $display("Passed           : %0d", pass_count);
    $display("Failed           : %0d", fail_count);
    $display("================================================================================\n");

    if (fail_count == 0) begin
      $display("✓ All tests PASSED!");
    end else begin
      $display("✗ Some tests FAILED!");
    end
    $display("\n");

    $finish;
  end

endmodule

