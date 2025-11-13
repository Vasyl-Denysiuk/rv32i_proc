module branch_gen (
    input  logic [31:0] pc,
    input  logic [31:0] imm,
    input  logic [31:0] rs1,
    input  logic        jalr,
    output logic [31:0] target
);
  // All jumps and branches except jalr are pc-relative
  always_comb target = jalr ? (rs1 + imm) : (pc + imm);


endmodule
