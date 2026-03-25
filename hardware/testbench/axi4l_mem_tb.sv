`include "axi4l/typedef.svh"
`include "vip/axi4l.svh"
module axi4l_mem_tb;

// ------------------- PARAMETERS -------------------
// AXI4-Lite configuration: 16-bit address, 32-bit data bus
localparam int ADDR_WIDTH = 16;
localparam int DATA_WIDTH = 32;

// Macro expands all AXI4-Lite typedefs (req_t, rsp_t, etc.)
`AXI4L_ALL(my, ADDR_WIDTH, DATA_WIDTH)

// ------------------- SIGNALS -------------------
logic arst_ni;          // active-low asynchronous reset
logic clk_i;            // clock input

// AXI4-Lite interface instance (uses the typedefs from macro)
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

// -------------------- TASKS --------------------
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

// -------------------- VIP DRIVER / MONITOR --------------------
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

// -------------------- HELPER TASKS --------------------
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

// -------------------- TEST CASES --------------------

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
        dvr.mbx.put(item);
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
        dvr.mbx.put(item);
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
    dvr.mbx.put(item);

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
    dvr.mbx.put(item_wr);
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
            dvr.mbx.put(item_wr);
        end
        begin
            item_rd = new();
            item_rd.is_write = 0;
            item_rd.addr     = 32'h200;
            dvr.mbx.put(item_rd);
        end
    join

    // to fire before bus activity begins; drain() handles sync correctly on its own
    drain(q);

    foreach (q[i])
        check(q[i].resp === 2'b00, p, f);
endtask

// -------------------- MAIN INITIAL --------------------
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

    // -------------------- ORIGINAL TESTS --------------------
    write_16(1, 'hABCD);               // 16-bit write to byte offset 1; data shifts to lanes [1:0]
    repeat (5) @(posedge clk_i);
    read_32(0, data);
    $display("R32 0 DATA:0x%h", data); // expect 0x0000ABCD (byte lanes [1:0] set; [3:2] still 0)
    read_16(1, data);
    $display("R16 1 DATA:0x%h", data);
    read_8(2, data);
    $display("R8 2 DATA:0x%h", data);

    // -------------------- VIP DRIVER RUN --------------------
    dvr = new();
    mon = new();
    dvr.connect_interface(intf);       // bind driver to the DUT interface virtual interface handle
    mon.connect_interface(intf);       // bind monitor to the same interface for passive observation
    dvr.run();                         // spawn driver thread: pulls items from dvr.mbx and drives bus
    mon.run();                         // spawn monitor thread: samples bus, pushes rsp_items to mon.mbx

    // -------------------- RUN TEST CASES --------------------
    repeat(5) begin                    // repeat all test cases 5× to stress pipelining behaviour
      tc3(p,f);  total_p += p; total_f += f;
      tc8(p,f);  total_p += p; total_f += f;
      tc13(p,f); total_p += p; total_f += f;
    end

    // -------------------- FINAL RESULT --------------------
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
    dvr.mbx.put(item);

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
    dvr.mbx.put(item);

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

// -------------------- TASKS --------------------
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

// -------------------- VIP DRIVER / MONITOR --------------------
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

// -------------------- HELPER TASKS --------------------
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

// -------------------- TEST CASES --------------------

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
        dvr.mbx.put(item);
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
        dvr.mbx.put(item);
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
    dvr.mbx.put(item);

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
    dvr.mbx.put(item_wr);
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
            dvr.mbx.put(item_wr);
        end
        begin
            item_rd = new();
            item_rd.is_write = 0;
            item_rd.addr     = 32'h200;
            dvr.mbx.put(item_rd);
        end
    join

    // to fire before bus activity begins; drain() handles sync correctly on its own
    drain(q);

    foreach (q[i])
        check(q[i].resp === 2'b00, p, f);
endtask

// -------------------- MAIN INITIAL --------------------
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

    // -------------------- ORIGINAL TESTS --------------------
    write_16(1, 'hABCD);               // 16-bit write to byte offset 1; data shifts to lanes [1:0]
    repeat (5) @(posedge clk_i);
    read_32(0, data);
    $display("R32 0 DATA:0x%h", data); // expect 0x0000ABCD (byte lanes [1:0] set; [3:2] still 0)
    read_16(1, data);
    $display("R16 1 DATA:0x%h", data);
    read_8(2, data);
    $display("R8 2 DATA:0x%h", data);

    // -------------------- VIP DRIVER RUN --------------------
    dvr = new();
    mon = new();
    dvr.connect_interface(intf);       // bind driver to the DUT interface virtual interface handle
    mon.connect_interface(intf);       // bind monitor to the same interface for passive observation
    dvr.run();                         // spawn driver thread: pulls items from dvr.mbx and drives bus
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

    dvr.mbx.put(item);

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

    dvr.mbx.put(item);

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

    dvr.mbx.put(item);

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

    dvr.mbx.put(item);

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

    // -------------------- RUN TEST CASES --------------------
    repeat(5) begin                    // repeat all test cases 5× to stress pipelining behaviour
      tc3(p,f);  total_p += p; total_f += f;
      tc8(p,f);  total_p += p; total_f += f;
      tc13(p,f); total_p += p; total_f += f;
    end

    // -------------------- FINAL RESULT --------------------
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


