; This is a small test program for vasm and vlink, which can be used as an
; alternative to the native QNICE assembler.
;
; Before proceeding, make sure, that you entered "source setenv.source" in
; your terminal, which is located in the in the "c" folder. This sets the path
; and the environment variables correctly.
;
; Enter this to assemble, link and to create a QNICE .out file:
; qvasm vasm_test.asm
;
; done by sy2002 in December 2016

.include "qnice-conv.vasm"
.include "monitor.vdef"

        MOVE        #HELLOWORLD, R8
        SYSCALL     puts, 1
        SYSCALL     crlf, 1
        SYSCALL     exit, 1

HELLOWORLD:
.word "Hello world!\r\nThis is a small but great vasm and vlink test.", 0
