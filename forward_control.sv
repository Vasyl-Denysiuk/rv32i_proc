module forward_control (
    input  logic [4:0] idex_rs1,
    input  logic [4:0] idex_rs2,
    input  logic       exmem_reg_write,
    input  logic [4:0] exmem_rd,
    input  logic       memwb_reg_write,
    input  logic [4:0] memwb_rd,
    output logic [1:0] forward_a,        // 00=reg, 01=ex/mem, 10=mem/wb
    output logic [1:0] forward_b
);

  always_comb begin
    forward_a = 2'b00;
    forward_b = 2'b00;

    if (exmem_reg_write && exmem_rd != 0 && exmem_rd == idex_rs1) forward_a = 2'b01;
    else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs1) forward_a = 2'b10;

    if (exmem_reg_write && exmem_rd != 0 && exmem_rd == idex_rs2) forward_b = 2'b01;
    else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs2) forward_b = 2'b10;
  end

endmodule
