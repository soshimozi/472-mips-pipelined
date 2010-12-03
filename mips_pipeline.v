//-----------------------------------------------------------------------------
// Title         : MIPS Pipelined Processor
// Project       : ECE 313 - Computer Organization
//-----------------------------------------------------------------------------
// File          : mips_single.v
// Author        : John Nestor  <nestorj@lafayette.edu>
// Organization  : Lafayette College
//
// Created       : October 2002
// Last modified : 7 January 2005
//-----------------------------------------------------------------------------
// Description :
//   Pipelined implementation of the MIPS processor subset described in
//   Section 6.3 of "Computer Organization and Design, 3rd ed."
//   by David Patterson & John Hennessey, Morgan Kaufmann, 2004 (COD3e).
//
//   It implements the equivalent of Figure 6.27 on page 404 of COD3e
//
//-----------------------------------------------------------------------------

module mips_pipeline(clk, reset);
input clk, reset;

    // ********************************************************************
    //                              Signal Declarations
    // ********************************************************************

    // IF Signal Declarations

    // MODIFICATIONS HERE:
    // Add a new wire between the jump and branch muxes
    wire [31:0] IF_instr, IF_pc, IF_pc_jump, IF_pc_next, IF_pc4;

    // ID Signal Declarations

    reg [31:0] ID_instr, ID_pc4;  // pipeline register values from EX

    wire [5:0] ID_op, ID_funct;
    wire [4:0] ID_rs, ID_rt, ID_rd;
    wire [15:0] ID_immed;
    wire [31:0] ID_extend, ID_rd1, ID_rd2;
    wire [31:0] ID_jaddr;

    assign ID_op = ID_instr[31:26];
    assign ID_rs = ID_instr[25:21];
    assign ID_rt = ID_instr[20:16];
    assign ID_rd = ID_instr[15:11];
    assign ID_immed = ID_instr[15:0];

    wire ID_RegWrite, ID_Branch, ID_RegDst, ID_MemtoReg,  // ID Control signals
         ID_MemRead, ID_MemWrite, ID_ALUSrc, ID_Jump;
    wire [1:0] ID_ALUOp;

    // EX Signals

    reg  [31:0] EX_pc4, EX_extend, EX_rd1, EX_rd2;
    wire [31:0]  EX_offset, EX_btgt, EX_alub, EX_ALUOut;
    reg  [4:0]  EX_rt, EX_rd;
    wire [4:0]  EX_RegRd;
    wire [5:0] EX_funct;

    reg  EX_RegWrite, EX_Branch, EX_RegDst, EX_MemtoReg,  // EX Control Signals
         EX_MemRead, EX_MemWrite, EX_ALUSrc;

    wire EX_Zero;

    reg  [1:0] EX_ALUOp;
    wire [2:0] EX_Operation;

   // MEM Signals

    wire MEM_PCSrc;

    reg  MEM_RegWrite, MEM_Branch, MEM_MemtoReg,
         MEM_MemRead, MEM_MemWrite, MEM_Zero;

    reg  [31:0] MEM_btgt, MEM_ALUOut, MEM_rd2;
    wire [31:0] MEM_memout;
    reg  [5:0] MEM_RegRd;

    // WB Signals

    reg WB_RegWrite, WB_MemtoReg;  // WB Control Signals

    reg  [31:0] WB_memout, WB_ALUOut;
    wire [31:0] WB_wd;
    reg  [4:0] WB_RegRd;

    // ********************************************************************
    //                              IF Stage
    // ********************************************************************

    // IF Hardware

    reg32		IF_PC(clk, reset, IF_pc_next, IF_pc);

    add32 		IF_PCADD(IF_pc, 32'd4, IF_pc4);

    // MODIFICATIONS HERE:
    // Use the jump target from the ID stage if that was a jump
    mux2 #(32)  IF_JMPMUX(ID_Jump, IF_pc4, ID_jaddr, IF_pc_jump);

    // MODIFICATIONS HERE:
    // Use the branch target from the MEM stage if that was a branch
    // (Note: the branch has priority over the jump, since that instruction came first)
    mux2 #(32)	IF_PCMUX(MEM_PCSrc, IF_pc_jump, MEM_btgt, IF_pc_next);

    rom32 		IMEM(IF_pc, IF_instr);

    always @(posedge clk)		    // IF/ID Pipeline Register
    begin
        if (reset)
        begin
            ID_instr <= 0;
            ID_pc4   <= 0;
        end
        else begin
            // MODIFICATIONS HERE:
            // Flush the loaded instruction to take the jump instead
            if (ID_Jump)
                ID_instr <= 0;
            else
                ID_instr <= IF_instr;
            ID_pc4   <= IF_pc4;
        end
    end

    // ********************************************************************
    //                              ID Stage
    // ********************************************************************

    reg_file	RFILE(clk, WB_RegWrite, ID_rs, ID_rt, WB_RegRd, ID_rd1, ID_rd2, WB_wd);

    // sign-extender
    assign ID_extend = { {16{ID_immed[15]}}, ID_immed };

    // MODIFICATIONS HERE:
    // Calculate the jump address from the incremented PC and the jump offset
    assign ID_jaddr = {ID_pc4[31:28], ID_instr[25:0], 2'b00};


    control_pipeline CTL(.opcode(ID_op), .RegDst(ID_RegDst),
                       .ALUSrc(ID_ALUSrc), .MemtoReg(ID_MemtoReg),
                       .RegWrite(ID_RegWrite), .MemRead(ID_MemRead),
                       .MemWrite(ID_MemWrite), .Branch(ID_Branch),
                       .ALUOp(ID_ALUOp), .Jump(ID_Jump));


    always @(posedge clk)		    // ID/EX Pipeline Register
    begin
        if (reset)
        begin
            // MODIFICATIONS HERE:
            // Remove redundant assignments
            EX_RegDst   <= 0;
            EX_ALUOp    <= 0;
            EX_ALUSrc   <= 0;
            EX_Branch   <= 0;
            EX_MemRead  <= 0;
            EX_MemWrite <= 0;
            EX_RegWrite <= 0;
            EX_MemtoReg <= 0;

            EX_pc4      <= 0;
            EX_rd1      <= 0;
            EX_rd2      <= 0;
            EX_extend   <= 0;
            EX_rt       <= 0;
            EX_rd       <= 0;
        end
        else begin
            // MODIFICATIONS HERE:
            // Remove redundant assignments
            EX_RegDst   <= ID_RegDst;
            EX_ALUOp    <= ID_ALUOp;
            EX_ALUSrc   <= ID_ALUSrc;
            EX_Branch   <= ID_Branch;
            EX_MemRead  <= ID_MemRead;
            EX_MemWrite <= ID_MemWrite;
            EX_RegWrite <= ID_RegWrite;
            EX_MemtoReg <= ID_MemtoReg;

            EX_pc4      <= ID_pc4;
            EX_rd1      <= ID_rd1;
            EX_rd2      <= ID_rd2;
            EX_extend   <= ID_extend;
            EX_rt       <= ID_rt;
            EX_rd       <= ID_rd;
        end
    end

    // ********************************************************************
    //                              EX Stage
    // ********************************************************************

    // branch offset shifter
    assign EX_offset = EX_extend << 2;

    assign EX_funct = EX_extend[5:0];

    add32 		EX_BRADD(EX_pc4, EX_offset, EX_btgt);

    wire [31:0] MuxA_out, MuxB_out;

    // MODIFICATIONS HERE:
    // Muxes to select forwarded values
    // If ForwardX:
    //     00 -> value from ID/EX
    //     01 -> value from MEM/WB
    //     10 -> value from EX/WB
    mux3 #(32)  FMUXA(ForwardA, EX_rd1, WB_wb, MEM_ALUOut, MuxA_out);
    mux3 #(32)  FMUXB(ForwardB, EX_rd2, WB_wb, MEM_ALUOut, MuxB_out);

    // MODIFICATIONS HERE:
    // Take the output from FMUXB instead of directly from ID/EX
    mux2 #(32) 	ALUMUX(EX_ALUSrc, MuxB_out, EX_extend, EX_alub);

    // MODIFICATIONS HERE:
    // Take the output from FMUXA instead of directly from ID/EX
    alu 		EX_ALU(EX_Operation, MuxA_out, EX_alub, EX_ALUOut, EX_Zero);

    mux2 #(5) 	EX_RFMUX(EX_RegDst, EX_rt, EX_rd, EX_RegRd);

    alu_ctl 	EX_ALUCTL(EX_ALUOp, EX_funct, EX_Operation);

    always @(posedge clk)		    // EX/MEM Pipeline Register
    begin
        if (reset)
        begin
            MEM_Branch   <= 0;
            MEM_MemRead  <= 0;
            MEM_MemWrite <= 0;
            MEM_RegWrite <= 0;
            MEM_MemtoReg <= 0;
            MEM_Zero     <= 0;

            MEM_btgt     <= 0;
            MEM_ALUOut   <= 0;
            MEM_rd2      <= 0;
            MEM_RegRd    <= 0;
        end
        else begin
            MEM_Branch   <= EX_Branch;
            MEM_MemRead  <= EX_MemRead;
            MEM_MemWrite <= EX_MemWrite;
            MEM_RegWrite <= EX_RegWrite;
            MEM_MemtoReg <= EX_MemtoReg;
            MEM_Zero     <= EX_Zero;

            MEM_btgt     <= EX_btgt;
            MEM_ALUOut   <= EX_ALUOut;
            MEM_rd2      <= EX_rd2;
            MEM_RegRd    <= EX_RegRd;
        end
    end

    // ********************************************************************
    //                              MEM Stage
    // ********************************************************************

    mem32 		MEM_DMEM(clk, MEM_MemRead, MEM_MemWrite, MEM_ALUOut, MEM_rd2, MEM_memout);

    and  		MEM_BR_AND(MEM_PCSrc, MEM_Branch, MEM_Zero);

    always @(posedge clk)		// MEM/WB Pipeline Register
    begin
        if (reset)
        begin
            WB_RegWrite <= 0;
            WB_MemtoReg <= 0;
            WB_ALUOut   <= 0;
            WB_memout   <= 0;
            WB_RegRd    <= 0;
        end
        else begin
            WB_RegWrite <= MEM_RegWrite;
            WB_MemtoReg <= MEM_MemtoReg;
            WB_ALUOut   <= MEM_ALUOut;
            WB_memout   <= MEM_memout;
            WB_RegRd    <= MEM_RegRd;
        end
    end

    // ********************************************************************
    //                              WB Stage
    // ********************************************************************

    mux2 #(32)	WB_WRMUX(WB_MemtoReg, WB_ALUOut, WB_memout, WB_wd);


endmodule

