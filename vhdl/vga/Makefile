SOURCES += ../tools.vhd
SOURCES += ../env1_globals.vhd

SOURCES += ../daisy_chain.vhd
SOURCES += asymmetric_true_dual_port_ram.vhd
SOURCES += true_dual_port_ram.vhd
SOURCES += vga_blockram_with_byte_enable.vhd
SOURCES += vga_pixel_counters.vhd
SOURCES += vga_register_map.vhd
SOURCES += vga_sync.vhd
SOURCES += vga_output.vhd
SOURCES += vga_text_mode.vhd
SOURCES += vga_video_ram.vhd
SOURCES += vga_scanline.vhd
SOURCES += vga_sprite.vhd
SOURCES += ../vga_multicolor.vhd


#TB         = tb_vga_text_mode
#TB_SOURCES = tb_vga_text_mode.vhd
#TB         = tb_vga_sprite
#TB_SOURCES = tb_vga_sprite.vhd
TB         = tb_vga_multicolor
TB_SOURCES = tb_vga_multicolor.vhd

WAVE       = $(TB).ghw
SAVE       = $(TB).gtkw

.PHONY: sim
sim: $(SOURCES)
	ghdl -i --work=work $(SOURCES) $(TB_SOURCES)
	ghdl -m --ieee=synopsys -fexplicit $(TB)
	ghdl -r --ieee=synopsys $(TB) --wave=$(WAVE) --max-stack-alloc=1024 --stop-time=55us
	gtkwave $(WAVE) $(SAVE)

