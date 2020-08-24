# This is a tcl command script for the Vivado tool chain
read_vhdl { \
   ../../../../vhdl/vga/true_dual_port_ram.vhd \
   ../../../../vhdl/vga/vga_video_ram.vhd \
   ../../../../vhdl/vga/vga_text_mode.vhd \
   ../../../../vhdl/vga/vga_sync.vhd \
   ../../../../vhdl/vga/vga_pixel_counters.vhd \
   ../../../../vhdl/vga/vga_output.vhd \
   ../../../../vhdl/vga/vga_register_map.vhd \
   ../../../../vhdl/vga_multicolour.vhd \
   vga_test.vhd \
}
read_xdc vga_test.xdc
synth_design -top vga_test -part xc7a100tcsg324-1 -flatten_hierarchy none
source debug.tcl
opt_design
place_design
route_design
write_checkpoint -force vga_test.dcp
write_bitstream -force vga_test.bit
report_methodology
report_timing_summary -file timing_summary.rpt
exit

