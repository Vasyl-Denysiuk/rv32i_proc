module imm_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm
);

  logic [6:0] opcode = instr[6:0];

  always_comb
    unique case (opcode)
      // I-type imm
      7'b0000011, 7'b0010011, 7'b1100111: imm = {{21{instr[31]}}, instr[30:20]};
      // S-type
      7'b0100011: imm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
      // B-type
      7'b1100011: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
      // U-type
      7'b0110111, 7'b0010111: imm = {instr[31:12], 12'b0};
      // J-type
      7'b1101111: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    endcase

endmodule

