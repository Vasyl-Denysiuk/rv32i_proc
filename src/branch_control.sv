import pkg::*;

module branch_control (
    input  pkg::branch_t branch,
    input  logic         zero,
    input  logic         sign,
    input  logic         borrow,
    input  logic         overflow,
    output logic         taken
);

  always_comb
    case (branch)
      BEQ: taken = zero ? 1 : 0;
      BNE: taken = zero ? 0 : 1;
      BLT: taken = sign ^ overflow;
      BGE: taken = ~(sign ^ overflow);
      BLTU: taken = borrow;
      BGEU: taken = ~borrow;
      JUMP: taken = 1;
      default: taken = 0;
    endcase

endmodule
