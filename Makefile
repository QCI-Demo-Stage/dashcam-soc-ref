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

.PHONY: regs lint sim ip_sim sw synth clean help

help:
	@echo "Dashcam SoC self-check gates:"
	@echo "  make regs   - generate register-map collateral"
	@echo "  make lint   - verilator lint-only (top+leaves) + lint_report.txt"
	@echo "  make sim    - verilator smoke (deletes stale outs first)"
	@echo "  make ip_sim - run per-IP Verilator testbenches"
	@echo "  make sw     - build sw/out/firmware.hex (GCC or stub fallback)"
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

# Leaf IPs linted standalone so uninstantiated modules (e.g. wb_periph_stub)
# still get full -Wall coverage; hierarchical modules are covered via LINT_TOP.
LINT_LEAVES := \
	cam_capture csr_cam csr_dma dma_engine csr_iomux iomux csr_irq irq_ctrl \
	picorv32_wb rst_sync csr_sdspi sd_spi sram_ctrl wb_interconnect wb_periph_stub

LINT_REPORT := $(ROOT)/lint_report.txt

# ---------------------------------------------------------------------------
# lint — synthesizable RTL only; never lint testbenches
# Writes lint_report.txt; fails on any %Warning / %Error (severity >= warning).
# ---------------------------------------------------------------------------
lint:
	@test -n "$(RTL_SV)" || (echo "error: no RTL sources found" >&2; exit 1)
	python3 $(SCRIPTS)/gen_agent_docs.py --check
	@rm -f $(LINT_REPORT)
	@set -e; \
	{ \
	  echo "=== lint top: $(LINT_TOP) ==="; \
	  verilator --lint-only -sv -Wall \
	    --top-module $(LINT_TOP) \
	    -I$(ROOT)/ips \
	    -I$(ROOT)/include \
	    $(RTL_SV); \
	  for m in $(LINT_LEAVES); do \
	    f=$$(echo $(RTL_SV) | tr ' ' '\n' | grep -E "/$${m}\\.(sv|v)$$" | head -n1); \
	    if [ -z "$$f" ]; then echo "error: missing RTL for leaf $$m" >&2; exit 1; fi; \
	    echo "=== lint leaf: $$m ($$f) ==="; \
	    verilator --lint-only -sv -Wall \
	      --top-module $$m \
	      -I$(ROOT)/ips \
	      -I$(ROOT)/include \
	      $$f; \
	  done; \
	  echo "lint: OK (0 Verilator findings across top + leaf RTL)"; \
	} 2>&1 | tee $(LINT_REPORT); \
	if grep -E '%Warning|%Error' $(LINT_REPORT) >/dev/null; then \
	  echo "error: lint_report.txt contains warning/error lines" >&2; \
	  exit 1; \
	fi
	@# Task parse: flag severity >= warning (Verilator %Warning / %Error tokens only)
	@! grep -E '%Warning|%Error' $(LINT_REPORT)

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
# ip_sim — per-IP directed/random Verilator benches (does not replace smoke)
# ---------------------------------------------------------------------------
IP_TBS := cam_capture dma_engine sram_ctrl sd_spi iomux rst_sync wb_periph_stub

ip_sim:
	@for d in $(IP_TBS); do \
		echo "=== ip_sim $$d ==="; \
		$(MAKE) -C $(ROOT)/dv/ip/$$d run ROOT=$(ROOT) || exit 1; \
	done
	@echo "ip_sim: OK"

# ---------------------------------------------------------------------------
# sw — RISC-V toolchain if present, else copy stub / Python stub-hex fallback
#
# Expected output: sw/out/firmware.hex  (also sw/out/firmware.bin)
# Fallback source: sw/stub/firmware_stub.hex  (committed; no GCC required)
# See docs/firmware.md for build/usage details.
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
	@for d in $(IP_TBS); do $(MAKE) -C $(ROOT)/dv/ip/$$d clean ROOT=$(ROOT); done
	$(MAKE) -C $(SW_DIR) clean
