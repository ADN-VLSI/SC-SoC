// write to RAM using backdoor access
function automatic void ram_write(int addr, int data);
  bit [3:0][7:0] byte_data;
  int aligned_addr;
  aligned_addr = addr & 'hffff_fffc;
  byte_data = data;
  foreach (byte_data[i]) u_dut.u_ram.mem[0][aligned_addr+i] = byte_data[i];
endfunction

// read from RAM using backdoor access
function automatic int ram_read(int addr);
  bit [3:0][7:0] byte_data;
  int aligned_addr;
  aligned_addr = addr & 'hffff_fffc;
  foreach (byte_data[i]) byte_data[i] = u_dut.u_ram.mem[0][aligned_addr+i];
  return byte_data;
endfunction

// LOAD SYMBOL FILE
function automatic void load_symbols(string filename);
  int file, r;
  string line;
  string key;
  int value;

  file = $fopen(filename, "r");
  if (file == 0) begin
    $fatal(1, " [FATAL] Could not open file %s", filename);
  end

  while (!$feof(
      file
  )) begin
    r = $fgets(line, file);
    if (r != 0) begin
      r = $sscanf(line, "%h %*s %s", value, key);
      if (r == 2) begin
        sym[key] = value;
      end
    end
  end
  if (debug) begin
    $display(" [DEBUG] Loaded symbols:");
    foreach (sym[key]) begin
      $display(" [DEBUG]   0x%08x %s", sym[key], key);
    end
  end
  $fclose(file);
endfunction

// LOAD PROGRAM
task automatic load_program(string filename);
  automatic bit [7:0]      bmem[int];
  automatic bit [3:0][7:0] wmem[int];

  bmem.delete();
  wmem.delete();
  $readmemh(filename, bmem);
  foreach (bmem[i]) begin
    wmem[i&'hffff_fffc][i&'h0000_0003] = bmem[i];
  end

  foreach (wmem[i]) begin
    if (debug) $display(" [DEBUG] RAM[0x%08x] <= 0x%08x", i, wmem[i]);
    if (back_door_load) begin
      ram_write(i, wmem[i]);
    end else begin
      apb_intf.apb_write(i, wmem[i]);
    end
  end
endtask
