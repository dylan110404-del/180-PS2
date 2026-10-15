# ECE180 Homework — FSMs and Register Files

**Two problems · Graded for completion · Due: see Gradescope**

This builds directly on the lab. If you have not finished `WORKBOOK.md`, do that first.

---

## How to submit

Graded for **completion**, not correctness of style. Two things:

1. **Push your work to a GitHub repo** and include the repo URL.
2. **Run `make all` and screenshot the output.** Upload the screenshot to Gradescope along with the link to the repo.

What we want to see in the screenshot:

```
=== p1  (rtl/) ===
P1 PASS  (3144 cycles checked, counter saturates correctly)
=== p2  (rtl/) ===
P2 PASS  (reset, r0, dual reads, write enable, bypass on/off)

Both problems ran. Screenshot the P1/P2 lines above.
```

If you get stuck and submit with one problem failing, **still submit** — include a short note in your repo's README saying what you tried and where it broke. That is worth far more to us than a blank submission, and it is how you should report a blocked task in any engineering job.

### Getting started

```bash
verilator --version      # need 5.0+
make p1                  # run one problem
make all                 # run both
make wave2               # dump build/p2/p2.vcd for GTKWave / Surfer
make clean
```

Only `rtl/` needs editing. Do not modify `tb/` — those are the checks.

```
rtl/hw_pkg.sv            shared types. Complete; read it, don't edit it.
rtl/p1_seq_detect.sv     Problem 1
rtl/p2_regfile.sv        Problem 2
tb/                      testbenches — do not edit
```

Same lint rules as the lab: `LATCH`, `WIDTH`, `CASEINCOMPLETE`, `BLKSEQ` and `COMBDLY` are **errors**. If the build stops on one of these, it is telling you about hardware you did not mean to build.

NOTE: If you still have issues with Verilator, use https://www.edaplayground.com/ (make sure to include both the code and testbench on the online editor). 

### Rough effort

| Problem | What it exercises | Est. |
|---|---|---|
| 1 | FSMs, enum state encoding, Mealy vs Moore, saturating counters | 1–1.5 h |
| 2 | Arrays, combinational read / sequential write, data hazards and bypassing | 1.5–2 h |

Each problem's source file carries the full briefing in its header comment. Read it before writing anything — the comments contain the hints, the common mistakes, and the reasoning. This document is the overview.

---

## Problem 1 — Overlapping sequence detector

**File:** `rtl/p1_seq_detect.sv` · **Run:** `make p1`

One bit of a serial stream arrives per clock. Assert `found_o` for exactly one cycle every time the pattern **1101** completes, counting **overlapping** matches. Also maintain a saturating count of matches.

```
  bit stream : 1 1 0 1 1 0 1 0 0 1 1 0 1
  found_o    :       ^     ^           ^       (3 matches)
```

"Overlapping" is where the problem lives. The match ending at position 3 leaves the stream ending in `1` — and that trailing `1` is the start of the *next* possible match. A detector that returns to IDLE after a hit misses the match at position 6 completely.

**The mental model that makes this easy:** each state means *"the longest prefix of 1101 that the stream currently ends with."* Once you phrase it that way, every transition answers itself — after each bit, ask what the stream now ends with. There are four such prefixes worth tracking (none, `1`, `11`, `110`), which is why there are four states and no `S_1101`.

Three sub-parts:

- **1a** — next-state and output logic (the `always_comb` block)
- **1b** — the state register (two lines)
- **1c** — the saturating match counter

The three transitions people get wrong are listed in the file. Work the state diagram out on paper before you type; an FSM debugged in a waveform viewer that was never drawn is a long afternoon.

> **Worth thinking about (not graded):** `found_o` here is a **Mealy** output — it depends on the current state *and* the current input bit, so it is high during the cycle the fourth bit arrives. The alternative is a **Moore** output: add a fifth state meaning "just matched" and drive `found_o` from the state register alone. That is one cycle later, costs a state, and gives you a registered output with no combinational path from `bit_i`. Which would you want if `found_o` drove something on the far side of the chip?

