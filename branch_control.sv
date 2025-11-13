module branch_control (
    input  logic [2:0] branch,
    input  logic       zero,
    input  logic       carry,
    input  logic       sign,
    input  logic       overflow,
    output logic       taken
);

  always_comb
    case (branch)
      3'b000:  taken = zero ? 1 : 0;
      3'b001:  taken = zero ? 0 : 1;
      3'b100:  taken = sign ^ overflow;
      3'b101:  taken = ~(sign ^ overflow);
      3'b110:  taken = ~carry;
      3'b111:  taken = carry;
      3'b011:  taken = 1;  // use for jumps
      default: taken = 0;
    endcase

endmodule
