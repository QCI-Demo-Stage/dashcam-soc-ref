# Dashcam SoC — root self-check contract
# Gates: make regs && make lint && make sim && make sw && make synth

ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
OUT       := $(ROOT)/out
SCRIPTS   := $(ROOT)/scripts
SMOKE_DIR := $(ROOT)/dv/sim/verilator_smoke
SMOKE_OUT := $(SMOKE_DIR)/out
SW_DIR    := $(ROOT)/sw

# Synthesizable RTL only (never testbenches)
RTL_SV := $(shell find $(ROOT)/ips $(ROOT)/top -type f \( -name '*.sv' -o -name '*.v' \) | sort)

.PHONY: regs lint sim sw synth clean help

help:
	@echo "Dashcam SoC self-check gates:"
	@echo "  make regs   - generate register-map collateral"
	@echo "  make lint   - verilator lint-only + AGENTS.md freshness"
	@echo "  make sim    - verilator smoke (deletes stale outs first)"
	@echo "  make sw     - build firmware image (toolchain or Python fallback)"
	@echo "  make synth  - yosys generic synth -top dashcam_soc_top"

# ---------------------------------------------------------------------------
# regs — run reggen.py; place SystemRDL + Verilog headers into include/
# ---------------------------------------------------------------------------
regs:
	@mkdir -p $(ROOT)/include $(ROOT)/sw/include $(ROOT)/docs
	python3 $(SCRIPTS)/csv_validation.py
	python3 $(SCRIPTS)/reggen.py
	@test -f $(ROOT)/include/regs_defines.vh || \
		(echo "error: missing include/regs_defines.vh after reggen" >&2; exit 1)
	@test -f $(ROOT)/include/cam_csr.rdl || \
		(echo "error: missing include/*_csr.rdl after reggen" >&2; exit 1)
	python3 $(SCRIPTS)/gen_agent_docs.py

# Optional: make lint MODULE=address_decode.v  (lint a specific RTL top)
MODULE ?=
LINT_TOP := $(if $(MODULE),$(basename $(notdir $(MODULE))),dashcam_soc_top)

# ---------------------------------------------------------------------------
# lint — synthesizable RTL only; never lint testbenches
# ---------------------------------------------------------------------------
lint:
	@test -n "$(RTL_SV)" || (echo "error: no RTL sources found" >&2; exit 1)
	python3 $(SCRIPTS)/gen_agent_docs.py --check
	verilator --lint-only -sv -Wall -Wno-fatal \
		--top-module $(LINT_TOP) \
		-I$(ROOT)/ips \
		-I$(ROOT)/include \
		$(RTL_SV)

# ---------------------------------------------------------------------------
# sim — delete stale outputs, then build/run; require SMOKE_PASS + PPM
# ---------------------------------------------------------------------------
sim:
	rm -rf $(SMOKE_OUT)
	mkdir -p $(SMOKE_OUT)
	$(MAKE) -C $(SMOKE_DIR) run ROOT=$(ROOT)
	@grep -q '^SMOKE_PASS$$' $(SMOKE_OUT)/sim.log || \
		(echo "error: SMOKE_PASS not found in sim.log" >&2; exit 1)
	@test -f $(SMOKE_OUT)/frame_0000.ppm || \
		(echo "error: missing $(SMOKE_OUT)/frame_0000.ppm" >&2; exit 1)
	@echo "sim: OK (SMOKE_PASS + frame_0000.ppm)"

# ---------------------------------------------------------------------------
# sw — RISC-V toolchain if present, else Python stub-hex fallback
# ---------------------------------------------------------------------------
sw:
	$(MAKE) -C $(SW_DIR) all

# ---------------------------------------------------------------------------
# synth — PDK-free yosys generic synthesis
# ---------------------------------------------------------------------------
synth:
	@mkdir -p $(OUT)
	@test -n "$(RTL_SV)" || (echo "error: no RTL sources found" >&2; exit 1)
	yosys -q -p "read_verilog -sv -I$(ROOT)/include $(RTL_SV); synth -top dashcam_soc_top; write_verilog $(OUT)/dashcam_soc_top.netlist.v"
	@test -f $(OUT)/dashcam_soc_top.netlist.v || \
		(echo "error: netlist not written" >&2; exit 1)
	@echo "synth: wrote $(OUT)/dashcam_soc_top.netlist.v"

clean:
	rm -rf $(OUT) $(SMOKE_OUT)
	$(MAKE) -C $(SMOKE_DIR) clean ROOT=$(ROOT)
	$(MAKE) -C $(SW_DIR) clean
