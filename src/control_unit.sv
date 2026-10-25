import pkg::*;

module control_unit (
    input  logic            [6:0] funct7,
    input  logic            [2:0] funct3,
    input  pkg::opcode_t          opcode,
    output pkg::alu_op_t          alu_op,
    output pkg::operand_a_t       alu_in1,
    output pkg::operand_b_t       alu_in2,
    output pkg::branch_t          branch,
    output logic                  jalr,
    output logic                  mem_read,
    output logic                  mem_write,
    output logic                  reg_write,
    output logic                  mem_to_reg,
    output logic            [1:0] mem_size,      // 00=byte, 01=halfword, 10=word
    output logic                  mem_unsigned,  // 1=unsigned, 0=signed
    output logic                  trap           // illegal instruction, ECALL or EBREAK
);

  always_comb begin
    alu_op       = ADD;
    alu_in1      = RS1;
    alu_in2      = RS2;
    branch       = NO_CF;
    jalr         = 0;
    mem_read     = 0;
    mem_write    = 0;
    reg_write    = 0;
    mem_to_reg   = 0;
    mem_size     = 2'b10;
    mem_unsigned = 0;
    trap         = 0;

    case (opcode)
      REG_OP: begin
        reg_write = 1;
        alu_op    = decode_alu(funct3, funct7[5]);
        // funct7 must be 0, except 0100000 for SUB and SRA
        if (funct7 != 7'b0000000 && !(funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101)))
          trap = 1;
      end

      IMM_OP: begin
        reg_write = 1;
        alu_in2   = IMM;
        // special case for SLLI, SRAI, and SRLI
        if (funct3 == 3'b001 || funct3 == 3'b101) alu_op = decode_alu(funct3, funct7[5]);
        else alu_op = decode_alu(funct3, 1'b0);
        // shamt is 5 bits, the rest of funct7 must be 0 or 0100000 for SRAI
        if (funct3 == 3'b001 && funct7 != 7'b0000000) trap = 1;
        if (funct3 == 3'b101 && funct7 != 7'b0000000 && funct7 != 7'b0100000) trap = 1;
      end

      LOAD: begin
        reg_write  = 1;
        alu_in2    = IMM;
        mem_read   = 1;
        mem_to_reg = 1;
        {mem_unsigned, mem_size} = funct3;
        if (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111) trap = 1;
      end

      STORE: begin
        alu_in2   = IMM;
        mem_write = 1;
        mem_size  = funct3[1:0];
        if (funct3[2] || funct3 == 3'b011) trap = 1;
      end

      BRANCH: begin
        branch = decode_branch(funct3);
        alu_op = SUB;
        if (funct3 == 3'b010 || funct3 == 3'b011) trap = 1;
      end

      JAL: begin
        reg_write = 1;
        alu_in1   = PC;
        alu_in2   = STEP;
        branch    = JUMP;
      end

      JALR: begin
        reg_write = 1;
        alu_in1   = PC;
        alu_in2   = STEP;
        branch    = JUMP;
        jalr      = 1;
        if (funct3 != 3'b000) trap = 1;
      end

      LUI: begin
        reg_write = 1;
        alu_in2 = IMM;
        alu_op = PASS_B;
      end

      AUIPC: begin
        reg_write = 1;
        alu_in1   = PC;
        alu_in2   = IMM;
      end

      // FENCE is NOP for in-order core
      MISC_MEM: if (funct3 != 3'b000) trap = 1;

      // ECALL and EBREAK trap
      SYSTEM: trap = 1;

      default: trap = 1;
    endcase

    if (trap) begin
      branch    = NO_CF;
      mem_read  = 0;
      mem_write = 0;
      reg_write = 0;
    end
  end

endmodule
