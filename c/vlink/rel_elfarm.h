/* $VER: vlink rel_elfarm.h V0.10a (05.11.06)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2006  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2006 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#ifndef REL_ELFARM_H
#define REL_ELFARM_H

#define R_ARM_NONE                  0
#define R_ARM_PC24                  1
#define R_ARM_ABS32                 2
#define R_ARM_REL32                 3
#define R_ARM_PC13                  4
#define R_ARM_LDR_PC_G0             4
#define R_ARM_ABS16                 5
#define R_ARM_ABS12                 6
#define R_ARM_THM_ABS5              7
#define R_ARM_ABS8                  8
#define R_ARM_SBREL32               9
#define R_ARM_THM_PC22              10
#define R_ARM_THM_CALL              10
#define R_ARM_THM_PC8               11
#define R_ARM_BREL_ADJ              12
#define R_ARM_SWI24                 13
#define R_ARM_THM_SWI8              14
#define R_ARM_XPC25                 15
#define R_ARM_THM_XPC25             16
#define R_ARM_TLS_DTPMOD32          17
#define R_ARM_TLS_DTPOFF32          18
#define R_ARM_TLS_TPOFF32           19
#define R_ARM_COPY                  20
#define R_ARM_GLOB_DAT              21
#define R_ARM_JUMP_SLOT             22
#define R_ARM_RELATIVE              23
#define R_ARM_GOTOFF32              24
#define R_ARM_BASE_PREL             25
#define R_ARM_GOT_BREL              26
#define R_ARM_PLT32                 27
#define R_ARM_CALL                  28
#define R_ARM_JUMP24                29
#define R_ARM_THM_JUMP24            30
#define R_ARM_BASE_ABS              31
#define R_ARM_ALU_PCREL_7_0         32
#define R_ARM_ALU_PCREL_15_8        33
#define R_ARM_ALU_PCREL_23_15       34
#define R_ARM_LDR_SBREL_11_0        35
#define R_ARM_ALU_SBREL_19_12       36
#define R_ARM_ALU_SBREL_27_20       37
#define R_ARM_RELABS32              38
#define R_ARM_TARGET1               38
#define R_ARM_ROSEGREL32            39
#define R_ARM_SBREL31               39
#define R_ARM_V4BX                  40
#define R_ARM_TARGET2               41
#define R_ARM_PREL31                42
#define R_ARM_MOVW_ABS_NC           43
#define R_ARM_MOVT_ABS              44
#define R_ARM_MOVW_PREL_NC          45
#define R_ARM_MOVT_PREL             46
#define R_ARM_THM_MOVW_ABS_NC       47
#define R_ARM_THM_MOVT_ABS          48
#define R_ARM_THM_MOVW_PREL_NC      49
#define R_ARM_THM_MOVT_PREL         50
#define R_ARM_THM_JUMP19            51
#define R_ARM_THM_JUMP6             52
#define R_ARM_THM_ALU_PREL_11_0     53
#define R_ARM_THM_PC12              54
#define R_ARM_ABS32_NOI             55
#define R_ARM_REL32_NOI             56
#define R_ARM_ALU_PC_G0_NC          57
#define R_ARM_ALU_PC_G0             58
#define R_ARM_ALU_PC_G1_NC          59
#define R_ARM_ALU_PC_G1             60
#define R_ARM_ALU_PC_G2             61
#define R_ARM_LDR_PC_G1             62
#define R_ARM_LDR_PC_G2             63
#define R_ARM_LDRS_PC_G0            64
#define R_ARM_LDRS_PC_G1            65
#define R_ARM_LDRS_PC_G2            66
#define R_ARM_LDC_PC_G0             67
#define R_ARM_LDC_PC_G1             68
#define R_ARM_LDC_PC_G2             69
#define R_ARM_ALU_SB_G0_NC          70
#define R_ARM_ALU_SB_G0             71
#define R_ARM_ALU_SB_G1_NC          72
#define R_ARM_ALU_SB_G1             73
#define R_ARM_ALU_SB_G2             74
#define R_ARM_LDR_SB_G0             75
#define R_ARM_LDR_SB_G1             76
#define R_ARM_LDR_SB_G2             77
#define R_ARM_LDRS_SB_G0            78
#define R_ARM_LDRS_SB_G1            79
#define R_ARM_LDRS_SB_G2            80
#define R_ARM_LDC_SB_G0             81
#define R_ARM_LDC_SB_G1             82
#define R_ARM_LDC_SB_G2             83
#define R_ARM_MOVW_BREL_NC          84
#define R_ARM_MOVT_BREL             85
#define R_ARM_MOVW_BREL             86
#define R_ARM_THM_MOVW_BREL_NC      87
#define R_ARM_THM_MOVT_BREL         88
#define R_ARM_THM_MOVW_BREL         89
#define R_ARM_PLT32_ABS             94
#define R_ARM_GOT_ABS               95
#define R_ARM_GOT_PREL              96
#define R_ARM_GOT_BREL12            97
#define R_ARM_GOTOFF12              98
#define R_ARM_GOTRELAX              99
#define R_ARM_THM_JUMP11            102
#define R_ARM_THM_JUMP8             103
#define R_ARM_TLS_GD32              104
#define R_ARM_TLS_LDM32             105
#define R_ARM_TLS_LDO32             106
#define R_ARM_TLS_IE32              107
#define R_ARM_TLS_LE32              108
#define R_ARM_TLS_LDO12             109
#define R_ARM_TLS_LE12              110
#define R_ARM_TLS_IE12GP            111

#endif
