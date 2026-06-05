module TopLevel (
    input           clk, reset,
    output logic    done
);

    /**** Program ****/
    parameter D = 10; // PC width

    wire[D-1:0] programCtr;
    wire[8:0] machineCode;

    /**** Register File ****/
    //input
    wire[1:0] addrA, addrB;
    wire[3:0] immValue;
    wire        regImm,
                regWrite,
                regPair;
    wire[1:0]   updateReg;

    // output
    wire[7:0] regDataA, regDataB;

    /**** ALU ****/
    // input
    wire[4:0] aluOp;
    logic carryIn;

    // state flags
    logic lessThan, equal, zero;

    // output
    wire[7:0] aluResult;
    wire carryOut;
    wire    updateFlags,
            lessThanN,
            equalN, zeroN;

    /**** Data Memory ****/
    wire memRead, memWrite;
    wire[7:0] memData;

    /**** Control ****/
    wire[6:0] controlInstr;

    wire[1:0] branch;
    wire[2:0] branchCond;

    /**** MUXes ****/
    wire[7:0] regWriteData;

    /**** Assigns ****/
    assign controlInstr = machineCode[8:2];
    assign addrA = machineCode[1:0];
    assign addrB = machineCode[3:2];
    assign immValue = machineCode[5:2];

    assign regWriteData = regImm ? {regDataA[7:4], immValue} : (memRead ? memData : aluResult);

    /**** Modules ****/

    PC #(.D(D)) pc (
        .clk,
        .reset,
        .branch,
        .branchCond,
        .branchValue (regDataA),
        .lessThan,
        .equal,
        .zero,

        .programCtr(programCtr)
    );

    InstructionROM #(.D(D)) rom (
        .programCtr,
        .machineCode
    );

    Control ctrl (
        .instr(controlInstr),
        .regImm,
        .regWrite,
        .regPair,
        .updateReg,
        .memRead,
        .memWrite,
        .aluOp,
        .branch,
        .branchCond,
        .done
    );

    RegFile regs (
        .clk,
        .dataIn(regWriteData),
        .writeEnable(regWrite),
        .regPair,
        .updatePair(updateReg),
        .addrA,
        .addrB,
        .dataOutA(regDataA),
        .dataOutB(regDataB)
    );

    ALU #(.D(D)) alu (
        .aluOp,
        .inA(regDataA),
        .inB(regDataB),
        .carryIn,
        .programCtr,
        .result(aluResult),
        .carryOut,
        .lessThan(lessThanN),
        .equal(equalN),
        .zero(zeroN),
        .update(updateFlags)
    );

    DataMem mem (
        .clk,
        .dataIn(regDataA),
        .writeEnable(memWrite),
        .addr(aluResult),
        .dataOut(memData)
    );


    /**** ALU flags ****/
    always_ff @(posedge clk) begin
        carryIn <= carryOut;
        if (updateFlags) begin
            lessThan <= lessThanN;
            equal <= equalN;
            zero <= zeroN;
        end
    end

endmodule