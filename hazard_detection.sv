module hazard_detection (
    input  logic       idex_mem_read,
    input  logic [4:0] idex_rd,
    input  logic [4:0] ifid_rs1,
    input  logic [4:0] ifid_rs2,
    output logic       bubble
);

  assign bubble = idex_mem_read && idex_rd != 0 && (idex_rd == ifid_rs1 || idex_rd == ifid_rs2);

endmodule
