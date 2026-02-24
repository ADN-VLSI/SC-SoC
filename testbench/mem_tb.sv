module mem_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = 8;
  localparam int DATA_WIDTH = 32;

  localparam realtime CLK_PERIOD = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                             clk_i;
  logic     [  ADDR_WIDTH-1:0]      addr_i;
  logic                             we_i;
  logic     [  DATA_WIDTH-1:0]      wdata_i;
  logic     [DATA_WIDTH/8-1:0]      wstrb_i;
  logic     [  DATA_WIDTH-1:0]      rdata_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TB VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit                               clock_enable;
  bit                               is_clock_aligned;

  semaphore                         bus_access = new(1);

  int                               case_pass = 0;
  int                               case_fail = 0;

  logic     [DATA_WIDTH/8-1:0][7:0] mem_model           [2**(ADDR_WIDTH-$clog2(DATA_WIDTH/8))-1:0];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INSTANTIATIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  mem #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk_i(clk_i),
      .addr_i(addr_i),
      .we_i(we_i),
      .wdata_i(wdata_i),
      .wstrb_i(wstrb_i),
      .rdata_o(rdata_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic apply_reset(input realtime duration);
    #(duration);
    clk_i   <= '0;
    addr_i  <= '0;
    we_i    <= '0;
    wdata_i <= '0;
    wstrb_i <= '0;
    #(duration);
  endtask

  task automatic enable_clock();
    clock_enable <= 1;
    @(posedge clk_i);
  endtask

  task automatic disable_clock();
    @(posedge clk_i);
    clock_enable <= 0;
  endtask

  task automatic mem_write(input logic [ADDR_WIDTH-1:0] addr,
                           input logic [DATA_WIDTH/8-1:0][7:0] data,
                           input logic [DATA_WIDTH/8-1:0] strb);
    bus_access.get(1);
    if (!is_clock_aligned) begin
      @(posedge clk_i);
    end
    addr_i  <= addr;
    we_i    <= '1;
    wdata_i <= data;
    wstrb_i <= strb;
    @(posedge clk_i);
    for (int i = 0; i < DATA_WIDTH / 8; i++) begin
      if (strb[i]) begin
        mem_model[addr[ADDR_WIDTH-1:$clog2(DATA_WIDTH/8)]][i] = data[i];
      end
    end
    we_i <= '0;
    bus_access.put(1);
  endtask

  task automatic mem_read(input logic [ADDR_WIDTH-1:0] addr,
                          output logic [DATA_WIDTH-1:0][7:0] data);
    bus_access.get(1);
    if (!is_clock_aligned) begin
      @(posedge clk_i);
    end
    addr_i <= addr;
    we_i   <= '0;
    @(posedge clk_i);
    data = rdata_o;
    for (int i = 0; i < DATA_WIDTH / 8; i++) begin
      if (mem_model[addr[ADDR_WIDTH-1:$clog2(DATA_WIDTH/8)]][i] === data[i]) begin
        case_pass++;
      end else begin
        case_fail++;
        $display("ERROR: Read data 0x%02X does NOT match model at byte %0d: 0x%02X", data[i], i,
                 mem_model[addr[ADDR_WIDTH-1:$clog2(DATA_WIDTH/8)]][i]);
      end
    end
    bus_access.put(1);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always @(posedge clk_i) begin
    #1;
    is_clock_aligned = 0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    $timeformat(-9, 0, "ns", 6);
    // $dumpfile("mem_tb.vcd");
    // $dumpvars(0, mem_tb);

    fork
      forever begin
        is_clock_aligned = clock_enable;
        clk_i <= clock_enable;
        #(CLK_PERIOD / 2);
        clk_i <= 0;
        #(CLK_PERIOD / 2);
      end
    join_none

    apply_reset(100ns);
    enable_clock();

    // fork
    //   begin
    //     mem_write(8'h00, 32'hF00DCAFE, 4'b1111);
    //     $display("111 mem_model[0][0]: 0x%02X", mem_model[0][0]);
    //     mem_model[0][0] = 8'h00;
    //     $display("222 mem_model[0][0]: 0x%02X", mem_model[0][0]);
    //   end
    //   mem_write(8'h04, 32'hDEADBEEF, 4'b1111);
    //   begin
    //     logic [DATA_WIDTH-1:0] read_data;
    //     mem_read(8'h02, read_data);
    //     $display("Read data: 0x%08X", read_data);
    //   end
    // join

    // foreach (mem_model[i]) mem_model[i] = $urandom;

    repeat (10000) begin
      int nobody_cares;
      randcase
        1: mem_write($urandom, $urandom, $urandom);
        1: mem_read($urandom, nobody_cares);
      endcase
    end

    repeat (10) @(posedge clk_i);

    if (case_fail) $write("\033[1;31m");
    else $write("\033[1;32m");
    $display("Test completed with %0d cases passed and %0d cases failed.\033[0m", case_pass,
             case_fail);

    $finish;

  end


endmodule
