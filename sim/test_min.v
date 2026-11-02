module test;
  reg clk;
  initial begin
    clk = 0;
    #10;
    $display("Hello Xcelium! Simulation works perfectly.");
    $finish;
  end
endmodule

