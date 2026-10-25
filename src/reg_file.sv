import pkg::*;

module reg_file (
    input  logic                    clk,
    input  logic [REGFILE_BITS-1:0] rs1_num,
    input  logic [REGFILE_BITS-1:0] rs2_num,
    input  logic [REGFILE_BITS-1:0] rd_num,
    input  logic [        XLEN-1:0] data,
    input  logic                    wb,
    output logic [        XLEN-1:0] rs1,
    output logic [        XLEN-1:0] rs2
);

  logic [XLEN-1:0] registers[0:2**REGFILE_BITS-1];

  assign rs1 = (rs1_num == 0) ? 32'b0 : (wb && rd_num == rs1_num) ? data : registers[rs1_num];
  assign rs2 = (rs2_num == 0) ? 32'b0 : (wb && rd_num == rs2_num) ? data : registers[rs2_num];

  always_ff @(posedge clk) if (wb && rd_num != 0) registers[rd_num] <= data;

endmodule
