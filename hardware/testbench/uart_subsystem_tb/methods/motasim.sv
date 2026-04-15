// motasim.sv
// Shared testcase helper tasks + counters.
// `include this file inside uart_subsystem_tb BEFORE the tc*.sv includes.

int total_p = 0;
int total_f = 0;

task automatic testcase_begin(input string name);
    $display("============================================================");
    $display("____BEGIN____: %s  ____BEGIN____", name);
    $display("============================================================");
endtask

task automatic testcase_end(input string name);
    $display("============================================================");
    $display("____END____: %s  ____END____", name); 
    //(pass so far: %0d  fail so far: %0d)",
    //       total_p, total_f) ;
    $display("============================================================");
endtask

task automatic testcase_check(input logic ok, input string msg);
    if (ok) begin
        total_p++;
        $display("[PASS] %s", msg);
    end else begin
        total_f++;
        $display("[FAIL] %s", msg);
    end
endtask


