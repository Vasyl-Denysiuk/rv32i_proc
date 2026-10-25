import pkg::*;

module alu (
    input  pkg::alu_op_t            ctl,
    input  logic         [XLEN-1:0] in_1,
    input  logic         [XLEN-1:0] in_2,
    output logic         [XLEN-1:0] out,
    output logic                    zero,
    output logic                    borrow,
    output logic                    overflow,
    output logic                    sign
);

  logic [$clog2(XLEN)-1:0] shamt;
  logic [XLEN:0] sum;
  logic [XLEN:0] diff;

  assign shamt = in_2[$clog2(XLEN)-1:0];

  always_comb begin
    sum      = '0;
    diff     = '0;
    out      = '0;
    borrow   = 0;
    overflow = 0;
    case (ctl)
      ADD: begin
        sum = {1'b0, in_1} + {1'b0, in_2};
        out = sum[XLEN-1:0];
        overflow = (in_1[XLEN-1] == in_2[XLEN-1]) && (out[XLEN-1] != in_1[XLEN-1]);
      end
      SUB: begin
        diff = {1'b0, in_1} - {1'b0, in_2};
        out = diff[XLEN-1:0];
        borrow = diff[XLEN];
        overflow = (in_1[XLEN-1] != in_2[XLEN-1]) && (out[XLEN-1] != in_1[XLEN-1]);
      end
      SLL: out = in_1 << shamt;
      SLT: out = $signed(in_1) < $signed(in_2) ? 1 : 0;
      SLTU: out = in_1 < in_2 ? 1 : 0;
      XOR: out = in_1 ^ in_2;
      SRL: out = in_1 >> shamt;
      OR: out = in_1 | in_2;
      AND: out = in_1 & in_2;
      SRA: out = $signed(in_1) >>> shamt;
      PASS_B: out = in_2;
      default: ;
    endcase
    zero = (out == '0);
    sign = out[XLEN-1];
  end
endmodule
