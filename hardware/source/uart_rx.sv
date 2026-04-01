module uart_rx (
    input  logic       clk_i,
    input  logic       arst_ni,
    input  logic       rx_i,
    input  logic [1:0] data_bits_i,
    input  logic       parity_en_i,
    input  logic       parity_type_i,
    output logic [7:0] data_o,
    output logic       data_valid_o,
    output logic       parity_error_o
);

  typedef enum logic [2:0] {
    IDLE,
    START,
    DATA,
    PARITY,
    STOP
  } rxrx_states_t;

  rxrx_states_t state, next_state;

  logic [7:0] shift_reg;
  logic [2:0] bit_cnt;
  logic        parity_bit;
  logic        parity_xor;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // PARITY XOR — only over received bits (constant bounds required by tool)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    case (data_bits_i)
      2'b00:   parity_xor = ^shift_reg[4:0];  // 5 bits
      2'b01:   parity_xor = ^shift_reg[5:0];  // 6 bits
      2'b10:   parity_xor = ^shift_reg[6:0];  // 7 bits
      default: parity_xor = ^shift_reg[7:0];  // 8 bits
    endcase
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // NEXT STATE LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    next_state = state;
    case (state)
      IDLE:    if (!rx_i)                           next_state = START;
      START:                                         next_state = DATA;
      DATA:    if (bit_cnt == (data_bits_i + 4)) begin
                 if (parity_en_i)                   next_state = PARITY;
                 else                               next_state = STOP;
               end
      PARITY:                                        next_state = STOP;
      STOP:                                          next_state = IDLE;
      default:                                       next_state = IDLE;
    endcase
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL BLOCK
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      state      <= IDLE;
      shift_reg  <= 8'b0;
      bit_cnt    <= 3'b0;
      parity_bit <= 1'b0;
    end else begin
      state <= next_state;

      // rx_i at START cycle is D0 — store it at bit 0, start counter at 1
      if (state == START) begin
        shift_reg <= {7'b0, rx_i};
        bit_cnt   <= 3'd1;
      end

      // Sample each data bit into correct position
      if (state == DATA) begin
        shift_reg[bit_cnt] <= rx_i;
        if (bit_cnt < (data_bits_i + 4))
          bit_cnt <= bit_cnt + 1'b1;
        else
          bit_cnt <= 3'b0;
      end

      // Capture received parity bit
      if (state == PARITY)
        parity_bit <= rx_i;

    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // OUTPUT LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    data_o         = 8'b0;
    data_valid_o   = 1'b0;
    parity_error_o = 1'b0;
    case (state)
      STOP: begin
        if (rx_i) begin
          data_o         = shift_reg;
          data_valid_o   = 1'b1;
          parity_error_o = parity_en_i &
                           ((parity_xor ^ parity_bit) != parity_type_i);
        end
      end
      default: begin
        data_o         = 8'b0;
        data_valid_o   = 1'b0;
        parity_error_o = 1'b0;
      end
    endcase
  end

endmodule