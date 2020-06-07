MEGA65 Hardware Drivers
-----------------------

Visit [https://mega65.org/](https://mega65.org/) to learn more about the
MEGA65 project.

The MEGA65 Hardware Drivers were written by Paul Gardner-Stephen, who is also
co-founder of the MEGA65 project.

The GitHub repository of the MEGA65 Core is here:
[https://github.com/MEGA65/mega65-core](https://github.com/MEGA65/mega65-core).

### License

Paul licensed the MEGA65 sources under GNU LESSER GENERAL PUBLIC LICENSE,
Version 3, 29 June 2007.


### Keyboard Driver

The MEGA65 keyboard driver is consisting of the following files:

```
kb_matrix_ram.vhdl
matrix_to_ascii.vhdl
mega65kbd_to_matrix.vhdl
```

I (sy2002) took them on April, 18 2020 from the
[MEGA65 GitHub Core Repo](https://github.com/MEGA65/mega65-core)
using branch `165-hyperram`.
[This link points to the relevant Commit #84e8394](https://github.com/MEGA65/mega65-core/tree/84e8394524814a4ac34e8722211642f0cabdaf31/src/vhdl),
in case you need to get these files from the original source.

#### Modifications

* Added support for the CURSOR LEFT and CURSOR UP keys (they appear like the shifted versions of RIGHT/DOWN)
* Added support for MEGA65 key + CURSOR LEFT/CURSOR UP ($dc/$db)
* The asterisk (*) key is now transmitted without shift
* Shift + asterisk sends $e3
* The British Pound (£) key now works without alt
* Arrow left/shift arrow left are now $ea/$eb
* Arrow up/shift arrow up are now $e0/$e8
* The pi symbol (MEGA65 + arrow up) sends $ec
* MEGA65 + 0 => degree symbol (°)
* Tab stays tab, also under shift, ctrl and alt
* Commented out debugtools and report outputs
* bugfix: did put suppress_key_glitches on sensitivity list of process

Important: Due to the cursor key enhancements, `matrix_col_idx` needs now
to count from 0 to 9 (versus 0 to 8 in the original driver).

### HyperRAM Driver

The MEGA65 HyperRAM driver consists of the file `hyperram.vhdl`.

I took it on June, 6 2020 from the
[MEGA65 GitHub Core Repo](https://github.com/MEGA65/mega65-core)
using branch `165-hyperram`.
[This link points to the relevant Commit #a100863](https://github.com/MEGA65/mega65-core/blob/a100863955f5feb67949f872cbb112d81aa7ce1e/src/vhdl/hyperram.vhdl),
in case you need to get the file from the original source.

#### Modifications

* Made it stand-alone by including the `debugtools` and `cputypes` 
  dependencies into `hyperram.vhdl`: Two new packages at the top of the file:
  `package cache_row_type` and `package `debugtools`.
