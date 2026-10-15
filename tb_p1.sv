// Testbench for Problem 1. Do not edit.
module tb_p1;

  logic       clk_i = 0, rst_ni, bit_i;
  logic       found_o;
  logic [7:0] count_o;
  int         errors = 0;

  always #5 clk_i = ~clk_i;

  p1_seq_detect dut (.*);

  // Golden model: a shift register plus a straight comparison. Slower and
  // bigger than an FSM, but obviously correct -- which is what you want from
  // a reference model.
  logic [3:0] shreg;
  int         exp_count = 0;
  int         seen      = 0;

  task automatic send(logic b, bit expect_found);
    @(negedge clk_i);
    bit_i = b;
    #1;
    // found_o is a Mealy output: it is high DURING the cycle the final bit of
    // the pattern is presented, before the clock edge that consumes it.
    if (found_o !== expect_found) begin
      $display("  FAIL cycle %0d: sent %0b, found_o=%0b expected %0b",
               seen, b, found_o, expect_found);
      errors++;
    end
    @(posedge clk_i); #1;
    if (expect_found && exp_count < 255) exp_count++;  // model saturates too
    if (count_o !== exp_count[7:0]) begin
      $display("  FAIL cycle %0d: count_o=%0d expected %0d",
               seen, count_o, exp_count);
      errors++;
    end
    seen++;
  endtask

  // Drive an arbitrary stream and check against the shift-register model.
  task automatic stream(logic b);
    bit exp;
    exp = (shreg[2:0] == 3'b110) && (b == 1'b1);
    shreg = {shreg[2:0], b};
    send(b, exp);
  endtask

  initial begin
    rst_ni = 0; bit_i = 0; shreg = '0;
    repeat (2) @(posedge clk_i);
    @(negedge clk_i);
    rst_ni = 1;

    if (count_o !== 8'd0) begin
      $display("  FAIL count_o not 0 after reset");
      errors++;
    end

    // --- the worked example from the problem statement ----------------------
    // 1 1 0 1 1 0 1 0 0 1 1 0 1   -> matches at positions 3, 6, 12
    begin
      automatic logic [12:0] pat = 13'b1101101001101;
      for (int i = 12; i >= 0; i--) stream(pat[i]);
    end

    if (exp_count != 3) begin
      $display("  INTERNAL: model expected 3 matches, got %0d", exp_count);
      errors++;
    end

    // --- back-to-back overlaps: 1101101101101 ------------------------------
    begin
      automatic logic [12:0] pat = 13'b1101101101101;
      for (int i = 12; i >= 0; i--) stream(pat[i]);
    end

    // --- long runs of ones, which is where the S_11 self-loop matters ------
    repeat (12) stream(1'b1);
    stream(1'b0);
    stream(1'b1);          // completes 1101

    // --- a long random stream ----------------------------------------------
    repeat (400) stream(logic'($urandom_range(0, 1)));

    // --- reset mid-stream must clear state and the counter ------------------
    @(negedge clk_i);
    rst_ni = 0;
    repeat (2) @(posedge clk_i);
    #1;
    if (count_o !== 8'd0) begin
      $display("  FAIL count_o=%0d after mid-stream reset, expected 0", count_o);
      errors++;
    end
    @(negedge clk_i);
    rst_ni = 1;
    shreg = '0; exp_count = 0;
    begin
      automatic logic [3:0] pat = 4'b1101;
      for (int i = 3; i >= 0; i--) stream(pat[i]);
    end
    if (count_o !== 8'd1) begin
      $display("  FAIL detector did not restart correctly after reset");
      errors++;
    end

    // --- saturation ---------------------------------------------------------
    // Drive 1101 repeatedly (overlapping: "1101101101..." gives a hit every
    // 3 bits) until well past 255 matches, then confirm the count stuck.
    repeat (900) begin
      stream(1'b1); stream(1'b0); stream(1'b1);
    end
    if (count_o !== 8'hFF) begin
      $display("  FAIL count_o=%0d after >255 matches, expected 255 (saturate, do not wrap)", count_o);
      errors++;
    end

    if (errors == 0)
      $display("P1 PASS  (%0d cycles checked, counter saturates correctly)", seen);
    else
      $display("P1 FAIL  (%0d errors)", errors);
    $finish;
  end

  initial begin
    if ($test$plusargs("trace")) begin
      $dumpfile("build/p1.vcd");
      $dumpvars(0, tb_p1);
    end
  end

  initial begin
    #2000000;
    $display("P1 TIMEOUT -- the testbench never reached the end; your design is probably stalled.");
    $fatal(1);
  end

endmodule
