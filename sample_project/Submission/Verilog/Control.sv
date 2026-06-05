// control decoder
module Control (
	input [6:0] 	instr,	// first 7 bits of machine code
	
	output logic 	regImm,
					regWrite,
					regPair,
	output logic[1:0] updateReg,
	
	output logic	memRead,
					memWrite,
							
	output logic[4:0] aluOp,
	
	output logic[1:0] branch,
	output logic[2:0] branchCond,

	output logic done
);

	always_comb begin
		//default values
		regImm = 'b0;		// 1 = read immediate value from instr
		regWrite = 'b0;		// 1 = write to file
		regPair = 'b0;		// 1 = swap primary/secondary when writing to pair
		updateReg = 'b0;	// 1X = set parity to X
		
		memRead = 'b0;		// 0 = reg write data is from ALU ; 1 = data is from mem
		memWrite = 'b0;		// 1 = write to mem
		aluOp = 'b1_111_1;	// 5 bit ALU opcode - default value is NOP
		
		branch = 'b0;		// 00 = no branch, 01 = relative inc, 10 = relative dec, 11 = absolute
		branchCond = 'b0;	// 3 bit branch condition
		done = 'b0;			// flag for program completion
		
		// separate into instr types
		casez (instr[6:4])
			/* R type: 0_CCC_F_RR - C=opcode, F=flag, R=reg */
			'b0_??: begin
				aluOp = instr[6:2]; // 0_CCC_F
				
				if (instr[5:3] == 'b111) begin // LDM/STM
					regWrite = !instr[2]; // enable write for load, disable for store
					
					memRead = !instr[2]; // enable mem read for load, disable for store
					memWrite = instr[2]; // enable mem write for store, disable for load
				end else if (instr[5:3] != 'b110) begin // all but CMP(R)
					regWrite = 'b1; // enable write
					regPair = instr[2]; // set pair flag
				end
			end
			
			/* B type: 10_BB_CCC - B=func, C=cond */
			'b10_?: begin
				branch = (instr[4:3] + 1); // this will overflow to 0 for the EXIT instr, which is fine
				branchCond = instr[2:0];
				
				if (instr[4:3] == 'b11) // EXIT
					done = 'b1;
			end
			
			/* D type: 110_CCC_F - C=opcode, F = flag */
			'b110: begin
				aluOp = {1'b1, instr[3:0]}; // 1_CCC_F
				
				if (instr[3:1] == 'b110) // PRME/PRMO
					updateReg = {1'b1, instr[0]}; // 1_F
				else if (instr[3:0] <= 'b1010) // excludes XORB, NOP
					regWrite = 'b1;
			end
			
			/* I type: 111_IIII - I=immediate value */
			'b111: begin
				regWrite = 'b1;
				regImm = 'b1;
			end
		endcase
	end
	
endmodule