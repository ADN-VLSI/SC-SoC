`define AX_CHAN(__NM__,__AW__,__TP__)           \
    typedef struct packed {                     \
      logic [``__AW__``-1:0] a``__TP__``addr;   \
      logic [       2:0] a``__TP__``prot;       \
    } ``__NM__``_a``__TP__``_chan_t;            \


`define AW_CHAN(__NM__,__AW__)                  \
    `AX_CHAN(``__NM__``,``__AW__``,w)           \


`define W_CHAN(__NM__,__DW__)                   \
    typedef struct packed {                     \
      logic [``__DW__``-1:0] wdata;             \
      logic [``__DW__``/8-1:0] wstrb;           \
    } ``__NM__``_w_chan_t;                      \


`define B_CHAN(__NM__)                          \
    typedef struct packed {                     \
      logic [1:0] bresp;                        \
    } ``__NM__``_b_chan_t;                      \


`define AR_CHAN(__NM__,__AW__)                  \
    `AX_CHAN(``__NM__``,``__AW__``,r)           \


`define R_CHAN(__NM__,__DW__)                   \
    typedef struct packed {                     \
      logic [``__DW__``-1:0] rdata;             \
      logic [1:0] rresp;                        \
    } ``__NM__``_r_chan_t;                      \