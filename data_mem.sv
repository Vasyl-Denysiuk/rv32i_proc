module data_mem
  import pkg::*;
#(
    parameter int DEPTH = 1024
) (
    input  logic              clk,
    input  logic [  XLEN-1:0] addr,
    input  logic [  XLEN-1:0] data,
    input  logic              re,
    input  logic [XLEN/8-1:0] be,
    output logic [  XLEN-1:0] rdata
);

  localparam int SEL_BITS = $clog2(XLEN / 8);

  logic [XLEN-1:0] ram[DEPTH-1:0];

  logic [$clog2(DEPTH)-1:0] w_addr;
  logic [SEL_BITS-1:0] offset;
  assign w_addr = addr[XLEN-1:SEL_BITS];
  assign offset = addr[SEL_BITS-1:0];

  always_ff @(posedge clk) begin
    for (int i = 0; i < (XLEN / 8); i++) begin
      if (be[i]) begin
        ram[w_addr][i*8+:8] <= data[i*8+:8];
      end
    end
  end

  always_ff @(posedge clk) begin
    if (re) begin
      rdata <= ram[w_addr];
    end
  end

endmodule
