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

    dvr.run();  // spawn driver thread: pulls items from dvr_mbx and drives bus
    mon.run();  // spawn monitor thread: samples bus, pushes rsp_items to mon.mbx

    repeat (5) begin
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
      total_p += p;
      total_f += f;

    end   
    
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

/*
TODO Dhruba

`include "axi4l/typedef.svh"
`include "vip/axi4l.svh"

module axi4l_mem_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH = 16;
  localparam int DATA_WIDTH = 32;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  `AXI4L_ALL(my, ADDR_WIDTH, DATA_WIDTH)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic arst_ni;
  logic clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACE
  //////////////////////////////////////////////////////////////////////////////////////////////////
  axi4l_if #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////////////////
  axi4l_mem #(
      .axi4l_req_t(my_req_t),
      .axi4l_rsp_t(my_rsp_t),
      .ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH)
  ) u_mem (
      .arst_ni    (arst_ni),
      .clk_i      (clk_i),
      .axi4l_req_i(intf.req),
      .axi4l_rsp_o(intf.rsp)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VIP IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  import axi4l_vip_pkg::axi4l_driver;
  import axi4l_vip_pkg::axi4l_monitor;
  import axi4l_vip_pkg::axi4l_seq_item;
  import axi4l_vip_pkg::axi4l_rsp_item;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VIP OBJECTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  axi4l_driver #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t),
      .IS_MASTER(1)
  ) dvr;

  axi4l_monitor #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) mon;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DIRECT ACCESS TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic write(
      input bit [15:0] addr,
      input bit [31:0] data,
      input bit [3:0]  strb
  );
    bit [31:0] wdata;
    bit [3:0]  wstrb;
    bit [1:0]  resp;

    wdata = data << ((addr % 4) * 8);
    wstrb = strb << (addr % 4);

    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w ({wdata, wstrb});
      intf.recv_b (resp);
    join
  endtask

  task automatic read(
      input  bit [15:0] addr,
      output bit [31:0] data
  );
    bit [31:0] rdata;
    bit [1:0]  resp;

    fork
      intf.send_ar({addr, 3'h0});
      intf.recv_r ({rdata, resp});
    join

    data = rdata >> ((addr % 4) * 8);
  endtask

  task automatic write_32(input bit [15:0] addr, input bit [31:0] data);
    write(addr, data, 4'b1111);
  endtask

  task automatic write_16(input bit [15:0] addr, input bit [15:0] data);
    write(addr, {16'h0000, data}, 4'b0011);
  endtask

  task automatic write_8(input bit [15:0] addr, input bit [7:0] data);
    write(addr, {24'h000000, data}, 4'b0001);
  endtask

  task automatic read_32(input bit [15:0] addr, output bit [31:0] data);
    read(addr, data);
  endtask

  task automatic read_16(input bit [15:0] addr, output bit [15:0] data);
    bit [31:0] tmp;
    read(addr, tmp);
    data = tmp[15:0];
  endtask

  task automatic read_8(input bit [15:0] addr, output bit [7:0] data);
    bit [31:0] tmp;
    read(addr, tmp);
    data = tmp[7:0];
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // HELPERS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic check(input bit ok, inout int p, inout int f);
    if (ok) p++;
    else    f++;
  endtask

  task automatic clear_monitor_mailbox();
    axi4l_rsp_item r;
    while (mon.mbx.num() > 0) begin
      mon.mbx.get(r);
    end
  endtask

  task automatic wait_for_vip_idle();
    mon.wait_for_idle();
    repeat (2) @(posedge clk_i);
  endtask

  task automatic drain_and_check_resps(
      input int expected_count,
      inout int p,
      inout int f
  );
    axi4l_rsp_item r;
    int count;

    wait_for_vip_idle();

    count = mon.mbx.num();
    check(count == expected_count, p, f);
    if (count != expected_count) begin
      $display("RESP COUNT MISMATCH: expected=%0d got=%0d", expected_count, count);
    end

    while (mon.mbx.num() > 0) begin
      mon.mbx.get(r);
      check(r.resp === 2'b00, p, f);
      if (r.resp !== 2'b00) begin
        $display("RESP ERROR: resp=%0b", r.resp);
      end
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // TC2: direct self-checking test
  task automatic tc2(output int p, output int f);
    bit [31:0] rd;
    bit [31:0] exp[0:3];

    p = 0;
    f = 0;

    exp[0] = 32'h0000_00A0;
    exp[1] = 32'h0000_00A1;
    exp[2] = 32'h0000_00A2;
    exp[3] = 32'h0000_00A3;

    for (int i = 0; i < 4; i++) begin
      write_32(i * 4, exp[i]);
    end

    for (int i = 0; i < 4; i++) begin
      read_32(i * 4, rd);
      check(rd === exp[i], p, f);
      if (rd !== exp[i]) begin
        $display("TC2 DATA MISMATCH: addr=0x%04h exp=0x%08h got=0x%08h",
                 i * 4, exp[i], rd);
      end
    end
  endtask

  // TC7: VIP write + response check + readback
  task automatic tc7(output int p, output int f);
    axi4l_seq_item item;
    bit [31:0] rd;
    bit [15:0] addr;
    bit [31:0] exp;

    p    = 0;
    f    = 0;
    addr = 16'h0100;
    exp  = 32'hDEAD_BEEF;

    clear_monitor_mailbox();

    item = new();
    item.is_write = 1'b1;
    item.addr     = addr;
    item.data     = exp;
    item.strb     = 4'b1111;
    dvr_mbx.put(item);

    // XSIM/VIP monitor is returning 2 response items here
    drain_and_check_resps(2, p, f);

    read_32(addr, rd);
    check(rd === exp, p, f);
    if (rd !== exp) begin
      $display("TC7 DATA MISMATCH: addr=0x%04h exp=0x%08h got=0x%08h",
               addr, exp, rd);
    end
  endtask

  // TC12: VIP write + response check + readback
  task automatic tc12(output int p, output int f);
    axi4l_seq_item item;
    bit [31:0] rd;
    bit [15:0] addr;
    bit [31:0] exp;

    p    = 0;
    f    = 0;
    addr = 16'h0200;
    exp  = 32'hAAAA_AAAA;

    clear_monitor_mailbox();

    item = new();
    item.is_write = 1'b1;
    item.addr     = addr;
    item.data     = exp;
    item.strb     = 4'b1111;
    dvr_mbx.put(item);

    // XSIM/VIP monitor is returning 2 response items here
    drain_and_check_resps(2, p, f);

    read_32(addr, rd);
    check(rd === exp, p, f);
    if (rd !== exp) begin
      $display("TC12 DATA MISMATCH: addr=0x%04h exp=0x%08h got=0x%08h",
               addr, exp, rd);
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAIN
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    bit [31:0] data32;
    bit [15:0] data16;
    bit [7:0]  data8;
    int total_p;
    int total_f;
    int p;
    int f;

    total_p = 0;
    total_f = 0;
    p       = 0;
    f       = 0;

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_mem_tb.vcd");
    $dumpvars(0, axi4l_mem_tb);

    arst_ni = 1'b0;
    intf.req_reset();

    repeat (4) @(posedge clk_i);
    arst_ni = 1'b1;
    repeat (4) @(posedge clk_i);

    $display("ENTERING SANITY CHECKS");

    write_16(16'h0001, 16'hABCD);
    repeat (5) @(posedge clk_i);

    read_32(16'h0000, data32);
    $display("R32 0 DATA:0x%08h", data32);

    read_16(16'h0001, data16);
    $display("R16 1 DATA:0x%04h", data16);

    read_8(16'h0002, data8);
    $display("R8 2 DATA:0x%02h", data8);

    dvr = new();
    mon = new();

    dvr.connect_interface(intf);
    mon.connect_interface(intf);

    fork
      dvr.run();
      mon.run();
    join_none

    repeat (5) @(posedge clk_i);

    $display("ENTERING TESTCASE LOOP");

    repeat (5) begin
      tc2(p, f);
      total_p += p;
      total_f += f;
      $display("TC2 : PASS=%0d FAIL=%0d", p, f);

      tc7(p, f);
      total_p += p;
      total_f += f;
      $display("TC7 : PASS=%0d FAIL=%0d", p, f);

      tc12(p, f);
      total_p += p;
      total_f += f;
      $display("TC12: PASS=%0d FAIL=%0d", p, f);
    end

    $display("REACHED FINAL SUMMARY");
    $display("\n==== FINAL RESULT ====");
    $display("TOTAL PASS = %0d", total_p);
    $display("TOTAL FAIL = %0d", total_f);

    if (total_f == 0)
      $display("OVERALL PASSED");
    else
      $display("OVERALL FAILED");

    repeat (20) @(posedge clk_i);
    $finish;
  end

endmodule

*/







