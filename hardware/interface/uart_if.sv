// UART Interface for simulating UART communication in testbenches
interface uart_if;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Signals
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Tri-state UART transmit line (default high due to tri1)
  tri1 tx;
  // Tri-state UART receive line (default high due to tri1)
  tri1 rx;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Parameters for UART configuration
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Baud rate for UART communication (default 115200)
  int  BAUD_RATE = 115200;
  // Enable parity bit (0 = disabled, 1 = enabled)
  bit  PARITY_ENABLE = 0;
  // Parity type (0 = even, 1 = odd)
  bit  PARITY_TYPE = 1;
  // Use second stop bit (0 = 1 stop bit, 1 = 2 stop bits)
  bit  SECOND_STOP_BIT = 0;
  // Number of data bits (typically 8)
  int  DATA_BITS = 8;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Methods
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Function to reset UART parameters to defaults
  function automatic void reset();
    BAUD_RATE       = 115200;
    PARITY_ENABLE   = 0;
    PARITY_TYPE     = 1;
    SECOND_STOP_BIT = 0;
    DATA_BITS       = 8;
  endfunction

  // Macro to define send and receive tasks for a UART port (tx or rx)
  `define SEND_RECV(__PORT__)                                                                     \
    /* Flag to control driving the port */                                                        \
    bit drive_``__PORT__``;                                                                       \
    /* Register to hold the value to drive */                                                     \
    bit reg_``__PORT__``;                                                                         \
                                                                                                  \
    /* Assign the port: drive if enabled, else high-Z */                                          \
    assign ``__PORT__`` = drive_``__PORT__`` ? reg_``__PORT__`` : 1'bz;                           \
                                                                                                  \
    /* Task to send data on the UART port */                                                      \
    task automatic send_``__PORT__``(                                                             \
        input logic [7:0] data, input int baud_rate = BAUD_RATE,                                  \
        input bit parity_enable = PARITY_ENABLE, input bit parity_type = PARITY_TYPE,             \
        input bit second_stop_bit = SECOND_STOP_BIT, input int data_bits = DATA_BITS);            \
                                                                                                  \
      realtime bit_time;                                                                          \
      bit parity_bit;                                                                             \
                                                                                                  \
      /* Update global parameters */                                                              \
      BAUD_RATE = baud_rate;                                                                      \
      PARITY_ENABLE = parity_enable;                                                              \
      PARITY_TYPE = parity_type;                                                                  \
      SECOND_STOP_BIT = second_stop_bit;                                                          \
      DATA_BITS = data_bits;                                                                      \
                                                                                                  \
      bit_time   = 1s / BAUD_RATE;                                                                \
      parity_bit = 0;                                                                             \
                                                                                                  \
      /* Calculate parity bit */                                                                  \
      for (int i = 0; i < DATA_BITS; i++) begin                                                   \
        parity_bit ^= data[i];                                                                    \
      end                                                                                         \
                                                                                                  \
      if (PARITY_TYPE) begin                                                                      \
        parity_bit = ~parity_bit;                                                                 \
      end                                                                                         \
                                                                                                  \
      drive_``__PORT__`` <= '1;                                                                   \
                                                                                                  \
      /* Start bit */                                                                             \
      reg_``__PORT__`` <= '0;                                                                     \
      #(bit_time);                                                                                \
                                                                                                  \
      /* Data bits */                                                                             \
      for (int i = 0; i < DATA_BITS; i++) begin                                                   \
        reg_``__PORT__`` <= data[i];                                                              \
        #(bit_time);                                                                              \
      end                                                                                         \
                                                                                                  \
      /* Parity bit */                                                                            \
      if (PARITY_ENABLE) begin                                                                    \
        reg_``__PORT__`` <= parity_bit;                                                           \
        #(bit_time);                                                                              \
      end                                                                                         \
                                                                                                  \
      /* Stop bits */                                                                             \
      reg_``__PORT__`` <= '1;                                                                     \
      #(bit_time);                                                                                \
      if (SECOND_STOP_BIT) begin                                                                  \
        #(bit_time);                                                                              \
      end                                                                                         \
                                                                                                  \
      drive_``__PORT__`` <= '0;                                                                   \
                                                                                                  \
    endtask                                                                                       \
                                                                                                  \
    /* Task to receive data on the UART port */                                                   \
    task automatic recv_``__PORT__``(                                                             \
        output logic [7:0] data, output logic parity, input int baud_rate = BAUD_RATE,            \
        input bit parity_enable = PARITY_ENABLE, input bit parity_type = PARITY_TYPE,             \
        input bit second_stop_bit = SECOND_STOP_BIT, input int data_bits = DATA_BITS);            \
                                                                                                  \
      realtime bit_time;                                                                          \
      bit expected_parity;                                                                        \
                                                                                                  \
      /* Update global parameters */                                                              \
      BAUD_RATE = baud_rate;                                                                      \
      PARITY_ENABLE = parity_enable;                                                              \
      PARITY_TYPE = parity_type;                                                                  \
      SECOND_STOP_BIT = second_stop_bit;                                                          \
      DATA_BITS = data_bits;                                                                      \
                                                                                                  \
      data = '0;                                                                                  \
                                                                                                  \
      /* Wait for start bit */                                                                    \
      do begin                                                                                    \
        wait(``__PORT__`` === '0);                                                                \
        bit_time = 1s / BAUD_RATE;                                                                \
        #(bit_time / 2);                                                                          \
      end while (``__PORT__`` != '0);                                                             \
                                                                                                  \
      /* Sample data bits */                                                                      \
      for (int i = 0; i < DATA_BITS; i++) begin                                                   \
        #(bit_time);                                                                              \
        data[i] = ``__PORT__``;                                                                   \
      end                                                                                         \
                                                                                                  \
      /* Sample parity bit */                                                                     \
      if (PARITY_ENABLE) begin                                                                    \
        #(bit_time);                                                                              \
        parity = ``__PORT__``;                                                                    \
      end                                                                                         \
                                                                                                  \
    endtask                                                                                       \

  // Instantiate the macro for tx port (creates send_tx and recv_tx tasks)
  `SEND_RECV(tx)
  // task automatic send_tx(DATA, baud_rate, parity_enable, parity_type, second_stop_bit, data_bits);
  // task automatic recv_tx(DATA, baud_rate, parity_enable, parity_type, second_stop_bit, data_bits);

  // Instantiate the macro for rx port (creates send_rx and recv_rx tasks)
  `SEND_RECV(rx)
  // task automatic send_rx(DATA, baud_rate, parity_enable, parity_type, second_stop_bit, data_bits);
  // task automatic recv_rx(DATA, baud_rate, parity_enable, parity_type, second_stop_bit, data_bits);

  // Undefine the macro to avoid conflicts
  `undef SEND_RECV

  task automatic wait_till_idle(input int tx_len = 3);
    realtime bit_time;
    int i;
    i = 0;
    while (i < tx_len * 22) begin
      bit_time = 1s / BAUD_RATE;
      #(bit_time / 2);
      i++;
      if (tx == 0 || rx == 0) i = 0;
    end
  endtask

endinterface
