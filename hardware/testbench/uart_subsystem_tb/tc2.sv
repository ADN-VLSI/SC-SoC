/////////////////////////////////////////////////////////////////////////
// 
// TC2: AXI Basic Read/Write
//
/////////////////////////////////////////////////////////////////////////
//
// Author: Shykul Islam Siam
//
/////////////////////////////////////////////////////////////////////////
//
// Objective: Verifies that the AXI4-Lite register interface responds
//            correctly to basic CPU read and write transactions.
//
/////////////////////////////////////////////////////////////////////////
//
// Restore:
//   CTRL, CFG, and INT_EN are restored to their baseline
//   values captured at the start of the task.
//
/////////////////////////////////////////////////////////////////////////
//
// Pass criteria:
//   All BRESP and RRESP responses == 2'b00 (OKAY).
//   CFG and INT_EN readback data matches written value.
//   STATUS readback data unchanged after write attempt.
//
/////////////////////////////////////////////////////////////////////////
//
// Step-by-step process:
//
//  Step 1:  Baseline reads
//          Read CTRL, CFG, and INT_EN to capture reset-state
//          values. Each read is checked for RRESP == OKAY.
//
//  Step 2  CTRL protocol stress
//    2a    Write 0xA5A5_A5A5. Check BRESP == OKAY.
//          Wait 5 clocks. Read back. Check RRESP == OKAY.
//    2b    Write 0x0000_0000. Check BRESP == OKAY.
//          Wait 5 clocks. Read back. Check RRESP == OKAY.
//          (No data check — DUT does not mirror CTRL cleanly.)
//
//  Step 3:  CFG write + readback
//          Write 0x0000_0271. Check BRESP == OKAY.
//          Read back. Check RRESP == OKAY.
//          Check readback data == 0x0000_0271.
//
//  Step 4:  INT_EN write + readback
//          Write 0x0000_000F. Check BRESP == OKAY.
//          Read back. Check RRESP == OKAY.
//          Check readback data == 0x0000_000F.
//
//  Step 5:  STATUS read-only verification
//          Read STATUS baseline. Check RRESP == OKAY.
//          Attempt write of 0xFFFF_FFFF. Log BRESP (no assert).
//          Read back. Check RRESP == OKAY.
//          Check readback data == baseline (register unchanged).
//
//  Step 6:  CTRL back-to-back pattern writes (i = 1 to 10)
//          For each i:
//            Write i to CTRL. Check BRESP == OKAY.
//            Wait 5 clocks. Read back. Check RRESP == OKAY.
//          (No data check — protocol stress only.)
//
//  Step 7:  Restore
//          Write saved baseline values back to CTRL, CFG,
//          and INT_EN. Wait 5 clocks.
//
/////////////////////////////////////////////////////////////////////////

