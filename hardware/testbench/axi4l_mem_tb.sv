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