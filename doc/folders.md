Folder Structure
----------------

### QNICE-FPGA Root Folder

| Folder name   | Description
|---------------|-------------------------------------------------------------
| assembler     | Native QNICE assembler: Main file is `qasm.c`. You usually call it via the script `asm`, which utilizes the C preprocessor (mainly for `#include`, `#define`, `#ifdef`, etc).
| c             | C programming environment based on the [vbcc](http://www.compilers.de/vbcc.html) compiler system. You need to activate `setenv.source` (e.g. via `source`) to use it and then use `qvc <sources> <options>` to compile and link. The subfolder `c/test_programs` contains experiments and demos written in C.
| demos         | QNICE demos written in assembler. Most noteworthy is `q-tris.asm`.
| dist_kit      | Distribution Kit: Contains standard include files for assembler and C as well as ready-made bitstreams and MEGA Core files in the folder `dist_kit/bin`. You might want to set this folder as your default folder for includes. Learn more via [dist_kit/README.md](../dist_kit/README.md)
| doc           | Documentation: See explanation of file and folder structure below.
| emulator      | QNICE Emulator: Learn more via [emulator/README.md](../emulator/README.md)
| hw            | Project files for IDEs to synthesize QNICE-FPGA: Learn more via [hw/README.md](../hw/README.md)
| monitor       | Monitor is the "operating system" of QNICE. Use `compile_and_distribute.sh` to compile it and to update `dist_kit`.
| pore          | Power On & Reset Execution ROM. This code is executed on power on and on each reset of the system, even before any standard operating system like the Monitor is being executed from ROM address 0. PORE is mainly responsible for printing the boot message. Use `compile_pore.sh` to compile it.
| qbin          | Compiled binaries (`.out` format) that can be put on an SD Card. You can load them directly when the Monitor is running using the File/Run command via `F` and `R`.
| test_programs | Experiments, development testbeds, and simple tests written in QNICE assembler.
| tools         | Various tools. Use `make_toolchain.sh` to compile the QNICE toolchain and `qtransfer.c` to transfer data from your Mac or PC to QNICE-FPGA.
| vhdl          | Portable QNICE-FPGA implementation. Subfolder `hw` contains hardware specific VHDL code. [vhdl/hw/MEGA65/README.md](../vhdl/hw/MEGA65/README.md) contains information about MEGA65 specific sources.

### Documentation Folder

| Folder name       | Description
|-------------------|----------------------------------------------------------
| demos             | Screenshots for the web site and for the main README.md showing the demos. Additionally, this folder contains the all-time high-scores for Q-TRIS in [demos/q-tris-highscore.txt](demos/q-tris-highscore.txt).
| github            | Images used for the presentation of the project on GitHub.
| history           | Right now, this folder only contains an old paper (`nice_can.pdf`) about the predecessor of QNICE: The NICE architecture. QNICE - albeit a 16-bit architecture - was created later than the 32-bit NICE architecture.
| intro             | LaTeX source and [PDF version](intro/qnice_intro.pdf) of the QNICE introduction presentation.
| monitor           | The script [create_documentation.pl](../monitor/create_documentation.pl) uses LaTeX to generate the basic Monitor library function documentation in the PDF file [doc.pdf](monitor/doc.pdf).
| programming_card  | LaTeX source and [PDF version](programming_card/programming_card_screen.pdf) of a convenient QNICE Assembler programming card (quick guide).