---

## Problem 2 — Register file with write-to-read bypass

**File:** `rtl/p2_regfile.sv` · **Run:** `make p2`

Eight 8-bit registers. Two combinational read ports, one sequential write port. Register 0 is hardwired to zero, RISC-V style. This is the structure in the middle of every CPU datapath you will draw this quarter.

```
      rs1_addr ──▶┌─────────────┐──▶ rs1_data
      rs2_addr ──▶│   8 × 8b    │──▶ rs2_data     combinational read
                  │  registers  │
         wr_i  ──▶└─────────────┘                 sequential write
```

**Reads are combinational, writes are sequential.** This asymmetry is deliberate, not sloppiness: registering the read port would add a cycle of latency to every instruction that reads a register, i.e. all of them. The price you pay instead is that the read path — address decode plus a mux across all eight registers — sits on your critical path. Every real CPU takes this side of the trade.

- **2a** — the write port: reset clears all registers; writes to r0 are discarded; `wr_i.en` is respected
- **2b** — the two combinational read ports, no bypass yet. **Get this passing before starting 2c.**
- **2c** — write-to-read bypass

### What 2c is about

Suppose this cycle the write port is writing 42 into r3, and a read port is simultaneously asking for r3. Without bypass you get the **old** value: the write does not land until the clock edge, and the read is combinational, so it sees stale state.

In a pipelined CPU that is precisely the **data hazard** you will spend a lecture on — an instruction reads a register one cycle before the instruction ahead of it finishes writing it, and silently computes with the wrong operand.

The fix is to detect the collision combinationally and mux in the new data. Three conditions all have to hold, and the testbench checks each one independently:

- the read address matches the write address
- the write is actually enabled
- the register is not r0 (a bypassed read of r0 must still return 0)

`bypass_en_i` lets the testbench check your behaviour both ways, so **both** paths must be right — with bypass off, a colliding read must return the *old* value.

> **Not free.** Bypassing adds a comparator and a mux to a path that was already critical. That is a cycle of latency traded for some delay — which is why it is an architectural decision rather than an obvious win.

> **One Verilog thing to be careful about.** The storage is `xdata_t regs_q [NUM_REGS];` — a *packed* type with an *unpacked* dimension. And the reset loop `for (int i = 0; i < NUM_REGS; i++) regs_q[i] <= '0;` is not a loop in time. It unrolls at elaboration into eight parallel reset connections that all happen on the same edge. If you catch yourself thinking "and then the loop runs again," stop and redraw the hardware.

---

## Checklist

- [ ] An FSM with a default-assignment `always_comb` block and a separate state register
- [ ] Why overlapping detection needs fallback to the longest live prefix, not to IDLE
- [ ] Mealy vs Moore outputs, and the timing/latency trade between them
- [ ] Saturating vs wrapping counters, and when each is right
- [ ] Why a register file reads combinationally and writes sequentially
- [ ] What a read-during-write hazard is and how a bypass mux fixes it, at what cost
- [ ] That a `for` loop in RTL describes parallel structure, not sequential steps

## Going further (ungraded)

- Parameterise Problem 1 on the pattern itself. What changes, and what does that tell you about where FSM complexity actually comes from?
- Rewrite Problem 1 as a Moore machine (add a fifth state, drive `found_o` from the register). Our testbench will fail it on timing — that is the point. Convince yourself *why*, and decide which version you would ship.
- Give Problem 2 a second write port. What new case appears that did not exist with one? (Hint: two writes to the same address on the same edge.)
- **The two-entry skid buffer.** This is the open question the lab's Part 7 ended on: with two entries you can have full throughput *and* an `input_ready_o` that depends only on registered state, with no combinational path from `output_ready_i`. The trick is that because `ready` is registered, the producer learns about a stall one cycle late and sends one more item — the second entry is where it lands, like a car needing a car's length to brake. Build it as a 2-entry FIFO with an occupancy counter, and watch the case where an item arrives and departs on the same edge. Not assigned, but it is the standard building block between pipeline stages in real designs.
