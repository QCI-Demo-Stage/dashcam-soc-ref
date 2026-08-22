# Firmware build — RISC-V GCC if present, else copy committed stub / Python fallback.
#
# Expected outputs (always produced; exit status 0):
#   sw/out/firmware.hex   — primary image for CPU-enabled bring-up ($readmemh)
#   sw/out/firmware.bin   — flat binary companion
#
# Fallback source (committed, no toolchain required):
#   sw/stub/firmware_stub.hex

ROOT    := $(abspath ..)
SW_DIR  := $(abspath .)
OUT     := $(SW_DIR)/out
SRC     := $(SW_DIR)/src/firmware.c $(SW_DIR)/src/crt0.c
INCLUDE := $(SW_DIR)/include
STUB_HEX := $(SW_DIR)/stub/firmware_stub.hex

RV64 := $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null)
RV32 := $(shell command -v riscv32-unknown-elf-gcc 2>/dev/null)

.PHONY: all clean stub check

# Primary artifact path documented for the root `make sw` gate.
all: $(OUT)/firmware.hex $(OUT)/firmware.bin
	@test -s $(OUT)/firmware.hex || (echo "error: $(OUT)/firmware.hex missing/empty" >&2; exit 1)
	python3 $(SW_DIR)/tests/test_firmware_hex.py
	@echo "sw: OK -> $(OUT)/firmware.hex"

# Refresh the committed no-op stub (python encodes stub.S machine code).
stub:
	python3 $(SW_DIR)/gen_stub_hex.py -o $(OUT)

check: $(OUT)/firmware.hex
	python3 $(SW_DIR)/tests/test_firmware_hex.py

ifeq ($(RV64)$(RV32),)
# No cross-compiler: copy pre-built stub, else generate via Python.
$(OUT)/firmware.hex $(OUT)/firmware.bin:
	mkdir -p $(OUT)
	@if [ -s $(STUB_HEX) ]; then \
		cp $(STUB_HEX) $(OUT)/firmware.hex; \
		python3 -c 'import pathlib,struct,sys; p=pathlib.Path(sys.argv[1]); words=[int(l,16) for l in p.read_text().split() if l.strip()]; pathlib.Path(sys.argv[2]).write_bytes(b"".join(struct.pack("<I",w) for w in words))' \
			$(OUT)/firmware.hex $(OUT)/firmware.bin; \
		echo "sw: copied fallback stub $(STUB_HEX) -> $(OUT)/firmware.hex"; \
	else \
		python3 $(SW_DIR)/gen_stub_hex.py -o $(OUT); \
	fi
else
ifeq ($(RV64),)
CC      := riscv32-unknown-elf-gcc
OBJCOPY := riscv32-unknown-elf-objcopy
else
CC      := riscv64-unknown-elf-gcc
OBJCOPY := riscv64-unknown-elf-objcopy
endif

$(OUT)/firmware.elf: $(SRC) $(wildcard $(INCLUDE)/*.h)
	mkdir -p $(OUT)
	$(CC) -march=rv32imc -mabi=ilp32 -nostdlib -nostartfiles \
		-I$(INCLUDE) -Os -Ttext=0x20000000 \
		$(SRC) -o $@

$(OUT)/firmware.bin: $(OUT)/firmware.elf
	$(OBJCOPY) -O binary $< $@

$(OUT)/firmware.hex: $(OUT)/firmware.bin
	python3 -c 'import pathlib,struct,sys; d=pathlib.Path(sys.argv[1]).read_bytes(); d+=bytes((-len(d))%4); fmt="<I"; \
p=pathlib.Path(sys.argv[2]); p.write_text("".join("{:08x}\n".format(struct.unpack_from(fmt,d,i)[0]) for i in range(0,len(d),4)))' \
		$(OUT)/firmware.bin $(OUT)/firmware.hex
endif

clean:
	rm -rf $(OUT)