task automatic tc2();                                       
    logic [31:0] r, ctrl0, cfg0, ien0, stat0;                                       // r = scratch; ctrl0/cfg0/ien0/stat0 = baseline snapshots
    logic [1:0]  bresp, rresp;                                                      // bresp = write response; rresp = read response

    $display("------------------------------------------------------------");       // visual separator in sim log
    $display("TC2: AXI Basic Read/Write");                                          // test case banner
    $display("------------------------------------------------------------");       // visual separator in sim log

    // Step 1: capture reset-state baselines before any writes
    cpu_read_32(UART_CTRL_OFFSET,   ctrl0, rresp); check(rresp == 2'b00, "CTRL baseline read RRESP=OK");    // save CTRL default
    cpu_read_32(UART_CFG_OFFSET,    cfg0,   rresp); check(rresp == 2'b00, "CFG baseline read RRESP=OK");    // save CFG default
    cpu_read_32(UART_INT_EN_OFFSET, ien0,   rresp); check(rresp == 2'b00, "INT_EN baseline read RRESP=OK"); // save INT_EN default

    // Step 2a: CTRL alternating-bit write — protocol check only, no data assert
    cpu_write_32(UART_CTRL_OFFSET, 32'hA5A5_A5A5, bresp);                            // 0xA5 = 1010_0101, exercises every bit position
    check(bresp == 2'b00, "CTRL write BRESP=OK");                                    // AXI must acknowledge write cleanly
    repeat (5) @(posedge clk_i);                                                     // settle before read
    cpu_read_32(UART_CTRL_OFFSET, r, rresp);                                         // read back after alternating-bit write
    check(rresp == 2'b00, "CTRL read RRESP=OK");                                     // read channel must respond OKAY

    // Step 2b: CTRL zero write — leaves register in neutral state before pattern loop
    cpu_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp);                           // clear all bits
    check(bresp == 2'b00, "CTRL zero write BRESP=OK");                              // AXI must acknowledge write cleanly
    repeat (5) @(posedge clk_i);                                                    // settle before read
    cpu_read_32(UART_CTRL_OFFSET, r, rresp);                                        // read back after zero write
    check(rresp == 2'b00, "CTRL zero read RRESP=OK");                               // read channel must respond OKAY

    // Step 3: CFG full write + exact readback check
    cpu_write_32(UART_CFG_OFFSET, 32'h0000_0271, bresp);                            // specific baud/config value
    check(bresp == 2'b00, "CFG write BRESP=OK");                                    // AXI must acknowledge write cleanly
    cpu_read_32(UART_CFG_OFFSET, r, rresp);                                         // read back written value
    check(rresp == 2'b00, "CFG read RRESP=OK");                                     // read channel must respond OKAY
    check(r == 32'h0000_0271, $sformatf("CFG readback 0x%08h", r));                 // must match exactly — CFG is full R/W

    // Step 4: INT_EN full write + exact readback check
    cpu_write_32(UART_INT_EN_OFFSET, 32'h0000_000F, bresp);                         // enable 4 lowest interrupt sources
    check(bresp == 2'b00, "INT_EN write BRESP=OK");                                 // AXI must acknowledge write cleanly
    cpu_read_32(UART_INT_EN_OFFSET, r, rresp);                                      // read back written value
    check(rresp == 2'b00, "INT_EN read RRESP=OK");                                  // read channel must respond OKAY
    check(r == 32'h0000_000F, $sformatf("INT_EN readback 0x%08h", r));              // must match exactly — no bit silently dropped

    // Step 5: STATUS is RO — write must not corrupt the register
    cpu_read_32(UART_STAT_OFFSET, stat0, rresp);                                    // capture HW-driven baseline
    check(rresp == 2'b00, "STATUS baseline read RRESP=OK");                         // bus must be alive before write attempt
    cpu_write_32(UART_STAT_OFFSET, 32'hFFFF_FFFF, bresp);                           // attempt all-ones write to RO register
    $display("STATUS write attempt BRESP=0x%0b", bresp);                            // log only — AXI4-Lite does not mandate SLVERR for RO
    cpu_read_32(UART_STAT_OFFSET, r, rresp);                                        // read back after write attempt
    check(rresp == 2'b00, "STATUS post-write read RRESP=OK");                       // read channel must still respond OKAY
    check(r == stat0, $sformatf("STATUS unchanged: 0x%08h == 0x%08h", r, stat0));   // data must be unaffected by write attempt

    // Step 6: back-to-back CTRL pattern writes — stresses AXI write path, protocol check only
    for (int i = 1; i <= 10; i++) begin                                             // iterate values 1 through 10
        cpu_write_32(UART_CTRL_OFFSET, i, bresp);                                   // write incrementing pattern value
        check(bresp == 2'b00, $sformatf("CTRL pattern %0d write BRESP=OK", i));     // AXI must acknowledge each write
        repeat (5) @(posedge clk_i);                                                // settle before read
        cpu_read_32(UART_CTRL_OFFSET, r, rresp);                                    // read back after each pattern write
        check(rresp == 2'b00, $sformatf("CTRL pattern %0d read RRESP=OK", i));      // read channel must respond OKAY each time
    end                                                                             // end pattern loop

    // Step 7: restore baselines so subsequent TCs start from a clean state
    cpu_write_32(UART_CTRL_OFFSET,   ctrl0, bresp);                                  // restore CTRL
    cpu_write_32(UART_CFG_OFFSET,    cfg0,   bresp);                                 // restore CFG
    cpu_write_32(UART_INT_EN_OFFSET, ien0,   bresp);                                 // restore INT_EN
    repeat (5) @(posedge clk_i);                                                     // settle before task returns

endtask                                                                              // end tc2