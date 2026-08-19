# Shared Verilator IP test runner
# Usage: make -f ../../common.mk TB=tb_foo RTL_FILES="..." run
ROOT      ?= $(abspath ../../..)
OUT       ?= $(CURDIR)/out
OBJ_DIR   := $(OUT)/obj_dir
BIN       := $(OUT)/sim_ip

.PHONY: all run clean

all: $(BIN)

$(BIN): $(TB).sv $(RTL_FILES)
	mkdir -p $(OUT)
	verilator --binary --timing -sv -Wall -Wno-fatal \
		--top-module $(TB) \
		-Mdir $(OBJ_DIR) \
		-o $(notdir $(BIN)) \
		$(TB).sv $(RTL_FILES)
	cp $(OBJ_DIR)/$(notdir $(BIN)) $(BIN)

run: $(BIN)
	mkdir -p $(OUT)
	cd $(CURDIR) && $(BIN) 2>&1 | tee $(OUT)/sim.log
	@grep -qE '_PASS$$' $(OUT)/sim.log || (echo "error: PASS token missing" >&2; exit 1)

clean:
	rm -rf $(OUT)
