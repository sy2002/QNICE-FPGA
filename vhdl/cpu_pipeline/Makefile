# This Makefile is used for simulation testing of the cpu_pipeline module.
# Simulation is done using the program ghdl. It may be available
# in your OS repository, otherwise it may be downloaded from here:
# https://github.com/ghdl/ghdl

SOURCES  = arbiter.vhd
SOURCES += memory.vhd
SOURCES += read_instruction.vhd
SOURCES += read_src_operand.vhd
SOURCES += read_dst_operand.vhd
SOURCES += write_result.vhd
SOURCES += cpu_pipeline.vhd
SOURCES += tb_cpu_pipeline.vhd

TB       = tb_cpu_pipeline
WAVE     = $(TB).ghw
SAVE     = $(TB).gtkw


#####################################
# Simulation
#####################################

show: $(WAVE)
	gtkwave $(WAVE) $(SAVE)

$(WAVE): $(SOURCES)
	ghdl -i -fsynopsys $(SOURCES)
	ghdl -m -fsynopsys $(TB)
	ghdl -r -fsynopsys $(TB) --wave=$(WAVE) --stop-time=1us


#####################################
# Cleanup
#####################################

clean:
	rm -rf work-*.cf
	rm -rf $(WAVE)

