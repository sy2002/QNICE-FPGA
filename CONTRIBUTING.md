Contributing to QNICE-FPGA
==========================

Welcome! QNICE-FPGA is a very relaxed project for learning, teaching,
tinkering, and having fun. Contributions are very welcome. There are numerous
ways to contribute to QNICE-FPGA, so even though we will not be able to list
them all, here are some examples:

* Write some cool demo / game / app in QNICE assembly

* Improve the quality of the VHDL code in terms of robustness,
  maintainability, readability, etc. 

* Report a bug

* Fix a bug

* Make a new device for the FPGA System-on-a-Chip

* Port QNICE-FPGA to another FPGA platform

* Make sure that the toolchain including the emulator also runs under Windows

* Tackle one of the challenges in [TODO.txt](https://github.com/sy2002/QNICE-FPGA/blob/develop/TODO.txt)

* Improve the documentation: More tutorials, better structure, etc.

We do not have a lot of rules, neither do we have a detailed written code of
conduct or even written coding guidelines. As written above: This is meant to
be a relaxed project :-) Nevertheless, here are some basics that we expect you
to follow when contributing.

Style
-----

* Ensure consistency: When editing an existing file, no matter if it is code
  or documentation, please stick as closely as you can to the style of the
  existing file. We sometimes do have mixed programming styles in multiple
  files; but we try to be consistent as possible within one file.
  
* Use American English. That means for example: color instead of colour,
  behavior instead of behaviour, favorite instead of favourite,
  center instead of centre, fiber instead of fibre,
  license instead of licence, etc.

Branches
--------

* The `master` branch is meant to be our stable branch. Usually, the master
  branch is identical to the latest [release](https://github.com/sy2002/QNICE-FPGA/releases/).

* The `develop` branch is where most of the development happens. It is
  semi-stable that means that we try to avoid to commit breaking changes that
  take longer than a day or so to develop or to fix.

* There are various `dev-*` and `develop-*` branches: Here we are developing
  larger features that take a while and here it might be, that parts of
  QNICE-FPGA and/or the toolchain are broken, since they are work-in-progress.

### Our best practice about deleting stale branches

* Our general philosophy is: Keep it simple: Delete stale branches.

* As soon as a `dev-*` and `develop-*` branch has been merged into the
  `develop` branch, we tend to keep the original branch for another few
  days. Just in case. But then, we delete it in GitHub.

* We recommend to also delete the local Git versions by using these commands
  inside the local `QNICE-FPGA` folder:
  ```
  git fetch -p
  git branch -d <name of the local branch to delete>
  ```

Pull Requests
-------------

* Make Pull Request for the `develop` branch, unless you have a very good
  reason to use another branch.

* Please use GitHub's features to describe your PR thoroughly.

* If you changed anything at the hardware level (VHDL), make sure you run
  at least the Smoke Test mentioned below. Also, it is recommended that
  for new hardware features you write a test program in `test_programs`.

* If you plan a larger contribution, it might make sense to discuss it
  with us upfront by opening an issue: Describe what you plan to do
  and @mention one or more of the core developers.

* Try to stick to the coding style of the actual file(s) that you are
  modifying.

* At least skim briefly through the documentation before submitting your
  first PR. Below, you find a recommended order of reading.

Smoke Test
----------

### For Hardware Changes

There is more to it than meets the eye: FPGA projects tend to be much more
complex than software projects. So many things can break without being noticed
at a first glance. Therefore, before making a Pull Request (or if you have
direct write access to the repository) before you commit a change that is
larger than "trivial", please run the following Smoke Test, which consists
of a bunch of separate tests on real hardware.

* Run the following test programs. They are all located in the folder
  `test_programs` and you find the expected output described in the comments
  of the program's header:

  - `cpu_test.asm`: CPU including edge cases
  - `eae.asm`: Extended arithmetic element
  - `ise.asm`: Instruction counter and cycle counter
  - `regbank.asm`: All 256 register banks
  - `int_test.asm`: Software interrupts
  - `timer_test.asm`: Timer interrupt test. Enhance this test by routing
    STDOUT to UART while the test runs and then play Q-TRIS.
  - `fancy.asm`: VGA scanline interrupt test

* If you develop for the MEGA65, please additionally run
  `test_programs/MEGA65/hyperram.asm`.

* Test the SD Card, VGA and PS/2 keyboard by copying the folder `qbin` on
  a FAT32 formatted SD card: Then switch STDIN to keyboard and STDOUT to
  VGA and run some of the programs in the `qbin` folder such as
  `qbin/q-tris.out` and `qbin/sierpinski.out`.

* Check the UART by either using `tools/qtransfer` or by switching the
  STDIN and STDOUT to UART and work with QNICE-FPGA for a while via a
  serial terminal.

### For Emulator Changes

* Run the monitor in the simplest form by changing into the `emulator` folder
  and 
  ```
  ./qnice ../monitor/monitor.out
  ```

* Play a short round of Q-TRIS by using `./run-vga.bash` and entering
  `F` `R` `qbin/q-tris.out`.

* Compile for the WebAssembly target using Emscripten and `./make-wasm.bash`
  and check, if the basics are still working. A quick round of Q-TRIS is
  always a good test, as it checks multiple complex circuits. Please note,
  that WebAssembly works quite differently than other platforms, so you
  might need to [port](https://emscripten.org/docs/porting/index.html) your
  changes proactively.

* Make sure that everything works at least under macOS and Linux.

