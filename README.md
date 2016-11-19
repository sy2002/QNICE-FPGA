QNICE-FPGA  16-bit System-on-a-Chip
===================================

![QNICE_Intro_Img](doc/github/intro.jpg)

What is QNICE-FPGA?
-------------------

QNICE-FPGA is a 16-bit computer system build as a fully-fledged
system-on-a-chip in portable VHDL on a FPGA. Specifications:

* 16-bit QNICE CPU featuring 16 registers, 8 of them in 256 register banks
  (learn more in [qnice_intro.pdf](doc/intro/qnice_intro.pdf))
* 32k words ROM (64kB)
* 32k words RAM (64kB)
* UART 115.200 baud, 8-N-1, CTS
* VGA 80x40 character textmode display (640x480 resolution)
* PS/2 keyboard support (mapped to USB on the Nexys4 DDR)
* 4-digit 7-segment display
* 16 hardware toggle switches

The main purpose of QNICE-FPGA is learning, teaching and having fun.

Getting Started
---------------

* Clone GitHub repo: Make sure you have `git` installed on your computer,
  open a Terminal or Command Line. We will automatically create a subdirectory
  called QNICE-FPGA, so navigate to an appropriate folder. Use this command
  to clone the `master` branch of QNICE-FPGA, as the `master` branch always
  contains the latest stable version:
  `git clone https://github.com/sy2002/QNICE-FPGA.git`
  (Hint: It is important, that you clone the repository instead of just
  downloading it as a ZIP. The reason is, that some build scripts rely on
  the fact, that there is an underlying git repository.)

* Hardware: Currently, we develop QNICE-FPGA on a Nexys 4 DDR development
  board, so if you own one, the fastest way of getting started is to
  download the bitstream file `dist_kit/qnice.bit` on the SD card of the
  Nexys board and set the jumpers to read the FPGA configuration from the
  SD card. Do not copy more than one `*.bit` file on the SD card, i.e. do
  not copy `dist_kit/q-tris.bit`, yet. Do empty the "Recycle Bin" or similar
  of your host OS between two `*.bit` copies, so that the Nexys board does not
  accidentally read the `*.bit` from your trash instead of the recent one.

* If you do not own a Nexys 4 DDR board, then use your VHDL development
  environment to synthesize QNICE-FPGA. The root file for the system
  is `vhdl/env1.vhdl`. Make sure that you connect at least the IO pins
  for PS2, VGA, UART and the two switches.

* Attach an "old" USB keyboard supporting boot mode to the board and attach
  a VGA monitor. Attach the USB cable to your desktop computer, so that you
  can setup a serial (terminal) connection between the desktop and the FPGA.

* On your host computer: Open a terminal and head to the root folder of the
  QNICE-FPGA GIT repository.

* Compile the toolchain: You need to have the GNU compiler toolchain
  installed, particularly `gcc` and `make` will be used. Open a terminal in
  the QNICE root folder. Enter the following (it is important, that you `cd`
  into the folder):
  ```
  cd tools
  ./make-toolchain.sh
  ```
  You will be asked several questions. Answer them using the default answers
  by pressing `Enter` instead of answering manually by choosing `y` or `n`.
  When done, `cd ..` back to the QNICE root folder.

* Compile the mandelbrot demo by entering
  `assembler/asm demos/mandel.asm`.

* On OSX, you now have an ASCII file in the clipboard/pasteboard that starts
  with the line `0xA000 0x0F80`. On other operating systems, you might see an
  error message, stating that `pbcopy` is not available. You can savely
  ignore this and manually copy the file `demos/mandel.out` into your
  clipboard/pasteboard.

* Open a serial terminal program, configure it as 115.200 baud, 8-N-1, CTS ON,
  attach the QNICE-FPGA, turn it on, after the bitstream loaded from the SD
  card, connect the terminal program to the serial interface of the FPGA and
  press the reset button. You should see a welcome message and the `QMON>`
  prompt in your terminal program's window.

* Enter `M` then `L` there. You should see something like "Memory/Load".

* Paste the `demos/mandel.out` file to your terminal program's window.
  Alternatively, some terminal programs offer a "Send File" command.
  (If you are using CoolTerm: Please do paste by using CTRL+V on Windows or
  on a Mac by using CMD+V, because using the "Paste" menu command that is
  available via the context menu is not always working properly, when it
  comes to sending data.)

* Press CTRL+E to leave the memory loading routine.

* Enter `C` then `R` and then `A000` in the terminal window. You should
  now see a Mandelbrot output similar to the above-mentioned screenshot in
  your serial terminal window.

* Now set the toggle switches #0 and #1 to '1' (on the Nexys 4 DDR board,
  these are the two rightmost switches). Press the reset button. STDIN/STDOUT
  are now routed from the serial terminal to the PS2/USB keyboard and to
  the VGA screen.

* A reset does not clear the memory, so enter `C` and then `R` and then
  `A000` again. Done! You now should see the same mandelbrot on your
  VGA screen as shown in the above-mentioned screenshot. Use cursor keys
  and page up/down keys to scroll.

More documentation to come.

Q-TRIS
------

Q-TRIS is a Tetris clone and the first game ever developed for QNICE-FPGA.
The rules of the game are very close to the "official" Tetris rules as
they can be found on 
[http://tetris.wikia.com/wiki/Tetris_Guideline](http://tetris.wikia.com/wiki/Tetris_Guideline).

![Q_TRIS_IMG](doc/demos/demo_q_tris.jpg)

Clearing a larger amount of lines at once (e.g. Double, Triple, Q-TRIS)
leads to much higher scores. Clearing a certain treshold of lines leads to the
next level. The game speed increases from level to level. If you clear
1.000 lines, then you win the game.

Q-TRIS uses the PS2/USB keyboard and VGA, no matter how STDIN/STDOUT
are routed. All speed calculations are based on a 50 MHz CPU that is equal
to the CPU revision contained in release V1.3.

The game can run stand-alone, i.e. instead of the Monitor as the "ROM"
for the QNICE-FPGA: Just use `dist_kit/q-tris.bit` instead of the
above-mentioned `dist_kit/qnice.bit`. Or, you can run it regularly as an app
within the Monitor environment. In this case, compile it and then load it with
the `M L` command sequence and start Q-TRIS using the address `0x8000`.

Programming in C
----------------

Thanks to Volker Barthelmann and his [vbcc](http://www.compilers.de/vbcc.html)
compiler system, QNICE also features a C programming environment. This is how
you can get started:

* The vbcc toolchain is automatically build, when you follow the
  above-mentioned "Getting Started" guide and run `make-toolchain.sh`.

* Open a terminal and from the QNICE root folder enter `cd c`.

* Let's compile a small shell, that can be used to browse the microSD Card
  of the FPGA board. Enter the following commands:
  ```
  source setenv.source
  cd test_programs
  qvc shell.c -c99
  ```

* Just as described above in "Getting Started", on macOS you now have the
  excutable in your clipboard so that you can use the `M` `L` Monitor
  command to load the shell. On other operating systems you can proceed
  manually.

* Run the shell using `C` `R` `8000`.

* Browse the microSD Card using `dir`, `cd`, `cat` and `cathex` commands.
  Exit the shell using `exit`.
