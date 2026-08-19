# =============================================================================
# Dashcam SoC — OpenROAD floorplan collateral (Sky130 padframe)
# -----------------------------------------------------------------------------
# Version : 1.0.0
# Author  : Dashcam SoC physical-design collateral
# Target  : sky130A / OpenROAD  (FILES ONLY — not executed in this repo)
# Top     : dashcam_soc_top
#
# Core dimensions are derived from the top-level block diagram in
# docs/integration.md / docs/integration_arch.svg:
#   - CSR cluster (cam/dma/irq/iomux/sdspi) + Wishbone fabric
#   - 1 Ki-word sram_ctrl window @ 0x2000_0000
#   - Camera / SPI / GPIO / IRQ pad groups
# Scaled for a compact Sky130 HD core (~15k gate budget from make synth).
# =============================================================================

# --- Units: microns ----------------------------------------------------------
set DIE_WIDTH   2500.0
set DIE_HEIGHT  2500.0
set CORE_MARGIN  220.0   ;# pad ring / IO region depth (Sky130 padframe)

set CORE_LL_X $CORE_MARGIN
set CORE_LL_Y $CORE_MARGIN
set CORE_UR_X [expr {$DIE_WIDTH  - $CORE_MARGIN}]
set CORE_UR_Y [expr {$DIE_HEIGHT - $CORE_MARGIN}]

# --- Die / core / IO regions -------------------------------------------------
# create core and I/O regions for later place-and-route
initialize_floorplan \
  -die_area  "0 0 $DIE_WIDTH $DIE_HEIGHT" \
  -core_area "$CORE_LL_X $CORE_LL_Y $CORE_UR_X $CORE_UR_Y" \
  -site      unithd

# Optional named regions (OpenROAD create_region when available)
# create_region -name CORE_REGION -box $CORE_LL_X $CORE_LL_Y $CORE_UR_X $CORE_UR_Y
# create_region -name IO_REGION   -die_boundary

# --- Tracks / routing layers (Sky130 HD defaults) ----------------------------
# make_tracks metal1 -offset 0.17 -pitch 0.34
# make_tracks metal2 -offset 0.23 -pitch 0.46

# --- IO placement (Sky130 padframe pin order) --------------------------------
# Clock / reset — west edge (near master mux / rst_sync)
place_pin -pin_name clk         -layer met3 -location [list 0 1250] -pin_size {2 2}
place_pin -pin_name rst_n_async -layer met3 -location [list 0 1150] -pin_size {2 2}

# External Wishbone master — west edge (USE_CPU=0 host)
set wb_y 400
foreach pin {
  ext_cyc ext_stb ext_we ext_ack
} {
  place_pin -pin_name $pin -layer met3 -location [list 0 $wb_y] -pin_size {2 2}
  set wb_y [expr {$wb_y + 40}]
}
foreach pin {
  ext_sel\[0\] ext_sel\[1\] ext_sel\[2\] ext_sel\[3\]
} {
  place_pin -pin_name $pin -layer met3 -location [list 0 $wb_y] -pin_size {2 2}
  set wb_y [expr {$wb_y + 30}]
}
# Wide buses placed as bus ranges along west edge
place_pins -hor_layers met3 -ver_layers met2 \
  -min_distance 0.12 \
  -exclude_left 0 -exclude_right 0

# Camera pads — north edge (cam_capture)
place_pin -pin_name cam_vsync      -layer met2 -location [list 600  $DIE_HEIGHT] -pin_size {2 2}
place_pin -pin_name cam_href       -layer met2 -location [list 700  $DIE_HEIGHT] -pin_size {2 2}
place_pin -pin_name cam_pclk_valid -layer met2 -location [list 800  $DIE_HEIGHT] -pin_size {2 2}
set cam_x 900
for {set i 0} {$i < 8} {incr i} {
  place_pin -pin_name "cam_data\[$i\]" -layer met2 \
    -location [list $cam_x $DIE_HEIGHT] -pin_size {2 2}
  set cam_x [expr {$cam_x + 40}]
}

# SPI pads — east edge (sd_spi)
place_pin -pin_name spi_sclk -layer met3 -location [list $DIE_WIDTH 1400] -pin_size {2 2}
place_pin -pin_name spi_mosi -layer met3 -location [list $DIE_WIDTH 1300] -pin_size {2 2}
place_pin -pin_name spi_miso -layer met3 -location [list $DIE_WIDTH 1200] -pin_size {2 2}
place_pin -pin_name spi_cs_n -layer met3 -location [list $DIE_WIDTH 1100] -pin_size {2 2}

# GPIO / IOMUX pads — south edge
set gpio_x 400
for {set i 0} {$i < 8} {incr i} {
  place_pin -pin_name "pad_in\[$i\]"  -layer met2 -location [list $gpio_x 0] -pin_size {2 2}
  place_pin -pin_name "pad_out\[$i\]" -layer met2 -location [list [expr {$gpio_x + 20}] 0] -pin_size {2 2}
  place_pin -pin_name "pad_oe\[$i\]"  -layer met2 -location [list [expr {$gpio_x + 40}] 0] -pin_size {2 2}
  set gpio_x [expr {$gpio_x + 120}]
}

# IRQ — east edge near SPI
place_pin -pin_name irq_out -layer met3 -location [list $DIE_WIDTH 900] -pin_size {2 2}

# --- Macro / soft placement constraints --------------------------------------
# Reserve a soft block for behavioral SRAM (blackboxed in PDK-free synth).
# Coordinates are core-relative estimates from the integration diagram.
# create_voltage_area -name VA_CORE -area "$CORE_LL_X $CORE_LL_Y $CORE_UR_X $CORE_UR_Y"

# Halo / placement density hooks for future PnR
set_placement_padding -global -left 2 -right 2
# set_global_routing_layer_adjustment met1-met5 0.5

# --- Done --------------------------------------------------------------------
puts "INFO: dashcam_soc_top floorplan defined (die ${DIE_WIDTH}x${DIE_HEIGHT} um, core margin ${CORE_MARGIN} um)"
