module uart_tx (
    input  logic       clk_i,
    input  logic       arst_ni,
    input  logic [7:0] data_i,
    input  logic       data_valid_i,
    input  logic [1:0] data_bits_i,
    input  logic       parity_en_i,
    input  logic       parity_type_i,
    input  logic       extra_stop_i,
    output logic       tx_o,
    output logic       data_ready_o
);

  typedef enum logic [2:0] {
    IDLE,
    START,
    DATA,
    PARITY,
    STOP,
    STOP2
  } txrx_states_t;

  txrx_states_t state, next_state;

  logic [7:0]  data_reg;
  logic [2:0]  bit_cnt;
  logic        parity_xor;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // PARITY XOR — only over transmitted bits (constant bounds required by tool)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    case (data_bits_i)
      2'b00:   parity_xor = ^data_reg[4:0];  // 5 bits
      2'b01:   parity_xor = ^data_reg[5:0];  // 6 bits
      2'b10:   parity_xor = ^data_reg[6:0];  // 7 bits
      default: parity_xor = ^data_reg[7:0];  // 8 bits
    endcase
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL BLOCK
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      state    <= IDLE;
      data_reg <= 8'b0;
      bit_cnt  <= 3'b0;
    end else begin
      state <= next_state;

      if (state == IDLE && data_valid_i)
        data_reg <= data_i;

      if (state == DATA) begin
        if (bit_cnt < (data_bits_i + 4))
          bit_cnt <= bit_cnt + 1'b1;
        else
          bit_cnt <= 3'b0;
      end else begin
        bit_cnt <= 3'b0;
      end
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // NEXT STATE LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    next_state = state;
    case (state)
      IDLE:    if (data_valid_i)                       next_state = START;
      START:                                           next_state = DATA;
      DATA:    if (bit_cnt == (data_bits_i + 4)) begin
                 if (parity_en_i)                      next_state = PARITY;
                 else                                  next_state = STOP;
               end
      PARITY:                                          next_state = STOP;
      STOP:    if (extra_stop_i)                       next_state = STOP2;
               else                                    next_state = IDLE;
      STOP2:                                           next_state = IDLE;
      default:                                         next_state = IDLE;
    endcase
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // OUTPUT LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    tx_o         = 1'b1;
    data_ready_o = 1'b0;
    case (state)
      IDLE:    data_ready_o = 1'b1;
      START:   tx_o         = 1'b0;
      DATA:    tx_o         = data_reg[bit_cnt];
      PARITY:  tx_o         = parity_type_i ? ~parity_xor : parity_xor;
      STOP:    tx_o         = 1'b1;
      STOP2:   tx_o         = 1'b1;
      default: tx_o         = 1'b1;
    endcase
  end

endmodule