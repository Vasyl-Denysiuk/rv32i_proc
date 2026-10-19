import pkg::*;
module branch_gen (
    input  logic [XLEN-1:0] pc,
    input  logic [XLEN-1:0] imm,
    input  logic [XLEN-1:0] rs1,
    input  logic            is_jalr,
    output logic [XLEN-1:0] target
);
  // All jumps and branches except jalr are pc-relative
  assign target = is_jalr ? (rs1 + imm) & ~XLEN'(1) : (pc + imm);

endmodule