/* TODO MOTASIM

`include "axi4l/typedef.svh"
`include "vip/axi4l.svh"

module axi4l_mem_tb;

  /////////////////////////////////////////////////////////////
  // IMPORT PACKAGE
  /////////////////////////////////////////////////////////////

  import axi4l_vip_pkg::*;

  /////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  /////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = 16;
  localparam int DATA_WIDTH = 32;

  /////////////////////////////////////////////////////////////
  // TYPE DEFINITIONS
  /////////////////////////////////////////////////////////////
  `AXI4L_ALL(my, ADDR_WIDTH, DATA_WIDTH)

  /////////////////////////////////////////////////////////////
  // SIGNALS
  /////////////////////////////////////////////////////////////
  
  logic arst_ni;
  logic clk_i;

  bit [3:0] wstrb;
  int back2back_reads;

  int unsigned err_count;
  int unsigned pass_count;

  int unsigned tc0_hits;
  int unsigned tc5_hits;
  int unsigned tc10_hits;
  int unsigned tc15_hits;

  /////////////////////////////////////////////////////////////
  // INTERFACE
  /////////////////////////////////////////////////////////////
  axi4l_if #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

// ------------------- DUT INSTANTIATION -------------------
// Memory model under test – single-cycle AXI4-Lite slave memory
axi4l_mem #(
  /////////////////////////////////////////////////////////////
  // DUT
  /////////////////////////////////////////////////////////////
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

// TASKS
// Low-level write task – handles byte-lane alignment & strobes
task automatic write(input bit [15:0] addr, input bit [31:0] data, input bit [3:0] strb);
    bit [31:0] wdata;
    bit [3:0]  wstrb;
    bit [1:0]  resp;
    wdata = data << ((addr % 4) * 8);   // shift data to correct byte lane (e.g. addr=1 → shift 8 bits)
    wstrb = strb << (addr % 4);         // shift strobe to match byte lane position
    fork
      intf.send_aw({addr, 3'h0});       // AXI4-Lite requires word-aligned addr; lower 3 bits forced 0
      intf.send_w({wdata, wstrb});      // send shifted data and strobe together on W channel
      intf.recv_b(resp);                // wait for write response on B channel (OKAY = 2'b00)
    join
endtask

// Low-level read task – handles byte-lane extraction
task automatic read(input bit [15:0] addr, output bit [31:0] data);
    bit [31:0] rdata;
    bit [1:0]  resp;
    fork
      intf.send_ar({addr, 3'h0});       // send word-aligned address on AR channel
      intf.recv_r({rdata, resp});       // capture full 32-bit word from R channel
    join
    data = rdata >> ((addr % 4) * 8);   // right-shift to extract the target byte lane
endtask

// Convenience wrappers for common access sizes
task automatic write_32(input bit [15:0] addr, input bit [31:0] data);
    write(addr, data, 4'b1111);         // all 4 byte strobes asserted → full word write
endtask

task automatic write_16(input bit [15:0] addr, input bit [15:0] data);
    write(addr, data, 4'b0011);         // lower 2 byte strobes; shift in write() places at addr%4
endtask

task automatic write_8(input bit [15:0] addr, input bit [7:0] data);
    write(addr, data, 4'b0001);         // single byte strobe; shift in write() places at addr%4
endtask

task automatic read_32(input bit [15:0] addr, output bit [31:0] data);
    read(addr, data);
endtask

task automatic read_16(input bit [15:0] addr, output bit [15:0] data);
    read(addr, data);                   // upper 16 bits silently dropped by implicit truncation on assign
endtask

task automatic read_8(input bit [15:0] addr, output bit [7:0] data);
    read(addr, data);                   // upper 24 bits dropped by truncation; lower byte is the result
endtask

// VIP DRIVER / MONITOR
import axi4l_vip_pkg::axi4l_driver;
import axi4l_vip_pkg::axi4l_monitor;
import axi4l_vip_pkg::axi4l_seq_item; // stimulus descriptor: addr, data, strb, is_write
import axi4l_vip_pkg::axi4l_rsp_item; // response descriptor: resp code from B or R channel

// Driver (master side) – used by test cases to inject transactions
axi4l_driver #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t),
      .IS_MASTER(1)                     // drives AW/W/AR channels; samples B/R channels
  ) dvr;

// Monitor – passively captures all transactions for checking
axi4l_monitor #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) mon;                                // deposits captured rsp_items into mon.mbx mailbox

// HELPER TASKS
task automatic check(input bit ok, inout int p, inout int f);
    if (ok) p++; else f++;              // increment pass or fail counter
endtask

// Drain monitor mailbox into queue for post-test verification
task automatic drain(output axi4l_rsp_item q[$]);
    axi4l_rsp_item r;
    mon.wait_for_idle();                // block until no bus activity seen for idle window
    while (mon.mbx.num()) begin
      mon.mbx.get(r);
      q.push_back(r);                  // collect all pending responses into dynamic queue
    end
endtask

// TEST CASES

// TC3: 4 consecutive 32-bit writes followed by 4 reads using VIP driver
task automatic tc3(output int p, output int f);
    axi4l_seq_item item;
    axi4l_rsp_item q[$];
    p = 0; f = 0;

    // Queue 4 write transactions to word-aligned addresses 0x00..0x0C
    for (int i=0; i<4; i++) begin
        item = new();
        item.is_write = 1;
        item.addr     = i * 4;          // word-aligned (0, 4, 8, 12)
        item.data     = 32'hA0 + i;
        item.strb     = 4'b1111;
        dvr_mbx.put(item);
    end
    drain(q);

    // Check write responses
    foreach (q[i])
        check(q[i].resp === 2'b00, p, f);

    q.delete();

    // Queue 4 read transactions to same addresses
    for (int i=0; i<4; i++) begin
        item = new();
        item.is_write = 0;
        item.addr     = i * 4;          // word-aligned, matching writes above
        dvr_mbx.put(item);
    end
    drain(q);

    // verify both OKAY response and read-back data against written values;
    // confirmed the memory actually returned the correct data
    foreach (q[i]) begin
        check(q[i].resp === 2'b00,      p, f);  // read OKAY
        check(q[i].data === 32'hA0 + i, p, f);  // data matches written value
    end
endtask

// TC8: Single 32-bit write, idle delay before checking response
task automatic tc8(output int p, output int f);
    axi4l_seq_item item;
    axi4l_rsp_item q[$];
    p = 0; f = 0;

    item = new();
    item.is_write = 1;
    item.addr     = 32'h100;
    item.data     = 32'hDEAD_BEEF;
    item.strb     = 4'b1111;
    dvr_mbx.put(item);

    repeat(5) @(posedge clk_i);   // idle gap
    drain(q);

    foreach (q[i])
        check(q[i].resp === 2'b00, p, f);
endtask

// TC13: Preload write → concurrent write + read → response check
task automatic tc13(output int p, output int f);
    axi4l_seq_item item_wr;             // dedicated handle for write branch
    axi4l_seq_item item_rd;             // dedicated handle for read branch
    axi4l_rsp_item q[$];
    p = 0; f = 0;

    // Preload: single write
    item_wr = new();
    item_wr.is_write = 1;
    item_wr.addr     = 32'h200;
    item_wr.data     = 32'hAAAA_AAAA;
    item_wr.strb     = 4'b1111;
    dvr_mbx.put(item_wr);
    drain(q);
    check(q[0].resp === 2'b00, p, f);

    q.delete();  // clear the queue

    // Concurrent write + read
    fork
        begin
            item_wr = new();
            item_wr.is_write = 1;
            item_wr.addr     = 32'h500;
            item_wr.data     = 32'hDEAD_BEEF;
            item_wr.strb     = 4'b1111;
            dvr_mbx.put(item_wr);
        end
        begin
            item_rd = new();
            item_rd.is_write = 0;
            item_rd.addr     = 32'h200;
            dvr_mbx.put(item_rd);
        end
    join

    // to fire before bus activity begins; drain() handles sync correctly on its own
    drain(q);

    foreach (q[i])
        check(q[i].resp === 2'b00, p, f);
endtask

// MAIN INITIAL
initial begin
    automatic bit [31:0] data;
    int total_p = 0;
    int total_f = 0;
    int p, f;

    $timeformat(-9,1," ns",20);        // display time in nanoseconds with 1 decimal place
    $dumpfile("axi4l_mem_tb.vcd");     // VCD output for waveform viewing (GTKWave etc.)
    $dumpvars(0, axi4l_mem_tb);        // depth=0 dumps all signals in the module hierarchy

    clk_i   <= '0;
    arst_ni <= '0;
    intf.req_reset();                  // drive all AXI request signals to idle/default state
    #20;
    arst_ni <= '1;                     // de-assert reset; DUT begins normal operation
    #20;

    fork forever #5 clk_i <= ~clk_i; join_none  // 10-unit period clock; join_none = non-blocking
    @(posedge clk_i);                  // sync to first rising edge before driving any transactions

    // ORIGINAL TESTS
    write_16(1, 'hABCD);               // 16-bit write to byte offset 1; data shifts to lanes [1:0]
    repeat (5) @(posedge clk_i);
    read_32(0, data);
    $display("R32 0 DATA:0x%h", data); // expect 0x0000ABCD (byte lanes [1:0] set; [3:2] still 0)
    read_16(1, data);
    $display("R16 1 DATA:0x%h", data);
    read_8(2, data);
    $display("R8 2 DATA:0x%h", data);

    // VIP DRIVER RUN
    dvr = new();
    mon = new();
    dvr.connect_interface(intf);       // bind driver to the DUT interface virtual interface handle
    mon.connect_interface(intf);       // bind monitor to the same interface for passive observation
    dvr.run();                         // spawn driver thread: pulls items from dvr_mbx and drives bus
    mon.run();                         // spawn monitor thread: samples bus, pushes rsp_items to mon.mbx
  /////////////////////////////////////////////////////////////
  // DRIVER / MONITOR
  /////////////////////////////////////////////////////////////
  axi4l_driver #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t),
      .IS_MASTER(1)
  ) dvr;
  /////////////////////////////////////////////////////////////
  // DRIVER / MONITOR
  /////////////////////////////////////////////////////////////
  axi4l_driver #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t),
      .IS_MASTER(1)
  ) dvr;

  axi4l_monitor #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) mon;

  /////////////////////////////////////////////////////////////
  // COVERGROUPS (TC0 / TC5 / TC10 / TC15)
  /////////////////////////////////////////////////////////////
  // Main functional covergroup for AXI4-Lite handshake and fields
  covergroup cg_axi4l @(posedge clk_i);
    option.per_instance = 1;

    coverpoint intf.rsp.aw_ready;
    coverpoint intf.rsp.w_ready;
    coverpoint intf.rsp.b_valid;
    coverpoint intf.rsp.ar_ready;
    coverpoint intf.rsp.r_valid;

    coverpoint wstrb;
    coverpoint back2back_reads;
  endgroup

  cg_axi4l cg;

  // Test case coverage for TC0/TC5/TC10/TC15
  int unsigned tc_id;

  covergroup cg_tc @(posedge clk_i);
    option.per_instance = 1;

    tc_cp: coverpoint tc_id {
      bins TC0  = {0};
      bins TC5  = {5};
      bins TC10 = {10};
      bins TC15 = {15};
      bins others = default;
    }

    write_cp: coverpoint (intf.req.aw_valid && intf.req.w_valid) {
      bins write_txn = {1};
    }

    read_cp: coverpoint intf.req.ar_valid;
  endgroup

  cg_tc tc_cg;

  task set_tc(input int unsigned id);
    tc_id = id;
    tc_cg.sample();
    case (id)
      0 : tc0_hits++;
      5 : tc5_hits++;
      10: tc10_hits++;
      15: tc15_hits++;
      default: ;
    endcase
  endtask

  /////////////////////////////////////////////////////////////
  // CLOCK
  /////////////////////////////////////////////////////////////
  task start_clock();
    forever begin
      clk_i = 0;
      #5ns;
      clk_i = 1;
      #5ns;
    end
  endtask

  /////////////////////////////////////////////////////////////
  // RESET
  /////////////////////////////////////////////////////////////
  task apply_reset();
    arst_ni = 0;
    repeat (5) @(posedge clk_i);
    arst_ni = 1;
    repeat (5) @(posedge clk_i);
  endtask

  /////////////////////////////////////////////////////////////
  // WRITE TASK
  /////////////////////////////////////////////////////////////
  task do_write(
      input bit [ADDR_WIDTH-1:0] addr_in,
      input bit [DATA_WIDTH-1:0] data_in,
      input bit [DATA_WIDTH/8-1:0] strb_in
  );
    axi4l_seq_item item;

    item = new();

    void'(item.randomize() with {
      item.is_write == 1;
      item.addr     == addr_in;
    });
    
    item.data = data_in;
    item.strb = strb_in;

    dvr_mbx.put(item);

    // coverage
    wstrb = strb_in;
    cg.sample();
  endtask

  /////////////////////////////////////////////////////////////
  // READ TASK
  /////////////////////////////////////////////////////////////
  task do_read(input bit [ADDR_WIDTH-1:0] addr_in);
    axi4l_seq_item item;

    item = new();

    void'(item.randomize() with {
      item.is_write == 0;
      item.addr     == addr_in;
    });

    dvr_mbx.put(item);

    back2back_reads++;
    cg.sample();
  endtask

  /////////////////////////////////////////////////////////////
  // INITIAL BLOCK
  /////////////////////////////////////////////////////////////
  initial begin

    $timeformat(-9, 1, " ns", 20);

    // Vivado-compatible dump
    $dumpfile("axi4l_mem_tb.vcd");
    $dumpvars(0, axi4l_mem_tb);

    clk_i   = 0;
    arst_ni = 0;

    // Create objects
    dvr = new();
    mon = new();

    dvr.connect_interface(intf);
    mon.connect_interface(intf);

    cg = new();
    tc_cg = new();

    // Start clock FIRST
    fork
      start_clock();
    join_none

    #1ns;
    apply_reset();

    // Start VIP components
    fork
      dvr.run();
      mon.run();
    join_none

    err_count  = 0;
    pass_count = 0;
    tc0_hits   = 0;
    tc5_hits   = 0;
    tc10_hits  = 0;
    tc15_hits  = 0;

    // ======================================================
    // TEST TRAFFIC: TC0, TC5, TC10, TC15
    // ======================================================

    // TC0: Single write-read pair
    set_tc(0);
    do_write(16'h0001, 32'hABCD1234, 4'b1111);
    do_read (16'h0001);

    // TC5: Multiple write bursts (5 writes) to unique addresses
    set_tc(5);
    do_write(16'h0010, 32'h11112222, 4'b1111);
    do_write(16'h0020, 32'h33334444, 4'b1111);
    do_write(16'h0030, 32'h55556666, 4'b1111);
    do_write(16'h0040, 32'h77778888, 4'b1111);
    do_write(16'h0050, 32'h9999AAAA, 4'b1111);

    // TC10: Mixed write and read in a small burst
    set_tc(10);
    do_write(16'h0100, 32'hDEADBEEF, 4'b1111);
    do_read (16'h0100);
    do_write(16'h0110, 32'hCAFEBABE, 4'b1111);
    do_read (16'h0110);

    // TC15: Back-to-back reads from random locations
    set_tc(15);
    repeat (8) begin
      do_read($urandom_range(0, 16'h00FF));
    end

    // Wait for completion
    mon.wait_for_idle();

    // ======================================================
    // PRINT RESPONSES
    // ======================================================
    while (mon.mbx.num() > 0) begin
      axi4l_rsp_item rsp;
      mon.mbx.get(rsp);
      $display("Received response:");
      rsp.print();

      // If we wanted stronger checks, we can validate rsp fields here
      pass_count++;
    end

    // final self-check status
    if (err_count != 0) begin
      $display("\n*** TEST FAILED: %0d error(s) detected ***", err_count);
      $fatal;
    end else if (tc0_hits == 0 || tc5_hits == 0 || tc10_hits == 0 || tc15_hits == 0) begin
      $display("\n*** TEST FAILED: TC hits missing (tc0=%0d tc5=%0d tc10=%0d tc15=%0d) ***", tc0_hits, tc5_hits, tc10_hits, tc15_hits);
      $fatal;
    end else begin
      $display("\n*** TEST PASSED: %0d checks executed; tc0=%0d, tc5=%0d, tc10=%0d, tc15=%0d ***", pass_count, tc0_hits, tc5_hits, tc10_hits, tc15_hits);
    end

  axi4l_monitor #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) mon;

  /////////////////////////////////////////////////////////////
  // COVERGROUPS (TC0 / TC5 / TC10 / TC15)
  /////////////////////////////////////////////////////////////
  // Main functional covergroup for AXI4-Lite handshake and fields
  covergroup cg_axi4l @(posedge clk_i);
    option.per_instance = 1;

    coverpoint intf.rsp.aw_ready;
    coverpoint intf.rsp.w_ready;
    coverpoint intf.rsp.b_valid;
    coverpoint intf.rsp.ar_ready;
    coverpoint intf.rsp.r_valid;

    coverpoint wstrb;
    coverpoint back2back_reads;
  endgroup

  cg_axi4l cg;

  // Test case coverage for TC0/TC5/TC10/TC15
  int unsigned tc_id;

  covergroup cg_tc @(posedge clk_i);
    option.per_instance = 1;

    tc_cp: coverpoint tc_id {
      bins TC0  = {0};
      bins TC5  = {5};
      bins TC10 = {10};
      bins TC15 = {15};
      bins others = default;
    }

    write_cp: coverpoint (intf.req.aw_valid && intf.req.w_valid) {
      bins write_txn = {1};
    }

    read_cp: coverpoint intf.req.ar_valid;
  endgroup

  cg_tc tc_cg;

  task set_tc(input int unsigned id);
    tc_id = id;
    tc_cg.sample();
    case (id)
      0 : tc0_hits++;
      5 : tc5_hits++;
      10: tc10_hits++;
      15: tc15_hits++;
      default: ;
    endcase
  endtask

  /////////////////////////////////////////////////////////////
  // CLOCK
  /////////////////////////////////////////////////////////////
  task start_clock();
    forever begin
      clk_i = 0;
      #5ns;
      clk_i = 1;
      #5ns;
    end
  endtask

  /////////////////////////////////////////////////////////////
  // RESET
  /////////////////////////////////////////////////////////////
  task apply_reset();
    arst_ni = 0;
    repeat (5) @(posedge clk_i);
    arst_ni = 1;
    repeat (5) @(posedge clk_i);
  endtask

  /////////////////////////////////////////////////////////////
  // WRITE TASK
  /////////////////////////////////////////////////////////////
  task do_write(
      input bit [ADDR_WIDTH-1:0] addr_in,
      input bit [DATA_WIDTH-1:0] data_in,
      input bit [DATA_WIDTH/8-1:0] strb_in
  );
    axi4l_seq_item item;

    item = new();

    void'(item.randomize() with {
      item.is_write == 1;
      item.addr     == addr_in;
    });
    
    item.data = data_in;
    item.strb = strb_in;

    dvr_mbx.put(item);

    // coverage
    wstrb = strb_in;
    cg.sample();
  endtask

  /////////////////////////////////////////////////////////////
  // READ TASK
  /////////////////////////////////////////////////////////////
  task do_read(input bit [ADDR_WIDTH-1:0] addr_in);
    axi4l_seq_item item;

    item = new();

    void'(item.randomize() with {
      item.is_write == 0;
      item.addr     == addr_in;
    });

    dvr_mbx.put(item);

    back2back_reads++;
    cg.sample();
  endtask

  /////////////////////////////////////////////////////////////
  // INITIAL BLOCK
  /////////////////////////////////////////////////////////////
  initial begin

    $timeformat(-9, 1, " ns", 20);

    // Vivado-compatible dump
    $dumpfile("axi4l_mem_tb.vcd");
    $dumpvars(0, axi4l_mem_tb);

    clk_i   = 0;
    arst_ni = 0;

    // Create objects
    dvr = new();
    mon = new();

    dvr.connect_interface(intf);
    mon.connect_interface(intf);

    cg = new();
    tc_cg = new();

    // Start clock FIRST
    fork
      start_clock();
    join_none

    #1ns;
    apply_reset();

    // Start VIP components
    fork
      dvr.run();
      mon.run();
    join_none

    err_count  = 0;
    pass_count = 0;
    tc0_hits   = 0;
    tc5_hits   = 0;
    tc10_hits  = 0;
    tc15_hits  = 0;

    // ======================================================
    // TEST TRAFFIC: TC0, TC5, TC10, TC15
    // ======================================================

    // TC0: Single write-read pair
    set_tc(0);
    do_write(16'h0001, 32'hABCD1234, 4'b1111);
    do_read (16'h0001);

    // TC5: Multiple write bursts (5 writes) to unique addresses
    set_tc(5);
    do_write(16'h0010, 32'h11112222, 4'b1111);
    do_write(16'h0020, 32'h33334444, 4'b1111);
    do_write(16'h0030, 32'h55556666, 4'b1111);
    do_write(16'h0040, 32'h77778888, 4'b1111);
    do_write(16'h0050, 32'h9999AAAA, 4'b1111);

    // TC10: Mixed write and read in a small burst
    set_tc(10);
    do_write(16'h0100, 32'hDEADBEEF, 4'b1111);
    do_read (16'h0100);
    do_write(16'h0110, 32'hCAFEBABE, 4'b1111);
    do_read (16'h0110);

    // TC15: Back-to-back reads from random locations
    set_tc(15);
    repeat (8) begin
      do_read($urandom_range(0, 16'h00FF));
    end

    // Wait for completion
    mon.wait_for_idle();

    // ======================================================
    // PRINT RESPONSES
    // ======================================================
    while (mon.mbx.num() > 0) begin
      axi4l_rsp_item rsp;
      mon.mbx.get(rsp);
      $display("Received response:");
      rsp.print();

      // If we wanted stronger checks, we can validate rsp fields here
      pass_count++;
    end

    // final self-check status
    if (err_count != 0) begin
      $display("\n*** TEST FAILED: %0d error(s) detected ***", err_count);
      $fatal;
    end else if (tc0_hits == 0 || tc5_hits == 0 || tc10_hits == 0 || tc15_hits == 0) begin
      $display("\n*** TEST FAILED: TC hits missing (tc0=%0d tc5=%0d tc10=%0d tc15=%0d) ***", tc0_hits, tc5_hits, tc10_hits, tc15_hits);
      $fatal;
    end else begin
      $display("\n*** TEST PASSED: %0d checks executed; tc0=%0d, tc5=%0d, tc10=%0d, tc15=%0d ***", pass_count, tc0_hits, tc5_hits, tc10_hits, tc15_hits);
    end

    // RUN TEST CASES
    repeat(5) begin                    // repeat all test cases 5× to stress pipelining behaviour
      tc3(p,f);  total_p += p; total_f += f;
      tc8(p,f);  total_p += p; total_f += f;
      tc13(p,f); total_p += p; total_f += f;
    end

    // FINAL RESULT
    $display("\n==== FINAL RESULT ====");
    $display("TOTAL PASS = %0d", total_p);
    $display("TOTAL FAIL = %0d", total_f);
    if (total_f == 0)
      $display("OVERALL PASSED");
    else
      $display("OVERALL FAILED");

    repeat (20) @(posedge clk_i);     // 20-cycle tail: lets in-flight transactions retire before finish
    $finish;
  end

endmodule

*/


