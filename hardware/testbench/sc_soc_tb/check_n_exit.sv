do #100ns; while (ram_read(sym["tohost"]) == 0);

exit_code = 'h7fff_ffff & ram_read(sym["tohost"]);

if (sym.exists("TEST_DATA_BYTES") && sym.exists("REF_DATA") && sym.exists("TEST_DATA")) begin
  
  automatic int test_data_bytes = ram_read(sym["TEST_DATA_BYTES"]);
  for (int i = 0; i < test_data_bytes; i++) begin
    int ref_data;
    int test_data;
    ref_data  = ram_read(sym["REF_DATA"] + i);
    test_data = ram_read(sym["TEST_DATA"] + i);
    ref_data  = ref_data  >> (i & 'h0000_0003);
    test_data = test_data >> (i & 'h0000_0003);
    ref_data  = ref_data  & 'h0000_00FF;
    test_data = test_data & 'h0000_00FF;
    if (ref_data != test_data) begin
      $display(" [ERROR] Data mismatch at index %0d: expected 0x%08x, got 0x%08x", i, ref_data, test_data);
      exit_code = exit_code | 'h8000_0000;
    end else if (debug) begin
      $display(" [DEBUG] Data match at index %0d: 0x%08x", i, ref_data);
    end
  end

end else begin
  $display("\033[1;33mNo test data to compare\033[0m");
end

$display("Exit code: 0x%08x (%0d)", exit_code, exit_code);

if (exit_code == 0) $display("\033[1;32m [PASS] %s\033[0m", test_name);
else                $display("\033[1;31m [FAIL] %s\033[0m", test_name);

$finish;
