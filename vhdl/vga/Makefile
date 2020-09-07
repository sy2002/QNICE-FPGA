SOURCES += true_dual_port_ram.vhd
SOURCES += vga_pixel_counters.vhd
SOURCES += vga_register_map.vhd
SOURCES += vga_sync.vhd
SOURCES += vga_output.vhd
SOURCES += vga_text_mode.vhd
SOURCES += vga_video_ram.vhd
SOURCES += ../vga_multicolour.vhd

TB         = tb_vga_text_mode
TB_SOURCES = tb_vga_text_mode.vhd
WAVE       = $(TB).ghw
SAVE       = $(TB).gtkw

.PHONY: sim
sim: $(SOURCES)
	ghdl -i --work=work $(SOURCES) $(TB_SOURCES)
	ghdl -m --ieee=synopsys -fexplicit $(TB)
	ghdl -r -fsynopsys  $(TB) --wave=$(WAVE) --stop-time=200us
	gtkwave $(WAVE) $(SAVE)

