" qnice assembler syntax file
" Language:     QNICE assembler
" Maintainer:   Bernd Ulmann <ulmann@analogparadigm.com>
" Last Change:  20-AUG-2020
" Filenames:    *.asm
" URL:          

"
"  To use this syntax highlighting file just add the following three lines to
" your .vimrc:
"
"syntax on
" au BufRead,BufNewFile *.asm set filetype=qasm
" au! Syntax qasm source <path_to_this_syntax_file>
"
"  On Mac OS X it might be worthwhile to set the environment variable TERM
" to xterm-color to get real colors displayed in vim. :-)
"

syn match Integer '\<-\=\d\+\>'
syn match Integer '\<&-\=\d\+\>'
highlight Integer ctermfg=DarkRed

syn match Hex '\<-\=0[xX][0-9a-f]\+\>'
syn match Hex '\<&-\=0[xX][0-9a-f]\+\>'
syn match Hex '\<-\=0[xX][0-9A-F]\+\>'
syn match Hex '\<&-\=0[xX][0-9A-F]\+\>'
highlight Hex ctermfg=DarkRed

syn match Register '\<-\=[rR][0-9]\+\>'
syn keyword Register SP SR PC
highlight Register ctermfg=Blue

syn region CharacterString start=+\.*\"+ end=+"+ end=+$+
syn region CharacterString start=+s\"+ end=+"+ end=+$+
syn region CharacterString start=+c\"+ end=+"+ end=+$+
highlight CharacterString ctermfg=DarkRed

syn keyword Instruction move add addc sub subc shl shr swap not and or xor
syn keyword Instruction cmp halt rti int incrb decrb
syn keyword Instruction MOVE ADD ADDC SUB SUBC SHL SHR SWAP NOT AND OR XOR
syn keyword Instruction CMP HALT RTI INT INCRB DECRB
highlight Instruction ctermfg=DarkGreen

syn keyword Control abra asub rbra rsub
syn keyword Control ABRA ASUB RBRA RSUB
highlight Control ctermfg=Green

syn keyword Directive org ascii_w ascii_p equ block dw
syn keyword Directive ORG ASCII_W ASCII_P EQU BLOCK DW
highlight Directive ctermfg=Red

syn keyword Macro ret not syscall
syn keyword Macro RET NOT SYSCALL
highlight Macro ctermfg=LightGreen

syn region CommentString start=";" end=+$+
highlight CommentString ctermfg=DarkGray

let b:current_syntax = "qnice"
