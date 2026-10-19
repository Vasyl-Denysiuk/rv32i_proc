import pkg::*;

module instr_mem #(
    parameter DEPTH = 1024
) (
    input logic clk,
    input logic [XLEN-1:0] addr,
    output logic [XLEN-1:0] instr
);

  logic [XLEN-1:0] ram[DEPTH];
  logic [$clog2(DEPTH)-1:0] r_addr;

  assign r_addr = addr[XLEN-1:$clog2(XLEN/8)];

  initial begin
    $readmemh("program.hex", ram);
  end

  always @(posedge clk) instr <= ram[r_addr];

endmodule
