module control_unit (
    input  logic [6:0] funct7,
    input  logic [2:0] funct3,
    input  logic [6:0] opcode,
    output logic [3:0] alu_op,
    output logic [1:0] alu_in2,      // 00=rs2, 01=imm, 10=4
    output logic       alu_in1,      // 0=rs1, 1=pc
    output logic [2:0] branch,
    output logic       jalr,
    output logic       mem_read,
    output logic       mem_write,
    output logic       reg_write,
    output logic       mem_to_reg,
    output logic [1:0] mem_size,     // 00=byte, 01=halfword, 10=word
    output logic       mem_unsigned  // 1=unsigned, 0=signed
);

  always_comb begin
    alu_op       = 4'b0000;
    alu_in1      = 0;
    alu_in2      = 2'b00;
    branch       = 3'b010;
    jalr         = 0;
    mem_read     = 0;
    mem_write    = 0;
    reg_write    = 0;
    mem_to_reg   = 0;
    mem_size     = 2'b10;
    mem_unsigned = 0;


    unique case (opcode)  // pragma full_case
      7'b0110011: begin  // R-R A/L ops
        reg_write = 1;
        alu_op    = {funct7[5], funct3};
      end

      7'b0010011: begin  // R-I A/L ops
        reg_write = 1;
        alu_in2   = 2'b01;
        // special case for SLLI, SRAI, and SRLI
        if (funct3 == 3'b001 || funct3 == 3'b101) alu_op = {funct7[5], funct3};
        else alu_op = {1'b0, funct3};
      end

      7'b0000011: begin  // Load
        reg_write  = 1;
        alu_in2    = 2'b01;
        mem_read   = 1;
        mem_to_reg = 1;
        {mem_unsigned, mem_size} = funct3;
      end

      7'b0100011: begin  // Store
        alu_in2   = 2'b01;
        mem_write = 1;
        mem_size  = funct3[1:0];
      end

      7'b1100011: begin  // Branch
        branch = funct3;
        alu_op = 4'b1000;  // SUB
      end

      7'b1101111: begin  // JAL
        reg_write = 1;
        alu_in1   = 1;
        alu_in2   = 2'b10;
        branch    = 3'b011;
      end

      7'b1100111: begin  // JALR
        reg_write = 1;
        alu_in1   = 1;
        alu_in2   = 2'b10;
        branch    = 3'b011;
        jalr      = 1;
      end

      7'b0110111: begin  // LUI
        reg_write = 1;
        alu_in2 = 2'b01;
        alu_op = 4'b1111;
      end

      7'b0010111: begin  // AUIPC
        reg_write = 1;
        alu_in1   = 1;
        alu_in2   = 2'b01;
      end
    endcase
  end

endmodule
