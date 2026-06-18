module plic #(
    localparam int ADDR_WIDTH      = 22,
    localparam int DATA_WIDTH      = 32,
    localparam int NUM_CORES       = 2,
    localparam int MAX_PRIORITY    = 7,
    localparam int NUM_INTERRUPTS  = 33,
    localparam int PLIC_ADDR_WIDTH = $clog2(NUM_INTERRUPTS)
) (
    // Global Signals
    input logic arst_ni,
    input logic clk_i,

    // Write interface
    input  logic [  ADDR_WIDTH-1:0] waddr_i,     // Write Address
    input  logic                    wnsecure_i,  // Write Non-secure region
    input  logic [  DATA_WIDTH-1:0] wdata_i,     // Write Data
    input  logic [DATA_WIDTH/8-1:0] wstrb_i,     // Write Strobe
    input  logic                    wenable_i,   // Write Enable
    output logic                    werror_o,    // Write Error

    // Read interface
    input  logic [ADDR_WIDTH-1:0] raddr_i,     // Read Address
    input  logic                  rnsecure_i,  // Read Non-secure region
    output logic [DATA_WIDTH-1:0] rdata_o,     // Read Data
    output logic                  rerror_o,    // Read Error

    // Interrupt interface
    input logic [NUM_INTERRUPTS-1:0] irq_i,  // Interrupt Sources

    // Core interface
    output logic [NUM_CORES-1:0][PLIC_ADDR_WIDTH-1:0] eiid_o,  //  External Interrupt ID
    output logic [NUM_CORES-1:0]                      ei_o     //  External Interrupt Valid
);

  logic [NUM_INTERRUPTS-1:0] irq_claim;  // TODO REG
  logic [NUM_INTERRUPTS-1:0] irq_q;

  for (genvar i = 0; i < NUM_INTERRUPTS; i++) begin
    always_ff @(posedge irq_i[i] or posedge irq_claim[i] or negedge arst_ni) begin
      if (irq_claim[i] | !arst_ni) begin
        irq_q[i] <= 1'b0;
      end else begin
        irq_q[i] <= irq_i[i];
      end
    end
  end

  // Calculate the number of bits needed to represent MAX_PRIORITY
  localparam int PRIO_BITS = $clog2(MAX_PRIORITY + 1);

  logic [ PRIO_BITS-1:0] intr_src_01_prio;
  logic [ PRIO_BITS-1:0] intr_src_02_prio;
  logic [ PRIO_BITS-1:0] intr_src_03_prio;
  logic [ PRIO_BITS-1:0] intr_src_04_prio;
  logic [ PRIO_BITS-1:0] intr_src_05_prio;
  logic [ PRIO_BITS-1:0] intr_src_06_prio;
  logic [ PRIO_BITS-1:0] intr_src_07_prio;
  logic [ PRIO_BITS-1:0] intr_src_08_prio;
  logic [ PRIO_BITS-1:0] intr_src_09_prio;
  logic [ PRIO_BITS-1:0] intr_src_10_prio;
  logic [ PRIO_BITS-1:0] intr_src_11_prio;
  logic [ PRIO_BITS-1:0] intr_src_12_prio;
  logic [ PRIO_BITS-1:0] intr_src_13_prio;
  logic [ PRIO_BITS-1:0] intr_src_14_prio;
  logic [ PRIO_BITS-1:0] intr_src_15_prio;
  logic [ PRIO_BITS-1:0] intr_src_16_prio;
  logic [ PRIO_BITS-1:0] intr_src_17_prio;
  logic [ PRIO_BITS-1:0] intr_src_18_prio;
  logic [ PRIO_BITS-1:0] intr_src_19_prio;
  logic [ PRIO_BITS-1:0] intr_src_20_prio;
  logic [ PRIO_BITS-1:0] intr_src_21_prio;
  logic [ PRIO_BITS-1:0] intr_src_22_prio;
  logic [ PRIO_BITS-1:0] intr_src_23_prio;
  logic [ PRIO_BITS-1:0] intr_src_24_prio;
  logic [ PRIO_BITS-1:0] intr_src_25_prio;
  logic [ PRIO_BITS-1:0] intr_src_26_prio;
  logic [ PRIO_BITS-1:0] intr_src_27_prio;
  logic [ PRIO_BITS-1:0] intr_src_28_prio;
  logic [ PRIO_BITS-1:0] intr_src_29_prio;
  logic [ PRIO_BITS-1:0] intr_src_30_prio;
  logic [ PRIO_BITS-1:0] intr_src_31_prio;
  logic [ PRIO_BITS-1:0] intr_src_32_prio;

  logic [DATA_WIDTH-1:0] enable_src3100_core_0;
  logic [DATA_WIDTH-1:0] enable_src6332_core_0;
  logic [DATA_WIDTH-1:0] enable_src3100_core_1;
  logic [DATA_WIDTH-1:0] enable_src6332_core_1;

  logic [ PRIO_BITS-1:0] core_0_threshold;
  logic [ PRIO_BITS-1:0] claim_id_core_0;
  logic [ PRIO_BITS-1:0] core_1_threshold;
  logic [ PRIO_BITS-1:0] claim_id_core_1;

  always_comb begin
    rerror_o = '1;
    rdata_o  = '0;
    case ({
      rnsecure_i, raddr_i
    })

      'h000004: begin
        rerror_o = '0;
        rdata_o  = intr_src_01_prio;
      end

      'h000008: begin
        rerror_o = '0;
        rdata_o  = intr_src_02_prio;
      end

      'h00000C: begin
        rerror_o = '0;
        rdata_o  = intr_src_03_prio;
      end

      'h000010: begin
        rerror_o = '0;
        rdata_o  = intr_src_04_prio;
      end

      'h000014: begin
        rerror_o = '0;
        rdata_o  = intr_src_05_prio;
      end

      'h000018: begin
        rerror_o = '0;
        rdata_o  = intr_src_06_prio;
      end

      'h00001C: begin
        rerror_o = '0;
        rdata_o  = intr_src_07_prio;
      end

      'h000020: begin
        rerror_o = '0;
        rdata_o  = intr_src_08_prio;
      end

      'h000024: begin
        rerror_o = '0;
        rdata_o  = intr_src_09_prio;
      end

      'h000028: begin
        rerror_o = '0;
        rdata_o  = intr_src_10_prio;
      end

      'h00002C: begin
        rerror_o = '0;
        rdata_o  = intr_src_11_prio;
      end

      'h000030: begin
        rerror_o = '0;
        rdata_o  = intr_src_12_prio;
      end

      'h000034: begin
        rerror_o = '0;
        rdata_o  = intr_src_13_prio;
      end

      'h000038: begin
        rerror_o = '0;
        rdata_o  = intr_src_14_prio;
      end

      'h00003C: begin
        rerror_o = '0;
        rdata_o  = intr_src_15_prio;
      end

      'h000040: begin
        rerror_o = '0;
        rdata_o  = intr_src_16_prio;
      end

      'h000044: begin
        rerror_o = '0;
        rdata_o  = intr_src_17_prio;
      end

      'h000048: begin
        rerror_o = '0;
        rdata_o  = intr_src_18_prio;
      end

      'h00004C: begin
        rerror_o = '0;
        rdata_o  = intr_src_19_prio;
      end

      'h000050: begin
        rerror_o = '0;
        rdata_o  = intr_src_20_prio;
      end

      'h000054: begin
        rerror_o = '0;
        rdata_o  = intr_src_21_prio;
      end

      'h000058: begin
        rerror_o = '0;
        rdata_o  = intr_src_22_prio;
      end

      'h00005C: begin
        rerror_o = '0;
        rdata_o  = intr_src_23_prio;
      end

      'h000060: begin
        rerror_o = '0;
        rdata_o  = intr_src_24_prio;
      end

      'h000064: begin
        rerror_o = '0;
        rdata_o  = intr_src_25_prio;
      end

      'h000068: begin
        rerror_o = '0;
        rdata_o  = intr_src_26_prio;
      end

      'h00006C: begin
        rerror_o = '0;
        rdata_o  = intr_src_27_prio;
      end

      'h000070: begin
        rerror_o = '0;
        rdata_o  = intr_src_28_prio;
      end

      'h000074: begin
        rerror_o = '0;
        rdata_o  = intr_src_29_prio;
      end

      'h000078: begin
        rerror_o = '0;
        rdata_o  = intr_src_30_prio;
      end

      'h00007C: begin
        rerror_o = '0;
        rdata_o  = intr_src_31_prio;
      end

      'h000080: begin
        rerror_o = '0;
        rdata_o  = intr_src_32_prio;
      end

      'h002000: begin
        rerror_o = '0;
        rdata_o  = enable_src3100_core_0;
      end

      'h002004: begin
        rerror_o = '0;
        rdata_o  = enable_src6332_core_0;
      end

      'h002080: begin
        rerror_o = '0;
        rdata_o  = enable_src3100_core_1;
      end

      'h002084: begin
        rerror_o = '0;
        rdata_o  = enable_src6332_core_1;
      end

      'h200000: begin
        rerror_o = '0;
        rdata_o  = core_0_threshold;
      end

      'h200004: begin
        rerror_o = '0;
        rdata_o  = claim_id_core_0;
      end

      'h201000: begin
        rerror_o = '0;
        rdata_o  = core_1_threshold;
      end

      'h201004: begin
        rerror_o = '0;
        rdata_o  = claim_id_core_1;
      end

      default: begin
        rerror_o = '1;
        rdata_o  = '0;
      end
    endcase
  end


  always_comb begin
    werror_o = '1;
    case ({
      wnsecure_i, waddr_i
    })
      'h000004, 'h000008, 'h00000C, 'h000010, 'h000014, 'h000018, 'h00001C, 'h000020, 'h000024,
      'h000028, 'h00002C, 'h000030, 'h000034, 'h000038, 'h00003C, 'h000040, 'h000044, 'h000048,
      'h00004C, 'h000050, 'h000054, 'h000058, 'h00005C, 'h000060, 'h000064, 'h000068, 'h00006C,
      'h000070, 'h000074, 'h000078, 'h00007C, 'h000080, 'h002000, 'h002004, 'h002080, 'h002084,
      'h200000, 'h200004, 'h201000, 'h201004:
      werror_o = (wstrb_i == '1);
      default: werror_o = '1;
    endcase
  end

  always_ff @(posedge clk_i or negedge arst_ni) begin
    irq_claim <= '0;
    if (~arst_ni) begin
      intr_src_01_prio      <= '0;
      intr_src_02_prio      <= '0;
      intr_src_03_prio      <= '0;
      intr_src_04_prio      <= '0;
      intr_src_05_prio      <= '0;
      intr_src_06_prio      <= '0;
      intr_src_07_prio      <= '0;
      intr_src_08_prio      <= '0;
      intr_src_09_prio      <= '0;
      intr_src_10_prio      <= '0;
      intr_src_11_prio      <= '0;
      intr_src_12_prio      <= '0;
      intr_src_13_prio      <= '0;
      intr_src_14_prio      <= '0;
      intr_src_15_prio      <= '0;
      intr_src_16_prio      <= '0;
      intr_src_17_prio      <= '0;
      intr_src_18_prio      <= '0;
      intr_src_19_prio      <= '0;
      intr_src_20_prio      <= '0;
      intr_src_21_prio      <= '0;
      intr_src_22_prio      <= '0;
      intr_src_23_prio      <= '0;
      intr_src_24_prio      <= '0;
      intr_src_25_prio      <= '0;
      intr_src_26_prio      <= '0;
      intr_src_27_prio      <= '0;
      intr_src_28_prio      <= '0;
      intr_src_29_prio      <= '0;
      intr_src_30_prio      <= '0;
      intr_src_31_prio      <= '0;
      intr_src_32_prio      <= '0;
      enable_src3100_core_0 <= '0;
      enable_src6332_core_0 <= '0;
      enable_src3100_core_1 <= '0;
      enable_src6332_core_1 <= '0;
      core_0_threshold      <= '0;
      claim_id_core_0       <= '0;
      core_1_threshold      <= '0;
      claim_id_core_1       <= '0;
    end else if (wenable_i & ~werror_o) begin
      case (waddr_i)
        'h000004: intr_src_01_prio <= wdata_i;
        'h000008: intr_src_02_prio <= wdata_i;
        'h00000C: intr_src_03_prio <= wdata_i;
        'h000010: intr_src_04_prio <= wdata_i;
        'h000014: intr_src_05_prio <= wdata_i;
        'h000018: intr_src_06_prio <= wdata_i;
        'h00001C: intr_src_07_prio <= wdata_i;
        'h000020: intr_src_08_prio <= wdata_i;
        'h000024: intr_src_09_prio <= wdata_i;
        'h000028: intr_src_10_prio <= wdata_i;
        'h00002C: intr_src_11_prio <= wdata_i;
        'h000030: intr_src_12_prio <= wdata_i;
        'h000034: intr_src_13_prio <= wdata_i;
        'h000038: intr_src_14_prio <= wdata_i;
        'h00003C: intr_src_15_prio <= wdata_i;
        'h000040: intr_src_16_prio <= wdata_i;
        'h000044: intr_src_17_prio <= wdata_i;
        'h000048: intr_src_18_prio <= wdata_i;
        'h00004C: intr_src_19_prio <= wdata_i;
        'h000050: intr_src_20_prio <= wdata_i;
        'h000054: intr_src_21_prio <= wdata_i;
        'h000058: intr_src_22_prio <= wdata_i;
        'h00005C: intr_src_23_prio <= wdata_i;
        'h000060: intr_src_24_prio <= wdata_i;
        'h000064: intr_src_25_prio <= wdata_i;
        'h000068: intr_src_26_prio <= wdata_i;
        'h00006C: intr_src_27_prio <= wdata_i;
        'h000070: intr_src_28_prio <= wdata_i;
        'h000074: intr_src_29_prio <= wdata_i;
        'h000078: intr_src_30_prio <= wdata_i;
        'h00007C: intr_src_31_prio <= wdata_i;
        'h000080: intr_src_32_prio <= wdata_i;
        'h002000: enable_src3100_core_0 <= wdata_i;
        'h002004: enable_src6332_core_0 <= wdata_i;
        'h002080: enable_src3100_core_1 <= wdata_i;
        'h002084: enable_src6332_core_1 <= wdata_i;
        'h200000: core_0_threshold <= wdata_i;
        'h200004: begin
          claim_id_core_0 <= wdata_i;
          irq_claim[wdata_i] <= '1;
        end
        'h201000: core_1_threshold <= wdata_i;
        'h201004: begin
          claim_id_core_1 <= wdata_i;
          irq_claim[wdata_i+DATA_WIDTH] <= '1;
        end
      endcase
    end
  end
endmodule
