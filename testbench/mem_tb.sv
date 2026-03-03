`timescale 1ns/1ps
`default_nettype none

module mem_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH = 8;
  localparam int DATA_WIDTH = 32;

  localparam int NUM_ROW_BYTES = DATA_WIDTH/8;              // 4 bytes for 32-bit
  localparam int LG_ROW_BYTES  = $clog2(NUM_ROW_BYTES);     // 2 for 4 bytes
  localparam int DEPTH_WORDS   = 1 << (ADDR_WIDTH-LG_ROW_BYTES);

  localparam realtime CLK_PERIOD = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic                             clk_i;
  logic     [  ADDR_WIDTH-1:0]      addr_i;
  logic                             we_i;
  logic     [  DATA_WIDTH-1:0]      wdata_i;
  logic     [DATA_WIDTH/8-1:0]      wstrb_i;
  logic     [  DATA_WIDTH-1:0]      rdata_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TB VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  bit                               clock_enable;
  bit                               is_clock_aligned;

  semaphore                         bus_access = new(1);

  int                               case_pass = 0;
  int                               case_fail = 0;

  // Byte-addressable golden model organized per "row/word"
  logic [NUM_ROW_BYTES-1:0][7:0] mem_model [DEPTH_WORDS-1:0];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INSTANTIATIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  mem #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk_i  (clk_i),
      .addr_i (addr_i),
      .we_i   (we_i),
      .wdata_i(wdata_i),
      .wstrb_i(wstrb_i),
      .rdata_o(rdata_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function automatic int row_index(input logic [ADDR_WIDTH-1:0] a);
    return a[ADDR_WIDTH-1:LG_ROW_BYTES];
  endfunction

  task automatic apply_reset(input realtime duration);
    #(duration);
    clk_i   <= '0;
    addr_i  <= '0;
    we_i    <= '0;
    wdata_i <= '0;
    wstrb_i <= '0;
    #(duration);
  endtask

  task automatic enable_clock();
    clock_enable <= 1;
    @(posedge clk_i);
  endtask

  task automatic disable_clock();
    @(posedge clk_i);
    clock_enable <= 0;
  endtask

  task automatic mem_write(input logic [ADDR_WIDTH-1:0]          addr,
                           input logic [NUM_ROW_BYTES-1:0][7:0]  data,
                           input logic [NUM_ROW_BYTES-1:0]       strb);
    bus_access.get(1);

    // align to clock boundary unless user explicitly wants otherwise
    if (!is_clock_aligned) begin
      @(posedge clk_i);
    end

    addr_i  <= addr;
    we_i    <= 1'b1;
    wdata_i <= data;     // packed assignment: [3:0][7:0] -> [31:0]
    wstrb_i <= strb;

    @(posedge clk_i);

    // Update golden model in the same way DUT does
    for (int i = 0; i < NUM_ROW_BYTES; i++) begin
      if (strb[i]) begin
        mem_model[row_index(addr)][i] = data[i];
      end
    end

    we_i <= 1'b0;
    bus_access.put(1);
  endtask

  task automatic mem_read(input  logic [ADDR_WIDTH-1:0]         addr,
                          output logic [NUM_ROW_BYTES-1:0][7:0] data);
    bus_access.get(1);

    if (!is_clock_aligned) begin
      @(posedge clk_i);
    end

    addr_i <= addr;
    we_i   <= 1'b0;

    @(posedge clk_i);

    data = rdata_o;

    for (int i = 0; i < NUM_ROW_BYTES; i++) begin
      if (mem_model[row_index(addr)][i] === data[i]) begin
        case_pass++;
      end
      else begin
        case_fail++;
        $display("ERROR: addr=0x%0h row=%0d byte=%0d exp=0x%02X got=0x%02X",
                 addr, row_index(addr), i, mem_model[row_index(addr)][i], data[i]);
      end
    end

    bus_access.put(1);
  endtask

  // Helper: quick pretty print
  task automatic show_word(input string tag,
                           input logic [ADDR_WIDTH-1:0] addr,
                           input logic [NUM_ROW_BYTES-1:0][7:0] data);
    $display("%s addr=0x%0h (row=%0d) data=0x%02X_%02X_%02X_%02X",
             tag, addr, row_index(addr), data[3], data[2], data[1], data[0]);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk_i) begin
    #1;
    is_clock_aligned = 0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    $timeformat(-9, 0, "ns", 6);

    // Optional waves
    // $dumpfile("mem_tb.vcd");
    // $dumpvars(0, mem_tb);

    // Init golden model to known values (avoid X-mismatch)
    foreach (mem_model[i]) begin
      mem_model[i] = '{default:8'h00};
    end

    // Clock generator (gated)
    fork
      forever begin
        is_clock_aligned = clock_enable;
        clk_i <= clock_enable;
        #(CLK_PERIOD/2);
        clk_i <= 1'b0;
        #(CLK_PERIOD/2);
      end
    join_none

    apply_reset(100ns);
    enable_clock();

    // ----------------------------------------------------------------------------
    // TC1: Full Write
    // ----------------------------------------------------------------------------
    $display("\n--- TC1: Full Write ---");
    begin
      logic [NUM_ROW_BYTES-1:0][7:0] rd;

      mem_write(8'h00, 32'hF00D_CAFE, 4'b1111);
      mem_read (8'h00, rd);
      show_word("TC1 READ ", 8'h00, rd);
    end

    // ----------------------------------------------------------------------------
    // TC2: Partial Write
    //   1) write a known pattern
    //   2) overwrite only some bytes using wstrb
    // ----------------------------------------------------------------------------
    $display("\n--- TC2: Partial Write ---");
    begin
      logic [NUM_ROW_BYTES-1:0][7:0] rd;

      // base pattern
      mem_write(8'h0C, 32'h11_22_33_44, 4'b1111);

      // overwrite bytes [0] and [2] only (LSB=byte0)
      // new data bytes: AA ?? BB ?? (depending on which lanes enabled)
      mem_write(8'h0C, 32'hAA_99_BB_88, 4'b0101);

      // expected result:
      // byte3 stays 0x11
      // byte2 becomes 0x99? wait: byte2 lane corresponds to bits [23:16] = 0x99 (from AA_99_BB_88)
      // byte1 stays 0x33
      // byte0 becomes 0x88
      mem_read(8'h0C, rd);
      show_word("TC2 READ ", 8'h0C, rd);
    end

    // ----------------------------------------------------------------------------
    // TC3: No-Op Write (wstrb = 0)
    //   write something, then "write" with strb=0, must NOT change
    // ----------------------------------------------------------------------------
    $display("\n--- TC3: No-Op Write ---");
    begin
      logic [NUM_ROW_BYTES-1:0][7:0] rd0, rd1;

      mem_write(8'h20, 32'hDEAD_BEEF, 4'b1111);
      mem_read (8'h20, rd0);

      // no-op write
      mem_write(8'h20, 32'hCAFE_BABE, 4'b0000);
      mem_read (8'h20, rd1);

      show_word("TC3 BEFORE", 8'h20, rd0);
      show_word("TC3 AFTER ", 8'h20, rd1);
    end

    // ----------------------------------------------------------------------------
    // TC4: Same Row test (No alignment = unaligned addresses)
    //   DUT uses addr[ADDR_WIDTH-1:LG_ROW_BYTES] as row index,
    //   so 0x10,0x11,0x12,0x13 all map to SAME row.
    // ----------------------------------------------------------------------------
    $display("\n--- TC4: Same Row / Unaligned Address Test ---");
    begin
      logic [NUM_ROW_BYTES-1:0][7:0] rd_a, rd_b, rd_c;

      // Full write at aligned address
      mem_write(8'h10, 32'hAA_BB_CC_DD, 4'b1111);

      // Read back using different unaligned byte addresses (same row)
      mem_read(8'h11, rd_a);
      mem_read(8'h12, rd_b);
      mem_read(8'h13, rd_c);

      show_word("TC4 READ@11", 8'h11, rd_a);
      show_word("TC4 READ@12", 8'h12, rd_b);
      show_word("TC4 READ@13", 8'h13, rd_c);
    end

    // Let a few cycles pass
    repeat (5) @(posedge clk_i);

    // Summary
    if (case_fail) $write("\033[1;31m");
    else           $write("\033[1;32m");
    $display("\nTest completed with %0d byte-checks passed and %0d byte-checks failed.\033[0m",
             case_pass, case_fail);

    $finish;
  end

endmodule

`default_nettype wire