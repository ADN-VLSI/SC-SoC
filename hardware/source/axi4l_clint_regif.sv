// =============================================================================
//   DATA FLOW SUMMARY:
//   CPU (AXI4-Lite) -> axi4l_fifo (buffer) -> axi4l_to_memif (protocol simplifier)
//     -> address decode (this module) -> read/write msip_q (Machine Software Interrupt Pending (_q = registered/current value) )/ mtimecmp_q (Machine Time Compare (_q = registered/current value) )  / mtime_q (Machine Time (_q = registered/current value) )
//     -> outputs: msip_irq_o (Machine Software Interrupt Request output), timer_irq_o (Timer Interrupt Request output), mtime_o (Machine Time output), mtimecmp_o (Machine Time Compare output)
//
//   mtime_q free-runs (+MTIME_INC every cycle) unless overwritten by software,
//   and timer_irq_o fires automatically the instant mtime_q >= mtimecmp_q.
// =============================================================================
// MODULE: axi4l_clint_regif
// PURPOSE: AXI4-Lite-facing register interface for a RISC-V CLINT
//          (Core Local Interruptor). Handles:
//            - msip   : software interrupt pending bit
//            - mtime  : free-running 64-bit timer
//            - mtimecmp: 64-bit compare/alarm value -> drives timer_irq_o
// =============================================================================

