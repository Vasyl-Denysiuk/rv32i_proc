module alu (
    input  logic [ 3:0] ctl,
    input  logic [31:0] in_1,
    input  logic [31:0] in_2,
    output logic [31:0] out,
    output logic        zero,
    output logic        carry,
    output logic        overflow,
    output logic        sign
);

  logic [ 4:0] shamt = in_2[4:0];
  logic [32:0] sum;
  logic [32:0] diff;

  always_comb begin
    carry = 0;
    overflow = 0;
    case (ctl)
      4'b0000: begin
        sum = {1'b0, in_1} + {1'b0, in_2};
        out = sum[31:0];
        carry = sum[32];
        overflow = (in_1[31] == in_2[31]) && (out[31] != in_1[31]);
      end
      4'b1000: begin
        diff = {1'b0, in_1} - {1'b0, in_2};
        out = diff[31:0];
        carry = diff[32];
        overflow = (in_1[31] != in_2[31]) && (out[31] != in_1[31]);
      end
      4'b0001: out = in_1 << shamt;
      4'b0010: out = $signed(in_1) < $signed(in_2) ? 1 : 0;
      4'b0011: out = in_1 < in_2 ? 1 : 0;
      4'b0100: out = in_1 ^ in_2;
      4'b0101: out = in_1 >> shamt;
      4'b0110: out = in_1 | in_2;
      4'b0111: out = in_1 & in_2;
      4'b1101: out = $signed(in_1) >>> shamt;
      // LUI - pass through
      4'b1111: out = in_2;
      default: out = 0;
    endcase
    zero = (out == 32'b0);
    sign = out[31];
  end
endmodule
