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


module bin_2_gray_tb #(
    parameter int WIDTH = 8  // Width of binary input and Gray output
);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Testbench Signals
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic [WIDTH-1:0] bin_stimulus;  // Binary input stimulus from up counter
  logic [WIDTH-1:0] gray_response; // Gray code output from DUT
  int               test_count;    // Counter for number of test cases
  int               pass_count;    // Counter for passed test cases
  int               fail_count;    // Counter for failed test cases

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Function to calculate expected Gray code
  ////////////////////////////////////////////////////////////////////////////////////////////////

  function logic [WIDTH-1:0] binary_to_gray(logic [WIDTH-1:0] binary_val);
    logic [WIDTH-1:0] gray_val;
    gray_val[WIDTH-1] = binary_val[WIDTH-1];
    for (int i = WIDTH-2; i >= 0; i--) begin

        gray_val[i] = binary_val[i] ^ binary_val[i+1];
    end
    return gray_val;
  endfunction

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Instantiate the Device Under Test (DUT)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  bin_2_gray #(.WIDTH(WIDTH)) dut_instance (
      .bin_i(bin_stimulus),
      .gray_o(gray_response)
  );

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
        bin_stimulus = i;

		// Wait one time unit for combinational logic to settle
		#1;

		// Verify the Gray code output
		verify_gray_output(i);
		test_count++;
    end

    // Display final test results
    $display("\n");
    $display("================================================================================");
    $display("                         Test Summary");
    $display("================================================================================");
    $display("Total Test Cases : %0d", test_count);
    $display("Passed          : %0d", pass_count);
    $display("Failed          : %0d", fail_count);
    $display("================================================================================\n");

    if (fail_count == 0) begin
        $display("✓ All tests PASSED successfully!");
    end else begin
        $display("✗ Some tests FAILED successfully!");
    end
    $display("\n");

    $finish;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Verification Task
  ////////////////////////////////////////////////////////////////////////////////////////////////

  task verify_gray_output(int binary_input);
        logic [WIDTH-1:0] expected_gray;
    expected_gray = binary_to_gray(binary_input);

    if (gray_response == expected_gray) begin
		pass_count++;
      $display("[PASS] Binary: %0d (0x%h) → Gray: %0d (0x%h)", binary_input, binary_input,
               gray_response, gray_response);
    end else begin
		fail_count++;
      $display("[FAIL] Binary: %0d (0x%h) → Gray: %0d (0x%h) | Expected: %0d (0x%h)",
               binary_input, binary_input, gray_response, gray_response, expected_gray,
               expected_gray);
    end
  endtask

endmodule

