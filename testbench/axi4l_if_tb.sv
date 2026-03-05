module axi4l_if_tb;

  logic clk_i;
  logic arst_ni;

  axi4l_if #() intf (
      .clk_i  (clk_i),
      .arst_ni(arst_ni)
  );

  initial begin

    automatic logic [34:0] aw_tx = '0;
    automatic logic [34:0] aw_rx = '0;

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_if_tb.vcd");
    $dumpvars(0, axi4l_if_tb);

    clk_i   <= '0;
    arst_ni <= '0;
    intf.req_reset();
    intf.rsp_reset();
    #20;
    arst_ni <= '1;
    #20;
    fork
      forever #5 clk_i <= ~clk_i;
    join_none

    @(posedge clk_i);

    fork
      begin
        #4ns;
        intf.send_aw(aw_tx);
        intf.send_aw(aw_tx);
      end
      begin
        @(posedge clk_i);
        intf.recv_aw(aw_rx);
        intf.recv_aw(aw_rx);
      end
    join

    repeat (20) @(posedge clk_i);

    $finish;

  end

endmodule
