package pkg;
  localparam int XLEN = 32;
  localparam int REGFILE_BITS = 5;

  typedef enum logic [1:0] {
    NONE,
    AFTER_EXE,
    AFTER_MEM
  } forward_t;

  typedef enum logic [6:0] {
    REG_OP = 7'b0110011,
    IMM_OP = 7'b0010011,
    LOAD   = 7'b0000011,
    STORE  = 7'b0100011,
    BRANCH = 7'b1100011,
    JAL    = 7'b1101111,
    JALR   = 7'b1100111,
    LUI    = 7'b0110111,
    AUIPC  = 7'b0010111
  } opcode_t;

  typedef enum logic [3:0] {
    ADD,
    SLL,
    SLT,
    SLTU,
    XOR,
    SRL,
    OR,
    AND,
    SUB,
    SRA,
    PASS_B
  } alu_op_t;

  typedef enum logic {
    RS1,
    PC
  } operand_a_t;

  typedef enum logic [1:0] {
    RS2,
    IMM,
    STEP
  } operand_b_t;

  typedef enum logic [2:0] {
    BEQ   = 3'b000,
    BNE   = 3'b001,
    NO_CF = 3'b010,
    JUMP  = 3'b011,
    BLT   = 3'b100,
    BGE   = 3'b101,
    BLTU  = 3'b110,
    BGEU  = 3'b111
  } branch_t;

  function automatic branch_t decode_branch(logic [2:0] funct3);
    case (funct3)
      3'b000:  return BEQ;
      3'b001:  return BNE;
      3'b100:  return BLT;
      3'b101:  return BGE;
      3'b110:  return BLTU;
      3'b111:  return BGEU;
      default: return NO_CF;
    endcase
  endfunction

  function automatic alu_op_t decode_alu(logic [2:0] funct3, logic alt);
    case (funct3)
      3'b000:  return alt ? SUB : ADD;
      3'b001:  return SLL;
      3'b010:  return SLT;
      3'b011:  return SLTU;
      3'b100:  return XOR;
      3'b101:  return alt ? SRA : SRL;
      3'b110:  return OR;
      default: return AND;
    endcase
  endfunction

  function automatic logic [XLEN-1:0] load_ext(logic [XLEN-1:0] data, logic [1:0] offset,
                                               logic [1:0] size, logic is_unsigned);
    logic [XLEN-1:0] aligned;

    unique case (size)
      2'b00: begin  // byte
        unique case (offset)
          2'b00:   aligned = {{XLEN - 8{1'b0}}, data[7:0]};
          2'b01:   aligned = {{XLEN - 8{1'b0}}, data[15:8]};
          2'b10:   aligned = {{XLEN - 8{1'b0}}, data[23:16]};
          2'b11:   aligned = {{XLEN - 8{1'b0}}, data[31:24]};
          default: aligned = '0;
        endcase
        if (!is_unsigned && aligned[7]) begin
          aligned[XLEN-1:8] = {XLEN - 8{1'b1}};
        end
      end

      2'b01: begin  // halfword
        unique case (offset[1])
          1'b0: aligned = {{XLEN - 16{1'b0}}, data[15:0]};
          1'b1: aligned = {{XLEN - 16{1'b0}}, data[31:16]};
          default: aligned = '0;
        endcase
        if (!is_unsigned && aligned[15]) begin
          aligned[XLEN-1:16] = {XLEN - 16{1'b1}};
        end
      end

      2'b10: begin  // word
        aligned = data;
      end

      default: aligned = '0;
    endcase

    return aligned;
  endfunction

  function automatic logic [3:0] byte_enable(logic [1:0] offset, logic [1:0] size);
    logic [3:0] be;
    case (size)
      2'b00: begin  // byte
        case (offset)
          2'b00:   be = 4'b0001;
          2'b01:   be = 4'b0010;
          2'b10:   be = 4'b0100;
          2'b11:   be = 4'b1000;
          default: be = 4'b0000;
        endcase
      end
      2'b01: begin  // halfword
        case (offset[1])
          1'b0: be = 4'b0011;
          1'b1: be = 4'b1100;
        endcase
      end
      2'b10: begin  // word
        be = 4'b1111;
      end
      default: be = 4'b0000;
    endcase
    return be;
  endfunction

endpackage
