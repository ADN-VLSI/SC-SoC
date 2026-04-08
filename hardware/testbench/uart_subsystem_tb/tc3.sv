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
    if ((rresp !== 2'b00) || (ctrl_rd !== ctrl_exp))
      $fatal(1, "TC3 CTRL changed unexpectedly: resp=%0b got=0x%08h expected=0x%08h",
             rresp, ctrl_rd, ctrl_exp);

    tc3_read_32(UART_CFG_OFFSET, cfg_rd, rresp);
    if ((rresp !== 2'b00) || (cfg_rd !== cfg_exp))
      $fatal(1, "TC3 CFG changed unexpectedly: resp=%0b got=0x%08h expected=0x%08h",
             rresp, cfg_rd, cfg_exp);

    tc3_read_32(UART_INT_EN_OFFSET, int_en_rd, rresp);
    if ((rresp !== 2'b00) || (int_en_rd !== int_en_exp))
      $fatal(1, "TC3 INT_EN changed unexpectedly: resp=%0b got=0x%08h expected=0x%08h",
             rresp, int_en_rd, int_en_exp);

    tc3_read_32(UART_STAT_OFFSET, stat_rd, rresp);
    if ((rresp !== 2'b00) || (stat_rd !== stat_exp))
      $fatal(1, "TC3 STATUS changed unexpectedly: resp=%0b got=0x%08h expected=0x%08h",
             rresp, stat_rd, stat_exp);
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
  begin
    $display("TC3: AXI Invalid Address");

    reset_dut();

    invalid_addrs = '{32'h0000_0FF0, 32'h0000_0100, 32'h0000_0200, 32'h0000_0FFC};

    tc3_read_32(UART_CTRL_OFFSET, ctrl_before, rresp);
    if (rresp !== 2'b00) $fatal(1, "TC3 failed to read CTRL snapshot, RRESP=%0b", rresp);

    tc3_read_32(UART_CFG_OFFSET, cfg_before, rresp);
    if (rresp !== 2'b00) $fatal(1, "TC3 failed to read CFG snapshot, RRESP=%0b", rresp);

    tc3_read_32(UART_INT_EN_OFFSET, int_en_before, rresp);
    if (rresp !== 2'b00) $fatal(1, "TC3 failed to read INT_EN snapshot, RRESP=%0b", rresp);

    tc3_read_32(UART_STAT_OFFSET, stat_before, rresp);
    if (rresp !== 2'b00) $fatal(1, "TC3 failed to read STATUS snapshot, RRESP=%0b", rresp);

    foreach (invalid_addrs[i]) begin
      $display("  Invalid AXI address 0x%08h", invalid_addrs[i]);

      tc3_write_32_strb(invalid_addrs[i], 32'h1234_5678, 4'hF, bresp);
      if (bresp !== 2'b10)
        $fatal(1, "TC3 invalid write with WSTRB=0xF returned BRESP=%0b at 0x%08h",
               bresp, invalid_addrs[i]);

      tc3_write_32_strb(invalid_addrs[i], 32'h89AB_CDEF, 4'h0, bresp);
      if (bresp !== 2'b10)
        $fatal(1, "TC3 invalid write with WSTRB=0x0 returned BRESP=%0b at 0x%08h",
               bresp, invalid_addrs[i]);

      tc3_read_32(invalid_addrs[i], rdata, rresp);
      if (rresp !== 2'b10)
        $fatal(1, "TC3 invalid read returned RRESP=%0b at 0x%08h", rresp, invalid_addrs[i]);
      if ((rdata !== 32'h0000_0000) && (rdata !== 32'hDEAD_BEEF))
        $fatal(1, "TC3 invalid read data was 0x%08h at 0x%08h; expected 0 or 0xDEADBEEF",
               rdata, invalid_addrs[i]);

      tc3_check_snapshot(ctrl_before, cfg_before, int_en_before, stat_before);

      tc3_write_32(UART_CTRL_OFFSET, ctrl_before, bresp);
      if (bresp !== 2'b00)
        $fatal(1, "TC3 recovery CTRL write failed after 0x%08h, BRESP=%0b", invalid_addrs[i], bresp);

      tc3_read_32(UART_CTRL_OFFSET, rdata, rresp);
      if ((rresp !== 2'b00) || (rdata !== ctrl_before))
        $fatal(1, "TC3 recovery CTRL readback failed after 0x%08h: resp=%0b data=0x%08h",
               invalid_addrs[i], rresp, rdata);

      tc3_check_snapshot(ctrl_before, cfg_before, int_en_before, stat_before);
    end

    repeat (2) @(posedge clk_i);
    if (req_i.aw_valid || req_i.w_valid || req_i.b_ready ||
        req_i.ar_valid || req_i.r_ready)
      $fatal(1, "TC3 detected a hung AXI handshake signal after completion");

    $display("TC3 completed successfully");
  end
endtask
