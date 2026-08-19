# Verilator smoke simulation
ROOT      ?= $(abspath ../../..)
SMOKE_DIR := $(abspath .)
OUT       := $(SMOKE_DIR)/out
OBJ_DIR   := $(OUT)/obj_dir
BIN       := $(OUT)/sim_smoke

RTL_SV := $(shell find $(ROOT)/ips $(ROOT)/top -type f \( -name '*.sv' -o -name '*.v' \) | sort)
TB_SV  := $(SMOKE_DIR)/tb_verilator_smoke.sv

.PHONY: all run clean

all: $(BIN)

$(BIN): $(TB_SV) $(RTL_SV)
	mkdir -p $(OUT)
	verilator --binary --timing -sv -Wall -Wno-fatal \
		--top-module tb_verilator_smoke \
		-I$(ROOT)/include \
		-Mdir $(OBJ_DIR) \
		-o $(notdir $(BIN)) \
		$(TB_SV) $(RTL_SV)
	cp $(OBJ_DIR)/$(notdir $(BIN)) $(BIN)

run: $(BIN)
	mkdir -p $(OUT)
	cd $(SMOKE_DIR) && $(BIN) 2>&1 | tee $(OUT)/sim.log

clean:
	rm -rf $(OUT)
