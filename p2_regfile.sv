// Problem 2 -- register file: combinational read, sequential write, r0 = 0
module p2_regfile
  import hw_pkg::*;
(
    input  logic     clk_i,
    input  logic     rst_ni,

    // two combinational read ports
    input  regid_t   rs1_addr_i,
    output xdata_t   rs1_data_o,
    input  regid_t   rs2_addr_i,
    output xdata_t   rs2_data_o,

    // one sequential write port (en, addr, data)
    input  wr_port_t wr_i,

    // when high, a read of the register being written this cycle
    // returns the NEW data instead of the old
    input  logic     bypass_en_i
);

  // packed element (8-bit) x unpacked dimension (8 entries)
  xdata_t regs_q [NUM_REGS];

  // 2a -- the write port
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      for (int i = 0; i < NUM_REGS; i++) regs_q[i] <= '0;
    end else if (wr_i.en && (wr_i.addr != '0)) begin
      regs_q[wr_i.addr] <= wr_i.data;   // writes to r0 are discarded
    end
  end

  // 2c -- bypass: same register, write enabled, not r0, bypass turned on
  logic byp1, byp2;

  assign byp1 = bypass_en_i && wr_i.en && (wr_i.addr == rs1_addr_i) && (wr_i.addr != '0);
  assign byp2 = bypass_en_i && wr_i.en && (wr_i.addr == rs2_addr_i) && (wr_i.addr != '0);

  // 2b -- combinational reads (r0 always 0), with the bypass mux from 2c
  assign rs1_data_o = (rs1_addr_i == '0) ? '0 :
                      byp1               ? wr_i.data :
                                           regs_q[rs1_addr_i];

  assign rs2_data_o = (rs2_addr_i == '0) ? '0 :
                      byp2               ? wr_i.data :
                                           regs_q[rs2_addr_i];

endmodule
