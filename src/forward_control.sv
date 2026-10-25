import pkg::*;

module forward_control (
    input  logic          [REGFILE_BITS-1:0] idex_rs1,
    input  logic          [REGFILE_BITS-1:0] idex_rs2,
    input  logic                             exmem_reg_write,
    input  logic          [REGFILE_BITS-1:0] exmem_rd,
    input  logic                             memwb_reg_write,
    input  logic          [REGFILE_BITS-1:0] memwb_rd,
    output pkg::forward_t                    forward_a,
    output pkg::forward_t                    forward_b
);

  always_comb begin
    forward_a = NONE;
    forward_b = NONE;

    if (exmem_reg_write && exmem_rd != 0 && exmem_rd == idex_rs1) forward_a = AFTER_EXE;
    else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs1) forward_a = AFTER_MEM;

    if (exmem_reg_write && exmem_rd != 0 && exmem_rd == idex_rs2) forward_b = AFTER_EXE;
    else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs2) forward_b = AFTER_MEM;
  end

endmodule