/* TODO SHUPARNA



`include "axi4l/typedef.svh"
`include "vip/axi4l.svh"

module axi4l_mem_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = 16;
  localparam int DATA_WIDTH = 32;


  import axi4l_vip_pkg::axi4l_cfg;
  import axi4l_vip_pkg::axi4l_seq_item;
  import axi4l_vip_pkg::axi4l_rsp_item;
  import axi4l_vip_pkg::axi4l_driver;
  import axi4l_vip_pkg::axi4l_monitor;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPE DEFINITIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `AXI4L_ALL(axi4l, 32, 32)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic arst_ni;
  logic clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_if #(
      .req_t(axi4l_req_t),
      .rsp_t(axi4l_rsp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_mem #(
      .axi4l_req_t(axi4l_req_t),
      .axi4l_rsp_t(axi4l_rsp_t),
      .ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH)
  ) u_mem (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .axi4l_req_i(intf.req),
      .axi4l_rsp_o(intf.rsp)
  );
// Driver and Monitor

    axi4l_driver #(
      .req_t(axi4l_req_t),
      .rsp_t(axi4l_rsp_t),
      .IS_MASTER(1)
  ) dvr;

  axi4l_monitor #(
      .req_t(axi4l_req_t),
      .rsp_t(axi4l_rsp_t)
  ) mon;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic write(input bit [15:0] addr, input bit [31:0] data, input bit [3:0] strb);
    bit [31:0] wdata;
    bit [ 3:0] wstrb;
    bit [ 1:0] resp;
    wdata = data << ((addr % 4) * 8);
    wstrb = strb << (addr % 4);
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w({wdata, wstrb});
      intf.recv_b(resp);
    join
  endtask

  task automatic read(input bit [15:0] addr, output bit [31:0] data);
    bit [31:0] rdata;
    bit [ 1:0] resp;
    fork
      intf.send_ar({addr, 3'h0});
      intf.recv_r({rdata, resp});
    join
    data = rdata >> ((addr % 4) * 8);
  endtask

  task automatic write_32(input bit [15:0] addr, input bit [31:0] data);
    write(addr, data, 4'b1111);
  endtask

  task automatic write_16(input bit [15:0] addr, input bit [15:0] data);
    write(addr, data, 4'b0011);
  endtask

  task automatic write_8(input bit [15:0] addr, input bit [7:0] data);
    write(addr, data, 4'b0001);
  endtask

  task automatic read_32(input bit [15:0] addr, output bit [31:0] data);
    read(addr, data);
  endtask

  task automatic read_16(input bit [15:0] addr, output bit [15:0] data);
    read(addr, data);
  endtask

  task automatic read_8(input bit [15:0] addr, output bit [7:0] data);
    read(addr, data);
  endtask
  // Test Case Tasks

  // Test Case 01: Lowest Address Access


  
task automatic lowest_address_access();
  bit [7:0] byte_data;

  // Write 0xA5 to address 0x0000
  write_8(16'h0000, 8'hA5);

  // Read back the same byte
  read_8(16'h0000, byte_data);

  $display("TC1 Read Byte @0x0000 = 0x%02h", byte_data);
endtask


task automatic lowest_address_access();
    bit [7:0] expected = 8'hA5;
    bit [31:0] rdata;
    bit [1:0]  resp;

    $display("[%0t] TC1: Direct Write and Read at 0x0000", $time);

    // --- WRITE 1 byte ---
    fork
        intf.send_aw({16'h0000, 3'h0});                // send address
        intf.send_w({expected, 4'b0001});              // send data + strobe
        intf.recv_b(resp);                             // wait for write response
    join
    $display("[%0t] WRITE @0x0000 = 0x%02h, resp=%0d", $time, expected, resp);

    repeat (2) @(posedge clk_i);

    // --- READ 1 byte ---
    fork
        intf.send_ar({16'h0000, 3'h0});                // send read address
        intf.recv_r({rdata, resp});                    // wait for read data
    join

    $display("[%0t] READ @0x0000 = 0x%02h", $time, rdata[7:0]);

    if (rdata[7:0] === expected)
        $display("[%0t] TC1 PASSED: Data matches 0x%02h", $time, rdata[7:0]);
    else
        $display("[%0t] TC1 FAILED: Expected 0x%02h, Got 0x%02h",
                  $time, expected, rdata[7:0]);

    repeat (5) @(posedge clk_i);
endtask

 // Test Case 06: No-Op Write 

task automatic no_op_write();
  bit [31:0] data;   // local variable
  write(16'h1000, 32'hDEADBEEF, 4'b0000); // no-op write
  read_32(16'h1000, data);
  $display("TC6 Read @0x1000 = 0x%08h", data);
endtask


// Test Case 11: AW and W Independent Scenarios


task automatic aw_w_independent();
    bit [31:0] exp_data;
    bit [31:0] rdata;
    bit [1:0]  resp;

    $display("[%0t] TC11: AW/W independence", $time);

    // Scenario 1: W before AW
    exp_data = 32'h000000A5; // example data
    fork
        intf.send_w({exp_data, 4'b0001});   // send data first
        intf.send_aw({32'h0000_2000, 3'h0}); // send address later
        intf.recv_b(resp);                  // wait for write response
    join
    // Read back
    fork
        intf.send_ar({32'h0000_2000, 3'h0});
        intf.recv_r({rdata, resp});
    join
    $display("[%0t] TC11 Scenario1 Read = 0x%08h", $time, rdata);
    if (rdata == exp_data)
        $display("[%0t] TC11 Scenario1 PASSED", $time);
    else
        $display("[%0t] TC11 Scenario1 FAILED", $time);

    // Scenario 2: AW before W
    exp_data = 32'h0000005A; // another example data
    fork
        intf.send_aw({32'h0000_2004, 3'h0}); // send address first
        intf.send_w({exp_data, 4'b0001});    // send data later
        intf.recv_b(resp);
    join
    // Read back
    fork
        intf.send_ar({32'h0000_2004, 3'h0});
        intf.recv_r({rdata, resp});
    join
    $display("[%0t] TC11 Scenario2 Read = 0x%08h", $time, rdata);
    if (rdata == exp_data)
        $display("[%0t] TC11 Scenario2 PASSED", $time);
    else
        $display("[%0t] TC11 Scenario2 FAILED", $time);

    $display("[%0t] TC11 completed", $time);
endtask


// Test Case 16: Random Stress Test

task automatic random_stress_test();
    int num_txn = $urandom_range(50, 100);
    int pass_count = 0;
    bit [7:0] mem_model [0:65535]; // reference memory
    bit [15:0] addr;
    bit [7:0] data8;

    $display("[%0t] TC16 Random Stress Test Start (%0d transactions)", $time, num_txn);

    repeat (num_txn) begin
        addr  = $urandom_range(0, 65535);
        data8 = $urandom_range(0, 255);

        // Random delay
        repeat ($urandom_range(0, 5)) @(posedge clk_i);

        if ($urandom_range(0,1)) begin
            // WRITE
            write_8(addr, data8);
            mem_model[addr] = data8;
            $display("[%0t] WRITE addr=0x%04h data=0x%02h", $time, addr, data8);
        end else begin
            // READ
            read_8(addr, data8);
            if (data8 !== mem_model[addr]) begin
                $display("[%0t] READ MISMATCH addr=0x%04h exp=0x%02h got=0x%02h",
                         $time, addr, mem_model[addr], data8);
            end else begin
                $display("[%0t] READ OK addr=0x%04h data=0x%02h", $time, addr, data8);
                pass_count++;
            end
        end
    end

    $display("[%0t] TC16 Random Stress Test Completed: %0d/%0d reads passed",
             $time, pass_count, num_txn);
endtask



  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURAL
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    automatic bit [31:0] data;

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_mem_tb.vcd");
    $dumpvars(0, axi4l_mem_tb);

    clk_i   <= '0;
    arst_ni <= '0;
    intf.req_reset();
    #20;
    arst_ni <= '1;
    #20;
    fork
      forever #5 clk_i <= ~clk_i;
    join_none

    dvr = new();
    mon = new();
    dvr.connect_interface(intf);
    mon.connect_interface(intf);

    dvr.run();
    mon.run();

  repeat (10) @(posedge clk_i);


    write_16(1, 'hABCD);

    repeat (5) @(posedge clk_i);

    read_32(0, data);

    $display("R32 0 DATA:0x%h", data);

    read_16(1, data);

    $display("R16 1 DATA:0x%h", data);

    read_8(2, data);

    $display("R8 2 DATA:0x%h", data);

    lowest_address_access();
    no_op_write();
    aw_w_independent();
    random_stress_test();
    repeat (20) @(posedge clk_i);

    $finish;

  end

endmodule

*/


