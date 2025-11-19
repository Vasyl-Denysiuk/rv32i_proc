module data_mem #(
    parameter int MEM_DEPTH = 1024,
    parameter int MEM_WIDTH = 32
) (
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] data,
    input  logic        read,
    input  logic        write,
    input  logic [ 1:0] size,   // 00=byte, 01=halfword, 10=word
    input  logic        sign,   // 1=unsigned, 0=signed
    output logic [31:0] out
);

  (* ram_style = "block" *) logic [MEM_WIDTH-1:0] mem[MEM_DEPTH-1];

  logic [31:0] w_addr;
  logic [1:0] byte_sel;

  assign w_addr   = addr >> 2;
  assign byte_sel = addr[1:0];

  always_comb begin
    out = 32'b0;
    if (read && w_addr < MEM_DEPTH) begin
      unique case (size)
        2'b00: begin
          unique case (byte_sel)
            2'b00:
            out = sign ? {24'b0, mem[w_addr][7:0]} : {{24{mem[w_addr][7]}}, mem[w_addr][7:0]};
            2'b01:
            out = sign ? {24'b0, mem[w_addr][15:8]} : {{24{mem[w_addr][15]}}, mem[w_addr][15:8]};
            2'b10:
            out = sign ? {24'b0, mem[w_addr][23:16]} : {{24{mem[w_addr][23]}}, mem[w_addr][23:16]};
            2'b11:
            out = sign ? {24'b0, mem[w_addr][31:24]} : {{24{mem[w_addr][31]}}, mem[w_addr][31:24]};
          endcase
        end

        2'b01: begin
          unique case (byte_sel[1])
            1'b0:
            out = sign ? {16'b0, mem[w_addr][15:0]} : {{16{mem[w_addr][15]}}, mem[w_addr][15:0]};
            1'b1:
            out = sign ? {16'b0, mem[w_addr][31:16]} : {{16{mem[w_addr][31]}}, mem[w_addr][31:16]};
          endcase
        end

        2'b10: begin
          out = mem[w_addr];
        end

        default: out = 32'b0;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (write && w_addr < MEM_DEPTH) begin
      unique case (size)
        2'b00: begin
          unique case (byte_sel)
            2'b00: mem[w_addr][7:0] <= data[7:0];
            2'b01: mem[w_addr][15:8] <= data[7:0];
            2'b10: mem[w_addr][23:16] <= data[7:0];
            2'b11: mem[w_addr][31:24] <= data[7:0];
          endcase
        end

        2'b01: begin
          unique case (byte_sel[1])
            1'b0: mem[w_addr][15:0] <= data[15:0];
            1'b1: mem[w_addr][31:16] <= data[15:0];
          endcase
        end

        2'b10: begin
          mem[w_addr] <= data;
        end
      endcase
    end
  end

endmodule
