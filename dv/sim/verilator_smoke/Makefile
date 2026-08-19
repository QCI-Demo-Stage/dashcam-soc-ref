# Verilator smoke simulation
ROOT      ?= $(abspath ../../..)
SMOKE_DIR := $(abspath .)
OUT       := $(SMOKE_DIR)/out
OBJ_DIR   := $(OUT)/obj_dir
BIN       := $(OUT)/sim_smoke
SW_DIR    := $(ROOT)/sw

RTL_SV := $(shell find $(ROOT)/ips $(ROOT)/top -type f \( -name '*.sv' -o -name '*.v' \) | sort)
TB_SV  := $(SMOKE_DIR)/tb_verilator_smoke.sv

.PHONY: all run clean

all: $(BIN)

$(BIN): $(TB_SV) $(RTL_SV)
	mkdir -p $(OUT)
	verilator --binary --timing -sv -Wall \
		--top-module tb_verilator_smoke \
		-I$(ROOT)/include \
		-Mdir $(OBJ_DIR) \
		-o $(notdir $(BIN)) \
		$(TB_SV) $(RTL_SV)
	cp $(OBJ_DIR)/$(notdir $(BIN)) $(BIN)

# Hardware smoke + firmware artifact check (CSR sequence parity with sw/).
run: $(BIN)
	mkdir -p $(OUT)
	cd $(SMOKE_DIR) && $(BIN) 2>&1 | tee $(OUT)/sim.log
	$(MAKE) -C $(SW_DIR) all 2>&1 | tee -a $(OUT)/sim.log
	@grep -q '^FW_CHECK_PASS$$' $(OUT)/sim.log || \
		(echo "error: FW_CHECK_PASS not found in sim.log" >&2; exit 1)

clean:
	rm -rf $(OUT)
