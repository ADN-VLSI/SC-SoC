`ifndef __GUARD_AXI4L_TYPEDEF_SVH__
`define __GUARD_AXI4L_TYPEDEF_SVH__ 0

`define AXI4L_AX_CHAN(__NM__,__AW__,__TP__)     \
    typedef struct packed {                     \
      logic [``__AW__``-1:0] addr;              \
      logic [           2:0] prot;              \
    } ``__NM__``_a``__TP__``_chan_t;            \


`define AXI4L_AW_CHAN(__NM__,__AW__)            \
    `AXI4L_AX_CHAN(``__NM__``,``__AW__``,w)     \


`define AXI4L_W_CHAN(__NM__,__DW__)             \
    typedef struct packed {                     \
      logic [  ``__DW__``-1:0]   data;          \
      logic [``__DW__``/8-1:0] strb;            \
    } ``__NM__``_w_chan_t;                      \


`define AXI4L_B_CHAN(__NM__)                    \
    typedef struct packed {                     \
      logic [1:0] resp;                         \
    } ``__NM__``_b_chan_t;                      \


`define AXI4L_AR_CHAN(__NM__,__AW__)            \
    `AXI4L_AX_CHAN(``__NM__``,``__AW__``,r)     \


`define AXI4L_R_CHAN(__NM__,__DW__)             \
    typedef struct packed {                     \
      logic [``__DW__``-1:0] data;              \
      logic [           1:0] resp;              \
    } ``__NM__``_r_chan_t;                      \


`define AXI4L_REQ(__NM__,__AW__,__DW__)         \
    `AXI4L_AW_CHAN(``__NM__``,``__AW__``)       \
    `AXI4L_W_CHAN(``__NM__``,``__DW__``)        \
    `AXI4L_AR_CHAN(``__NM__``,``__AW__``)       \
                                                \
    typedef struct packed {                     \
      ``__NM__``_aw_chan_t aw;                  \
      logic                aw_valid;            \
      ``__NM__``_w_chan_t  w;                   \
      logic                w_valid;             \
      logic                b_ready;             \
      ``__NM__``_ar_chan_t ar;                  \
      logic                ar_valid;            \
      logic                r_ready;             \
    } ``__NM__``_req_t;                         \


`define AXI4L_RSP(__NM__,__DW__)                \
    `AXI4L_B_CHAN(``__NM__``)                   \
    `AXI4L_R_CHAN(``__NM__``,``__DW__``)        \
                                                \
    typedef struct packed {                     \
      logic                aw_ready;            \
      logic                w_ready;             \
      ``__NM__``_b_chan_t  b;                   \
      logic                b_valid;             \
      logic                ar_ready;            \
      ``__NM__``_r_chan_t  r;                   \
      logic                r_valid;             \
    } ``__NM__``_rsp_t;                         \


// AXI4-Lite
// this macro define:
//   - ``__NM__``_aw_chan_t
//   - ``__NM__``_w_chan_t
//   - ``__NM__``_b_chan_t
//   - ``__NM__``_ar_chan_t
//   - ``__NM__``_r_chan_t
//   - ``__NM__``_req_t
//   - ``__NM__``_rsp_t
`define AXI4L_ALL(__NM__,__AW__,__DW__)         \
    `AXI4L_REQ(__NM__,__AW__,__DW__)            \
    `AXI4L_RSP(__NM__,__DW__)                   \

`endif
