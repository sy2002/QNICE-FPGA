# This Makefile is used for simulation testing of the cpu_pipeline module.
# Simulation is done using the program ghdl. It may be available
# in your OS repository, otherwise it may be downloaded from here:
# https://github.com/ghdl/ghdl
#
# To run a test, just type e.g. "make test1".

SOURCES  = cpu_constants.vhd
SOURCES += arbiter_regs.vhd
SOURCES += arbiter_mem.vhd
SOURCES += memory.vhd
SOURCES += alu.vhd
SOURCES += registers.vhd
SOURCES += read_instruction.vhd
SOURCES += read_src_operand.vhd
SOURCES += read_dst_operand.vhd
SOURCES += write_result.vhd
SOURCES += cpu_pipeline.vhd
SOURCES += system.vhd
SOURCES += tb_system.vhd

TB       = tb_system
WAVE     = $(TB).ghw
SAVE     = $(TB).gtkw
ROM      = prog.rom
PROG     = prog.asm


#####################################
# Simulation
#####################################

.PHONY: show
show: $(WAVE)
	gtkwave $(WAVE) $(SAVE)

$(WAVE): $(SOURCES) $(ROM)
	ghdl -i --ieee=synopsys $(SOURCES)
	ghdl -m --ieee=synopsys $(TB)
	ghdl -r --ieee=synopsys $(TB) --wave=$(WAVE) --stop-time=200us

test%:
	../../assembler/asm $@.asm
	mv $@.rom $(ROM)
	make show


#####################################
# Cleanup
#####################################

clean:
	rm -rf work-*.cf
	rm -rf $(WAVE)
	rm -rf cpu_pipeline/cpu_pipeline.cache
	rm -rf cpu_pipeline/cpu_pipeline.hw
	rm -rf cpu_pipeline/cpu_pipeline.ip_user_files
	rm -rf cpu_pipeline/cpu_pipeline.runs
	rm -rf cpu_pipeline/cpu_pipeline.sim
	rm -rf vivado.jou
	rm -rf $(ROM)
	rm -rf *.lis
	rm -rf *.out

