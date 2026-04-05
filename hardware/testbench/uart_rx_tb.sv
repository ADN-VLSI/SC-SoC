`include "../include/package/uart_pkg.sv"

module uart_rx_tb;

  parameter OVERSAMPLE = 16;

  // DUT signals
  logic        clk_i;
  logic        arst_ni;
  logic        rx_i;
  logic [1:0]  data_bits_i;
  logic        parity_en_i;
  logic        parity_type_i;
  logic [7:0]  data_o;
  logic        data_valid_o;
  logic        parity_error_o;

  // Clock generation
  initial clk_i = 0;
  always #5 clk_i = ~clk_i;

  // DUT
  uart_rx dut (
    .clk_i(clk_i),
    .arst_ni(arst_ni),
    .rx_i(rx_i),
    .data_bits_i(data_bits_i),
    .parity_en_i(parity_en_i),
    .parity_type_i(parity_type_i),
    .data_o(data_o),
    .data_valid_o(data_valid_o),
    .parity_error_o(parity_error_o)
  );

  // --------------------------------------------------
  // Helper: get actual number of bits
  // --------------------------------------------------
  function int get_data_bits(input logic [1:0] sel);
    case (sel)
      2'd0: return 5;
      2'd1: return 6;
      2'd2: return 7;
      2'd3: return 8;
    endcase
  endfunction

  // --------------------------------------------------
  // UART FRAME DRIVER
  // --------------------------------------------------
  task send_uart_frame(
    input logic [7:0] data,
    input logic [1:0] data_sel,
    input bit parity_en,
    input bit parity_type,
    input int stop_bits,
    input bit inject_parity_error = 0,
    input bit bad_stop = 0
  );

    int nbits;
    bit parity;
    logic [7:0] masked_data;
    int i;

    nbits = get_data_bits(data_sel);

    // Mask unused upper bits
    masked_data = data & ((1 << nbits) - 1);

    // Compute parity ONLY on valid bits
    parity = ^masked_data[nbits-1:0];

    // Adjust parity type
    if (parity_type == 0) parity = ~parity; // even

    if (inject_parity_error)
      parity = ~parity;

    // ---------------- START BIT ----------------
    rx_i = 0;
    repeat (OVERSAMPLE) @(posedge clk_i);

    // ---------------- DATA ----------------
    for (i = 0; i < nbits; i++) begin
      rx_i = masked_data[i];
      repeat (OVERSAMPLE) @(posedge clk_i);
    end

    // ---------------- PARITY ----------------
    if (parity_en) begin
      rx_i = parity;
      repeat (OVERSAMPLE) @(posedge clk_i);
    end

    // ---------------- STOP ----------------
    for (i = 0; i < stop_bits; i++) begin
      rx_i = (bad_stop && i == 0) ? 0 : 1;
      repeat (OVERSAMPLE) @(posedge clk_i);
    end

    // Idle
    rx_i = 1;
    repeat (OVERSAMPLE) @(posedge clk_i);

  endtask

  // --------------------------------------------------
  // COVERGROUP (TEST INTENT DOCUMENTED HERE)
  // --------------------------------------------------
  covergroup uart_cg @(posedge clk_i);

    coverpoint data_bits_i {
      bins b5 = {0};
      bins b6 = {1};
      bins b7 = {2};
      bins b8 = {3};
    }

    coverpoint parity_en_i {
      bins off = {0};
      bins on  = {1};
    }

    coverpoint parity_type_i {
      bins even = {0};
      bins odd  = {1};
    }

    coverpoint data_o {
      bins zero = {8'h00};
      bins ones = {8'hFF};
      bins mid  = default;
    }

    coverpoint parity_error_o {
      bins no_err = {0};
      bins err    = {1};
    }

    cross data_bits_i, parity_en_i, parity_type_i;

  endgroup

  uart_cg cg = new();

  // --------------------------------------------------
  // MONITOR + SELF CHECK
  // --------------------------------------------------
  logic [7:0] expected_data;
  logic expected_parity_error;

  always @(posedge clk_i) begin
    if (data_valid_o) begin
      $display("Time=%0t DATA=0x%0h PARITY_ERR=%0b",
               $time, data_o, parity_error_o);

      // Basic check
      if (data_o !== expected_data)
        $error("DATA MISMATCH! Expected=0x%0h Got=0x%0h",
                expected_data, data_o);

      if (parity_error_o !== expected_parity_error)
        $error("PARITY FLAG MISMATCH!");

      cg.sample();
    end
  end

  // --------------------------------------------------
  // TEST SEQUENCE
  // --------------------------------------------------
  initial begin

    // Init
    rx_i = 1;
    arst_ni = 0;
    data_bits_i = 2'd3;
    parity_en_i = 0;
    parity_type_i = 0;

    repeat (10) @(posedge clk_i);
    arst_ni = 1;

    // ---------------- BASIC TEST ----------------
    expected_data = 8'hA5;
    expected_parity_error = 0;
    send_uart_frame(8'hA5, 2'd3, 0, 0, 1);

    // ---------------- ALL ZERO ----------------
    expected_data = 8'h00;
    send_uart_frame(8'h00, 2'd3, 0, 0, 1);

    // ---------------- ALL ONES ----------------
    expected_data = 8'hFF;
    send_uart_frame(8'hFF, 2'd3, 0, 0, 1);

    // ---------------- EVEN PARITY ----------------
    parity_en_i = 1;
    parity_type_i = 0;
    expected_data = 8'h3C;
    expected_parity_error = 0;
    send_uart_frame(8'h3C, 2'd3, 1, 0, 1);

    // ---------------- ODD PARITY ----------------
    parity_type_i = 1;
    expected_data = 8'h55;
    send_uart_frame(8'h55, 2'd3, 1, 1, 1);

    // ---------------- PARITY ERROR ----------------
    expected_data = 8'hAA;
    expected_parity_error = 1;
    send_uart_frame(8'hAA, 2'd3, 1, 0, 1, 1);

    // ---------------- VARIABLE DATA WIDTH ----------------
    data_bits_i = 2'd0; // 5-bit
    expected_data = 8'h1F;
    send_uart_frame(8'h1F, 2'd0, 0, 0, 1);

    data_bits_i = 2'd1; // 6-bit
    expected_data = 8'h2F;
    send_uart_frame(8'h2F, 2'd1, 0, 0, 1);

    data_bits_i = 2'd2; // 7-bit
    expected_data = 8'h6F;
    send_uart_frame(8'h6F, 2'd2, 0, 0, 1);

    data_bits_i = 2'd3; // 8-bit
    expected_data = 8'hAF;
    send_uart_frame(8'hAF, 2'd3, 0, 0, 1);

    // ---------------- FRAMING ERROR ----------------
    expected_data = 8'h99;
    expected_parity_error = 0;
    send_uart_frame(8'h99, 2'd3, 0, 0, 1, 0, 1);

    // ---------------- FALSE START ----------------
    rx_i = 0;
    repeat (4) @(posedge clk_i); // too short
    rx_i = 1;

    repeat (20) @(posedge clk_i);

    // ---------------- BACK-TO-BACK ----------------
    expected_data = 8'h12;
    send_uart_frame(8'h12, 2'd3, 0, 0, 1);

    expected_data = 8'h34;
    send_uart_frame(8'h34, 2'd3, 0, 0, 1);

    // ---------------- RESET MID FRAME ----------------
    fork
      send_uart_frame(8'hAB, 2'd3, 0, 0, 1);
      begin
        repeat (10) @(posedge clk_i);
        arst_ni = 0;
        repeat (5) @(posedge clk_i);
        arst_ni = 1;
      end
    join

    repeat (100) @(posedge clk_i);
    $finish;

  end

endmodule