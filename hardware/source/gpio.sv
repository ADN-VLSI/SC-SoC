// @foez-bhai add description to this module

module gpio #(
    parameter int GPIO_WIDTH = 32
) (
    input  logic [GPIO_WIDTH-1:0] gpio_dir_i,   // 0=input, 1=output
    input  logic [GPIO_WIDTH-1:0] gpio_out_i,   // Output data
    input  logic [GPIO_WIDTH-1:0] gpio_pull_i,  // Pull enable
    output logic [GPIO_WIDTH-1:0] gpio_in_o,    // Input data
    inout  wire  [GPIO_WIDTH-1:0] gpio_pin_io   // Physical pins
);
 
    genvar i;
    generate
        for (i = 0; i < GPIO_WIDTH; i++) begin : gen_pad
            io_pad u_pad (
                .pull_i  (gpio_pull_i[i]),
                .wen_i   (gpio_dir_i[i]),
                .wdata_i (gpio_out_i[i]),
                .rdata_o (gpio_in_o[i]),
                .pin_io  (gpio_pin_io[i])
            );
        end
    endgenerate
 
endmodule