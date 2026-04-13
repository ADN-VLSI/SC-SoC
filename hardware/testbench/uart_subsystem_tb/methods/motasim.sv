// motasim.sv
// Shared testcase helper tasks + counters.
// `include this file inside uart_subsystem_tb BEFORE the tc*.sv includes.

int total_pass = 0;
int total_fail = 0;

task automatic testcase_begin(input string name);
    $display("============================================================");
    $display("BEGIN: %s", name);
    $display("============================================================");
endtask

task automatic testcase_end();
    $display("============================================================");
    $display("END  (pass so far: %0d  fail so far: %0d)",
             total_pass, total_fail);
    $display("============================================================");
endtask

task automatic testcase_check(input logic ok, input string msg);
    if (ok) begin
        total_pass++;
        $display("[PASS] %s", msg);
    end else begin
        total_fail++;
        $display("[FAIL] %s", msg);
    end
endtask