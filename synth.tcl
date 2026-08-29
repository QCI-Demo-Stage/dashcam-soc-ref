# Dashcam SoC — PDK-free Yosys synthesis script (public entry)
#
# Usage (from repository root):
#   yosys -s synth.tcl
#   make synth
#
# Yosys 0.33 distinguishes `-s` (command script) from `-c` (pure TCL). This
# file is the `-s` entry required by CI. The TCL body in
# scripts/synth_pdk_free.tcl performs the Synthesis Collateral flow:
#
#   1. Recursive find of ips/**, fips/**, and top/** (*.sv / *.v)
#   2. read_verilog -sv -Iinclude for each file
#   3. hierarchy -check -top dashcam_soc_top  (+ blackbox sram_ctrl)
#   4. read_sdc synth_constraints.sdc          (shim; logs success)
#   5. synth -top dashcam_soc_top -run coarse
#   6. opt_clean ; write_verilog synth/*.netlist.v
#   7. stat / techmap / write_report → synth/*.rpt (gate budget ≤ 15 k)
#
# See docs/synthesis.md for reports, SDC, and PDK extension notes.

tcl scripts/synth_pdk_free.tcl
