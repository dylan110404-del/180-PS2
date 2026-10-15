// Testbench for Problem 2. Do not edit.
module tb_p2;
  import hw_pkg::*;

  logic     clk_i = 0, rst_ni;
  regid_t   rs1_addr_i, rs2_addr_i;
  xdata_t   rs1_data_o, rs2_data_o;
  wr_port_t wr_i;
  logic     bypass_en_i;
  int       errors = 0;

  always #5 clk_i = ~clk_i;

  p2_regfile dut (.*);

  xdata_t model [NUM_REGS];   // golden copy

  task automatic chk(string what, xdata_t got, xdata_t exp);
    if (got !== exp) begin
      $display("  FAIL %-28s got=%0h expected=%0h", what, got, exp);
      errors++;
    end
  endtask

  // Write a value, with the model kept in step.
  task automatic wr(regid_t a, xdata_t d);
    @(negedge clk_i);
    wr_i = '{en: 1'b1, addr: a, data: d};
    @(posedge clk_i); #1;
    @(negedge clk_i);
    wr_i = '0;
    if (a != 0) model[a] = d;
  endtask

  // Read both ports combinationally and check against the model.
  task automatic rd_chk(regid_t a1, regid_t a2);
    rs1_addr_i = a1;
    rs2_addr_i = a2;
    #1;
    chk($sformatf("rs1 read of r%0d", a1), rs1_data_o, (a1 == 0) ? '0 : model[a1]);
    chk($sformatf("rs2 read of r%0d", a2), rs2_data_o, (a2 == 0) ? '0 : model[a2]);
  endtask

  initial begin
    rst_ni = 0;
    wr_i = '0; bypass_en_i = 0; rs1_addr_i = '0; rs2_addr_i = '0;
    for (int i = 0; i < NUM_REGS; i++) model[i] = '0;
    repeat (2) @(posedge clk_i);
    @(negedge clk_i);
    rst_ni = 1;
    #1;

    // ---- (a) reset clears everything ---------------------------------------
    for (int i = 0; i < NUM_REGS; i++) rd_chk(regid_t'(i), regid_t'(i));

    // ---- (b) basic write then read -----------------------------------------
    for (int i = 1; i < NUM_REGS; i++) wr(regid_t'(i), xdata_t'(8'hA0 + i));
    for (int i = 0; i < NUM_REGS; i++) rd_chk(regid_t'(i), regid_t'(NUM_REGS - 1 - i));

    // ---- (b) the two read ports are independent ----------------------------
    rs1_addr_i = 3'd2; rs2_addr_i = 3'd5; #1;
    chk("independent ports rs1", rs1_data_o, model[2]);
    chk("independent ports rs2", rs2_data_o, model[5]);

    // ---- (b) r0 is hardwired -----------------------------------------------
    @(negedge clk_i);
    wr_i = '{en: 1'b1, addr: 3'd0, data: 8'hFF};
    @(posedge clk_i); #1;
    @(negedge clk_i); wr_i = '0;
    rs1_addr_i = 3'd0; #1;
    chk("r0 after writing FF to it", rs1_data_o, 8'h00);

    // ---- (b) write enable is respected -------------------------------------
    @(negedge clk_i);
    wr_i = '{en: 1'b0, addr: 3'd4, data: 8'h5A};   // en low: must not land
    @(posedge clk_i); #1;
    @(negedge clk_i); wr_i = '0;
    rd_chk(3'd4, 3'd4);

    // ---- (b) random traffic ------------------------------------------------
    for (int i = 0; i < 100; i++) begin
      wr(regid_t'($urandom_range(0, NUM_REGS-1)), xdata_t'($urandom));
      rd_chk(regid_t'($urandom_range(0, NUM_REGS-1)),
             regid_t'($urandom_range(0, NUM_REGS-1)));
    end

    // ---- (c) read-during-write, bypass OFF: must see the OLD value ----------
    bypass_en_i = 1'b0;
    @(negedge clk_i);
    wr_i       = '{en: 1'b1, addr: 3'd3, data: 8'h77};
    rs1_addr_i = 3'd3;
    rs2_addr_i = 3'd3;
    #1;
    chk("bypass OFF: rs1 sees old value", rs1_data_o, model[3]);
    chk("bypass OFF: rs2 sees old value", rs2_data_o, model[3]);
    @(posedge clk_i); #1;
    @(negedge clk_i); wr_i = '0;
    model[3] = 8'h77;
    rd_chk(3'd3, 3'd3);   // and it landed on the edge

    // ---- (c) read-during-write, bypass ON: must see the NEW value -----------
    bypass_en_i = 1'b1;
    @(negedge clk_i);
    wr_i       = '{en: 1'b1, addr: 3'd6, data: 8'h99};
    rs1_addr_i = 3'd6;    // colliding read
    rs2_addr_i = 3'd2;    // non-colliding read
    #1;
    chk("bypass ON: colliding rs1 sees new data",  rs1_data_o, 8'h99);
    chk("bypass ON: other port unaffected",        rs2_data_o, model[2]);
    @(posedge clk_i); #1;
    @(negedge clk_i); wr_i = '0;
    model[6] = 8'h99;

    // ---- (c) bypass must respect the write enable ---------------------------
    bypass_en_i = 1'b1;
    @(negedge clk_i);
    wr_i       = '{en: 1'b0, addr: 3'd6, data: 8'hEE};   // en LOW
    rs1_addr_i = 3'd6;
    #1;
    chk("bypass ON but wr.en low: no forwarding", rs1_data_o, model[6]);
    @(negedge clk_i); wr_i = '0;

    // ---- (c) bypass must never override r0 ----------------------------------
    bypass_en_i = 1'b1;
    @(negedge clk_i);
    wr_i       = '{en: 1'b1, addr: 3'd0, data: 8'hBB};
    rs1_addr_i = 3'd0;
    rs2_addr_i = 3'd0;
    #1;
    chk("bypass ON: r0 still reads zero", rs1_data_o, 8'h00);
    chk("bypass ON: r0 still reads zero", rs2_data_o, 8'h00);
    @(posedge clk_i); #1;
    @(negedge clk_i); wr_i = '0;

    // ---- (c) randomised collisions on both ports ----------------------------
    for (int i = 0; i < 200; i++) begin
      automatic regid_t wa = regid_t'($urandom_range(0, NUM_REGS-1));
      automatic xdata_t wd = xdata_t'($urandom);
      automatic regid_t a1 = regid_t'($urandom_range(0, NUM_REGS-1));
      automatic regid_t a2 = regid_t'($urandom_range(0, NUM_REGS-1));
      automatic logic   we = logic'($urandom_range(0, 1));
      automatic logic   be = logic'($urandom_range(0, 1));

      @(negedge clk_i);
      bypass_en_i = be;
      wr_i        = '{en: we, addr: wa, data: wd};
      rs1_addr_i  = a1;
      rs2_addr_i  = a2;
      #1;
      chk($sformatf("random rs1 (bypass=%0b we=%0b)", be, we), rs1_data_o,
          (a1 == 0) ? '0 : (be && we && (wa == a1) && (wa != 0)) ? wd : model[a1]);
      chk($sformatf("random rs2 (bypass=%0b we=%0b)", be, we), rs2_data_o,
          (a2 == 0) ? '0 : (be && we && (wa == a2) && (wa != 0)) ? wd : model[a2]);

      @(posedge clk_i); #1;
      if (we && wa != 0) model[wa] = wd;
      @(negedge clk_i);
      wr_i = '0;
    end

    if (errors == 0) $display("P2 PASS  (reset, r0, dual reads, write enable, bypass on/off)");
    else             $display("P2 FAIL  (%0d errors)", errors);
    $finish;
  end

  initial begin
    if ($test$plusargs("trace")) begin
      $dumpfile("build/p2.vcd");
      $dumpvars(0, tb_p2);
    end
  end

  initial begin
    #2000000;
    $display("P2 TIMEOUT -- the testbench never reached the end; your design is probably stalled.");
    $fatal(1);
  end

endmodule
