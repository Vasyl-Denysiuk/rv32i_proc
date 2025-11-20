module pc #(
    parameter logic [31:0] INITIAL_PC = 32'b0
) (
    input  logic        rst,
    input  logic        clk,
    input  logic        stall,
    input  logic        taken,
    input  logic [31:0] target,
    output logic [31:0] pc_out
);

  always_ff @(posedge clk)
    if (rst) pc_out <= INITIAL_PC;
    else if (taken) pc_out <= target;
    else if (~stall) pc_out <= pc_out + 32'd4;

endmodule
