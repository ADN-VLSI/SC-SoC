interface ctrl_if;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic arst_ni;
  logic clk;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  realtime tp = 10ns;

  bit int_clk;
  bit clk_en;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always begin
    realtime tp_local;
    tp_local = tp;
    #(tp_local / 2);
    int_clk <= '1;
    #(tp_local / 2);
    int_clk <= '0;
  end

  always begin
    @(posedge int_clk);
    clk <= clk_en;
    @(negedge int_clk);
    clk <= '0;
  end

  function void set_clk_en(input bit en = '1);
    clk_en = en;
  endfunction

  task automatic start_clk(input real fr = 100_000_000);
    tp = 1s / fr;
    set_clk_en('1);
    @(posedge clk);
  endtask

  task automatic apply_reset(input realtime duration = 100ns,
                             input realtime pre_delay = duration / 10,
                             input realtime post_delay = pre_delay);
    #(pre_delay);
    arst_ni <= '0;
    #(duration);
    arst_ni <= '1;
    #(post_delay);
  endtask

endinterface
