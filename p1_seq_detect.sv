// Problem 1 -- overlapping "1101" detector (Mealy output)
module p1_seq_detect (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic       bit_i,       // one bit of the stream, per cycle
    output logic       found_o,     // 1-cycle pulse on each completed match
    output logic [7:0] count_o      // matches so far (saturates at 255)
);

  // Each state = the longest prefix of 1101 the stream currently ends with.
  typedef enum logic [1:0] {
    S_IDLE = 2'b00,   // no useful prefix
    S_1    = 2'b01,   // ends with 1
    S_11   = 2'b10,   // ends with 11
    S_110  = 2'b11    // ends with 110
  } state_e;

  state_e state_q, state_d;

  logic [7:0] count_q;

  // 1a -- next state and output logic
  always_comb begin
    state_d = state_q;   // default: hold
    found_o = 1'b0;      // default: no match this cycle

    case (state_q)
      S_IDLE: begin
        if (bit_i) state_d = S_1;
        else       state_d = S_IDLE;
      end

      S_1: begin
        if (bit_i) state_d = S_11;     // "11", not back to start
        else       state_d = S_IDLE;   // "10" is no prefix of 1101
      end

      S_11: begin
        if (bit_i) state_d = S_11;     // still ends with "11"
        else       state_d = S_110;
      end

      S_110: begin
        if (bit_i) begin
          found_o = 1'b1;              // 1101 just completed
          state_d = S_1;               // trailing 1 is a live prefix (overlap)
        end else begin
          state_d = S_IDLE;            // "1100" kills every prefix
        end
      end

      default: begin
        state_d = S_IDLE;
      end
    endcase
  end

  // 1b -- the state register
  always_ff @(posedge clk_i) begin
    if (!rst_ni) state_q <= S_IDLE;
    else         state_q <= state_d;
  end

  // 1c -- saturating match counter
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      count_q <= '0;
    end else if (found_o && (count_q != 8'hFF)) begin
      count_q <= count_q + 8'd1;
    end
  end

  assign count_o = count_q;

endmodule
