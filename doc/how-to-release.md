How to make a new QNICE-FPGA release
====================================

A QNICE-FPGA release is meant to freeze a stable state. It consists of the
following components:

* Synthesizeable VHDL code for all supported platforms, including the correct
  project files for the IDEs

* Emulator for POSIX, VGA (SDL based) and WASM, including a downloadable
  disk image that contains the newest `qbin` files

* Monitor

* Distribution Kit, including bitstreams for all supported platforms

* Native toolchain consisting of the assembler and the `tools` folder

* VBCC toolchain that is known to work with the intricacies of the release
  at hand

* Test programs and demos in assembler and C and a `qbin` folder with binaries
  of a selection of them

* Documentation

* Website at qnice-fpga.com (located in the branch `gh-pages`), including
  correct version numbers and links and an updated WASM emulator

* VERSIONS.txt file that describes the release at hand

* Formal GitHub Release at https://github.com/sy2002/QNICE-FPGA/releases
  including a tag in the form `V<major>.<minor>`.

Working with branches
---------------------

* The QNICE-FPGA project uses the `master` branch as the pointer to the
  latest release. At most, very minor documentation fixes such as typos and
  the likes are committed to `master` between releases.

* All release preparations need to happen in a branch other than `master`.
  Normally, you use the `develop` branch for that.

* After you worked through the following steps, you will have merged your
  working branch such as `develop` into `master`.

Step 1: Rebuild toolchain, ROMs, demos, disk image & emulator
-------------------------------------------------------------

Rebuilding everything is on the one hand an excellent smoke test because if
anything during the rebuild fails, the release cannot proceed. On the other
hand, some components such as the Monitor's ROM are part of actually released
artifact (e.g. bitstreams). Therefore rebuilding everything is a crucial part
of any new release.

Since the PORE message contains the Git commit hash (7 digits), make sure that
you start the release process with this "Step 1" again, if you changed
anything other than documentation. Alternatively, if you know what you are
doing, you can also re-run `pore/compile_pore.sh`.

1. Make sure the PORE texts in the `.txt` are correct, particular when it
   comes to the version number and the date.

2. Run `tools/make-toolchain.sh`

3. In case you updated any component of the VBCC toolchain, you need to
   rebuild the monitor library as well as the standard C library: Follow the
   instructions in "Recompile the libraries" in [doc/vbcc.md](vbcc.md).

4. Use `qbin/make.sh` to rebuild all demo apps.

5. Create a disk image that contains a `qbin` folder with all the demo
   apps. It is a best practice to copy some more folders and files into
   the disk image. The reason is, while the disk image's minimum size is 32MB
   anyway, that some additional "material" to browse while using demo apps
   such as `shell.out` is just nicer than having only some `.out` files
   and nothing else. So we suggest that you add the `test_programs` folder
   to the disk image and call the folder `asm` and that you add the
   `c/test_programs` folder and call the folder `c`. Additionally it makes
   sense to copy the `demos` folder, so that the overall folder structure
   looks like this:
   ```
   asm
   c
   demos
   qbin
   ```
   Hints about how to create a disk image can be found in `doc/emumount.txt`.

6. Upload the disk image to a persistent webhosting location. The default
   location is `http://sy2002x.de/hwdp/`, so that an example full path for
   the disk image is: `http://sy2002x.de/hwdp/qnice_disk_v16.img`

7. In the file `emulator/run-vga.bash`: Adjust the variables `DISK_IMAGE` and
   `HOSTING_LOCATION` to fit your needs. In the file `emulator/qnice.c`,
   adjust the following section, which is the section that downloads the
   very disk image for the WASM emulator:
   ```
   emscripten_run_script("Module.setStatus('Please wait: Downloading 32MB SD card disk image...');");    
   emscripten_wget("https://sy2002x.de/hwdp/qnice_disk_v16.img", "qnice_disk_v16.img");
   emscripten_run_script("statusElement.style.display = 'none';");
   sd_attach("qnice_disk_v16.img");
   ```

