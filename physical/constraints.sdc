# =============================================================================
# Dashcam SoC — SDC timing constraints (Sky130 collateral)
# Top: dashcam_soc_top
# Primary clock: 100 MHz (10.0 ns) — matches synth_constraints.sdc
# FILES ONLY: intended for future OpenROAD / OpenSTA / OpenLane PnR.
# =============================================================================

# -----------------------------------------------------------------------------
# Corner: TYPICAL (tt, 1.8 V, 25 C) — default analysis view
# Use with: sky130_fd_sc_hd__tt_025C_1v80.lib
# -----------------------------------------------------------------------------

# Primary system clock
create_clock -name clk -period 10.0 [get_ports clk]

# Optional virtual clock for external Wishbone host timing (same period)
create_clock -name virt_wb_clk -period 10.0

# -----------------------------------------------------------------------------
# Async reset — false paths into all clocks
# SoC port: rst_n_async (async assert / sync deassert via rst_sync)
# Logical alias async_reset kept for synthesis-story compatibility.
# -----------------------------------------------------------------------------
set_false_path -from [get_ports rst_n_async] -to [all_clocks]
set_false_path -from [get_ports async_reset] -to [all_clocks]

# -----------------------------------------------------------------------------
# I/O delay budgets (typical corner): 20% of period in, 20% out
# Relative to clk unless noted. External WB host uses virt_wb_clk.
# -----------------------------------------------------------------------------
set_input_delay  -clock clk -max 2.0 [get_ports {cam_vsync cam_href cam_pclk_valid}]
set_input_delay  -clock clk -min 0.5 [get_ports {cam_vsync cam_href cam_pclk_valid}]
set_input_delay  -clock clk -max 2.0 [get_ports cam_data*]
set_input_delay  -clock clk -min 0.5 [get_ports cam_data*]

set_input_delay  -clock clk -max 2.0 [get_ports spi_miso]
set_input_delay  -clock clk -min 0.5 [get_ports spi_miso]
set_input_delay  -clock clk -max 2.0 [get_ports pad_in*]
set_input_delay  -clock clk -min 0.5 [get_ports pad_in*]

set_input_delay  -clock virt_wb_clk -max 2.0 [get_ports {ext_cyc ext_stb ext_we}]
set_input_delay  -clock virt_wb_clk -min 0.5 [get_ports {ext_cyc ext_stb ext_we}]
set_input_delay  -clock virt_wb_clk -max 2.0 [get_ports ext_sel*]
set_input_delay  -clock virt_wb_clk -min 0.5 [get_ports ext_sel*]
set_input_delay  -clock virt_wb_clk -max 2.0 [get_ports ext_adr*]
set_input_delay  -clock virt_wb_clk -min 0.5 [get_ports ext_adr*]
set_input_delay  -clock virt_wb_clk -max 2.0 [get_ports ext_dat_w*]
set_input_delay  -clock virt_wb_clk -min 0.5 [get_ports ext_dat_w*]

set_output_delay -clock clk -max 2.0 [get_ports {spi_sclk spi_mosi spi_cs_n}]
set_output_delay -clock clk -min 0.5 [get_ports {spi_sclk spi_mosi spi_cs_n}]
set_output_delay -clock clk -max 2.0 [get_ports pad_out*]
set_output_delay -clock clk -min 0.5 [get_ports pad_out*]
set_output_delay -clock clk -max 2.0 [get_ports pad_oe*]
set_output_delay -clock clk -min 0.5 [get_ports pad_oe*]
set_output_delay -clock clk -max 2.0 [get_ports irq_out]
set_output_delay -clock clk -min 0.5 [get_ports irq_out]

set_output_delay -clock virt_wb_clk -max 2.0 [get_ports ext_dat_r*]
set_output_delay -clock virt_wb_clk -min 0.5 [get_ports ext_dat_r*]
set_output_delay -clock virt_wb_clk -max 2.0 [get_ports ext_ack]
set_output_delay -clock virt_wb_clk -min 0.5 [get_ports ext_ack]

# Drive / load placeholders (Sky130 pad-scale; refined when PDK is linked)
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]
set_load 0.05 [all_outputs]

# -----------------------------------------------------------------------------
# Corner: SLOW (ss, 1.60 V, 100 C) — setup-critical view
# Use with: sky130_fd_sc_hd__ss_100C_1v60.lib
# Derate clock uncertainty / IO for pessimism; period unchanged (100 MHz target).
# -----------------------------------------------------------------------------
# set_timing_derate -early 0.95
# set_timing_derate -late  1.05
set_clock_uncertainty -setup 0.25 [get_clocks clk]
set_clock_uncertainty -hold  0.10 [get_clocks clk]
# set_input_delay  -clock clk -max 2.5 [all_inputs]
# set_output_delay -clock clk -max 2.5 [all_outputs]

# -----------------------------------------------------------------------------
# Corner: FAST (ff, 1.95 V, -40 C) — hold-critical view
# Use with: sky130_fd_sc_hd__ff_n40C_1v95.lib
# -----------------------------------------------------------------------------
# set_timing_derate -early 1.05
# set_timing_derate -late  0.95
# set_clock_uncertainty -hold 0.15 [get_clocks clk]
# set_input_delay  -clock clk -min 0.2 [all_inputs]
# set_output_delay -clock clk -min 0.2 [all_outputs]

# End of physical/constraints.sdc
