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
    input  logic [  XLEN-1:0] dmem_rdata,
    // RVFI ports
    output logic                    rvfi_valid,
    output logic [            63:0] rvfi_order,
    output logic [            31:0] rvfi_insn,
    output logic                    rvfi_trap,
    output logic                    rvfi_halt,
    output logic                    rvfi_intr,
    output logic [             1:0] rvfi_mode,
    output logic [             1:0] rvfi_ixl,
    output logic [REGFILE_BITS-1:0] rvfi_rs1_addr,
    output logic [REGFILE_BITS-1:0] rvfi_rs2_addr,
    output logic [        XLEN-1:0] rvfi_rs1_rdata,
    output logic [        XLEN-1:0] rvfi_rs2_rdata,
    output logic [REGFILE_BITS-1:0] rvfi_rd_addr,
    output logic [        XLEN-1:0] rvfi_rd_wdata,
    output logic [        XLEN-1:0] rvfi_pc_rdata,
    output logic [        XLEN-1:0] rvfi_pc_wdata,
    output logic [        XLEN-1:0] rvfi_mem_addr,
    output logic [      XLEN/8-1:0] rvfi_mem_rmask,
    output logic [      XLEN/8-1:0] rvfi_mem_wmask,
    output logic [        XLEN-1:0] rvfi_mem_rdata,
    output logic [        XLEN-1:0] rvfi_mem_wdata
);

  // IF/ID pipeline registers
  logic            [        XLEN-1:0] ifid_pc;
  logic            [        XLEN-1:0] ifid_instr;
  logic                               ifid_valid;

  // ID/EX pipeline registers
  logic                               idex_valid;
  logic            [        XLEN-1:0] idex_instr;
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
  logic                               idex_trap;

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
  logic                               exmem_valid;
  logic                               exmem_trap;
  // used only by RVFI
  logic            [        XLEN-1:0] exmem_instr;
  logic            [        XLEN-1:0] exmem_pc;
  logic            [        XLEN-1:0] exmem_next_pc;
  logic            [REGFILE_BITS-1:0] exmem_rs1_num;
  logic            [REGFILE_BITS-1:0] exmem_rs2_num;
  logic            [        XLEN-1:0] exmem_rs1;

  // MEM/WB pipeline registers
  logic            [        XLEN-1:0] memwb_alu_out;
  logic            [REGFILE_BITS-1:0] memwb_rd;
  logic                               memwb_reg_write;
  logic                               memwb_mem_to_reg;
  logic                               memwb_valid;
  logic                               memwb_trap;
  // used only by RVFI
  logic            [        XLEN-1:0] memwb_instr;
  logic            [        XLEN-1:0] memwb_pc;
  logic            [        XLEN-1:0] memwb_next_pc;
  logic            [REGFILE_BITS-1:0] memwb_rs1_num;
  logic            [REGFILE_BITS-1:0] memwb_rs2_num;
  logic            [        XLEN-1:0] memwb_rs1;
  logic            [        XLEN-1:0] memwb_rs2;
  logic            [        XLEN-1:0] memwb_mem_addr;
  logic            [      XLEN/8-1:0] memwb_rmask;
  logic            [      XLEN/8-1:0] memwb_wmask;
  logic            [        XLEN-1:0] memwb_wdata;

  // IF stage
  logic [XLEN-1:0] pc, next_pc;
  logic [XLEN-1:0] instr;
  logic            bubble;

  logic            branch_taken;
  logic [XLEN-1:0] branch_target;

  logic ex_trap;
  logic flush;
  logic halted;

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
      .stall(bubble || halted),
      .taken(branch_taken),
      .target(branch_target),
      .pc(pc),
      .next_pc(next_pc)
  );

  // imem access
  assign imem_addr = next_pc;
  assign instr     = imem_rdata;

  always_ff @(posedge clk) begin
    if (!rst_n || flush || halted) begin
      ifid_valid <= 0;
      ifid_pc    <= 0;
      ifid_instr <= 32'h00000013; // ADDI x0,x0,0 (NOP)
    end else if (~bubble) begin
      ifid_valid <= 1;
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
  logic       id_trap;

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
      .mem_unsigned(mem_unsigned),
      .trap(id_trap)
  );

  always_ff @(posedge clk) begin
    if (!rst_n || flush || halted || bubble) begin
      idex_valid        <= 0;
      idex_instr        <= 32'h00000013; // ADDI x0,x0,0 (NOP)
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
      idex_trap         <= 0;
    end else begin
      idex_valid        <= ifid_valid;
      idex_instr        <= ifid_instr;
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
      idex_trap         <= id_trap;
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

  // Traps
  logic mem_misaligned, target_misaligned;
  always_comb begin
    case (idex_mem_size)
      2'b01:   mem_misaligned = alu_out[0];
      2'b10:   mem_misaligned = alu_out[1:0] != 0;
      default: mem_misaligned = 0;
    endcase
    mem_misaligned = mem_misaligned && (idex_mem_read || idex_mem_write);
  end

  assign target_misaligned = branch_taken && branch_target[1:0] != 0;
  assign ex_trap = idex_valid && (idex_trap || mem_misaligned || target_misaligned);
  assign flush   = branch_taken || ex_trap;

  always_ff @(posedge clk) begin
    if (!rst_n) halted <= 0;
    else if (ex_trap) halted <= 1;
  end

  always_ff @(posedge clk) begin
    exmem_alu_out      <= alu_out;
    exmem_rs2          <= forward_rs2;
    exmem_rd           <= idex_rd;
    exmem_mem_to_reg   <= idex_mem_to_reg;
    exmem_mem_size     <= idex_mem_size;
    exmem_mem_unsigned <= idex_mem_unsigned;
    exmem_instr        <= idex_instr;
    exmem_pc           <= idex_pc;
    exmem_next_pc      <= branch_taken ? branch_target : idex_pc + XLEN'(4);
    exmem_rs1_num      <= idex_rs1_num;
    exmem_rs2_num      <= idex_rs2_num;
    exmem_rs1          <= forward_rs1;

    if (!rst_n) begin
      exmem_valid     <= 0;
      exmem_trap      <= 0;
      exmem_mem_read  <= 0;
      exmem_mem_write <= 0;
      exmem_reg_write <= 0;
    end else begin
      exmem_valid     <= idex_valid;
      exmem_trap      <= ex_trap;
      exmem_mem_read  <= idex_mem_read && !ex_trap;
      exmem_mem_write <= idex_mem_write && !ex_trap;
      exmem_reg_write <= idex_reg_write && !ex_trap;
    end
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

  // dmem access
  assign dmem_addr  = exmem_alu_out;
  assign dmem_wdata = wdata;
  assign dmem_be    = be;
  assign dmem_re    = exmem_mem_read;
  assign dmem_size  = exmem_mem_size;
  assign mem_out    = dmem_rdata;

  // read mask for RVFI
  logic [XLEN/8-1:0] rmask;
  assign rmask = exmem_mem_read ? byte_enable(exmem_alu_out[1:0], exmem_mem_size) : '0;

  always_ff @(posedge clk) begin
    memwb_alu_out      <= exmem_alu_out;
    memwb_rd           <= exmem_rd;
    memwb_mem_to_reg   <= exmem_mem_to_reg;
    memwb_offset       <= exmem_alu_out[1:0];
    memwb_mem_size     <= exmem_mem_size;
    memwb_mem_unsigned <= exmem_mem_unsigned;
    memwb_instr        <= exmem_instr;
    memwb_pc           <= exmem_pc;
    memwb_next_pc      <= exmem_next_pc;
    memwb_rs1_num      <= exmem_rs1_num;
    memwb_rs2_num      <= exmem_rs2_num;
    memwb_rs1          <= exmem_rs1;
    memwb_rs2          <= exmem_rs2;
    // aligned address for RVFI
    memwb_mem_addr     <= {exmem_alu_out[XLEN-1:2], 2'b00};
    memwb_rmask        <= rmask;
    memwb_wmask        <= be;
    memwb_wdata        <= wdata;

    if (!rst_n) begin
      memwb_valid     <= 0;
      memwb_trap      <= 0;
      memwb_reg_write <= 0;
    end else begin
      memwb_valid     <= exmem_valid;
      memwb_trap      <= exmem_trap;
      memwb_reg_write <= exmem_reg_write;
    end
  end

  // WB stage
  assign wb_data = memwb_mem_to_reg ? load_ext(
      mem_out, memwb_offset, memwb_mem_size, memwb_mem_unsigned
  ) : memwb_alu_out;

  // RVFI retire
  logic [63:0] order;
  always_ff @(posedge clk) begin
    if (!rst_n) order <= 0;
    else if (memwb_valid) order <= order + 1;
  end

  logic rd_written;
  assign rd_written = memwb_reg_write && memwb_rd != 0;

  assign rvfi_valid     = memwb_valid;
  assign rvfi_order     = order;
  assign rvfi_insn      = memwb_instr;
  assign rvfi_trap      = memwb_trap;
  assign rvfi_halt      = memwb_trap;  // trapping instruction is last before halt
  assign rvfi_intr      = 0;           // no trap handler is ever entered
  assign rvfi_mode      = 2'd3;  // M-mode
  assign rvfi_ixl       = 2'd1;  // 32-bit
  assign rvfi_rs1_addr  = memwb_rs1_num;
  assign rvfi_rs2_addr  = memwb_rs2_num;
  assign rvfi_rs1_rdata = memwb_rs1;
  assign rvfi_rs2_rdata = memwb_rs2;
  assign rvfi_rd_addr   = rd_written ? memwb_rd : '0;
  assign rvfi_rd_wdata  = rd_written ? wb_data : '0;
  assign rvfi_pc_rdata  = memwb_pc;
  assign rvfi_pc_wdata  = memwb_next_pc;
  assign rvfi_mem_addr  = memwb_mem_addr;
  assign rvfi_mem_rmask = memwb_rmask;
  assign rvfi_mem_wmask = memwb_wmask;
  assign rvfi_mem_rdata = mem_out;
  assign rvfi_mem_wdata = memwb_wdata;

endmodule
