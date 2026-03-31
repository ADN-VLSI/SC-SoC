// task automatic ``__NAME__``_read_8(addr, data, resp);
// task automatic ``__NAME__``_write_8(addr, data, resp);
// task automatic ``__NAME__``_read_16(addr, data, resp);
// task automatic ``__NAME__``_write_16(addr, data, resp);
// task automatic ``__NAME__``_read_32(addr, data, resp);
// task automatic ``__NAME__``_write_32(addr, data, resp);
// task automatic ``__NAME__``_read_64(addr, data, resp);
// task automatic ``__NAME__``_write_64(addr, data, resp);
`define SIMPLE_AXI_M_DRIVER(__NAME__, __CLK__, __ARST_N__, __REQ__, __RESP__)                      \
                                                                                                   \
  localparam ``__NAME__``_AW = $bits(``__REQ__``.aw.addr);                                         \
  localparam ``__NAME__``_DW = $bits(``__RESP__``.r.data);                                         \
                                                                                                   \
  event ``__NAME__``_aw_channel_done_trigger;                                                      \
  longint ``__NAME__``_aw_channel_next_id = 0;                                                     \
  longint ``__NAME__``_aw_channel_access_q[$];                                                     \
  task automatic ``__NAME__``_aw_channel_send(input logic [``__NAME__``_AW-1:0] addr);             \
    longint this_task_id;                                                                          \
    this_task_id = ``__NAME__``_aw_channel_next_id;                                                \
    ``__NAME__``_aw_channel_next_id++;                                                             \
    ``__NAME__``_aw_channel_access_q.push_back(this_task_id);                                      \
    while ((``__NAME__``_aw_channel_access_q[0] != this_task_id) && (``__ARST_N__`` == 1))         \
      @(``__NAME__``_aw_channel_done_trigger);                                                     \
    if ((``__ARST_N__`` == 1)) begin                                                               \
      ``__REQ__``.aw.id     <= '0;                                                                 \
      ``__REQ__``.aw.addr   <= addr;                                                               \
      ``__REQ__``.aw.len    <= '0;                                                                 \
      ``__REQ__``.aw.size   <= 3;                                                                  \
      ``__REQ__``.aw.burst  <= 1;                                                                  \
      ``__REQ__``.aw.lock   <= '0;                                                                 \
      ``__REQ__``.aw.cache  <= '0;                                                                 \
      ``__REQ__``.aw.prot   <= '0;                                                                 \
      ``__REQ__``.aw.qos    <= '0;                                                                 \
      ``__REQ__``.aw.region <= '0;                                                                 \
      ``__REQ__``.aw.user   <= '0;                                                                 \
      ``__REQ__``.aw.atop   <= '0;                                                                 \
      ``__REQ__``.aw_valid  <= '1;                                                                 \
      do @(posedge ``__CLK__``); while (``__RESP__``.aw_ready !== '1);                             \
    end                                                                                            \
    ``__REQ__``.aw_valid <= '0;                                                                    \
    ``__NAME__``_aw_channel_access_q.delete(0);                                                    \
    ->``__NAME__``_aw_channel_done_trigger;                                                        \
  endtask                                                                                          \
                                                                                                   \
  event ``__NAME__``_w_channel_done_trigger;                                                       \
  longint ``__NAME__``_w_channel_next_id = 0;                                                      \
  longint ``__NAME__``_w_channel_access_q[$];                                                      \
  task automatic ``__NAME__``_w_channel_send(input logic [``__NAME__``_DW-1:0] data,               \
                                             input logic [``__NAME__``_DW/8-1:0] strb);            \
    longint this_task_id;                                                                          \
    this_task_id = ``__NAME__``_w_channel_next_id;                                                 \
    ``__NAME__``_w_channel_next_id++;                                                              \
    ``__NAME__``_w_channel_access_q.push_back(this_task_id);                                       \
    while ((``__NAME__``_w_channel_access_q[0] != this_task_id) && (``__ARST_N__`` == 1))          \
      @(``__NAME__``_w_channel_done_trigger);                                                      \
    if ((``__ARST_N__`` == 1)) begin                                                               \
      ``__REQ__``.w.data  <= data;                                                                 \
      ``__REQ__``.w.strb  <= strb;                                                                 \
      ``__REQ__``.w.last  <= '1;                                                                   \
      ``__REQ__``.w.user  <= '0;                                                                   \
      ``__REQ__``.w_valid <= '1;                                                                   \
      do @(posedge ``__CLK__``); while (``__RESP__``.w_ready !== '1);                              \
    end                                                                                            \
    ``__REQ__``.w_valid <= '0;                                                                     \
    ``__NAME__``_w_channel_access_q.delete(0);                                                     \
    ->``__NAME__``_w_channel_done_trigger;                                                         \
  endtask                                                                                          \
                                                                                                   \
  event ``__NAME__``_b_channel_done_trigger;                                                       \
  longint ``__NAME__``_b_channel_next_id = 0;                                                      \
  longint ``__NAME__``_b_channel_access_q[$];                                                      \
  task automatic ``__NAME__``_b_channel_recv(output logic [1:0] resp);                             \
    longint this_task_id;                                                                          \
    this_task_id = ``__NAME__``_b_channel_next_id;                                                 \
    ``__NAME__``_b_channel_next_id++;                                                              \
    ``__NAME__``_b_channel_access_q.push_back(this_task_id);                                       \
    while ((``__NAME__``_b_channel_access_q[0] != this_task_id) && (``__ARST_N__`` == 1))          \
      @(``__NAME__``_b_channel_done_trigger);                                                      \
    if ((``__ARST_N__`` == 1)) begin                                                               \
      ``__REQ__``.b_ready <= '1;                                                                   \
      do @(posedge ``__CLK__``); while (``__RESP__``.b_valid !== '1);                              \
      resp = ``__RESP__``.b.resp;                                                                  \
    end                                                                                            \
    ``__REQ__``.b_ready <= '0;                                                                     \
    ``__NAME__``_b_channel_access_q.delete(0);                                                     \
    ->``__NAME__``_b_channel_done_trigger;                                                         \
  endtask                                                                                          \
                                                                                                   \
  event ``__NAME__``_ar_channel_done_trigger;                                                      \
  longint ``__NAME__``_ar_channel_next_id = 0;                                                     \
  longint ``__NAME__``_ar_channel_access_q[$];                                                     \
  task automatic ``__NAME__``_ar_channel_send(input logic [``__NAME__``_AW-1:0] addr);             \
    longint this_task_id;                                                                          \
    this_task_id = ``__NAME__``_ar_channel_next_id;                                                \
    ``__NAME__``_ar_channel_next_id++;                                                             \
    ``__NAME__``_ar_channel_access_q.push_back(this_task_id);                                      \
    while ((``__NAME__``_ar_channel_access_q[0] != this_task_id) && (``__ARST_N__`` == 1))         \
      @(``__NAME__``_ar_channel_done_trigger);                                                     \
    if ((``__ARST_N__`` == 1)) begin                                                               \
      ``__REQ__``.ar.id     <= '0;                                                                 \
      ``__REQ__``.ar.addr   <= addr;                                                               \
      ``__REQ__``.ar.len    <= '0;                                                                 \
      ``__REQ__``.ar.size   <= 3;                                                                  \
      ``__REQ__``.ar.burst  <= 1;                                                                  \
      ``__REQ__``.ar.lock   <= '0;                                                                 \
      ``__REQ__``.ar.cache  <= '0;                                                                 \
      ``__REQ__``.ar.prot   <= '0;                                                                 \
      ``__REQ__``.ar.qos    <= '0;                                                                 \
      ``__REQ__``.ar.region <= '0;                                                                 \
      ``__REQ__``.ar.user   <= '0;                                                                 \
      ``__REQ__``.ar_valid  <= '1;                                                                 \
      do @(posedge ``__CLK__``); while (``__RESP__``.ar_ready !== '1);                             \
    end                                                                                            \
    ``__REQ__``.ar_valid <= '0;                                                                    \
    ``__NAME__``_ar_channel_access_q.delete(0);                                                    \
    ->``__NAME__``_ar_channel_done_trigger;                                                        \
  endtask                                                                                          \
                                                                                                   \
  event ``__NAME__``_r_channel_done_trigger;                                                       \
  longint ``__NAME__``_r_channel_next_id = 0;                                                      \
  longint ``__NAME__``_r_channel_access_q[$];                                                      \
  task automatic ``__NAME__``_r_channel_recv(output logic [``__NAME__``_DW-1:0] data,              \
                                             output logic [1:0] resp);                             \
    longint this_task_id;                                                                          \
    this_task_id = ``__NAME__``_r_channel_next_id;                                                 \
    ``__NAME__``_r_channel_next_id++;                                                              \
    ``__NAME__``_r_channel_access_q.push_back(this_task_id);                                       \
    while ((``__NAME__``_r_channel_access_q[0] != this_task_id) && (``__ARST_N__`` == 1))          \
      @(``__NAME__``_r_channel_done_trigger);                                                      \
    if ((``__ARST_N__`` == 1)) begin                                                               \
      ``__REQ__``.r_ready <= '1;                                                                   \
      do @(posedge ``__CLK__``); while (``__RESP__``.r_valid !== '1);                              \
      data = ``__RESP__``.r.data;                                                                  \
      resp = ``__RESP__``.r.resp;                                                                  \
    end                                                                                            \
    ``__REQ__``.r_ready <= '0;                                                                     \
    ``__NAME__``_r_channel_access_q.delete(0);                                                     \
    ->``__NAME__``_r_channel_done_trigger;                                                         \
  endtask                                                                                          \
                                                                                                   \
  always @(negedge ``__ARST_N__``) begin                                                           \
    ->``__NAME__``_aw_channel_done_trigger;                                                        \
    ->``__NAME__``_w_channel_done_trigger;                                                         \
    ->``__NAME__``_b_channel_done_trigger;                                                         \
    ->``__NAME__``_ar_channel_done_trigger;                                                        \
    ->``__NAME__``_r_channel_done_trigger;                                                         \
  end                                                                                              \
                                                                                                   \
  task automatic ``__NAME__``_write_64(                                                            \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    input logic [63:0] data,                                                                       \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    logic [``__NAME__``_AW/8-1:0] tstrb;                                                           \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFF8;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    tdata = {'0, data};                                                                            \
    tdata = tdata << (offset * 8);                                                                 \
    tstrb = 'h0FF;                                                                                 \
    tstrb = tstrb << offset;                                                                       \
    fork                                                                                           \
      ``__NAME__``_aw_channel_send(addr);                                                          \
      ``__NAME__``_w_channel_send(tdata, tstrb);                                                   \
      ``__NAME__``_b_channel_recv(resp);                                                           \
    join                                                                                           \
  endtask                                                                                          \
                                                                                                   \
  task automatic ``__NAME__``_read_64(                                                             \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    output logic [63:0] data,                                                                      \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFF8;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    fork                                                                                           \
      ``__NAME__``_ar_channel_send(addr);                                                          \
      ``__NAME__``_r_channel_recv(tdata, resp);                                                    \
    join                                                                                           \
    tdata = tdata >> (8 * offset);                                                                 \
    data  = tdata;                                                                                 \
  endtask                                                                                          \
                                                                                                   \
  task automatic ``__NAME__``_write_32(                                                            \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    input logic [31:0] data,                                                                       \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    logic [``__NAME__``_AW/8-1:0] tstrb;                                                           \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFFC;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    tdata = {'0, data};                                                                            \
    tdata = tdata << (offset * 8);                                                                 \
    tstrb = 'h0F;                                                                                  \
    tstrb = tstrb << offset;                                                                       \
    fork                                                                                           \
      ``__NAME__``_aw_channel_send(addr);                                                          \
      ``__NAME__``_w_channel_send(tdata, tstrb);                                                   \
      ``__NAME__``_b_channel_recv(resp);                                                           \
    join                                                                                           \
  endtask                                                                                          \
                                                                                                   \
  task automatic ``__NAME__``_read_32(                                                             \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    output logic [31:0] data,                                                                      \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFFC;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    fork                                                                                           \
      ``__NAME__``_ar_channel_send(addr);                                                          \
      ``__NAME__``_r_channel_recv(tdata, resp);                                                    \
    join                                                                                           \
    tdata = tdata >> (8 * offset);                                                                 \
    data  = tdata;                                                                                 \
  endtask                                                                                          \
                                                                                                   \
  task automatic ``__NAME__``_write_16(                                                            \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    input logic [15:0] data,                                                                       \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    logic [``__NAME__``_AW/8-1:0] tstrb;                                                           \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFFE;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    tdata = {'0, data};                                                                            \
    tdata = tdata << (offset * 8);                                                                 \
    tstrb = 'h03;                                                                                  \
    tstrb = tstrb << offset;                                                                       \
    fork                                                                                           \
      ``__NAME__``_aw_channel_send(addr);                                                          \
      ``__NAME__``_w_channel_send(tdata, tstrb);                                                   \
      ``__NAME__``_b_channel_recv(resp);                                                           \
    join                                                                                           \
  endtask                                                                                          \
                                                                                                   \
  task automatic ``__NAME__``_read_16(                                                             \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    output logic [15:0] data,                                                                      \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFFE;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    fork                                                                                           \
      ``__NAME__``_ar_channel_send(addr);                                                          \
      ``__NAME__``_r_channel_recv(tdata, resp);                                                    \
    join                                                                                           \
    tdata = tdata >> (8 * offset);                                                                 \
    data  = tdata;                                                                                 \
  endtask                                                                                          \
                                                                                                   \
  task automatic ``__NAME__``_write_8(                                                             \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    input logic [7:0] data,                                                                        \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    logic [``__NAME__``_AW/8-1:0] tstrb;                                                           \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFFF;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    tdata = {'0, data};                                                                            \
    tdata = tdata << (offset * 8);                                                                 \
    tstrb = 'h01;                                                                                  \
    tstrb = tstrb << offset;                                                                       \
    fork                                                                                           \
      ``__NAME__``_aw_channel_send(addr);                                                          \
      ``__NAME__``_w_channel_send(tdata, tstrb);                                                   \
      ``__NAME__``_b_channel_recv(resp);                                                           \
    join                                                                                           \
  endtask                                                                                          \
                                                                                                   \
  task automatic ``__NAME__``_read_8(                                                              \
    input logic [``__NAME__``_AW-1:0] addr,                                                        \
    output logic [7:0] data,                                                                       \
    output logic [1:0] resp);                                                                      \
    int offset;                                                                                    \
    logic [``__NAME__``_AW-1:0] tdata;                                                             \
    offset = addr;                                                                                 \
    offset = offset & 'hFFFF_FFFF;                                                                 \
    offset = offset % (``__NAME__``_DW / 8);                                                       \
    fork                                                                                           \
      ``__NAME__``_ar_channel_send(addr);                                                          \
      ``__NAME__``_r_channel_recv(tdata, resp);                                                    \
    join                                                                                           \
    tdata = tdata >> (8 * offset);                                                                 \
    data  = tdata;                                                                                 \
  endtask                                                                                          \


