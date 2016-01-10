#undef RAM_MONITOR
#undef DEBUG
;
#ifdef RAM_MONITOR
                .ORG 0x8000
#else
                .ORG 0x0000                ; The monitor begins at address 0x0000, so the lower 
                                           ; address EPROMs should be mapped into memory by hardware 
                                           ; default on power up.
#endif
;
#include "sysdef.asm"
#include "qmon.asm"
#include "io_library.asm"
#include "string_library.asm"
#include "mem_library.asm"
#include "debug_library.asm"
#include "misc_library.asm"
#include "uart_library.asm"
#include "usb_keyboard_library.asm"
#include "vga_library.asm"
#include "math_library.asm"
;
#include "test_library.asm"
;
QMON$LAST_ADDR  HALT
;
#include "variables.asm"
