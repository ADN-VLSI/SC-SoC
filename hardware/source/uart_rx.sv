module uart_rx (
    input  logic       clk_i,          // baud-rate clock
    input  logic       arst_ni,        // active-low async reset
    input  logic       rx_i,           // serial input
    input  logic [1:0] data_bits_i,    // 00→5-bit … 11→8-bit
    input  logic       parity_en_i,    // 1: parity enabled
    input  logic       parity_type_i,  // 0: even, 1: odd
    output logic [7:0] data_o,         // received data (masked to active width)
    output logic       data_valid_o,   // high for STOP cycle
    output logic       parity_error_o  // parity mismatch flag
);

typedef enum logic [2:0] {
    IDLE,    // wait for start bit
    START,   // sample D0, init bit_cnt = 1
    DATA,    // shift in D1..D(N-1) LSB-first
    PARITY,  // sample parity bit
    STOP     // check stop bit, drive outputs
} rx_state_t;

rx_state_t state, next_state;

logic [7:0] shift_reg;   // incoming data shift register
logic [2:0] bit_cnt;     // current bit index (1..N-1 during DATA)
logic       parity_bit;  // received parity bit
logic       parity_xor;  // computed parity over data width

////////////////////////////////////////////////////////////
// Parity calculation — XOR over active data width only.
// Constant slice bounds required by synthesis tools.
////////////////////////////////////////////////////////////

always_comb begin
    case (data_bits_i)
        2'b00:   parity_xor = ^shift_reg[4:0];  // 5-bit
        2'b01:   parity_xor = ^shift_reg[5:0];  // 6-bit
        2'b10:   parity_xor = ^shift_reg[6:0];  // 7-bit
        default: parity_xor = ^shift_reg[7:0];  // 8-bit
    endcase
end

/////////////////////////////////////////////////////////////////////////////////
// Next-state logic.
// DATA exits when bit_cnt reaches the last-bit index for the configured width.
// Last-bit index = 3'(data_bits_i) + 3'd4  (4/5/6/7 for 5/6/7/8-bit).
/////////////////////////////////////////////////////////////////////////////////

always_comb begin
    next_state = state;
    case (state)
        IDLE:    if (!rx_i) next_state = START;
        START:   next_state = DATA;
        DATA:    if (bit_cnt == (3'(data_bits_i) + 3'd4))
                     next_state = parity_en_i ? PARITY : STOP;
        PARITY:  next_state = STOP;
        STOP:    next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Sequential logic.
// START state now samples D0 into shift_reg[0] and sets bit_cnt = 1.
// rx_i carries D0 at the START clock (the start bit was the prior clock).
// DATA therefore opens at D1, restoring correct bit alignment.
// `bit_cnt < last_bit` so the counter stops cleanly at the last valid index without an extra tick.
/////////////////////////////////////////////////////////////////////////////////////////////////////

always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
        state      <= IDLE;
        shift_reg  <= 8'b0;
        bit_cnt    <= 3'b0;
        parity_bit <= 1'b0;
    end else begin
        state <= next_state;

        if (state == START) begin
            // D0 is on rx_i right now.
            shift_reg[0] <= rx_i;   // sample D0 into bit 0
            bit_cnt      <= 3'd1;   // DATA will continue from D1 onward
        end

        if (state == DATA) begin
            shift_reg[bit_cnt] <= rx_i;   // capture D(bit_cnt) LSB-first

            // bit_cnt stops at the last valid index.
            if (bit_cnt < (3'(data_bits_i) + 3'd4))
                bit_cnt <= bit_cnt + 3'd1;
            else
                bit_cnt <= 3'd0;           // reset after final bit
        end

        if (state == PARITY)
            parity_bit <= rx_i;            // latch received parity bit
    end
end

///////////////////////////////////////////////////////////////////////////
// Output logic — drives outputs in STOP on a valid (high) stop bit.
///////////////////////////////////////////////////////////////////////////

logic [7:0] data_masked;
always_comb begin
    case (data_bits_i)
        2'b00:   data_masked = {3'b0, shift_reg[4:0]};  // 5-bit: zero [7:5]
        2'b01:   data_masked = {2'b0, shift_reg[5:0]};  // 6-bit: zero [7:6]
        2'b10:   data_masked = {1'b0, shift_reg[6:0]};  // 7-bit: zero [7]
        default: data_masked =        shift_reg[7:0];   // 8-bit: no masking
    endcase
end

always_comb begin
    data_o         = 8'b0;
    data_valid_o   = 1'b0;
    parity_error_o = 1'b0;

    if (state == STOP && rx_i) begin                      // valid stop bit
        data_o         = data_masked;                     // masked output
        data_valid_o   = 1'b1;
        parity_error_o = parity_en_i & ((parity_xor ^ parity_bit) != parity_type_i);
    end
end

endmodule