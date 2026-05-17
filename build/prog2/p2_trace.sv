module p2_trace;
 bit clk=0,start=1; wire done; int i; DUT D1(.clk(clk),.start(start),.done(done)); always #50 clk=!clk;
 always @(posedge clk) if(!start && D1.pc==10'd140) $display("t=%0t j=%0d k=%0d dist=%h%h a?",$time,D1.dm.core[128],D1.dm.core[129],D1.dm.core[134],D1.dm.core[135]);
 initial begin $readmemb("test0.txt",D1.dm.core); D1.dm.core[66]=8'hff; D1.dm.core[67]=8'hff; for(i=68;i<256;i++) D1.dm.core[i]=0; #200 start=0; wait(done); #100; $display("out %h%h %h%h",D1.dm.core[66],D1.dm.core[67],D1.dm.core[68],D1.dm.core[69]); $finish; end
endmodule
