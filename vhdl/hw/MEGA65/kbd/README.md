MEGA65 Keyboard Driver
----------------------

Visit [https://mega65.org/](https://mega65.org/) to learn more about the
MEGA65 project.

The MEGA65 Keyboard Driver was written by Paul Gardner-Stephen, who is also
co-founder of the MEGA65 project. It is consisting of the following files:

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

### Modifications

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

Important: Due to the cursor key enhancements, `matrix_col_idx` needs now
to count from 0 to 9 (versus 0 to 8 in the original driver).

### License

Paul licensed the MEGA65 sources under GNU LESSER GENERAL PUBLIC LICENSE,
Version 3, 29 June 2007.
