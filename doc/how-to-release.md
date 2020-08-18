How to make a new QNICE-FPGA release
====================================

WORK-IN-PROGRESS

this should become a checklist style document

rebuild the toolchain using tools/make-toolchain.sh, this includes rebuilding
the Monitor ROM and PORE ROM

update this document on the go while doing the V1.6 release

update VERSIONS.txt

FINAL TOUCHES JUST BEFORE RELEASING on GitHub:

1. Make sure that the PORE texts are correct (for the MEGA65 version as well
as for the standard version)

2. <restructure dist_kit and have .bit and .cor files ready and then update
all the links @TODO, for example in the hw/README.md and doc/README.md,
others? Make all the .bit files with Vivado as it seems to be more reliable
than ISE>

3. <make sure to update the Getting Started section to reflect all the news
about ISE and Vivado and also about the platforms. Have also a MEGA65.bit
and a MEGA65.cor in the dist_kit and mention it in the Getting Started 
section>

DIRECTLY AFTER RELEASE on GitHub: Update Website:

<Update the qnice-fpga.com website: new version number, mention hardware
platforms, mention Vivado>
