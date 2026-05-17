module p2_debug;
  bit clk=0,start=1; wire done; int i;
  DUT D1(.clk(clk),.start(start),.done(done));
  always #50 clk=!clk;
  initial begin
    $readmemb("test4.txt",D1.dm.core);
    D1.dm.core[66]=8'hff; D1.dm.core[67]=8'hff;
    for(i=68;i<256;i++) D1.dm.core[i]=0;
    #200 start=0; wait(done); #100;
    $display("out %h %h %h %h",D1.dm.core[66],D1.dm.core[67],D1.dm.core[68],D1.dm.core[69]);
    $display("scratch min %h %h max %h %h dist %h %h j %0d k %0d",D1.dm.core[130],D1.dm.core[131],D1.dm.core[132],D1.dm.core[133],D1.dm.core[134],D1.dm.core[135],D1.dm.core[128],D1.dm.core[129]);
    $finish;
  end
endmodule
