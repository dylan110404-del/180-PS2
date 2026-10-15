# ============================================================================
# ECE180 Verilog homework
#
#   make p1 / p2          build + run one problem
#   make all              run both  <-- screenshot THIS for Gradescope
#   make wave1/2          run and dump build/pN/pN.vcd
#   make clean
# ============================================================================

VERILATOR ?= verilator
RTL       ?= rtl

VFLAGS = --binary --timing -j 0 \
         -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-VARHIDDEN \
         -Wno-fatal \
         -Werror-LATCH -Werror-WIDTH -Werror-CASEINCOMPLETE \
         -Werror-BLKSEQ -Werror-COMBDLY -Werror-MULTIDRIVEN \
         -Werror-IMPLICIT -Werror-PINMISSING \
         --Mdir build/$(T) -o sim

PKG = $(RTL)/hw_pkg.sv

.PHONY: all clean p1 p2

all: p1 p2
	@echo ""
	@echo "Both problems ran. Screenshot the P1/P2 lines above."

p1: ; @$(MAKE) --no-print-directory run T=$@ SRC="$(RTL)/p1_seq_detect.sv"
p2: ; @$(MAKE) --no-print-directory run T=$@ SRC="$(PKG) $(RTL)/p2_regfile.sv"

wave%: ; @$(MAKE) --no-print-directory p$* TRACE=1

run:
	@mkdir -p build/$(T)
	@echo "=== $(T)  ($(RTL)/) ==="
	@$(VERILATOR) $(VFLAGS) $(if $(TRACE),--trace --trace-structs) \
	    --top-module tb_$(T) $(SRC) tb/tb.vlt tb/tb_$(T).sv \
	    > build/$(T)/compile.log 2>&1 \
	  || { grep -E '%(Error|Warning)' build/$(T)/compile.log | head -40; \
	       echo "  (full log: build/$(T)/compile.log)"; exit 1; }
	@grep -E '%Warning' build/$(T)/compile.log | head -20 || true
	@./build/$(T)/sim $(if $(TRACE),+trace) | grep -v '\$$finish'

clean:
	@rm -rf build *.vcd
