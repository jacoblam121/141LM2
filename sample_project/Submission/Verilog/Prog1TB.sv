module Prog1TB();

bit clk, reset;
wire done;

// program 1 variables
bit [11:1] d_in[15];
bit p0, p8, p4, p2, p1;
bit [15:0] d_calc, d_out;
bit [15:0] score, total;

TopLevel DUT (
    .clk,
    .reset,
    .done
);

initial begin
    // load the program into ROM
    $readmemb("prog1_mach.txt", DUT.rom.core);

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

    // generate 15 random messages, store in memory 0-29
    for (int i = 0; i < 15; i++) begin
        d_in[i] = $random>>4;

        DUT.mem.core[2*i + 1]   = {5'b0, d_in[i][11:9]};
        DUT.mem.core[2*i]       = d_in[i][8:1];
    end

    $display("Beginning program");
    #10ns reset = 1'b1; // reset PC so program can begin
    #10ns reset = 1'b0;
    wait(done);
    $display("Program finished!");

    $display("-----");

    for (int i = 0; i < 15; i++) begin
        // parities
        p8 = ^d_in[i][11:5];
        p4 = (^d_in[i][11:8])^(^d_in[i][4:2]); 
        p2 = d_in[i][11]^d_in[i][10]^d_in[i][7]^d_in[i][6]^d_in[i][4]^d_in[i][3]^d_in[i][1];
        p1 = d_in[i][11]^d_in[i][ 9]^d_in[i][7]^d_in[i][5]^d_in[i][4]^d_in[i][2]^d_in[i][1];
        p0 = ^d_in[i]^p8^p4^p2^p1;

        d_calc = {d_in[i][11:5], p8, d_in[i][4:2], p4, d_in[i][1], p2, p1, p0};
        $displayb(d_calc);

        d_out = {DUT.mem.core[31 + 2*i], DUT.mem.core[30 + 2*i]};
        $displayb(d_out);

        if (d_out == d_calc) begin
            $display("We have a match!");
            score++;
        end else begin
            $display("Incorrect output");
        end

        $display();
        total++;
    end

    $display("Program 1 score = %d out of %d", score, total);

    #10ns $stop;
end

always begin
    #5ns clk = 1;
    #5ns clk = 0;
end

endmodule