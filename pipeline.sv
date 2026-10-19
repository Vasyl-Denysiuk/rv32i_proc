import pkg::*;

module pipeline (
    input  logic              clk,
    input  logic              rst_n,
    output logic [  XLEN-1:0] imem_addr,
    input  logic [      31:0] imem_rdata,
    output logic [  XLEN-1:0] dmem_addr,
    output logic [  XLEN-1:0] dmem_wdata,
    output logic [XLEN/8-1:0] dmem_be,
    output logic              dmem_re,
    output logic [       1:0] dmem_size,
    input  logic [  XLEN-1:0] dmem_rdata
);

  // IF/ID pipeline registers
  logic            [        XLEN-1:0] ifid_pc;
  logic            [        XLEN-1:0] ifid_instr;

  // ID/EX pipeline registers
  logic            [        XLEN-1:0] idex_pc;
  logic            [        XLEN-1:0] idex_rs1;
  logic            [        XLEN-1:0] idex_rs2;
  logic            [REGFILE_BITS-1:0] idex_rs1_num;
  logic            [REGFILE_BITS-1:0] idex_rs2_num;
  logic            [        XLEN-1:0] idex_imm;
  logic            [REGFILE_BITS-1:0] idex_rd;
  pkg::alu_op_t                       idex_alu_op;
  pkg::operand_b_t                    idex_alu_in2;
  pkg::operand_a_t                    idex_alu_in1;
  pkg::branch_t                       idex_branch;
  logic                               idex_jalr;
  logic                               idex_mem_read;
  logic                               idex_mem_write;
  logic                               idex_reg_write;
  logic                               idex_mem_to_reg;
  logic            [             1:0] idex_mem_size;
  logic                               idex_mem_unsigned;

  // EX/MEM pipeline registers
  logic            [        XLEN-1:0] exmem_alu_out;
  logic            [        XLEN-1:0] exmem_rs2;
  logic            [REGFILE_BITS-1:0] exmem_rd;
  logic                               exmem_mem_read;
  logic                               exmem_mem_write;
  logic                               exmem_reg_write;
  logic                               exmem_mem_to_reg;
  logic            [             1:0] exmem_mem_size;
  logic                               exmem_mem_unsigned;

  // MEM/WB pipeline registers
  logic            [        XLEN-1:0] memwb_alu_out;
  logic            [        XLEN-1:0] memwb_mem_out;
  logic            [REGFILE_BITS-1:0] memwb_rd;
  logic                               memwb_reg_write;
  logic                               memwb_mem_to_reg;

  // IF stage
  logic [XLEN-1:0] pc, next_pc;
  logic [XLEN-1:0] instr;
  logic            bubble;

  // required for compilation, assigned later
  logic            branch_taken;
  logic [XLEN-1:0] branch_target;

  hazard_detection hd_i (
      .idex_mem_read(idex_mem_read),
      .idex_rd(idex_rd),
      .ifid_rs1(ifid_instr[19:15]),
      .ifid_rs2(ifid_instr[24:20]),
      .bubble(bubble)
  );

  pc pc_i (
      .rst_n(rst_n),
      .clk(clk),
      .stall(bubble),
      .taken(branch_taken),
      .target(branch_target),
      .pc(pc),
      .next_pc(next_pc)
  );

  instr_mem imem (
      .clk  (clk),
      .addr (next_pc),
      .instr(instr)
  );

  always_ff @(posedge clk) begin
    if (!rst_n || branch_taken) begin
      ifid_pc    <= 0;
      ifid_instr <= 32'h00000013; // ADDI x0,x0,0 (NOP)
    end else if (~bubble) begin
      ifid_pc    <= pc;
      ifid_instr <= instr;
    end
  end

  // ID stage
  logic [XLEN-1:0] rs1_val, rs2_val;
  logic [XLEN-1:0] wb_data;
  reg_file rf_i (
      .clk(clk),
      .rs1_num(ifid_instr[19:15]),
      .rs2_num(ifid_instr[24:20]),
      .rd_num(memwb_rd),
      .data(wb_data),
      .wb(memwb_reg_write),
      .rs1(rs1_val),
      .rs2(rs2_val)
  );

  logic [XLEN-1:0] imm;
  imm_gen ig_i (
      .instr(ifid_instr),
      .imm  (imm)
  );

  pkg::alu_op_t    alu_op;
  pkg::operand_b_t alu_in2_sel;
  pkg::operand_a_t alu_in1_sel;
  pkg::branch_t    branch_type;
  logic            jalr;
  logic mem_read, mem_write, reg_write, mem_to_reg;
  logic [1:0] mem_size;
  logic       mem_unsigned;

  control_unit cu_i (
      .funct7(ifid_instr[31:25]),
      .funct3(ifid_instr[14:12]),
      .opcode(pkg::opcode_t'(ifid_instr[6:0])),
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
    if (!rst_n || branch_taken || bubble) begin
      idex_pc           <= 0;
      idex_rs1          <= 0;
      idex_rs2          <= 0;
      idex_rs1_num      <= 0;
      idex_rs2_num      <= 0;
      idex_imm          <= 0;
      idex_rd           <= 0;
      idex_alu_op       <= ADD;
      idex_alu_in2      <= RS2;
      idex_alu_in1      <= RS1;
      idex_branch       <= NO_CF;
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
  logic [XLEN-1:0] forward_rs1, forward_rs2;
  logic [XLEN-1:0] alu_in1, alu_in2, alu_out;
  logic alu_zero, alu_borrow, alu_overflow, alu_sign;
  logic [1:0] forward_a, forward_b;

  forward_control fc_i (
      .idex_rs1(idex_rs1_num),
      .idex_rs2(idex_rs2_num),
      .exmem_reg_write(exmem_reg_write),
      .exmem_rd(exmem_rd),
      .memwb_reg_write(memwb_reg_write),
      .memwb_rd(memwb_rd),
      .forward_a(forward_a),
      .forward_b(forward_b)
  );

  assign forward_rs1 = forward_a == NONE ? idex_rs1 : forward_a == AFTER_EXE ? exmem_alu_out : wb_data;
  assign forward_rs2 = forward_b == NONE ? idex_rs2 : forward_b == AFTER_EXE ? exmem_alu_out : wb_data;

  assign alu_in1 = idex_alu_in1 ? idex_pc : forward_rs1;

  always_comb
    case (idex_alu_in2)
      RS2: alu_in2 = forward_rs2;
      IMM: alu_in2 = idex_imm;
      STEP: alu_in2 = 32'd4;
      default: alu_in2 = 32'd0;
    endcase

  alu alu_i (
      .ctl(idex_alu_op),
      .in_1(alu_in1),
      .in_2(alu_in2),
      .out(alu_out),
      .zero(alu_zero),
      .borrow(alu_borrow),
      .overflow(alu_overflow),
      .sign(alu_sign)
  );

  branch_control bc_i (
      .branch(idex_branch),
      .zero(alu_zero),
      .borrow(alu_borrow),
      .overflow(alu_overflow),
      .sign(alu_sign),
      .taken(branch_taken)
  );

  branch_gen bg_i (
      .pc(idex_pc),
      .imm(idex_imm),
      .rs1(forward_rs1),
      .is_jalr(idex_jalr),
      .target(branch_target)
  );

  always_ff @(posedge clk) begin
    exmem_alu_out <= alu_out;
    exmem_rs2 <= forward_b == NONE ? idex_rs2 : forward_b == AFTER_EXE ? exmem_alu_out : wb_data;
    exmem_rd <= idex_rd;
    exmem_mem_read <= idex_mem_read;
    exmem_mem_write <= idex_mem_write;
    exmem_reg_write <= idex_reg_write;
    exmem_mem_to_reg <= idex_mem_to_reg;
    exmem_mem_size <= idex_mem_size;
    exmem_mem_unsigned <= idex_mem_unsigned;
  end

  // MEM stage
  logic [XLEN-1:0] mem_out;
  logic [1:0] memwb_offset, memwb_mem_size;
  logic              memwb_mem_unsigned;

  logic [XLEN/8-1:0] be;
  always_comb begin
    if (exmem_mem_write) be = byte_enable(exmem_alu_out[1:0], exmem_mem_size);
    else be = '0;
  end

  logic [XLEN-1:0] wdata;

  always_comb begin
    case (exmem_mem_size)
      2'b00:   wdata = {4{exmem_rs2[7:0]}};
      2'b01:   wdata = {2{exmem_rs2[15:0]}};
      default: wdata = exmem_rs2;
    endcase
  end

  data_mem dmem (
      .clk(clk),
      .addr(exmem_alu_out),
      .data(wdata),
      .re(exmem_mem_read),
      .be(be),
      .rdata(mem_out)
  );

  always_ff @(posedge clk) begin
    memwb_alu_out      <= exmem_alu_out;
    memwb_mem_out      <= mem_out;
    memwb_rd           <= exmem_rd;
    memwb_reg_write    <= exmem_reg_write;
    memwb_mem_to_reg   <= exmem_mem_to_reg;
    memwb_offset       <= exmem_alu_out[1:0];
    memwb_mem_size     <= exmem_mem_size;
    memwb_mem_unsigned <= exmem_mem_unsigned;
  end

  // WB stage
  assign wb_data = memwb_mem_to_reg ? load_ext(
      mem_out, memwb_offset, memwb_mem_size, memwb_mem_unsigned
  ) : memwb_alu_out;

endmodule
