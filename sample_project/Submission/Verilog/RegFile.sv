// cache memory/register file
// 4 pairs of registers
//
// registers are organized into pairs as such:
// 000 & 001 - first pair
// 010 & 011 - second pair
// 100 & 101 - third pair
// 110 & 111 - fourth pair
//
// given a 2-bit pair address AA:
// the pair's primary flag, F, is parity[AA]
// the primary register's address is AAF
// the secondary register's address is AAS, where S = F ^ 1
module RegFile (
	input      	clk,
	
	input[7:0]	dataIn,
	input 		writeEnable,	// write enable
	input		regPair,		// write to pairA secondary
	input[1:0] 	updatePair,		// flag to update pairA parity
	input[1:0] 	addrA,			// pair pointers
				addrB,

	output logic[7:0] dataOutA,
					dataOutB
);

	logic[7:0] 	core[8];		// 8 registers
	logic		parity[4];		// pair parities

	logic[2:0] readIndexA, readIndexB, writeIndex;
	
	always_comb begin
		// standard behavior: read indices A and B are the primary registers of the addrA and addrB pairs
		// if addrA = addrB, the secondary read index becomes the secondary register of the targeted pair
		// if the regPair flag is set, the write index becomes the secondary register of the A pair;
		// otherwise, it is the primary
		readIndexA = addrA*2 + parity[addrA];
		readIndexB = addrB*2 + (parity[addrB] ^ (addrA == addrB));
		writeIndex = addrA*2 + (parity[addrA] ^ regPair);
		

		// reads are combinational
		dataOutA = core[readIndexA];
		dataOutB = core[readIndexB];
	end

	// writes are sequential (clocked)
	always_ff @(posedge clk) begin
		if(writeEnable)			// anything but stores or no ops
			core[writeIndex] <= dataIn;
		if(updatePair[1])		// need to update pair parity?
			parity[addrA] <= updatePair[0];
	end
endmodule