module pc (
    input  logic        clk,
    input  logic        rst,
    input  logic        sel,
    input  logic [31:0] pc_rel,
    output logic [31:0] pc
);

  always_ff @(posedge clk or posedge rst)
    if (rst) pc <= 32'b0;
    else if (sel) pc <= pc + pc_rel;
    else pc <= pc + 32'd4;

endmodule
