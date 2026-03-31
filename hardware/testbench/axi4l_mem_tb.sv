`include "axi4l/typedef.svh"
`include "vip/axi4l.svh"
module axi4l_mem_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  import axi4l_vip_pkg::axi4l_cfg;
  import axi4l_vip_pkg::axi4l_seq_item;
  import axi4l_vip_pkg::axi4l_rsp_item;
  import axi4l_vip_pkg::axi4l_driver;
  import axi4l_vip_pkg::axi4l_monitor;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = 16;
  localparam int DATA_WIDTH = 32;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Macros
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `AXI4L_ALL(my, ADDR_WIDTH, DATA_WIDTH)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic arst_ni;  // active-low asynchronous reset
  logic clk_i;  // clock input

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Class Instances
  //////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_cfg cfg;

  mailbox #(axi4l_seq_item) dvr_mbx;
  mailbox #(axi4l_rsp_item) mon_mbx;

  // Driver (master side) – used by test cases to inject transactions
  axi4l_driver #(
      .req_t    (my_req_t),
      .rsp_t    (my_rsp_t),
      .IS_MASTER(1)          // drives AW/W/AR channels; samples B/R channels
  ) dvr;

  // Monitor – passively captures all transactions for checking
  axi4l_monitor #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) mon;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Interfaces
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // AXI4-Lite interface instance (uses the typedefs from macro)
  axi4l_if #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

  // Memory model under test – single-cycle AXI4-Lite slave memory
  axi4l_mem #(
      .axi4l_req_t(my_req_t),
      .axi4l_rsp_t(my_rsp_t),
      .ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH)
  ) u_mem (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .axi4l_req_i(intf.req),
      .axi4l_rsp_o(intf.rsp)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Low-level write task – handles byte-lane alignment & strobes
  task automatic write(input bit [15:0] addr, input bit [31:0] data, input bit [3:0] strb);
    bit [31:0] wdata;
    bit [ 3:0] wstrb;
    bit [ 1:0] resp;
    wdata = data << ((addr % 4) * 8);   // shift data to correct byte lane (e.g. addr=1 → shift 8 bits)
    wstrb = strb << (addr % 4);  // shift strobe to match byte lane position
    fork
      intf.send_aw({addr, 3'h0});  // AXI4-Lite requires word-aligned addr; lower 3 bits forced 0
      intf.send_w({wdata, wstrb});  // send shifted data and strobe together on W channel
      intf.recv_b(resp);  // wait for write response on B channel (OKAY = 2'b00)
    join
  endtask

  // Low-level read task – handles byte-lane extraction
  task automatic read(input bit [15:0] addr, output bit [31:0] data);
    bit [31:0] rdata;
    bit [ 1:0] resp;
    fork
      intf.send_ar({addr, 3'h0});  // send word-aligned address on AR channel
      intf.recv_r({rdata, resp});  // capture full 32-bit word from R channel
    join
    data = rdata >> ((addr % 4) * 8);  // right-shift to extract the target byte lane
  endtask

  // Convenience wrappers for common access sizes
  task automatic write_32(input bit [15:0] addr, input bit [31:0] data);
    write(addr, data, 4'b1111);  // all 4 byte strobes asserted → full word write
  endtask

  task automatic write_16(input bit [15:0] addr, input bit [15:0] data);
    write(addr, data, 4'b0011);  // lower 2 byte strobes; shift in write() places at addr%4
  endtask

  task automatic write_8(input bit [15:0] addr, input bit [7:0] data);
    write(addr, data, 4'b0001);  // single byte strobe; shift in write() places at addr%4
  endtask

  task automatic read_32(input bit [15:0] addr, output bit [31:0] data);
    read(addr, data);
  endtask

  task automatic read_16(input bit [15:0] addr, output bit [15:0] data);
    read(addr, data);  // upper 16 bits silently dropped by implicit truncation on assign
  endtask

  task automatic read_8(input bit [15:0] addr, output bit [7:0] data);
    read(addr, data);  // upper 24 bits dropped by truncation; lower byte is the result
  endtask

  // Do a High Level AXI4-Lite Write transaction using the VIP driver
  task automatic write_seq(input bit [ADDR_WIDTH-1:0] _addr, input bit [DATA_WIDTH-1:0] data, input bit [DATA_WIDTH/8-1:0] strb);
    axi4l_seq_item sit;
    cfg = new();
    cfg.addr_width = ADDR_WIDTH;
    cfg.data_width = DATA_WIDTH;
    sit = new();
    sit.configure(cfg);
    sit.randomize() with {sit.is_write == 1; sit.addr == _addr; sit.size == $clog2(DATA_WIDTH / 8);};
    sit.data = data;
    sit.strb = strb;
    dvr_mbx.put(sit);
  endtask

  // Do a High Level AXI4-Lite Read transaction using the VIP driver
  task automatic read_seq(input bit [ADDR_WIDTH-1:0] _addr);
    axi4l_seq_item sit;
    cfg = new();
    cfg.addr_width = ADDR_WIDTH;
    cfg.data_width = DATA_WIDTH;
    sit = new();
    sit.configure(cfg);
    sit.randomize() with {sit.is_write == 0; sit.addr == _addr; sit.size == $clog2(DATA_WIDTH / 8);};
    
    dvr_mbx.put(sit);
  endtask

  // HELPER TASKS
  task automatic check(input bit ok, inout int p, inout int f);
    if (ok) p++;
    else f++;  // increment pass or fail counter
  endtask

  // Collect monitor mailbox into queue for post-test verification
  task automatic collect(output axi4l_rsp_item q[$]);
    axi4l_rsp_item r;
    mon.wait_for_idle();  // block until no bus activity seen for idle window
    while (mon.mbx.num()) begin
      mon.mbx.get(r);
      q.push_back(r);  // collect all pending responses into dynamic queue
    end
  endtask

  `include "axi4l_mem_tb/methods/adnan.sv"

  `include "axi4l_mem_tb/methods/siam.sv"

  `include "axi4l_mem_tb/methods/motasim.sv"

  `include "axi4l_mem_tb/methods/shuparna.sv"

  `include "axi4l_mem_tb/methods/dhruba.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "axi4l_mem_tb/tc0.sv"

  `include "axi4l_mem_tb/tc1.sv"

  `include "axi4l_mem_tb/tc2.sv"

  `include "axi4l_mem_tb/tc3.sv"

  `include "axi4l_mem_tb/tc4.sv"

  `include "axi4l_mem_tb/tc5.sv"

  `include "axi4l_mem_tb/tc6.sv"

  `include "axi4l_mem_tb/tc7.sv"

  `include "axi4l_mem_tb/tc8.sv"

  `include "axi4l_mem_tb/tc9.sv"

  `include "axi4l_mem_tb/tc10.sv"

  `include "axi4l_mem_tb/tc11.sv"

  `include "axi4l_mem_tb/tc12.sv"

  `include "axi4l_mem_tb/tc13.sv"

  `include "axi4l_mem_tb/tc14.sv"

  `include "axi4l_mem_tb/tc15.sv"

  `include "axi4l_mem_tb/tc16.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAIN INITIAL
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    automatic bit [31:0] data;
    automatic int total_p = 0;
    automatic int total_f = 0;
    int p, f;
    int test_number;

    if (!$value$plusargs("TEST=%d", test_number)) begin
      $fatal(1, "Must specify test number with TEST=N argument (e.g. TEST=3)");
    end else begin
      $display("Running test number %0d", test_number);
    end

    $timeformat(-9, 1, " ns", 20);  // display time in nanoseconds with 1 decimal place
    $dumpfile("axi4l_mem_tb.vcd");  // VCD output for waveform viewing (GTKWave etc.)
    $dumpvars(0, axi4l_mem_tb);  // depth=0 dumps all signals in the module hierarchy

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // BUILD
    ////////////////////////////////////////////////////////////////////////////////////////////////

    cfg     = new();
    dvr_mbx = new(1);
    mon_mbx = new();
    dvr     = new();
    mon     = new();

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // CONNECT
    ////////////////////////////////////////////////////////////////////////////////////////////////

    dvr.connect_interface(intf);
    mon.connect_interface(intf);
    dvr.connect_mailbox(dvr_mbx);
    mon.connect_mailbox(mon_mbx);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RUN
    ////////////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////
    // RESET
    //////////////////////////////////////////////

    clk_i   <= '0;
    arst_ni <= '0;
    intf.req_reset();  // drive all AXI request signals to idle/default state
    #20;
    arst_ni <= '1;  // de-assert reset; DUT begins normal operation
    #20;

    //////////////////////////////////////////////
    // CONFIGURE
    //////////////////////////////////////////////

    cfg.addr_width = ADDR_WIDTH;
    cfg.data_width = DATA_WIDTH;

    fork
      forever #5 clk_i <= ~clk_i;
    join_none  // 10-unit period clock; join_none = non-blocking
    @(posedge clk_i);  // sync to first rising edge before driving any transactions

    //////////////////////////////////////////////
    // MAIN
    //////////////////////////////////////////////

    if (test_number != 0) begin
      dvr.run();  // spawn driver thread: pulls items from dvr_mbx and drives bus
      mon.run();  // spawn monitor thread: samples bus, pushes rsp_items to mon.mbx
    end

    case (test_number)

      0: begin
        tc0(p, f);
      end

      1: begin
        tc1(p, f);
      end

      2: begin
        tc2(p, f);
      end

      3: begin
        tc3(p, f);
      end

      4: begin
        tc4(p, f);
      end

      5: begin
        tc5(p, f);
      end

      6: begin
        tc6(p, f);
      end

      7: begin
        tc7(p, f);
      end

      8: begin
        tc8(p, f);
      end

      9: begin
        tc9(p, f);
      end

      10: begin
        tc10(p, f);
      end

      11: begin
        tc11(p, f);
      end

      12: begin
        tc12(p, f);
      end

      13: begin
        tc13(p, f);
      end

      14: begin
        tc14(p, f);
      end

      15: begin
        tc15(p, f);
      end

      16: begin
        tc16(p, f);
      end

      default: begin
        $fatal(1, "Invalid test number %0d. Valid range is 0-16.", test_number);
      end

    endcase

    // show selected test result in terminal (unconditional, immediate)
    $display("SELECTED TEST %0d RESULT: PASS=%0d FAIL=%0d", test_number, p, f);
    total_p += p;
    total_f += f;
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    // CLEANUP
    ////////////////////////////////////////////////////////////////////////////////////////////////

    // FINAL RESULT
    $display("\n==== FINAL RESULT ====");
    $display("TOTAL PASS = %0d", total_p);
    $display("TOTAL FAIL = %0d", total_f);
    if (total_f == 0) $display("OVERALL PASSED");
    else $display("OVERALL FAILED");

    repeat (20)
    @(posedge clk_i);  // 20-cycle tail: lets in-flight transactions retire before finish
    $finish;

  end

endmodule
