// 8-bit wide, 256-word (byte) deep memory array
module DataMem (
	input      clk,
	
	input[7:0] dataIn,	// data to write, if enabled
	input      writeEnable,
	input[7:0] addr,	// read/write address
  
	output logic [7:0] dataOut
);

	logic[7:0] core[256]; // 2-dim array  8 wide  256 deep

	// reads are combinational; no enable or clock required
	assign dataOut = core[addr];

	// writes are sequential (clocked) -- occur on stores
	always_ff @(posedge clk) begin
		if (writeEnable)
			core[addr] <= dataIn;
	end
endmodule