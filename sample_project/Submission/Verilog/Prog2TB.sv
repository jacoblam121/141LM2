// CSE141L  Winter 2023
// test bench for program 2
// flip probabilities:
// 75% one error bit
//    condition: flip2[5:4] != 2'b00;
// 25 * (255/256)%  two error bits
//    condition: flip2[5:4] == 2'b00 && flip2[3:0] != flip;
// 25 * (1/256)% no errors (flip2[5:4] == 2'b00 && flip2[3:0] == flip)
//    
module Prog2TB();

bit clk,                    // clock source -- drives DUT input of same name
    req;	                // req -- start program -- drives DUT input
wire done;		    	    // ack -- from DUT -- done w/ program

// program 1-specific variables
bit  [11:1] d1_in[15];          // original messages
logic      p0, p8, p4, p2, p1;  // Hamming block parity bits
logic[15:0] d1_out[15];         // orig messages w/ parity inserted

// program 2-specific variables
logic[11:1] d2_in[15];           // use to generate data
logic[15:0] d2_good[15];         // d2_in w/ parity
logic[ 3:0] flip[15];            // position of first corruption bit
logic[ 5:0] flip2[15];           // position of possible second corruption bit
logic[15:0] d2_bad1[15];         // possibly corrupt message w/ parity
logic[15:0] d2_bad[15];          // possibly corrupt messages w/ parity
logic       s16, s8, s4, s2, s1; // parity generated from data of d_bad
logic[ 3:0] err;                 // bitwise XOR of p* and s* as 4-bit vector        
logic[11:1] d2_corr[15];         // recovered and corrected messages
bit  [15:0] score2, case2;

bit[15:0] mask;


TopLevel DUT (
    .clk,
    .reset(req),
    .done
);

initial begin
    // load the program into ROM
    $readmemb("prog2_mach.txt", DUT.rom.core);

    // reset memory, reg files, flags to 0
    for (int i = 0; i < 256; i++) begin
        DUT.mem.core[i] = 0;
    end
    for (int i = 0; i < 8; i++) begin
        DUT.regs.core[i] = 0;
        DUT.regs.parity[i%2] = 0;
    end
    DUT.carryIn = 0;
    DUT.equal = 0;
    DUT.lessThan = 0;
    DUT.zero = 0;

    // generate parity from random 11-bit messages 
    for(int i=0; i<15; i++) begin
        d2_in[i] = $random;
        p8 = ^d2_in[i][11:5];
        p4 = (^d2_in[i][11:8])^(^d2_in[i][4:2]); 
        p2 = d2_in[i][11]^d2_in[i][10]^d2_in[i][7]^d2_in[i][6]^d2_in[i][4]^d2_in[i][3]^d2_in[i][1];
        p1 = d2_in[i][11]^d2_in[i][ 9]^d2_in[i][7]^d2_in[i][5]^d2_in[i][4]^d2_in[i][2]^d2_in[i][1];
        p0 = ^d2_in[i]^p8^p4^p2^p1;
        d2_good[i] = {d2_in[i][11:5],p8,d2_in[i][4:2],p4,d2_in[i][1],p2,p1,p0};
        // flip one bit
        flip[i] = $random;	  // 'b1000000;
        d2_bad1[i] = d2_good[i] ^ (1'b1<<flip[i]);
        // flip second bit about 25% of the time (flip2<16)		// 00_0010     1010
        // if flip2[5:4]!=0, flip2 will have no effect, and we'll have a one-bit flip
        flip2[i] = $random;	   // 'b0;
        d2_bad[i] = d2_bad1[i] ^ (1'b1<<flip2[i]);
        // if flip2[5:4]==0 && flip2[3:0]==flip, then flip2 undoes flip, so no error
        DUT.mem.core[31+2*i] = {d2_bad[i][15:8]};
        DUT.mem.core[30+2*i] = {d2_bad[i][ 7:0]};
    end

    mask = 'b1;
    for (int i = 0; i < 15; i++) begin
        DUT.mem.core[128 + i*2] = mask[7:0];
        DUT.mem.core[129 + i*2] = mask[15:8];

        mask = mask << 1;
    end

    #10ns req   = 1;
    #10ns req   = 0;
    wait(done);
    $display();
    $display("start program 2");
    $display();
    for(int i=0; i<15; i++) begin
        $displayb({5'b0,d2_in[i]});
        $writeb  (DUT.mem.core[1+2*i]);
        $displayb(DUT.mem.core[0+2*i]);
        if(flip2[i][5:4]) begin :sgl_err                           // single error scenario
            $display("single error injected, expecting MSBs of output = 2'b01");
            if({5'b01000,d2_in[i]}=={DUT.mem.core[1+2*i],DUT.mem.core[0+2*i]}) begin
                $display("we have a match");
                score2++;
            end else begin
                $display("erroneous output");
            end
            $display("expected %b, got %b",{5'b01000,d2_in[i]},{DUT.mem.core[1+2*i],DUT.mem.core[0+2*i]});
        end	 :sgl_err

        else if(flip2[i][3:0]==flip[i]) begin :no_err       // zero error scenario: flip2 undoes flip
            $display("no errors injected, expecting MSBs of output = 2'b00");
            if({5'b00000,d2_in[i]}=={DUT.mem.core[1+2*i],DUT.mem.core[0+2*i]}) begin
                $display("we have a match");
                score2++;
            end else begin
                $display("erroneous output");
            end
            $display("expected %b, got %b",{5'b00000,d2_in[i]},{DUT.mem.core[1+2*i],DUT.mem.core[0+2*i]});
        end	:no_err

        else begin :dbl_err									// two-error scenario; time to give up and raise the white flag
            $display("two errors injected, expecting MSB of output = 1'b1");
            if(DUT.mem.core[1+2*i][7]==1'b1) begin		   // test for MSB = 1 (two error flag)
                $display("we have a match");
                score2++;
            end else begin
            $display("erroneous output");
            end
            $display("expected 1???????????????, got %b",{DUT.mem.core[1+2*i],DUT.mem.core[0+2*i]});
        end :dbl_err

        case2++;
        $display("flip positions = %b %b",flip2[i],flip[i]);
        $display();
    end

    $display("program 2 score = %d out of %d",score2,case2);
    #10ns $stop;
end

always begin
  #5ns clk = 1;            // tic
  #5ns clk = 0;			   // toc
end										

endmodule
										   