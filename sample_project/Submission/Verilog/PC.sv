// program counter
// supports both relative and absolute jumps
// use either or both, as desired
module PC #(parameter D=10)(
	input 		clk,
				reset,
			
	input[1:0] 	branch,		// 00 = no branch, 01 = relative inc, 10 = relative dec, 11 = absolute
	input[2:0] 	branchCond,
	input[7:0] 	branchValue,
	
	input 		lessThan,
				equal, zero,
	
	output logic[D-1:0] programCtr
);

	logic condMet;
	
	always_comb begin
		condMet = 'b0;
		
		case (branchCond)
			'b000: condMet = 'b1; // always
			'b001: condMet = equal; // equal
			'b010: condMet = !equal; // not equal
			'b011: condMet = (!lessThan && !equal); // greater than
			'b100: condMet = lessThan;	// less than
			'b101: condMet = !lessThan; // greater than or equal
			'b110: condMet = (lessThan || equal); // less than or equal
			'b111: condMet = zero; // zero
		endcase
	end
	
	always_ff @(posedge clk) begin
		if (reset) begin
			programCtr <= 'b0;
		end else begin
			if (branch != 'b0 && condMet) begin
				case (branch)
					'b01: programCtr <= programCtr - branchValue;
					'b10: programCtr <= programCtr + branchValue;
					'b11: programCtr <= (branchValue << 2); // left shift because regs are 8 bits, PC is 10
				endcase
			
			end else begin
				programCtr <= programCtr + 'b1;
			end
		end
	end

endmodule