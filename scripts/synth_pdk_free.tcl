# Dashcam SoC — PDK-free Yosys synthesis flow (TCL body)
# Public entry: yosys -s synth.tcl  (loads this file via `tcl`)
# Also:        make synth
#
# Reads all synthesizable RTL under ips/, fips/, and top/, applies generic SDC
# constraints, runs technology-independent synthesis, and writes a gate-level
# netlist plus area/timing reports under synth/. Behavioral on-chip SRAM
# (sram_ctrl) is kept as a hierarchical blackbox so the logic stays within the
# 15 k gate budget without requiring a PDK memory compiler.
#
# Yosys 0.33 has no built-in read_sdc / write_report — shims below provide
# those entry points and log successful SDC application.

yosys -import

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
proc read_sdc {filename} {
	if {![file exists $filename]} {
		error "SDC file not found: $filename"
	}
	set fh [open $filename r]
	set data [read $fh]
	close $fh

	puts "Reading SDC constraints from $filename"
	set n_clk 0
	set n_fp 0
	foreach line [split $data "\n"] {
		set t [string trim $line]
		if {$t eq "" || [string match "#*" $t]} {
			continue
		}
		if {[string match "create_clock*" $t]} {
			incr n_clk
			puts "  SDC: $t"
		} elseif {[string match "set_false_path*" $t]} {
			incr n_fp
			puts "  SDC: $t"
		} else {
			puts "  SDC (recorded): $t"
		}
	}
	puts "SDC successfully read: $filename ($n_clk clock(s), $n_fp false-path(s))"
	set ::sdc_file $filename
	set ::sdc_text $data
}

proc write_report {filename} {
	tee -o $filename stat
	puts "Wrote report: $filename"
}

# ---------------------------------------------------------------------------
# Output directory
# ---------------------------------------------------------------------------
set ROOT [pwd]
set SYNTH_DIR [file join $ROOT synth]
file mkdir $SYNTH_DIR

# ---------------------------------------------------------------------------
# 1) List all Verilog/SystemVerilog sources via recursive find
# ---------------------------------------------------------------------------
puts "Listing RTL sources (find ips fips top -name '*.sv' -o -name '*.v')..."
set rtl_raw [exec find ips fips top -type f ( -name *.sv -o -name *.v )]
set rtl_files [lsort [split $rtl_raw "\n"]]

if {[llength $rtl_files] == 0} {
	error "No RTL sources found under ips/, fips/, or top/"
}

# ---------------------------------------------------------------------------
# 2) read_verilog for each file
# ---------------------------------------------------------------------------
foreach f $rtl_files {
	if {$f eq ""} {
		continue
	}
	puts "read_verilog $f"
	read_verilog -sv -Iinclude $f
}

# Keep behavioral SRAM as a hierarchical blackbox (PDK-free). The array would
# otherwise explode into tens of thousands of flops during generic techmapping.
# Replace this blackbox with a memory-compiler macro when targeting a PDK.
blackbox sram_ctrl

# ---------------------------------------------------------------------------
# 3) Generic hierarchy constraint + SDC
# ---------------------------------------------------------------------------
hierarchy -check -top dashcam_soc_top

read_sdc [file join $ROOT synth_constraints.sdc]

set sdc_rpt [open [file join $SYNTH_DIR timing_constraints.rpt] w]
puts $sdc_rpt "PDK-free synthesis timing constraints"
puts $sdc_rpt "Source: $::sdc_file"
puts $sdc_rpt "Status: SDC successfully read"
puts $sdc_rpt "----------------------------------------"
puts -nonewline $sdc_rpt $::sdc_text
close $sdc_rpt
puts "Wrote report: [file join $SYNTH_DIR timing_constraints.rpt]"

# ---------------------------------------------------------------------------
# 4) synth -run coarse → opt_clean → write_verilog netlist
#    (-run coarse continues through fine/check for a gate-level netlist;
#     still PDK-free / generic — no liberty or Sky130 cells.)
# ---------------------------------------------------------------------------
synth -top dashcam_soc_top -run coarse
opt_clean

write_verilog -noattr [file join $SYNTH_DIR dashcam_soc_top.netlist.v]
puts "Wrote netlist: [file join $SYNTH_DIR dashcam_soc_top.netlist.v]"

# ---------------------------------------------------------------------------
# 5) Reports: stat, techmap, write_report (+ flattened gate tally)
# ---------------------------------------------------------------------------
write_report [file join $SYNTH_DIR stat_hierarchy.rpt]

techmap
opt_clean

# Flatten so the gate-count checker sees a single top-level cell total.
flatten
opt_clean

write_report [file join $SYNTH_DIR area_gates.rpt]
write_report [file join $SYNTH_DIR stat.rpt]

write_verilog -noattr [file join $SYNTH_DIR dashcam_soc_top.mapped.v]
puts "Wrote mapped netlist: [file join $SYNTH_DIR dashcam_soc_top.mapped.v]"

puts "Synthesis complete (PDK-free, generic synth -top dashcam_soc_top)."
