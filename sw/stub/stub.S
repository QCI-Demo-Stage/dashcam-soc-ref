# Minimal RV32I no-op boot stub used when the full firmware is not built.
# Assembles to: addi x0,x0,0 ; jal x0,0 (infinite loop at reset PC).
# Prefixed metadata words are injected by gen_stub_hex.py for $readmemh.

    .section .text
    .globl _start
_start:
    addi x0, x0, 0
1:
    jal  x0, 1b
