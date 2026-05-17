module p3_wtrace; bit clk=0,start=1; wire done; int i; DUT D1(.clk(clk),.start(start),.done(done)); always #50 clk=!clk;
always @(posedge clk) if(D1.dm_wen && D1.dm_addr>=64 && D1.dm_addr<68) $display("t=%0t pc=%0d addr=%0d data=%h idx=%0d",$time,D1.pc,D1.dm_addr,D1.dm_dat_in,D1.dm.core[128]);
initial begin $readmemb("test0.txt",D1.dm.core); #200 start=0; wait(done); #100; $display("final %h %h %h %h",D1.dm.core[64],D1.dm.core[65],D1.dm.core[66],D1.dm.core[67]); $finish; end endmodule
