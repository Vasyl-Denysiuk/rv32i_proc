// riscv-formal wrapper: the solver drives instruction and data memory read data
// with arbitrary values on every cycle, so every instruction sequence is explored
module rvfi_wrapper (
    input clock,
    input reset,
    `RVFI_OUTPUTS
);

  (* keep *) `rvformal_rand_reg [31:0] imem_rdata;
  (* keep *) `rvformal_rand_reg [31:0] dmem_rdata;

  (* keep *) wire [31:0] imem_addr;
  (* keep *) wire [31:0] dmem_addr;
  (* keep *) wire [31:0] dmem_wdata;
  (* keep *) wire [ 3:0] dmem_be;
  (* keep *) wire        dmem_re;
  (* keep *) wire [ 1:0] dmem_size;

  pipeline uut (
      .clk       (clock),
      .rst_n     (!reset),

      .imem_addr (imem_addr),
      .imem_rdata(imem_rdata),
      .dmem_addr (dmem_addr),
      .dmem_wdata(dmem_wdata),
      .dmem_be   (dmem_be),
      .dmem_re   (dmem_re),
      .dmem_size (dmem_size),
      .dmem_rdata(dmem_rdata),

      `RVFI_CONN
  );

endmodule
