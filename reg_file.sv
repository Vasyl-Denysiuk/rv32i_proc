module reg_file (
    input  logic        clk,
    input  logic [ 4:0] rs1_num,
    input  logic [ 4:0] rs2_num,
    input  logic [ 4:0] rd_num,
    input  logic [31:0] data,
    input  logic        write,
    output logic [31:0] rs1,
    output logic [31:0] rs2
);

  logic [31:0] registers[1:31];  // x1-x31 register, x0 is asserted to 0

  assign rs1 = (rs1_num == 0) ? 32'b0 : registers[rs1_num];
  assign rs2 = (rs2_num == 0) ? 32'b0 : registers[rs2_num];

  always_ff @(posedge clk) if (write && rd_num != 0) registers[rd_num] <= data;

endmodule
