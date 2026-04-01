module uart_rx (
    input  logic       clk_i,          // system clock
    input  logic       arst_ni,        // active-low reset
    input  logic       rx_i,           // serial input line
    input  logic [1:0] data_bits_i,    // number of data bits (5–8)
    input  logic       parity_en_i,    // enable parity
    input  logic       parity_type_i,  // 0: even, 1: odd

    output logic [7:0] data_o,         // received data
    output logic       data_valid_o,   // data valid pulse
    output logic       parity_error_o  // parity error flag
);

    // FSM state definition
    typedef enum logic [2:0] {
        IDLE,    // wait for start bit
        START,   // first data bit alignment
        DATA,    // receiving data bits
        PARITY,  // receiving parity bit
        STOP     // stop bit check
    } rx_state_t;

    rx_state_t state, next_state;

    // internal registers
    logic [7:0] shift_reg;   // stores incoming data bits
    logic [2:0] bit_cnt;     // counts received bits
    logic       parity_bit;  // received parity bit
    logic       parity_xor;  // calculated parity

    // parity calculation based on received data width
    always_comb begin
        case (data_bits_i)
            2'b00:   parity_xor = ^shift_reg[4:0];
            2'b01:   parity_xor = ^shift_reg[5:0];
            2'b10:   parity_xor = ^shift_reg[6:0];
            default: parity_xor = ^shift_reg[7:0];
        endcase
    end

    // next-state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE:    if (!rx_i) next_state = START;  // detect start bit (low)

            START:   next_state = DATA;              // move to data phase

            DATA: begin
                // after last bit, go to PARITY or STOP
                if (bit_cnt == (data_bits_i + 4)) begin
                    if (parity_en_i) next_state = PARITY;
                    else             next_state = STOP;
                end
            end

            PARITY:  next_state = STOP;

            STOP:    next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    // sequential logic: state, shift register, counters
    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            state      <= IDLE;
            shift_reg  <= 8'b0;
            bit_cnt    <= 3'b0;
            parity_bit <= 1'b0;
        end else begin
            state <= next_state;

            // first data bit captured immediately after start
            if (state == START) begin
                shift_reg <= {7'b0, rx_i};
                bit_cnt   <= 3'd1;
            end

            // capture incoming bits
            if (state == DATA) begin
                shift_reg[bit_cnt] <= rx_i;

                if (bit_cnt < (data_bits_i + 4))
                    bit_cnt <= bit_cnt + 1'b1;
                else
                    bit_cnt <= 3'b0;
            end

            // capture parity bit
            if (state == PARITY)
                parity_bit <= rx_i;
        end
    end

    // output logic
    always_comb begin
        data_o         = 8'b0;
        data_valid_o   = 1'b0;
        parity_error_o = 1'b0;

        case (state)
            STOP: begin
                if (rx_i) begin // valid stop bit
                    data_o       = shift_reg;
                    data_valid_o = 1'b1;

                    // parity check
                    parity_error_o = parity_en_i &
                                     ((parity_xor ^ parity_bit) != parity_type_i);
                end
            end
        endcase
    end

endmodule