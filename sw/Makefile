# Firmware build — try RISC-V GCC, else Python stub-hex fallback
ROOT    := $(abspath ..)
SW_DIR  := $(abspath .)
OUT     := $(SW_DIR)/out
SRC     := $(SW_DIR)/src/main.c
INCLUDE := $(SW_DIR)/include

RV64 := $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null)
RV32 := $(shell command -v riscv32-unknown-elf-gcc 2>/dev/null)

.PHONY: all clean

all: $(OUT)/firmware.hex $(OUT)/firmware.bin

ifeq ($(RV64)$(RV32),)
# No cross-compiler: portable Python stub
$(OUT)/firmware.hex $(OUT)/firmware.bin:
	mkdir -p $(OUT)
	python3 $(SW_DIR)/gen_stub_hex.py -o $(OUT)
else
ifeq ($(RV64),)
CC := riscv32-unknown-elf-gcc
else
CC := riscv64-unknown-elf-gcc
endif

$(OUT)/firmware.elf: $(SRC) $(wildcard $(INCLUDE)/*.h) $(SW_DIR)/src/crt0.c
	mkdir -p $(OUT)
	$(CC) -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
		-I$(INCLUDE) -Os -Ttext=0x20000000 \
		$(SW_DIR)/src/crt0.c $(SRC) -o $@

$(OUT)/firmware.bin: $(OUT)/firmware.elf
	$(CC:%gcc=%objcopy) -O binary $< $@

$(OUT)/firmware.hex: $(OUT)/firmware.bin
	python3 -c 'import pathlib,struct,sys; d=pathlib.Path(sys.argv[1]).read_bytes(); d+=bytes((-len(d))%4); \
p=pathlib.Path(sys.argv[2]); p.write_text("".join(f"{struct.unpack_from(\"<I\",d,i)[0]:08x}\n" for i in range(0,len(d),4)))' \
		$(OUT)/firmware.bin $(OUT)/firmware.hex
endif

clean:
	rm -rf $(OUT)
