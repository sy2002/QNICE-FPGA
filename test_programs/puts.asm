#include "../monitor/sysdef.asm"
#include "../monitor/monitor.def"

                .ORG    0x8000
                MOVE    TEXT, R8
                RSUB    IO$PUTS, 1
                ABRA    0x0000, 1


TEXT            .ASCII_W    "Hello world!\n"
