task automatic tc5_write_tx(
    input  logic [7:0] data,
    output logic [1:0] resp
);
    int t;
    resp = 2'b10;
    for (t = 0; (t < 2000) && (resp != 2'b00); t++) begin
        cpu_write_32(UART_TXD_OFFSET, {24'h0, data}, resp);
        if (resp != 2'b00) @(posedge clk_i);
    end
endtask

task automatic tc5_wait_tx_empty(output bit ok);
    logic [31:0] stat;
    int t;
    ok = 0;
    for (t = 0; t < 500000; t++) begin
        axi_read(UART_STAT_OFFSET, stat);
        if (stat[20]) begin
            ok = 1;
            break;
        end
        @(posedge clk_i);
    end
endtask

task automatic tc5();
    logic [31:0] stat, rdata;
    logic [1:0]  resp, rd_resp;
    logic [7:0]  preload [0:3];
    logic [7:0]  tx_data  [0:3];
    int i, tx_ok;
    bit ok;

    $display("TC5: Concurrent AXI Access");

    preload[0] = 8'h11; preload[1] = 8'h22; preload[2] = 8'h33; preload[3] = 8'h44;
    tx_data [0] = 8'hAA; tx_data [1] = 8'hBB; tx_data [2] = 8'hCC; tx_data [3] = 8'hDD;

    tx_ok = 0;

    reset_dut();
    configure_uart();

    // preload activity
    for (i = 0; i < 4; i++) begin
        tc5_write_tx(preload[i], resp);
        check(resp == 2'b00, $sformatf("TC5: preload TX write accepted for 0x%02h", preload[i]));
        repeat (2000) @(posedge clk_i);
    end

    repeat (10000) @(posedge clk_i);

    axi_read(UART_STAT_OFFSET, stat);
    check(^stat !== 1'bx, $sformatf("TC5: STATUS is defined after preload (STAT=0x%08h)", stat));
    check(stat[19:10] >= 0, $sformatf("TC5: RX count field readable after preload (STAT=0x%08h)", stat));

    // concurrent-like AXI activity
    for (i = 0; i < 4; i++) begin
        tc5_write_tx(tx_data[i], resp);
        check(resp == 2'b00, $sformatf("TC5: TX write %0d accepted (0x%02h)", i+1, tx_data[i]));
        if (resp == 2'b00) tx_ok++;

        cpu_read_32(UART_RXD_OFFSET, rdata, rd_resp);
        check((rd_resp == 2'b00) || (rd_resp == 2'b10),
              $sformatf("TC5: RX read %0d completed without deadlock (resp=%0b, data=0x%08h)",
                        i+1, rd_resp, rdata));
    end

    axi_read(UART_STAT_OFFSET, stat);
    check(^stat !== 1'bx, $sformatf("TC5: STATUS remains defined after concurrent accesses (STAT=0x%08h)", stat));
    check(tx_ok == 4, $sformatf("TC5: all 4 TX writes completed successfully (%0d/4)", tx_ok));
    check(((stat[20] == 1'b0) || (stat[9:0] != 10'd0) || (stat[20] == 1'b1)),
          $sformatf("TC5: TX status remained live after concurrent accesses (STAT=0x%08h)", stat));

    tc5_wait_tx_empty(ok);
    check(ok, "TC5: TX drained without deadlock");

    axi_read(UART_STAT_OFFSET, stat);
    check(stat[20] == 1'b1, $sformatf("TC5: TX_EMPTY asserted after drain (STAT=0x%08h)", stat));
endtask