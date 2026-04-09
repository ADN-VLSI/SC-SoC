task automatic tc3_write_32(
  input  logic [31:0] addr,
  input  logic [31:0] data,
  output logic [1:0]  bresp
);
  begin
    cpu_write_32(addr, data, bresp);
  end
endtask

task automatic tc3_write_32_strb(
  input  logic [31:0] addr,
  input  logic [31:0] data,
  input  logic [3:0]  strb,
  output logic [1:0]  bresp
);
  begin
    fork
      cpu_aw_channel_send(addr);
      cpu_w_channel_send(data, strb);
      cpu_b_channel_recv(bresp);
    join
  end
endtask

task automatic tc3_read_32(
  input  logic [31:0] addr,
  output logic [31:0] data,
  output logic [1:0]  rresp
);
  begin
    cpu_read_32(addr, data, rresp);
  end
endtask

task automatic tc3_check_snapshot(
  input string       label,
  input logic [31:0] ctrl_exp,
  input logic [31:0] cfg_exp,
  input logic [31:0] int_en_exp,
  input logic [31:0] stat_exp
);
  logic [31:0] ctrl_rd;
  logic [31:0] cfg_rd;
  logic [31:0] int_en_rd;
  logic [31:0] stat_rd;
  logic [1:0]  rresp;

  begin
    tc3_read_32(UART_CTRL_OFFSET, ctrl_rd, rresp);
    testcase_check((rresp === 2'b00) && (ctrl_rd === ctrl_exp),
                   $sformatf("%s CTRL unchanged (resp=%0b got=0x%08h exp=0x%08h)",
                             label, rresp, ctrl_rd, ctrl_exp));

    tc3_read_32(UART_CFG_OFFSET, cfg_rd, rresp);
    testcase_check((rresp === 2'b00) && (cfg_rd === cfg_exp),
                   $sformatf("%s CFG unchanged (resp=%0b got=0x%08h exp=0x%08h)",
                             label, rresp, cfg_rd, cfg_exp));

    tc3_read_32(UART_INT_EN_OFFSET, int_en_rd, rresp);
    testcase_check((rresp === 2'b00) && (int_en_rd === int_en_exp),
                   $sformatf("%s INT_EN unchanged (resp=%0b got=0x%08h exp=0x%08h)",
                             label, rresp, int_en_rd, int_en_exp));

    tc3_read_32(UART_STAT_OFFSET, stat_rd, rresp);
    testcase_check((rresp === 2'b00) && (stat_rd === stat_exp),
                   $sformatf("%s STATUS unchanged (resp=%0b got=0x%08h exp=0x%08h)",
                             label, rresp, stat_rd, stat_exp));
  end
endtask

task automatic tc3(); // AXI Invalid Address
  logic [31:0] ctrl_before;
  logic [31:0] cfg_before;
  logic [31:0] stat_before;
  logic [31:0] int_en_before;
  logic [31:0] rdata;
  logic [1:0]  bresp;
  logic [1:0]  rresp;
  logic [31:0] invalid_addrs[4];
  bit          snapshot_valid;
  string       addr_label;

  begin
    testcase_begin("TC3");
    reset_dut();

    invalid_addrs = '{32'h0000_0FF0, 32'h0000_0100, 32'h0000_0200, 32'h0000_0FFC};
    snapshot_valid = 1'b1;

    tc3_read_32(UART_CTRL_OFFSET, ctrl_before, rresp);
    testcase_check(rresp === 2'b00,
                   $sformatf("CTRL snapshot read returned OKAY (RRESP=%0b)", rresp));
    if (rresp !== 2'b00) snapshot_valid = 1'b0;

    tc3_read_32(UART_CFG_OFFSET, cfg_before, rresp);
    testcase_check(rresp === 2'b00,
                   $sformatf("CFG snapshot read returned OKAY (RRESP=%0b)", rresp));
    if (rresp !== 2'b00) snapshot_valid = 1'b0;

    tc3_read_32(UART_INT_EN_OFFSET, int_en_before, rresp);
    testcase_check(rresp === 2'b00,
                   $sformatf("INT_EN snapshot read returned OKAY (RRESP=%0b)", rresp));
    if (rresp !== 2'b00) snapshot_valid = 1'b0;

    tc3_read_32(UART_STAT_OFFSET, stat_before, rresp);
    testcase_check(rresp === 2'b00,
                   $sformatf("STATUS snapshot read returned OKAY (RRESP=%0b)", rresp));
    if (rresp !== 2'b00) snapshot_valid = 1'b0;

    if (snapshot_valid) begin
      foreach (invalid_addrs[i]) begin
        addr_label = $sformatf("addr 0x%08h", invalid_addrs[i]);

        tc3_write_32_strb(invalid_addrs[i], 32'h1234_5678, 4'hF, bresp);
        testcase_check(bresp === 2'b10,
                       $sformatf("%s invalid write with WSTRB=0xF returned SLVERR (BRESP=%0b)",
                                 addr_label, bresp));

        tc3_write_32_strb(invalid_addrs[i], 32'h89AB_CDEF, 4'h0, bresp);
        testcase_check(bresp === 2'b10,
                       $sformatf("%s invalid write with WSTRB=0x0 returned SLVERR (BRESP=%0b)",
                                 addr_label, bresp));

        tc3_read_32(invalid_addrs[i], rdata, rresp);
        testcase_check(rresp === 2'b10,
                       $sformatf("%s invalid read returned SLVERR (RRESP=%0b)", addr_label, rresp));
        testcase_check((rdata === 32'h0000_0000) || (rdata === 32'hDEAD_BEEF),
                       $sformatf("%s invalid read data allowed don't-care value 0x%08h",
                                 addr_label, rdata));

        tc3_check_snapshot({addr_label, " post-invalid"}, ctrl_before, cfg_before,
                           int_en_before, stat_before);

        tc3_write_32(UART_CTRL_OFFSET, ctrl_before, bresp);
        testcase_check(bresp === 2'b00,
                       $sformatf("%s recovery CTRL write succeeded (BRESP=%0b)",
                                 addr_label, bresp));

        tc3_read_32(UART_CTRL_OFFSET, rdata, rresp);
        testcase_check((rresp === 2'b00) && (rdata === ctrl_before),
                       $sformatf("%s recovery CTRL readback matched snapshot (RRESP=%0b DATA=0x%08h)",
                                 addr_label, rresp, rdata));

        tc3_check_snapshot({addr_label, " post-recovery"}, ctrl_before, cfg_before,
                           int_en_before, stat_before);
      end
    end else begin
      testcase_check(1'b0, "Snapshot setup failed, skipping invalid-address body checks");
    end

    repeat (2) @(posedge clk_i);
    testcase_check(!(req_i.aw_valid || req_i.w_valid || req_i.b_ready ||
                     req_i.ar_valid || req_i.r_ready),
                   $sformatf("AXI handshake signals returned idle (aw=%0b w=%0b b_ready=%0b ar=%0b r_ready=%0b)",
                             req_i.aw_valid, req_i.w_valid, req_i.b_ready, req_i.ar_valid, req_i.r_ready));

    testcase_end();
  end
endtask
