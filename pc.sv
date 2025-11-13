module pc (
    input  logic        clk,
    input  logic        rst,
    input  logic        taken,
    input  logic [31:0] target,
    output logic [31:0] pc
);

  always_ff @(posedge clk or posedge rst)
    if (rst) pc <= 32'b0;
    else if (taken) pc <= target;
    else pc <= pc + 32'd4;

endmodule