8. Make the VGA (SDL) and WASM version of the emulator, as the POSIX shell
   version has been automatically built during `make-toolchain.sh`. You
   need [Emscripten](https://emscripten.org/) to build the WASM emulator.
   ```
   cd emulator
   ./make-vga.bash
   source <your-path-to-emscripten>/emsdk/emsdk_env.sh
   ./make-wasm.bash
   ```

9. Make a ROM of the Q-TRIS arcade version (you will need it in the next
   step): Edit the file `demos/q-tris.asm` and change this line
   ```
   #undef QTRIS_STANDALONE
   ```
   into this line and then assemble it while being in the `demos` folder:
   ```
   #define QTRIS_STANDALONE
   ../assembler/asm q-tris.asm
   ```
   The result will be `demos/q-tris.rom`.

   Important: Do not commit and check in this change to Git. This is just a
   temporary compiler switch for making a ROM that is capable to run stand
   alone, i.e. run from `0x0000` on without using any Monitor functions.


Step 2: Synthesize for all supported platforms
----------------------------------------------

We use Vivado as our default toolchain for Xilinx. Synthesize the following
four variants: Two for Nexys 4 DDR and two for the MEGA65:

File            | Platform    | Description
----------------|-------------|-----------------
M65QTRIS.cor    | MEGA65R2    | Turn the MEGA65 into a Q-TRIS arcade
MEGA65.cor      | MEGA65R2    | QNICE-FPGA for MEGA65
QNICE-V16.bit   | Nexys 4 DDR | QNICE-FPGA for Nexys 4 DDR
QTRIS-V16.bit   | Nexys 4 DDR | Turn the Nexys 4 DDR into a Q-TRIS arcade

Two of the variants are normal QNICE-FPGA versions, where the ROM contains
the Monitor. Make sure that in `vhdl/env1_globals.vhd` the following line
is present:

```
constant ROM_FILE             : string    := "../monitor/monitor.rom";
```

For making the Q-TRIS arcade versions, this line needs to be present:

```
constant ROM_FILE             : string    := "../demos/q-tris.rom";
```

The MEGA65 supports loading so called "Core" files directly from the SD card,
so MEGA65 users do not need a Xilinx toolchain to change the cores of their
machine. A Core file has the `.cor` file extension and is generated from a
compatible bitstream by using `tools/bit2core`. (Refer to section
"Creating Core files" in [doc/README.md](README.md) to learn what a
"compatible" bitstream is.)

Copy the `.bit` and `.cor` files to `dist_kit/bin`. After that, you need to
adjust links and file names:

* [README.md](../README.md): Sections "Getting Started" and "Q-TRIS"

* [hw/README.md](../hw/README.md): Sections "Nexys 4 DDR and Nexys A7" and
  "MEGA65"

Step 3: Thoroughly test the release
-----------------------------------

Since QNICE-FPGA consists of many interdependent components, a stable state
is often non-trivial to achieve. Very thorough testing is necessary. As a
minimum, perform the Smoke Tests described in
[CONTRIBUTING.md](../CONTRIBUTING.md). But it is highly recommended to test
more, particularly around topics you worked on during the release.

If you changed anything regarding the instruction set architecture (ISA) or
the way MMIO works in general and EAE in particular, please be aware that
subtle bugs might have creept into the VBCC toolchain. Perform rigorous tests
and run corresponding test programs from `c/test_programs`.

Test, if synthesis works also on ISE for all platforms and perform some basic
tests using ISE bistreams. But you can discard the generated bitstreams as
they are not part of the release.

Step 4: Update VERSIONS.txt and the documentation
-------------------------------------------------

* Add all relevant news to `VERSIONS.txt`. Make sure, that you stick to the
  style and to the way how this file is structured.

* Mentally work through all the changes you made in the current release and
  think about the implications that they might have to various parts of the
  documentation: ISA/MMIO/device changes (programming card, intro document);
  monitor changes (re-run `monitor/create_documentation.pl`); platforms? (`hw`
  folder); general programming topics?; getting started topics?; etc.

* Are there new constraints (e.g. things that are not "fully" working) or
  did you solve constraints? Update `doc/constraints.md`.

* Update the documentation and re-run LaTeX for the respective documentations
  and check-in the PDF versions of those documents.

Step 5: Merge to the `master` branch
------------------------------------

Merge everything to the `master` branch. This will be the stable branch for
the release.

**Make sure that you add a tag called `V<major>.<minor>` (for example `V1.6`)
to the `master` branch.**

As a final test: Clone the Git repository into a brand new folder and work
through the "Getting Started" tutorial. After that, synthesize the main
platform (currently Nexys 4 DDR) with Vivado. If that works, you can consider
the release as ready.

Step 6: Make a formal GitHub release
------------------------------------

Use the [GitHub release feature](https://github.com/sy2002/QNICE-FPGA/releases)
to attach a formal release to the tag that you have generated in Step 5.
Copy the releasenotes from `VERSIONS.txt` into GitHub's release description
field and make sure that you follow the style of former release notes.

Step 7: Update the website qnice-fpga.com
-----------------------------------------

The QNICE-FPGA website is hosted on GitHub using
[GitHub Pages](https://docs.github.com/en/github/working-with-github-pages/setting-up-a-github-pages-site-with-jekyll)
and the static website generator [Jekyll](https://jekyllrb.com/). The branch
`gh-pages` contains the Jekyll source code of the website.

As a minimum, there are three steps necessary for updating the website:

1. Set the variable `version` in `_config.yml` to the currently active
   version.

2. Review and update `index.md`

3. Update the WebAssembly (WASM) online emulator by following the steps
   described below

### How to update the WebAssembly (WASM) Emulator online:

1. Rebuild the monitor using `monitor/compile_and_distribute.sh`.

2. Make a release build of the WebAssembly Emulator using
   `emulator/make-wasm.bash RELEASE`. (It is important to use the release
   flag, otherwise `qnice.html` will have the wrong format.)

3. Copy these files from the `emulator` folder into a temporary scratch
   folder outside your QNICE-FPGA Git repository: `qnice.css`, `qnice.data`,
   `qnice.html`, `qnice.js` and `qnice.wasm`.

4. Switch the Git repository to the branch `gh-pages`. This branch contains
   the Jekyll source code that GitHub's built-in version of Jekyll translates
   into the website.

5. From your scratch folder, copy the files like described here:

```
qnice.css   => ./public/css/qnice.css
qnice.html  => ./_includes
qnice.data  => .                          (copy to the root of the repository)
qnice.js    => .
qnice.wasm  => .
```
