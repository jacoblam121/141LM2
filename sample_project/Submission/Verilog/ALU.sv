// combinational -- no clock
// 
//	ALU OP FORMAT: 5'bT_CCC_F
// T represents instruction type (R=0, D=1)
// C represents instruction opcode
// F represents instruction flag 
// flag may be ignored by ALU depending on instruction
//
// D parameter represents PC width
module ALU #(parameter D=10) (
  input[4:0] 	aluOp,		// ALU instructions
  input[7:0] 	inA, inB,	// 8-bit wide data path
  input      	carryIn,	// carry in value
  input[D-1:0] 	programCtr,	// current program counter
  
  output logic[7:0] result,

  output logic carryOut,	// ALU flags
				lessThan,
				equal, zero,
				update
);

	always_comb begin
		result = 'b0;
		carryOut = carryIn;
		
		update = 'b0;
		lessThan = 'b0;
		equal = 'b0;
		zero = 'b0;
		
		casez (aluOp)
			/* R type */
			5'b0_000_?:		// ADD(I)
				{carryOut, result} = inA + inB;
			5'b0_001_?:		// SUB(I)
				{carryOut, result} = inA - inB;
			5'b0_010_?:		// CPY
				result = inB;	// CPY takes value B reg, stores in A reg
			5'b0_011_?:		// AND(I)
				result = inA & inB;
			5'b0_100_?:		// OR(I)
				result = inA | inB;
			5'b0_101_?:		// XOR(I)
				result = inA ^ inB;
			5'b0_110_0:	begin	// CMP
				update = 'b1;
				lessThan = (inA < inB);
				equal = (inA == inB);
				zero = (inA == 'b0);
			end
			5'b0_110_1:		// CMPR
				update = 'b1;
			5'b0_111_?:		// LDM/STM
				result = inB; // LDM and STM use inB as mem address
			
			/* D type */
			5'b1_000_0:		// SSL
				result = (inA << 1);
			5'b1_000_1:		// SLLC
				{carryOut, result} = {inA, carryIn};
			5'b1_001_0:		// SSR
				result = (inA >> 1);
			5'b1_001_1:		// SSRC
				{result, carryOut} = {carryIn, inA};
			5'b1_010_0:		// HSL
				result = (inA << 4);
			5'b1_010_1:		// HSR
				result = (inA >> 4);
			5'b1_011_0:		// INC
				result = (inA + 'b1);
			5'b1_011_1:		// DEC
				result = (inA - 'b1);
			5'b1_100_?:		// SPC
				result = programCtr[D-1:D-8]; // first 8 bits of PC
			5'b1_101_0:		// CLR
				result = 'b0;
			5'b1_101_1:		// XORB
				carryOut = ^inA;
			//5'b1_110_?:	// PRME/PRMO
			//5'b1_111_1:	// NOP
		endcase
	end
endmodule