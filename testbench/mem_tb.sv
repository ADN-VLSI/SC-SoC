module mem_tb;

  // -----------------------------------------
  // Parameters 
  // -----------------------------------------
  localparam int ADDR_WIDTH    = 4;
  localparam int DATA_WIDTH    = 32;
  localparam int NUM_ROW_BYTES = DATA_WIDTH/8;
  localparam int LG_ROW_BYTES  = $clog2(NUM_ROW_BYTES);
  localparam int DEPTH_WORDS   = 1 << (ADDR_WIDTH - LG_ROW_BYTES);

  // -----------------------------------------
  // DUT Signals
  // -----------------------------------------
  logic                      clk_i;
  logic [ADDR_WIDTH-1:0]     addr_i;
  logic                      we_i;
  logic [DATA_WIDTH-1:0]     wdata_i;
  logic [NUM_ROW_BYTES-1:0]  wstrb_i;
  logic [DATA_WIDTH-1:0]     rdata_o;

  // -----------------------------------------
  // DUT Instantiation
  // -----------------------------------------
  mem #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i   (clk_i),
    .addr_i  (addr_i),
    .we_i    (we_i),
    .wdata_i (wdata_i),
    .wstrb_i (wstrb_i),
    .rdata_o (rdata_o)
  );

  // -----------------------------------------
  // Simple Waveform Dump
  // -----------------------------------------
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, mem_tb);
  end

  // -----------------------------------------
  // Clock Generation
  // -----------------------------------------
  initial clk_i = 0;
  always #5 clk_i = ~clk_i;

  // -----------------------------------------
  // Row Index Function
  // -----------------------------------------
  function automatic int unsigned row_idx(input logic [ADDR_WIDTH-1:0] a);
    return (a >> LG_ROW_BYTES);
  endfunction

  // -----------------------------------------
  // Scoreboard
  // -----------------------------------------
  logic [DATA_WIDTH-1:0] ref_mem   [0:DEPTH_WORDS-1];
  bit                   init_done [0:DEPTH_WORDS-1];

  task automatic sb_apply_write(
    input logic [ADDR_WIDTH-1:0]    addr,
    input logic [DATA_WIDTH-1:0]    wdata,
    input logic [NUM_ROW_BYTES-1:0] wstrb
  );
    int unsigned wi = row_idx(addr);

    for (int b = 0; b < NUM_ROW_BYTES; b++) begin
      if (wstrb[b])
        ref_mem[wi][8*b +: 8] = wdata[8*b +: 8];
    end

    init_done[wi] = 1'b1;
  endtask

  task automatic sb_check_read(input logic [ADDR_WIDTH-1:0] addr);
    int unsigned wi = row_idx(addr);

    if (!init_done[wi]) begin
      $display("[SB] Skip (uninitialized) addr=%0d", addr);
      return;
    end

    if (rdata_o !== ref_mem[wi])
      $error("[SB] FAIL addr=%0d exp=%h got=%h",
             addr, ref_mem[wi], rdata_o);
    else
      $display("[SB] PASS addr=%0d data=%h",
               addr, rdata_o);
  endtask

  // -----------------------------------------
  // Driver Tasks
  // -----------------------------------------
  task automatic drive_idle();
    addr_i  = 0;
    we_i    = 0;
    wdata_i = 0;
    wstrb_i = 0;
  endtask

  task automatic do_write(
    input logic [ADDR_WIDTH-1:0]    addr,
    input logic [DATA_WIDTH-1:0]    wdata,
    input logic [NUM_ROW_BYTES-1:0] wstrb
  );
    addr_i  = addr;
    wdata_i = wdata;
    wstrb_i = wstrb;
    we_i    = 1;

    @(posedge clk_i);
    we_i = 0;

    #1; // allow read to settle
    sb_apply_write(addr, wdata, wstrb);
  endtask

  task automatic do_read_and_check(input logic [ADDR_WIDTH-1:0] addr);
  addr_i = addr;
  we_i   = 0;

  // allow addr to be seen before clock edge
  #0;

  @(posedge clk_i);
  #1;

  sb_check_read(addr);
endtask

  // -----------------------------------------
  // Testcases
  // -----------------------------------------
  task automatic tc_full_write();
    $display("\n--- TC1: Full Write ---");
    do_write(4'h3, 32'hDEAD_BEEF, 4'b1111);
    do_read_and_check(4'h3);
  endtask

  task automatic tc_partial_write();
    $display("\n--- TC2: Partial Write ---");
    do_write(4'hB, 32'h1122_3344, 4'b1111);
    do_write(4'hB, 32'h0000_00AA, 4'b0001);
    do_read_and_check(4'hB);
  endtask

  task automatic tc_noop();
    $display("\n--- TC3: No-op Write ---");
    do_write(4'h4, 32'hCAFE_BABE, 4'b1111);
    do_write(4'h4, 32'hFFFF_FFFF, 4'b0000);
    do_read_and_check(4'h4);
  endtask

  task automatic tc_same_row();
    $display("\n--- TC4: Same Row Test ---");
    do_write(4'h8, 32'hAAAA_BBBB, 4'b1111);
    do_read_and_check(4'h9);
    do_read_and_check(4'hA);
  endtask

  // -----------------------------------------
  // Main Test Sequence
  // -----------------------------------------
  initial begin
    for (int i = 0; i < DEPTH_WORDS; i++) begin
      ref_mem[i]   = 0;
      init_done[i] = 0;
    end

    drive_idle();
    repeat (2) @(posedge clk_i);

    tc_full_write();
    tc_partial_write();
    tc_noop();
    tc_same_row();

    $display("\nAll tests completed.");
    #10;
    $finish;
  end

endmodule

`default_nettype wire