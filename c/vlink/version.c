/* $VER: vlink version.c V0.15a (04.02.16)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2016  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2016 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


/* version/revision */
#define VERSION "0.15a"

#define VERSION_C
#include "vlink.h"


#ifdef AMIGAOS
static const char *_ver = "$VER: " PNAME " " VERSION " " __AMIGADATE__ "\r\n";
#endif



void show_version(void)
{
  printf(PNAME " V" VERSION " (c)1997-2016 by Frank Wille\n"
         "build date: " __DATE__ ", " __TIME__ "\n\n");
}


void show_usage(void)
{
  show_version();

  printf("Usage: " PNAME " [-dhnqrstvwxMRSX] [-B linkmode] [-b targetname] "
         "[-baseoff offset] [-C constructor-type] "
#if 0 /* not implemented */
         "[-D symbol[=value]] "
#endif
         "[-da] [-dc] [-dp] [-EB] [-EL] [-e entrypoint] [-export-dynamic] "
         "[-f flavour] [-fixunnamed] [-F filename] "
         "[-hunkattr secname=value] [-interp path] "
         "[-L library-search-path] [-l library-specifier] [-minalign value] "
         "[-mrel] [-multibase] [-nostdlib] [-o filename] [-osec] "
         "[-rpath path] [-sc] [-sd] [-shared] [-soname name] [-static] "
         "[-T filename] [-Ttext addr] [-textbaserel] "
         "[-tos-flags/fastload/fastram/private/global/super/readable] "
         "[-u symbol] "
         "[-V version] [-y symbol] [-P symbol] "
         "input-files...\n\nOptions:\n"

         "<input-files>     object files and libraries to link\n"
         "-F<file>          read a list of input files from <file>\n"
         "-o<output>        output file name\n"
         "-b<target>        output file format\n"
         "-l<libspec>       link with specified library (static or dynamic)\n"
         "-L<libpath>       add search path for libraries\n"
         "-f<flavour>       add a library flavour\n"
         "-rpath<path>      add search path for dynamic linker\n"
         "-e<entrypoint>    address of program's entry point\n"
         "-interp <path>    set interpreter path (dynamic linker for ELF)\n"
         "-y<symbol>        trace symbol accesses by the linker\n"
         "-P<symbol>        protect symbol from stripping\n"
#if 0 /* not implemented */
         "-D<symbol>[=exp]  define a symbol\n"
#endif
         "-u<symbol>        mark a symbol as undefined\n"
         "-T<script>        use linker script for output file\n"
         "-Ttext <address>  define start address of first section\n"
         "-B<mode>          link mode: static, dynamic, shareable, symbolic\n"
         "-EB/-EL           set big-endian/little-endian mode\n"
         "-V<version>       minimum version of shared object\n"
         "-C<constr.type>   Set type of con-/destructors to scan for\n"
         "-minalign <val>   Minimal section alignment (default 0)\n"
         "-baseoff <offset> offset for base relative relocations\n"
         "-fixunnamed       unnamed sections are named according to their type\n"
         "-nostdlib         don't use default search path\n"
         "-multibase        don't auto-merge base-relative accessed sections\n"
         "-textbaserel      allow base-relative access on code sections\n"
         "-tos-flags <val>  sets TOS flags, refer to documentation\n"
         "-hunkattr <s>=<v> overwrite input section's memory attributes\n"
         "-shared           generate shared object\n"
         "-soname <name>    set real name of shared object\n"
         "-export-dynamic   export all global symbols as dynamic symbols\n"
         "-osec             output each section as an individual file\n"
         "-Rstd             standard relocation table\n"
         "-Radd             relocation table with addends\n"
         "-Rshort           relocation table with short offsets\n"
         "-d                force allocation of common symbols (also -dc,-dp)\n"
         "-da               force allocation of address symbols (PowerOpen)\n"
         "-sc               merge all code sections\n"
         "-sd               merge all data and bss sections\n"
         "-mrel             merge sections with pc-relative references\n"
         "-t                trace file accesses by the linker\n"
         "-M                print segment mappings and symbol values\n"
         "-n                no page alignment\n"
         "-q                keep relocations in the final executable\n"
         "-r                generate relocatable object\n"
         "-s                strip all symbols\n"
         "-S                strip debugging symbols only\n"
         "-x                discard all local symbols\n"
         "-X                discard temporary local symbols\n"
         "-w                suppress warnings\n"
         "-v                print version and implemented targets\n"
         "-h                shows this help text\n"
         );
}
