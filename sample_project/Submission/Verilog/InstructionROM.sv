// machine code lookup table
// 9 bits wide; as deep as you wish
module InstructionROM #(parameter D=10) (
	input[D-1:0] programCtr,
	output logic[8:0] machineCode
);

	// this field should be populated by the test bench
	logic[8:0] core[2**D];

	always_comb begin
		machineCode = core[programCtr];
	end

endmodule