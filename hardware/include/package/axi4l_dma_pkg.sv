`ifndef AXI4L_DMA_PKG_SV
`define AXI4L_DMA_PKG_SV
`include "axi/typedef.svh"

package axi4l_dma_pkg;

  // Register offsets
  parameter int DMA_SRC_ADDR_OFFSET  = 'h00;
  parameter int DMA_DST_ADDR_OFFSET  = 'h04;
  parameter int DMA_NUM_WORDS_OFFSET = 'h08;
  parameter int DMA_REMAINING_OFFSET = 'h0C;
  parameter int DMA_CTRL_OFFSET      = 'h10;
  parameter int DMA_STAT_OFFSET      = 'h14;

  // AXI4-Lite types: ADDR=6 DATA=32
  `AXI_LITE_TYPEDEF_ALL(dma_axil, logic[5:0], logic[31:0], logic[3:0])

  typedef struct packed { logic [31:0] src_addr;  } dma_src_addr_reg_t;
  typedef struct packed { logic [31:0] dst_addr;  } dma_dst_addr_reg_t;
  typedef struct packed { logic [31:0] num_words; } dma_num_words_reg_t;
  typedef struct packed { logic [31:0] remaining; } dma_remaining_reg_t;

  typedef struct packed {
    logic        intr_en;
    logic        init;  // start of transfer when set
  } dma_ctrl_reg_t;

  typedef struct packed {
    logic        error;
    logic        busy;
  } dma_stat_reg_t;


  endpackage : axi4l_dma_pkg