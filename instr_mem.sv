module instr_mem #(
    parameter int MEM_DEPTH = 1024,
    parameter int MEM_WIDTH = 32
) (
    input  logic        clk,
    input  logic [31:0] pc,
    output logic [31:0] instr
);

  (* ram_style = "block" *) logic [MEM_WIDTH-1:0] mem[MEM_DEPTH-1];

  initial begin
    $readmemh("program.hex", mem);
  end

  logic [$clog2(MEM_DEPTH)-1:0] pc_index;
  always_comb pc_index = pc[$clog2(MEM_DEPTH)+1:2];

  always_ff @(posedge clk) instr <= mem[pc_index];

endmodule
