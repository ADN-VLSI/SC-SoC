task automatic tc5(output int p, output int f);
  bit [31:0] expected;
  bit [31:0] read_data;
  bit [31:0] write_data;

  p = 0;
  f = 0;

  expected = 32'h00000000;
  write_data = 32'h11223344;

  // Ensure a known initial state at a fixed address.
  write_32(16'h0100, 32'h00000000);

  for (int i = 0; i < 16; i++) begin
    bit [3:0] strb = i;
    bit [31:0] strobe_mask = 32'h00000000;

    for (int b = 0; b < 4; b++) begin
      if (strb[b]) strobe_mask |= (32'hFF << (b * 8));
    end

    write(16'h0100, write_data, strb);
    expected = (expected & ~strobe_mask) | (write_data & strobe_mask);

    read(16'h0100, read_data);
    check(read_data == expected, p, f);
  end

  //$display("TC5: PASS=%0d FAIL=%0d", p, f);
endtask
