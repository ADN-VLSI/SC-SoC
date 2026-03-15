module rv32imf_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic        clk;
  logic        arst_n;

  logic [31:0] boot_addr;
  logic [31:0] dm_halt_addr;
  logic [31:0] hart_id;
  logic [31:0] dm_exception_addr;

  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;

  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [ 3:0] data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;

  logic [31:0] irq;
  logic        irq_ack;
  logic [ 4:0] irq_id;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  int          sym               [string];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  rv32imf u_core (
      .clk_i              (clk),
      .rst_ni             (arst_n),
      .boot_addr_i        (boot_addr),
      .dm_halt_addr_i     (dm_halt_addr),
      .hart_id_i          (hart_id),
      .dm_exception_addr_i(dm_exception_addr),
      .instr_req_o        (instr_req),
      .instr_gnt_i        (instr_gnt),
      .instr_rvalid_i     (instr_rvalid),
      .instr_addr_o       (instr_addr),
      .instr_rdata_i      (instr_rdata),
      .data_req_o         (data_req),
      .data_gnt_i         (data_gnt),
      .data_rvalid_i      (data_rvalid),
      .data_we_o          (data_we),
      .data_be_o          (data_be),
      .data_addr_o        (data_addr),
      .data_wdata_o       (data_wdata),
      .data_rdata_i       (data_rdata),
      .irq_i              (irq),
      .irq_ack_o          (irq_ack),
      .irq_id_o           (irq_id)
  );

  tcdm_sim_memory u_mem (
      .clk_i         (clk),
      .rst_ni        (arst_n),
      .instr_req_i   (instr_req),
      .instr_addr_i  (instr_addr),
      .instr_gnt_o   (instr_gnt),
      .instr_rdata_o (instr_rdata),
      .instr_rvalid_o(instr_rvalid),
      .data_req_i    (data_req),
      .data_addr_i   (data_addr),
      .data_we_i     (data_we),
      .data_wdata_i  (data_wdata),
      .data_be_i     (data_be),
      .data_gnt_o    (data_gnt),
      .data_rvalid_o (data_rvalid),
      .data_rdata_o  (data_rdata)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic apply_reset(input realtime duration = 100ns);
    #(duration);
    arst_n            <= '0;
    clk               <= '0;
    boot_addr         <= '0;
    dm_halt_addr      <= '0;
    hart_id           <= '0;
    dm_exception_addr <= '0;
    irq               <= '0;
    #(duration);
    arst_n <= '1;
    #(duration);
  endtask

  task automatic start_clock(input realtime period = 10ns);
    fork
      forever #(period / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  function automatic void load_sym_file(string filename);
    int file, r;
    string line;
    string key;
    int value;
    file = $fopen(filename, "r");
    if (file == 0) begin
      $display("Error: Could not open file %s", filename);
      $finish;
    end
    while (!$feof(
        file
    )) begin
      r = $fgets(line, file);
      if (r != 0) begin
        r = $sscanf(line, "%h %*s %s", value, key);
        sym[key] = value;
      end
    end
    $fclose(file);
  endfunction

  function void load_hex_file(string filename);
    u_mem.load_hex(filename);
  endfunction

  task static wait_exit();
    int exit_code;
    exit_code = '1;
    fork
      begin
        do begin
          @(posedge clk);
        end while (!(data_addr === sym["tohost"] && data_we === '1 && data_be === 'hf &&
                     data_req === '1 && data_gnt === '1));
        exit_code = data_wdata;
      end
      begin
        #1ms;
      end
    join_any
    $display("\033[0;35mEXIT CODE      : 0x%08x\033[0m", exit_code);
    if (exit_code == 0) $display("\033[1;32m************** TEST PASSED **************\033[0m");
    else $display("\033[1;31m************** TEST FAILED **************\033[0m");
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    $timeformat(-9, 0, "ns", 6);

    $dumpfile("rv32imf_tb.vcd");
    $dumpvars(0, rv32imf_tb);

    load_sym_file("prog.sym");
    load_hex_file("prog.hex");

    apply_reset();

    boot_addr         <= sym["__start"];
    dm_halt_addr      <= sym["__dm_halt"];
    hart_id           <= sym["__hart_id"];
    dm_exception_addr <= sym["__dm_exception"];

    start_clock();

    wait_exit();

    $finish;

  end

endmodule
