module uart_rx (
    input  logic       clk_i,          // baud-rate clock
    input  logic       arst_ni,        // active-low async reset
    input  logic       rx_i,           // serial input
    input  logic [1:0] data_bits_i,    // 00→5-bit … 11→8-bit
    input  logic       parity_en_i,    // 1: parity enabled
    input  logic       parity_type_i,  // 0: even, 1: odd
    output logic [7:0] data_o,         // received data
    output logic       data_valid_o,   // high for STOP cycle
    output logic       parity_error_o  // parity mismatch flag
);

    typedef enum logic [2:0] {
        IDLE,    // wait for start bit
        START,   // align counter, skip start bit sample
        DATA,    // shift in data bits LSB-first
        PARITY,  // sample parity bit
        STOP     // check stop bit, drive outputs
    } rx_state_t;

    rx_state_t state, next_state;

    logic [7:0] shift_reg;   // incoming data shift register
    logic [2:0] bit_cnt;     // current bit index
    logic       parity_bit;  // received parity bit
    logic       parity_xor;  // computed parity over data width

    // parity calculation: XOR over active data width; constant slice bounds required by tools
    always_comb begin
        case (data_bits_i)
            2'b00:   parity_xor = ^shift_reg[4:0];  // 5-bit
            2'b01:   parity_xor = ^shift_reg[5:0];  // 6-bit
            2'b10:   parity_xor = ^shift_reg[6:0];  // 7-bit
            default: parity_xor = ^shift_reg[7:0];  // 8-bit
        endcase
    end

    // next-state logic: transitions driven by current state and inputs; DATA exits at last bit index
    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (!rx_i) next_state = START;                          // start bit detected
            START:   next_state = DATA;                                      // begin data capture
            DATA:    if (bit_cnt == (3'(data_bits_i) + 3'd4))               // last bit reached
                         next_state = parity_en_i ? PARITY : STOP;
            PARITY:  next_state = STOP;
            STOP:    next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // sequential logic: advances state, captures rx_i LSB-first, skips start bit, latches parity
    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            state      <= IDLE;
            shift_reg  <= 8'b0;
            bit_cnt    <= 3'b0;
            parity_bit <= 1'b0;
        end else begin
            state <= next_state;

            if (state == START)
                bit_cnt <= 3'b0;              // rx_i is still start bit, do not sample

            if (state == DATA) begin
                shift_reg[bit_cnt] <= rx_i;   // capture bit LSB-first
                if (bit_cnt <= (3'(data_bits_i) + 3'd4))
                    bit_cnt <= bit_cnt + 1'b1;
                else
                    bit_cnt <= 3'b0;           // reset after last bit
            end

            if (state == PARITY)
                parity_bit <= rx_i;            // latch received parity
        end
    end

    // output logic: drives outputs in STOP on valid stop bit; checks parity; defaults to 0
    always_comb begin
        data_o         = 8'b0;
        data_valid_o   = 1'b0;
        parity_error_o = 1'b0;

        if (state == STOP && rx_i) begin                                     // valid stop bit
            data_o         = shift_reg;
            data_valid_o   = 1'b1;
            parity_error_o = parity_en_i & ((parity_xor ^ parity_bit) != parity_type_i);
        end
    end

endmodule