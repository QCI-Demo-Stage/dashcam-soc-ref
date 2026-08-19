# Dashcam SoC — generic SDC for PDK-free Yosys synthesis
# Primary clock: 100 MHz (10 ns period)
# Async reset is excluded from timed paths (false path into all clocks).

create_clock -period 10.0 -name sys_clk [get_ports clk]

# Story-required async-reset false path (logical reset domain name).
set_false_path -from [get_ports async_reset] -to [all_clocks]

# SoC top port is rst_n_async (async assert / sync deassert via rst_sync).
set_false_path -from [get_ports rst_n_async] -to [all_clocks]
