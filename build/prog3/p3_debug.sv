module p3_debug; bit clk=0,start=1; wire done; int i; DUT D1(.clk(clk),.start(start),.done(done)); always #50 clk=!clk;
initial begin $readmemb("test0.txt",D1.dm.core); #200 start=0; wait(done); #100; for(i=0;i<16;i++) $display("%0d: %h %h %h %h",i,D1.dm.core[64+4*i],D1.dm.core[65+4*i],D1.dm.core[66+4*i],D1.dm.core[67+4*i]); $finish; end endmodule
