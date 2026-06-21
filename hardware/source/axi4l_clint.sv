// =============================================================================
//   DATA FLOW SUMMARY:
//   CPU (AXI4-Lite) -> axi4l_clint_regif (register file: msip/mtime/mtimecmp)
//     -> msip_irq_o / timer_irq_o (from regif) + ext_irq_i (external input)
//     -> bit-packed into irq_o (this module's only added logic)
//
//   This module is a thin wrapper: it instantiates axi4l_clint_regif (which does
//   all the real work -- AXI handling, register storage, mtime counting) and adds
//   one small piece of glue logic: packing the three interrupt sources (software,
//   timer, external) into a single 32-bit interrupt vector (irq_o) using the
//   standard RISC-V CLINT/PLIC-style bit positions (msip=3, mtimer=7, mext=11).
// =============================================================================
// MODULE: axi4l_clint
// PURPOSE: Top-level AXI4-Lite CLINT (Core Local Interruptor) wrapper.
//          Wraps axi4l_clint_regif and additionally packs:
//            - msip_irq_o  (software interrupt, from regif)
//            - timer_irq_o (timer interrupt, from regif)
//            - ext_irq_i   (external interrupt, passed in from outside the CLINT)
//          into a single 32-bit interrupt-vector output (irq_o), in addition to
//          exposing the individual interrupt lines and timer registers directly.
// =============================================================================

`include "package/clint_pkg.sv"
module axi4l_clint
  import clint_pkg::*;                  // import all names from clint_pkg
#(
    // ---- Compile-time parameters ----
    parameter type         axil_req_t  = clint_axil_req_t,   // struct type for AXI4-Lite request
    parameter type         axil_resp_t = clint_axil_resp_t,  // struct type for AXI4-Lite response
    parameter logic [63:0] MTIME_INC   = CLINT_MTIME_INC_DEFAULT // amount mtime increments per clock
) (
    // ---- Clock / Reset ----
    input logic clk_i,                  // system clock
    input logic arst_ni,                // ASYNC, ACTIVE-LOW reset ('n' = active-low, 'i' = input)

    // ---- Control ----
    input logic timer_en_i,             // 1 = mtime auto-increments each cycle; 0 = frozen

    // ---- AXI4-Lite bus ----
    input  axil_req_t  axi4l_req_i,     // incoming AXI request bundle (addr/data/valid/etc.)
    output axil_resp_t axi4l_resp_o,    // outgoing AXI response bundle

    // ---- External interrupt passthrough ----
    input logic ext_irq_i,              // external interrupt source (e.g. PLIC) -> packed into irq_o[11]

    // ---- Outputs to the rest of the SoC ----
    output logic [31:0] irq_o,          // packed interrupt vector: bit3=msip, bit7=timer, bit11=ext
    output logic        msip_irq_o,     // software interrupt line -> CPU interrupt controller (direct)
    output logic        timer_irq_o,    // timer interrupt line -> CPU interrupt controller (direct)
    output logic [63:0] mtime_o,        // current time counter value (observability)
    output logic [63:0] mtimecmp_o      // current alarm/compare value (observability)
);

  // ===========================================================================
  // STEP 1: Register interface instance
  // WHY: all AXI4-Lite handling, address decode, and msip/mtime/mtimecmp storage
  //      lives in axi4l_clint_regif. This module doesn't duplicate any of that --
  //      it just forwards the bus and control signals through and takes the
  //      resulting interrupt lines/timer values back out.
  // ===========================================================================
  axi4l_clint_regif #(
      .axil_req_t (axil_req_t),
      .axil_resp_t(axil_resp_t),
      .ADDR_WIDTH (CLINT_ADDR_WIDTH),    // fixed to the package default (not exposed as a param here)
      .DATA_WIDTH (CLINT_DATA_WIDTH),    // fixed to the package default (not exposed as a param here)
      .MTIME_INC  (MTIME_INC)
  ) u_regif (
      .clk_i      (clk_i),
      .arst_ni    (arst_ni),
      .timer_en_i (timer_en_i),
      .req_i      (axi4l_req_i),        // forward CPU's AXI request straight in
      .resp_o     (axi4l_resp_o),       // forward regif's AXI response straight back out
      .msip_irq_o (msip_irq_o),         // software interrupt -> exposed directly AND packed into irq_o
      .timer_irq_o(timer_irq_o),        // timer interrupt    -> exposed directly AND packed into irq_o
      .mtime_o    (mtime_o),            // current time        -> passthrough for observability
      .mtimecmp_o (mtimecmp_o)          // current compare val  -> passthrough for observability
  );

  // ===========================================================================
  // STEP 2: Interrupt-vector packing (combinational)
  // WHY: some interrupt controllers/cores expect a single wide vector rather
  //      than individual lines. Bit positions follow the conventional
  //      RISC-V CLINT/PLIC interrupt-cause numbering:
  //        bit 3  = machine software interrupt (MSIP)
  //        bit 7  = machine timer interrupt (MTIP)
  //        bit 11 = machine external interrupt (MEIP)
  //      All other bits are tied low.
  // ===========================================================================
  always_comb begin
    irq_o     = '0;          // default: all interrupt bits cleared
    irq_o[3]  = msip_irq_o;  // software interrupt, from regif
    irq_o[7]  = timer_irq_o; // timer interrupt, from regif
    irq_o[11] = ext_irq_i;   // external interrupt, passed straight through from input
  end

endmodule