module io_pad #(
) (
    input  wire pull_i,
    input  wire wdata_i,
    input  wire wen_i,
    output wire rdata_o,
    inout  wire pin_io
);

  bufif1 (pull1, pull0) pull_down (pin_io, wdata_i, pull_i);
  bufif1 (strong1, strong0) wdata_drive (pin_io, wdata_i, wen_i);
  buf (strong1, strong0) read_data (rdata_o, pin_io);

endmodule
