import pkg::*;

module pc #(
    parameter logic [XLEN-1:0] INITIAL_PC = '0
) (
    input  logic            rst_n,
    input  logic            clk,
    input  logic            stall,
    input  logic            taken,
    input  logic [XLEN-1:0] target,
    output logic [XLEN-1:0] pc,
    output logic [XLEN-1:0] next_pc
);
  assign next_pc = !rst_n ? INITIAL_PC : taken ? target : stall ? pc : pc + XLEN'(4);
  always_ff @(posedge clk) pc <= next_pc;
endmodule
