module pipeline (
    input logic clk,
    input logic rst
);

  // IF/ID pipeline registers
  logic [31:0] ifid_pc;
  logic [31:0] ifid_instr;

  // ID/EX pipeline registers
  logic [31:0] idex_pc;
  logic [31:0] idex_rs1;
  logic [31:0] idex_rs2;
  logic [ 4:0] idex_rs1_num;
  logic [ 4:0] idex_rs2_num;
  logic [31:0] idex_imm;
  logic [ 4:0] idex_rd;
  logic [ 3:0] idex_alu_op;
  logic [ 1:0] idex_alu_in2;
  logic        idex_alu_in1;
  logic [ 2:0] idex_branch;
  logic        idex_jalr;
  logic        idex_mem_read;
  logic        idex_mem_write;
  logic        idex_reg_write;
  logic        idex_mem_to_reg;
  logic [ 1:0] idex_mem_size;
  logic        idex_mem_unsigned;

  // EX/MEM pipeline registers
  logic [31:0] exmem_alu_out;
  logic [31:0] exmem_rs2;
  logic [ 4:0] exmem_rd;
  logic        exmem_mem_read;
  logic        exmem_mem_write;
  logic        exmem_reg_write;
  logic        exmem_mem_to_reg;
  logic [ 1:0] exmem_mem_size;
  logic        exmem_mem_unsigned;

  // MEM/WB pipeline registers
  logic [31:0] memwb_alu_out;
  logic [31:0] memwb_mem_out;
  logic [ 4:0] memwb_rd;
  logic        memwb_reg_write;
  logic        memwb_mem_to_reg;

  // IF stage
  logic [31:0] pc;
  logic [31:0] instr;
  logic        bubble;

  // required for compilation, assigned later
  logic        branch_taken;
  logic [31:0] branch_target;

  hazard_detection hdu_inst (
      .idex_mem_read(idex_mem_read),
      .idex_rd(idex_rd),
      .ifid_rs1(ifid_instr[19:15]),
      .ifid_rs2(ifid_instr[24:20]),
      .bubble(bubble)
  );

  pc pc_inst (
      .rst(rst),
      .clk(clk),
      .stall(bubble),
      .taken(branch_taken),
      .target(branch_target),
      .pc_out(pc)
  );

  instr_mem imem (
      .pc(pc),
      .instr(instr)
  );

  always_ff @(posedge clk) begin
    if (rst || branch_taken) begin
      ifid_pc    <= 0;
      ifid_instr <= 32'h00000013; // ADDI x0,x0,0 (NOP)
    end else if (~bubble) begin
      ifid_pc    <= pc;
      ifid_instr <= instr;
    end
  end

  // ID stage
  logic [31:0] rs1_val, rs2_val;
  reg_file rf_inst (
      .clk(clk),
      .rs1_num(ifid_instr[19:15]),
      .rs2_num(ifid_instr[24:20]),
      .rd_num(memwb_rd),
      .data(memwb_mem_to_reg ? memwb_mem_out : memwb_alu_out),
      .write(memwb_reg_write),
      .rs1(rs1_val),
      .rs2(rs2_val)
  );

  logic [31:0] imm;
  imm_gen ig_inst (
      .instr(ifid_instr),
      .imm  (imm)
  );

  logic [3:0] alu_op;
  logic [1:0] alu_in2_sel;
  logic       alu_in1_sel;
  logic [2:0] branch_type;
  logic       jalr;
  logic mem_read, mem_write, reg_write, mem_to_reg;
  logic [1:0] mem_size;
  logic       mem_unsigned;

  control_unit cu_inst (
      .funct7(ifid_instr[31:25]),
      .funct3(ifid_instr[14:12]),
      .opcode(ifid_instr[6:0]),
      .alu_op(alu_op),
      .alu_in2(alu_in2_sel),
      .alu_in1(alu_in1_sel),
      .branch(branch_type),
      .jalr(jalr),
      .mem_read(mem_read),
      .mem_write(mem_write),
      .reg_write(reg_write),
      .mem_to_reg(mem_to_reg),
      .mem_size(mem_size),
      .mem_unsigned(mem_unsigned)
  );

  always_ff @(posedge clk) begin
    if (rst || branch_taken || bubble) begin
      idex_pc           <= 0;
      idex_rs1          <= 0;
      idex_rs2          <= 0;
      idex_rs1_num      <= 0;
      idex_rs2_num      <= 0;
      idex_imm          <= 0;
      idex_rd           <= 0;
      idex_alu_op       <= 0;
      idex_alu_in2      <= 0;
      idex_alu_in1      <= 0;
      idex_branch       <= 0;
      idex_jalr         <= 0;
      idex_mem_read     <= 0;
      idex_mem_write    <= 0;
      idex_reg_write    <= 0;
      idex_mem_to_reg   <= 0;
      idex_mem_size     <= 0;
      idex_mem_unsigned <= 0;
    end else begin
      idex_pc           <= ifid_pc;
      idex_rs1          <= rs1_val;
      idex_rs2          <= rs2_val;
      idex_rs1_num      <= ifid_instr[19:15];
      idex_rs2_num      <= ifid_instr[24:20];
      idex_imm          <= imm;
      idex_rd           <= ifid_instr[11:7];
      idex_alu_op       <= alu_op;
      idex_alu_in2      <= alu_in2_sel;
      idex_alu_in1      <= alu_in1_sel;
      idex_branch       <= branch_type;
      idex_jalr         <= jalr;
      idex_mem_read     <= mem_read;
      idex_mem_write    <= mem_write;
      idex_reg_write    <= reg_write;
      idex_mem_to_reg   <= mem_to_reg;
      idex_mem_size     <= mem_size;
      idex_mem_unsigned <= mem_unsigned;
    end
  end

  // EX stage
  logic [31:0] forward_rs1, forward_rs2;
  logic [31:0] alu_in1, alu_in2, alu_out;
  logic alu_zero, alu_carry, alu_overflow, alu_sign;
  logic [1:0] forward_a, forward_b;

  forward_control fc_inst (
      .idex_rs1(idex_rs1_num),
      .idex_rs2(idex_rs2_num),
      .*
  );

  assign forward_rs1 = forward_a == 2'b00 ? idex_rs1 : forward_a == 2'b01 ? exmem_alu_out : memwb_alu_out;
  assign forward_rs2 = forward_b == 2'b00 ? idex_rs2 : forward_b == 2'b01 ? exmem_alu_out : memwb_alu_out;

  assign alu_in1 = idex_alu_in1 ? idex_pc : forward_rs1;

  always_comb
    case (idex_alu_in2)
      2'b00:   alu_in2 = forward_rs2;
      2'b01:   alu_in2 = idex_imm;
      2'b10:   alu_in2 = 32'd4;
      default: alu_in2 = 32'd0;
    endcase

  alu alu_inst (
      .ctl(idex_alu_op),
      .in_1(alu_in1),
      .in_2(alu_in2),
      .out(alu_out),
      .zero(alu_zero),
      .carry(alu_carry),
      .overflow(alu_overflow),
      .sign(alu_sign)
  );

  branch_control bc_inst (
      .branch(idex_branch),
      .zero(alu_zero),
      .carry(alu_carry),
      .sign(alu_sign),
      .overflow(alu_overflow),
      .taken(branch_taken)
  );

  branch_gen bg_inst (
      .pc(idex_pc),
      .imm(idex_imm),
      .rs1(forward_rs1),
      .jalr(idex_jalr),
      .target(branch_target)
  );

  always_ff @(posedge clk) begin
    exmem_alu_out <= alu_out;
    exmem_rs2 <= forward_b == 2'b00 ? idex_rs2 : forward_b == 2'b01 ? exmem_alu_out : memwb_alu_out;
    exmem_rd <= idex_rd;
    exmem_mem_read <= idex_mem_read;
    exmem_mem_write <= idex_mem_write;
    exmem_reg_write <= idex_reg_write;
    exmem_mem_to_reg <= idex_mem_to_reg;
    exmem_mem_size <= idex_mem_size;
    exmem_mem_unsigned <= idex_mem_unsigned;
  end

  // MEM stage
  logic [31:0] mem_out;

  data_mem dmem (
      .clk  (clk),
      .addr (exmem_alu_out),
      .data (exmem_rs2),
      .read (exmem_mem_read),
      .write(exmem_mem_write),
      .size (exmem_mem_size),
      .sign (exmem_mem_unsigned),
      .out  (mem_out)
  );

  always_ff @(posedge clk) begin
    memwb_alu_out    <= exmem_alu_out;
    memwb_mem_out    <= mem_out;
    memwb_rd         <= exmem_rd;
    memwb_reg_write  <= exmem_reg_write;
    memwb_mem_to_reg <= exmem_mem_to_reg;
  end

endmodule