`include "package/clint_pkg.sv"
module axi4l_clint_regif
  import clint_pkg::*;                  // import all names from clint_pkg 
#(
    // ---- Compile-time parameters 
    parameter type        axil_req_t  = clint_axil_req_t,   // struct type for AXI4-Lite request
    parameter type        axil_resp_t = clint_axil_resp_t,  // struct type for AXI4-Lite response
    parameter int         ADDR_WIDTH  = CLINT_ADDR_WIDTH,    // address bus width in bits
    parameter int         DATA_WIDTH  = CLINT_DATA_WIDTH,    // data bus width in bits 
    parameter logic [63:0] MTIME_INC  = CLINT_MTIME_INC_DEFAULT // amount mtime increments per clock
) (
    // ---- Clock / Reset ----
    input logic clk_i,                  // system clock
    input logic arst_ni,                // ASYNC, ACTIVE-LOW reset ('n' = active-low, 'i' = input)

    // ---- Control ----
    input logic timer_en_i,             // 1 = mtime auto-increments each cycle; 0 = frozen

    // ---- AXI4-Lite bus 
    input  axil_req_t  req_i,           // incoming AXI request bundle (addr/data/valid/etc.)
    output axil_resp_t resp_o,          // outgoing AXI response bundle

    // ---- Outputs to the rest of the SoC ----
    output logic        msip_irq_o,     // software interrupt line -> CPU interrupt controller
    output logic        timer_irq_o,    // timer interrupt line -> CPU interrupt controller
    output logic [63:0] mtime_o,        // current time counter value (observability)
    output logic [63:0] mtimecmp_o      // current alarm/compare value (observability)
);

  // ===========================================================================
  // STEP 1: AXI4-Lite FIFO buffering stage
  // WHY: decouples external bus timing from internal logic; smooths back-to-back
  //      transactions; helps timing closure. FIFO_SIZE=2 means it can hold 2
  //      outstanding entries.
  // ===========================================================================
  axil_req_t  fifo_req;                 // request, AFTER the fifo (goes to the converter)
  axil_resp_t fifo_resp;                // response, BEFORE going back out to req_i's master

  axi4l_fifo #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH),
      .FIFO_SIZE   (2)                  // depth of the buffer = 2 entries
  ) u_axi4l_fifo (
      .clk_i     (clk_i),
      .arst_ni   (arst_ni),
      .slv_req_i (req_i),               // SLAVE side: faces the external CPU/bus master
      .slv_resp_o(resp_o),              // SLAVE side: response sent back to the CPU
      .mst_req_o (fifo_req),            // MASTER side: forwards buffered request onward
      .mst_resp_i(fifo_resp)            // MASTER side: receives response to buffer/forward back
  );

  // ===========================================================================
  // STEP 2: Signals for the simplified "memory-style" interface
  // WHY: AXI is complex (many handshake signals). The axi4l_to_memif converter
  //      below turns it into plain addr/data/enable signals that are much
  //      easier to decode against in the register logic that follows.
  // ===========================================================================
  logic [  ADDR_WIDTH-1:0] mem_waddr;       // write address
  logic [  DATA_WIDTH-1:0] mem_wdata;       // write data
  logic [DATA_WIDTH/8-1:0] mem_wstrb;       // write byte-strobe (1 bit per byte lane)
  logic                    mem_wenable;     // write enable pulse
  logic                    mem_werror;      // we DRIVE this back: 1 = write was invalid
  logic [  ADDR_WIDTH-1:0] mem_raddr;       // read address
  logic [  DATA_WIDTH-1:0] mem_rdata;       // we DRIVE this back: read data to return
  logic                    mem_rerror;      // we DRIVE this back: 1 = read was invalid
  logic                    mem_read_active; // computed below: "a read is happening this cycle"
  logic                    mem_write_ok;    // computed below: "write enabled AND no error"

  // These two outputs from the converter are intentionally NOT used by this design
  // (CLINT here doesn't implement secure/non-secure access checks). The attribute
  // tells the linter/synth tool not to warn about them being dangling.
  (* unused = "true" *) logic mem_wnsecure_unused;
  (* unused = "true" *) logic mem_rnsecure_unused;

  axil_resp_t mem_resp;                 // raw AXI response coming back from converter (pre-cleanup)

  // ---- The actual converter instance ----
  axi4l_to_memif #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH)
  ) u_axi4l_to_memif (
      .axi4l_req_i (fifo_req),          // takes the FIFO-buffered AXI request in
      .axi4l_resp_o(mem_resp),          // produces a raw AXI response (cleaned up below)
      .waddr_o     (mem_waddr),         // --> decoded write address out
      .wnsecure_o  (mem_wnsecure_unused),
      .wdata_o     (mem_wdata),         // --> write data out
      .wstrb_o     (mem_wstrb),         // --> byte strobe out
      .wenable_o   (mem_wenable),       // --> write-enable pulse out
      .werror_i    (mem_werror),        // <-- WE tell it if the write was an error
      .raddr_o     (mem_raddr),         // --> decoded read address out
      .rnsecure_o  (mem_rnsecure_unused),
      .rdata_i     (mem_rdata),         // <-- WE supply the read data
      .rerror_i    (mem_rerror)         // <-- WE tell it if the read was an error
  );

  // ===========================================================================
  // STEP 3: Response cleanup
  // WHY: AXI4 defines 4 response codes: OKAY(00), EXOKAY(01), SLVERR(10), DECERR(11).
  //      This design doesn't want to expose DECERR distinctly -- it downgrades any
  //      DECERR (2'b11) to SLVERR (2'b10) on both write-response (b.resp) and
  //      read-response (r.resp) channels. Everything else (e.g. OKAY) passes through.
  // ===========================================================================
  always_comb begin                              // combinational: re-evaluates instantly
    fifo_resp        = mem_resp;                  // start by copying the whole response struct
    fifo_resp.b.resp = (mem_resp.b.resp == 2'b11) ? 2'b10 : mem_resp.b.resp; // write resp: DECERR->SLVERR
    fifo_resp.r.resp = (mem_resp.r.resp == 2'b11) ? 2'b10 : mem_resp.r.resp; // read resp: DECERR->SLVERR
  end

  // -> converter has accepted the address (ar_ready) AND is presenting valid read data (r_valid) simultaneously.
  always_comb mem_read_active = mem_resp.r_valid && mem_resp.ar_ready;
  
  // -> write is enabled AND there is no error on it.
  always_comb mem_write_ok    = mem_wenable && !mem_werror;

  // ===========================================================================
  // STEP 4: The actual CLINT register state
  // ===========================================================================
  logic [31:0] msip_q;       // software-interrupt-pending register (only bit 0 is meaningful)
  logic [63:0] mtimecmp_q;   // 64-bit alarm/compare threshold register
  logic [63:0] mtime_q;      // 64-bit free-running time counter (current value)
  logic [63:0] mtime_d;      // NEXT value of mtime_q, computed combinationally below
                              // (naming convention: _q = current/registered, _d = next/data-in)

  // ---- Direct wiring of registers to module outputs ----
  assign msip_irq_o   = msip_q[0];                  // only bit 0 of msip drives the IRQ line
  assign timer_irq_o  = (mtime_q >= mtimecmp_q);     // ALARM CONDITION: fires once time catches up
  assign mtime_o      = mtime_q;                     // expose current time externally
  assign mtimecmp_o   = mtimecmp_q;                  // expose current compare value externally

  // ===========================================================================
  // STEP 5: Compute mtime_d (the NEXT value mtime_q will take on the clock edge)
  // LOGIC:
  //   1) Default: auto-increment by MTIME_INC if timer_en_i, else hold steady.
  //   2) Override: if software is writing to MTIME_LO/HI this cycle, that write
  //      wins over the auto-increment (lets software set/sync the clock).
  // ===========================================================================
  always_comb begin
    mtime_d = timer_en_i ? (mtime_q + MTIME_INC) : mtime_q;  // default: increment or hold

    if (mem_write_ok) begin                          // only consider overriding if write is valid
      case (mem_waddr)
        // Software writes the LOW 32 bits -> keep upper 32 bits, replace lower 32 bits
        CLINT_MTIME_LO_OFFSET: mtime_d = {mtime_q[63:32], mem_wdata};
        // Software writes the HIGH 32 bits -> keep lower 32 bits, replace upper 32 bits
        CLINT_MTIME_HI_OFFSET: mtime_d = {mem_wdata, mtime_q[31:0]};
        default: begin
          // any other address: no override, mtime_d keeps the increment/hold value from above
        end
      endcase
    end
  end

  // ===========================================================================
  // STEP 6: Sequential (clocked) register update -- THE ONLY always_ff block
  // Triggered on: rising edge of clk_i, OR falling edge of arst_ni (async reset)
  // ===========================================================================
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      // ---- ASYNC RESET: loads immediately, independent of clk_i ----
      msip_q     <= CLINT_MSIP_RESET;          // reset value for software-interrupt bit
      mtimecmp_q <= CLINT_MTIMECMP_RESET;      // reset value for alarm threshold
      mtime_q    <= CLINT_MTIME_RESET;         // reset value for the time counter
    end else begin
      // ---- NORMAL OPERATION (every rising clock edge) ----
      mtime_q <= mtime_d;                      // always load whatever STEP 5 computed

      if (mem_write_ok) begin                  // only touch other registers on a valid write
        case (mem_waddr)
          CLINT_MSIP_OFFSET: begin
            // Per RISC-V spec, only bit 0 of msip is meaningful -> force upper 31 bits to 0
            msip_q <= {31'b0, mem_wdata[0]};
          end

          CLINT_MTIMECMP_LO_OFFSET: begin
            mtimecmp_q[31:0] <= mem_wdata;     // update lower half of the alarm threshold
          end

          CLINT_MTIMECMP_HI_OFFSET: begin
            mtimecmp_q[63:32] <= mem_wdata;    // update upper half of the alarm threshold
          end

          default: begin
            // address didn't match any known register -> no register update
            // (mem_werror logic below should have already flagged this as an error)
          end
        endcase
      end
    end
  end

  // ===========================================================================
  // STEP 7: Write-error detection (combinational)
  // RULES:
  //   - Default to ERROR (fail-safe).
  //   - Only clear the error if the write is a FULL-WORD write (all byte-strobe
  //     bits set -- no partial/byte writes allowed) AND the address matches one
  //     of the 5 known valid register offsets.
  // ===========================================================================
  always_comb begin
    mem_werror = 1'b1;                          // fail-safe default: assume error

    if (mem_wstrb == {DATA_WIDTH / 8{1'b1}}) begin   // check ALL byte lanes are being written
      case (mem_waddr)
        CLINT_MSIP_OFFSET,
        CLINT_MTIMECMP_LO_OFFSET,
        CLINT_MTIMECMP_HI_OFFSET,
        CLINT_MTIME_LO_OFFSET,
        CLINT_MTIME_HI_OFFSET: begin
          mem_werror = 1'b0;                    // valid address + full-word write -> no error
        end

        default: begin
          // unrecognized address -> mem_werror stays 1 (error)
        end
      endcase
    end
    // if wstrb wasn't "all bytes" (i.e. a partial write), mem_werror also stays 1 (error)
  end

  // ===========================================================================
  // STEP 8: Read-data multiplexer (combinational)
  // RULES:
  //   - Default to ZERO data + ERROR (fail-safe).
  //   - Only drive real data when mem_read_active is true (a real read is in flight).
  //   - Decode the address and select the matching register/half.
  // ===========================================================================
  always_comb begin
    mem_rdata  = '0;                            // fail-safe default: zero data
    mem_rerror = 1'b1;                          // fail-safe default: assume error

    if (mem_read_active) begin                  // only act if a read is genuinely happening now
      case (mem_raddr)
        CLINT_MSIP_OFFSET: begin
          mem_rdata  = msip_q;                  // return the full 32-bit msip register
          mem_rerror = 1'b0;
        end

        CLINT_MTIMECMP_LO_OFFSET: begin
          mem_rdata  = mtimecmp_q[31:0];         // return lower half of mtimecmp
          mem_rerror = 1'b0;
        end

        CLINT_MTIMECMP_HI_OFFSET: begin
          mem_rdata  = mtimecmp_q[63:32];        // return upper half of mtimecmp
          mem_rerror = 1'b0;
        end

        CLINT_MTIME_LO_OFFSET: begin
          mem_rdata  = mtime_q[31:0];            // return lower half of mtime
          mem_rerror = 1'b0;
        end

        CLINT_MTIME_HI_OFFSET: begin
          mem_rdata  = mtime_q[63:32];           // return upper half of mtime
          mem_rerror = 1'b0;
        end

        default: begin
          // unrecognized address -> mem_rdata stays 0, mem_rerror stays 1 (error)
        end
      endcase
    end
  end

endmodule
