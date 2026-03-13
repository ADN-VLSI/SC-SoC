module hello;

  initial $display("\033[7;37m################### TEST STARTED ###################\033[0m");
  final   $display("\033[7;37m#################### TEST ENDED ####################\033[0m");

  initial begin
    $display("Hello, World!");
    $finish;
  end

endmodule
