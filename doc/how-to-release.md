How to make a new QNICE-FPGA release
====================================

WORK-IN-PROGRESS

Rebuild toolchain, rebuild monitor library, rebuild VBCC library

Perform "cpu_test.asm" and "The Smoke Test" (describe it) on the hardware and
on the emulator

this should become a checklist style document

rebuild the toolchain using tools/make-toolchain.sh, this includes rebuilding
the Monitor ROM and PORE ROM

update this document on the go while doing the V1.6 release

update VERSIONS.txt

Background info on how the QNICE-FPGA website works:
https://docs.github.com/en/github/working-with-github-pages/setting-up-a-github-pages-site-with-jekyll

how to locally run Jekyll (from GitHub doc, link to GitHub)
`bundle exec jekyll serve`
https://docs.github.com/en/github/working-with-github-pages/testing-your-github-pages-site-locally-with-jekyll


How to update the WebAssembly (WASM) Emulator online:

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