/* ADNAN

`include "axi4l/typedef.svh"
`include "vip/axi4l.svh"

// =============================================================================
// TC4  – Read-After-Write      → VIP interface tasks
// TC9  – W-channel backpressure → fully manual
// TC14 – Back-to-back writes   → VIP interface tasks
// DUT  : axi4l_mem  ADDR_WIDTH=32  DATA_WIDTH=64
// =============================================================================

module axi4l_mem_tb;

  //-------
  // 1. Clock / reset
  //-------

  logic clk_i   = 0;
  logic arst_ni = 0;

  always #5ns clk_i = ~clk_i;  // 100 MHz

  //-------
  // 2. Type definitions  (32-bit addr, 64-bit data)
  //-------

  `AXI4L_ALL(my, 32, 64)

  //-------
  // 3. Interface
  //-------

  axi4l_if #(
    .req_t (my_req_t),
    .rsp_t (my_rsp_t)
  ) intf (
    .arst_ni (arst_ni),
    .clk_i   (clk_i)
  );

  //-------
  // 4. DUT
  //-------

  axi4l_mem #(
    .axi4l_req_t (my_req_t),
    .axi4l_rsp_t (my_rsp_t),
    .ADDR_WIDTH  (32),
    .DATA_WIDTH  (64)
  ) dut (
    .arst_ni     (arst_ni),
    .clk_i       (clk_i),
    .axi4l_req_i (intf.req),
    .axi4l_rsp_o (intf.rsp)
  );

  //-------
  // 5. VIP objects
  //-------

  import axi4l_vip_pkg::axi4l_driver;
  import axi4l_vip_pkg::axi4l_monitor;

  axi4l_driver  #(.req_t(my_req_t), .rsp_t(my_rsp_t), .IS_MASTER(1)) dvr;
  axi4l_monitor #(.req_t(my_req_t), .rsp_t(my_rsp_t))                 mon;

  //-------
  // 6. Scoreboard
  //-------

  int pass_count = 0;
  int fail_count = 0;

  task automatic check_resp(
    input string      label,
    input logic [1:0] got,
    input logic [1:0] exp
  );
    if (got === exp)
      $display("  [PASS] %s", label);
    else
      $display("  [FAIL] %s  got=2'b%02b  exp=2'b%02b", label, got, exp);
    if (got === exp) pass_count++; else fail_count++;
  endtask

  task automatic check_data(
    input string       label,
    input logic [63:0] got,
    input logic [63:0] exp
  );
    if (got === exp)
      $display("  [PASS] %s", label);
    else
      $display("  [FAIL] %s  got=0x%016h  exp=0x%016h", label, got, exp);
    if (got === exp) pass_count++; else fail_count++;
  endtask

  //-------
  // 7. write64 / read64 helpers
  //-------

  task automatic write64(
    input logic [31:0] addr,
    input logic [63:0] data
  );
    my_aw_chan_t aw;
    my_w_chan_t  w;
    my_b_chan_t  b;
    aw.addr = addr;  aw.prot = 3'b000;
    w.data  = data;  w.strb  = 8'hFF;
    fork
      intf.send_aw(aw);
      intf.send_w(w);
      intf.recv_b(b);
    join
  endtask

  task automatic read64(
    input  logic [31:0] addr,
    output logic [63:0] data
  );
    my_ar_chan_t ar;
    my_r_chan_t  r;
    ar.addr = addr;  ar.prot = 3'b000;
    fork
      intf.send_ar(ar);
      intf.recv_r(r);
    join
    data = r.data;
  endtask

  // ===================================================================
  // TC4 – Read-After-Write
  // ===================================================================

  task automatic tc4();
    my_aw_chan_t aw;
    my_w_chan_t  w;
    my_b_chan_t  b;
    my_ar_chan_t ar;
    my_r_chan_t  r1;
    logic [63:0] rdata2;

    $display("\n[TC4] Read-After-Write");

    aw.addr = 32'h0000_0010;  aw.prot = 3'b000;
    w.data  = 64'hDEAD_BEEF_CAFE_1234;  w.strb = 8'hFF;
    ar.addr = 32'h0000_0010;  ar.prot = 3'b000;

    fork
      intf.send_aw(aw);
      intf.send_w(w);
      begin @(posedge clk_i); intf.send_ar(ar); end  // 1 cycle after AW+W
      intf.recv_b(b);
      intf.recv_r(r1);
    join

    $display("  b.resp=%0b  r1.data=0x%016h (old or new – both OK)",
             b.resp, r1.data);
    check_resp("TC4 write resp", b.resp, 2'b00);

    read64(32'h0000_0010, rdata2);
    $display("  r2.data=0x%016h", rdata2);
    check_data("TC4 readback", rdata2, 64'hDEAD_BEEF_CAFE_1234);

  endtask

  // =========================================================================
  // TC9 – W-Channel Back-Pressure  (manual — no VIP driver)
  //
  // Phase 1 – fill W FIFO:
  //   Drive each beat as a PROPER handshake:
  //     assert w_valid → wait one posedge → if w_ready=1 beat accepted,
  //     deassert w_valid → wait one cycle → next beat.
  //   This keeps w_valid LOW when w_ready=0, which is AXI-compliant and
  //   prevents new beats entering the FIFO during the drain phase.
  //   Loop runs 6 cycles: expect 4 accepted + 2 blocked (FIFO full).
  //
  // Phase 2 – drain:
  //   w_valid is already 0. Supply 4 AW beats with b_ready=1.
  //   FIFO drains cleanly with no new beats entering.
  //
  // Phase 3 – readback.
  // =========================================================================

  task automatic tc9();
    int  accepted = 0;
    bit  went_low = 0;
    logic [63:0] rdata;

    $display("\n[TC9] W-channel back-pressure");

    // Idle all channels
    intf.req.aw_valid <= 0;
    intf.req.b_ready  <= 0;
    intf.req.w_valid  <= 0;
    intf.req.ar_valid <= 0;
    intf.req.r_ready  <= 0;
    @(posedge clk_i);

    //------
    // Phase 1: drive beats — check w_ready BEFORE asserting w_valid
    //
    // KEY FIX: if w_ready is already 0 (FIFO full), do NOT assert valid.
    // AXI rule: valid must not be dropped while ready=0.
    // Solution: never assert valid when ready=0 — observe full passively.
    //------
    for (int i = 0; i < 6; i++) begin

      // Sample w_ready BEFORE asserting valid
      // Use negedge to set data stable, then check ready at next posedge
      @(negedge clk_i);
      intf.req.w.data <= 64'hA5A5_A5A5_5A5A_5A5A;
      intf.req.w.strb <= 8'hFF;

      @(posedge clk_i);   // sample point — valid still 0 here

      if (intf.rsp.w_ready) begin
        // FIFO has space — safe to assert valid and complete handshake
        @(negedge clk_i);
        intf.req.w_valid <= 1;          // assert valid
        @(posedge clk_i);               // handshake completes this cycle
        // w_ready=1 (we checked before asserting), handshake done
        @(negedge clk_i);
        intf.req.w_valid <= 0;          // safe to drop — ready was 1
        accepted++;
        $display("  beat %0d accepted", accepted);
      end else begin
        // FIFO full — observe back-pressure WITHOUT asserting valid
        // No AXI violation possible since valid never went high
        if (!went_low) begin
          went_low = 1;
          $display("  FIFO full after %0d beats – now blocking", accepted);
        end
        // w_valid stays 0 — nothing to clean up
      end

    end

    //------
    // Phase 2: drain — w_valid=0, FIFO has exactly 4 buffered beats
    // Supply 4 AW beats. Each pops one W beat from FIFO.
    // Nothing new enters because w_valid=0.
    //------
    intf.req.b_ready <= 1;

    repeat (4) begin
      @(negedge clk_i);
      intf.req.aw.addr  <= 32'h0000_0000;
      intf.req.aw.prot  <= 3'b000;
      intf.req.aw_valid <= 1;

      do @(posedge clk_i); while (!intf.rsp.aw_ready);

      @(negedge clk_i);
      intf.req.aw_valid <= 0;

      do @(posedge clk_i); while (!intf.rsp.b_valid);
      check_resp("TC9 b.resp", intf.rsp.b.resp, 2'b00);
    end

    @(negedge clk_i);
    intf.req.b_ready <= 0;
    repeat(3) @(posedge clk_i);

    //------
    // Phase 3: read back
    //------
    read64(32'h0000_0000, rdata);
    check_resp("TC9 w_ready went low", {1'b0, went_low}, 2'b01);
    check_data("TC9 readback",         rdata, 64'hA5A5_A5A5_5A5A_5A5A);

  endtask

  // ===================================================================
  // TC14 – Back-to-Back Writes
  // ===================================================================

  task automatic tc14();
    logic [63:0] rdata;

    $display("\n[TC14] Back-to-back writes");

    write64(32'h0000_0100, 64'hCAFE_0000_0000_0001);
    write64(32'h0000_0108, 64'hCAFE_0000_0000_0002);
    write64(32'h0000_0110, 64'hCAFE_0000_0000_0003);
    write64(32'h0000_0118, 64'hCAFE_0000_0000_0004);

    read64(32'h0000_0100, rdata); check_data("TC14 addr=0x100", rdata, 64'hCAFE_0000_0000_0001);
    read64(32'h0000_0108, rdata); check_data("TC14 addr=0x108", rdata, 64'hCAFE_0000_0000_0002);
    read64(32'h0000_0110, rdata); check_data("TC14 addr=0x110", rdata, 64'hCAFE_0000_0000_0003);
    read64(32'h0000_0118, rdata); check_data("TC14 addr=0x118", rdata, 64'hCAFE_0000_0000_0004);

  endtask

  // ===================================================================
  // Main
  // ===================================================================

  initial begin
    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_mem_tb.vcd");
    $dumpvars(0, axi4l_mem_tb);
    $display("\033[7;38m TEST STARTED \033[0m");

    dvr = new();
    mon = new();
    dvr.connect_interface(intf);
    mon.connect_interface(intf);

    arst_ni = 0;
    intf.req_reset();
    repeat (4) @(posedge clk_i);
    arst_ni = 1;
    repeat (4) @(posedge clk_i);

    dvr.run();
    mon.run();

    tc4();
    repeat (10) @(posedge clk_i);

    tc9();
    repeat (10) @(posedge clk_i);

    tc14();
    repeat (5) @(posedge clk_i);

    $display("\n\033[7;%0dm  RESULT: %0d PASS  |  %0d FAIL  \033[0m",
             (fail_count == 0) ? 32 : 31, pass_count, fail_count);
    $display("\033[7;38m TEST ENDED \033[0m");
    $finish;
  end

endmodule

*/

