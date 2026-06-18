`include "package/clint_pkg.sv"

module axi4l_clint_regif
  import clint_pkg::*;
#(
    parameter type        axil_req_t  = clint_axil_req_t,
    parameter type        axil_resp_t = clint_axil_resp_t,
    parameter int         ADDR_WIDTH  = CLINT_ADDR_WIDTH,
    parameter int         DATA_WIDTH  = CLINT_DATA_WIDTH,
    parameter logic [63:0] MTIME_INC  = CLINT_MTIME_INC_DEFAULT
) (
    input logic clk_i,
    input logic arst_ni,

    input logic timer_en_i,

    input  axil_req_t  req_i,
    output axil_resp_t resp_o,

    output logic        msip_irq_o,
    output logic        timer_irq_o,
    output logic [63:0] mtime_o,
    output logic [63:0] mtimecmp_o
);

  axil_req_t  fifo_req;
  axil_resp_t fifo_resp;

  axi4l_fifo #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH),
      .FIFO_SIZE   (2)
  ) u_axi4l_fifo (
      .clk_i     (clk_i),
      .arst_ni   (arst_ni),
      .slv_req_i (req_i),
      .slv_resp_o(resp_o),
      .mst_req_o (fifo_req),
      .mst_resp_i(fifo_resp)
  );

  logic [  ADDR_WIDTH-1:0] mem_waddr;
  logic [  DATA_WIDTH-1:0] mem_wdata;
  logic [DATA_WIDTH/8-1:0] mem_wstrb;
  logic                    mem_wenable;
  logic                    mem_werror;
  logic [  ADDR_WIDTH-1:0] mem_raddr;
  logic [  DATA_WIDTH-1:0] mem_rdata;
  logic                    mem_rerror;
  logic                    mem_read_active;
  logic                    mem_write_ok;
  (* unused = "true" *) logic mem_wnsecure_unused;
  (* unused = "true" *) logic mem_rnsecure_unused;
  axil_resp_t mem_resp;

  axi4l_to_memif #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH)
  ) u_axi4l_to_memif (
      .axi4l_req_i (fifo_req),
      .axi4l_resp_o(mem_resp),
      .waddr_o     (mem_waddr),
      .wnsecure_o  (mem_wnsecure_unused),
      .wdata_o     (mem_wdata),
      .wstrb_o     (mem_wstrb),
      .wenable_o   (mem_wenable),
      .werror_i    (mem_werror),
      .raddr_o     (mem_raddr),
      .rnsecure_o  (mem_rnsecure_unused),
      .rdata_i     (mem_rdata),
      .rerror_i    (mem_rerror)
  );

  always_comb begin
    fifo_resp        = mem_resp;
    fifo_resp.b.resp = (mem_resp.b.resp == 2'b11) ? 2'b10 : mem_resp.b.resp;
    fifo_resp.r.resp = (mem_resp.r.resp == 2'b11) ? 2'b10 : mem_resp.r.resp;
  end

  always_comb mem_read_active = mem_resp.r_valid && mem_resp.ar_ready;
  always_comb mem_write_ok    = mem_wenable && !mem_werror;

  logic [31:0] msip_q;
  logic [63:0] mtimecmp_q;
  logic [63:0] mtime_q;
  logic [63:0] mtime_d;

  assign msip_irq_o   = msip_q[0];
  assign timer_irq_o  = (mtime_q >= mtimecmp_q);
  assign mtime_o      = mtime_q;
  assign mtimecmp_o   = mtimecmp_q;

  always_comb begin
    mtime_d = timer_en_i ? (mtime_q + MTIME_INC) : mtime_q;

    if (mem_write_ok) begin
      case (mem_waddr)
        CLINT_MTIME_LO_OFFSET: mtime_d = {mtime_q[63:32], mem_wdata};
        CLINT_MTIME_HI_OFFSET: mtime_d = {mem_wdata, mtime_q[31:0]};
        default: begin
        end
      endcase
    end
  end

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      msip_q     <= CLINT_MSIP_RESET;
      mtimecmp_q <= CLINT_MTIMECMP_RESET;
      mtime_q    <= CLINT_MTIME_RESET;
    end else begin
      mtime_q <= mtime_d;

      if (mem_write_ok) begin
        case (mem_waddr)
          CLINT_MSIP_OFFSET: begin
            msip_q <= {31'b0, mem_wdata[0]};
          end

          CLINT_MTIMECMP_LO_OFFSET: begin
            mtimecmp_q[31:0] <= mem_wdata;
          end

          CLINT_MTIMECMP_HI_OFFSET: begin
            mtimecmp_q[63:32] <= mem_wdata;
          end

          default: begin
          end
        endcase
      end
    end
  end

  always_comb begin
    mem_werror = 1'b1;

    if (mem_wstrb == {DATA_WIDTH / 8{1'b1}}) begin
      case (mem_waddr)
        CLINT_MSIP_OFFSET,
        CLINT_MTIMECMP_LO_OFFSET,
        CLINT_MTIMECMP_HI_OFFSET,
        CLINT_MTIME_LO_OFFSET,
        CLINT_MTIME_HI_OFFSET: begin
          mem_werror = 1'b0;
        end

        default: begin
        end
      endcase
    end
  end

  always_comb begin
    mem_rdata  = '0;
    mem_rerror = 1'b1;

    if (mem_read_active) begin
      case (mem_raddr)
        CLINT_MSIP_OFFSET: begin
          mem_rdata  = msip_q;
          mem_rerror = 1'b0;
        end

        CLINT_MTIMECMP_LO_OFFSET: begin
          mem_rdata  = mtimecmp_q[31:0];
          mem_rerror = 1'b0;
        end

        CLINT_MTIMECMP_HI_OFFSET: begin
          mem_rdata  = mtimecmp_q[63:32];
          mem_rerror = 1'b0;
        end

        CLINT_MTIME_LO_OFFSET: begin
          mem_rdata  = mtime_q[31:0];
          mem_rerror = 1'b0;
        end

        CLINT_MTIME_HI_OFFSET: begin
          mem_rdata  = mtime_q[63:32];
          mem_rerror = 1'b0;
        end

        default: begin
        end
      endcase
    end
  end

endmodule
