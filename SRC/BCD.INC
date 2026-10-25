.8086

; Purpose: Add six packed-BCD bytes in place and report decimal overflow.
; Inputs: DS:SI points to the addend; DS:DI points to the destination.
; Outputs: Destination receives the sum; CF=1 if a carry leaves byte 5.
; Registers: Preserves all general and segment registers.
; Flags: CF reports overflow; other flags unspecified.
; ISA: ADC, DAA, LOOP, and register-indirect addressing.
bcd_add PROC NEAR
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    MOV CX, 6
    CLC
bcd_add_byte:
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    LOOP bcd_add_byte
    POP DI
    POP SI
    POP CX
    POP AX
    RET
bcd_add ENDP

; Purpose: Subtract six packed-BCD bytes in place and report decimal borrow.
; Inputs: DS:SI points to the subtrahend; DS:DI points to the destination.
; Outputs: Destination receives the difference; CF=1 if it underflows.
; Registers: Preserves all general and segment registers.
; Flags: CF reports underflow; other flags unspecified.
; ISA: SBB, DAS, LOOP, and register-indirect addressing.
bcd_sub PROC NEAR
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    MOV CX, 6
    CLC
bcd_sub_byte:
    MOV AL, [DI]
    SBB AL, [SI]
    DAS
    MOV [DI], AL
    INC SI
    INC DI
    LOOP bcd_sub_byte
    POP DI
    POP SI
    POP CX
    POP AX
    RET
bcd_sub ENDP

; Purpose: Compare two six-byte packed-BCD values from most to least significant.
; Inputs: DS:SI and DS:DI point to the values being compared.
; Outputs: CF=1 when [SI] is less; ZF=1 when the values are equal.
; Registers: Preserves all general and segment registers.
; Flags: CF and ZF report the unsigned comparison; other flags unspecified.
; ISA: CMP, conditional branches, and register-indirect addressing.
bcd_cmp PROC NEAR
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    ADD SI, 5
    ADD DI, 5
    MOV CX, 6
bcd_cmp_byte:
    MOV AL, [SI]
    CMP AL, [DI]
    JNE bcd_cmp_done
    LOOP bcd_cmp_more
    JMP bcd_cmp_done
bcd_cmp_more:
    DEC SI
    DEC DI
    JMP bcd_cmp_byte
bcd_cmp_done:
    POP DI
    POP SI
    POP CX
    POP AX
    RET
bcd_cmp ENDP

; Purpose: Parse decimal text into six packed-BCD bytes.
; Inputs: DS:SI points to CX bytes of text; DS:DI is the six-byte destination.
; Outputs: AL=0/CF=0 on success; AL=1/CF=1 for invalid text or 12-digit overflow.
; Registers: Preserves all general and segment registers except AX; destination may
;            contain a partial value on failure.
; Flags: CF reports validity.
; ISA: SHL/SHR by one, LOOP, conditional branches, and based-indexed addressing.
bcd_parse PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    XOR DX, DX
    XOR BP, BP
    MOV BX, 0
bcd_parse_clear:
    MOV BYTE PTR [DI+BX], 0
    INC BX
    CMP BX, 6
    JB bcd_parse_clear

bcd_parse_next:
    OR CX, CX
    JZ bcd_parse_finish
    MOV AL, [SI]
    CMP AL, '.'
    JE bcd_parse_point
    CMP AL, '0'
    JAE bcd_parse_low_digit
    JMP bcd_parse_early_bad
bcd_parse_low_digit:
    CMP AL, '9'
    JBE bcd_parse_high_digit
    JMP bcd_parse_early_bad
bcd_parse_high_digit:
    CMP DH, 0
    JNE bcd_parse_fraction_digit
    INC BP
    CMP BP, 10
    JBE bcd_parse_integer_count_ok
    JMP bcd_parse_early_bad
bcd_parse_integer_count_ok:
    JMP bcd_parse_digit
bcd_parse_fraction_digit:
    CMP DL, 2
    JB bcd_parse_fraction_count_ok
    JMP bcd_parse_early_bad
bcd_parse_fraction_count_ok:
    INC DL
bcd_parse_digit:
    SUB AL, '0'
    PUSH DX
    MOV DL, AL
    XOR BX, BX
bcd_parse_shift:
    MOV AL, [DI+BX]
    MOV AH, AL
    AND AL, 0Fh
    SHL AL, 1
    SHL AL, 1
    SHL AL, 1
    SHL AL, 1
    OR AL, DL
    MOV [DI+BX], AL
    MOV DL, AH
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
    INC BX
    CMP BX, 6
    JB bcd_parse_shift
    OR DL, DL
    POP DX
    JNZ bcd_parse_bad
    INC SI
    DEC CX
    JMP bcd_parse_next

bcd_parse_early_bad:
    JMP bcd_parse_bad

bcd_parse_point:
    CMP DH, 0
    JNE bcd_parse_bad
    CMP BP, 0
    JE bcd_parse_bad
    MOV DH, 1
    INC SI
    DEC CX
    JMP bcd_parse_next

bcd_parse_finish:
    CMP BP, 0
    JE bcd_parse_bad
    CMP DH, 0
    JE bcd_parse_pad_two
    CMP DL, 0
    JE bcd_parse_bad
    CMP DL, 1
    JE bcd_parse_pad_one
    JMP bcd_parse_ok

bcd_parse_pad_two:
    MOV CX, 2
    JMP bcd_parse_pad
bcd_parse_pad_one:
    MOV CX, 1
bcd_parse_pad:
    PUSH DX
    XOR DL, DL
    XOR BX, BX
bcd_parse_pad_shift:
    MOV AL, [DI+BX]
    MOV AH, AL
    AND AL, 0Fh
    SHL AL, 1
    SHL AL, 1
    SHL AL, 1
    SHL AL, 1
    OR AL, DL
    MOV [DI+BX], AL
    MOV DL, AH
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
    INC BX
    CMP BX, 6
    JB bcd_parse_pad_shift
    OR DL, DL
    POP DX
    JNZ bcd_parse_bad
    LOOP bcd_parse_pad

bcd_parse_ok:
    XOR AL, AL
    CLC
    JMP bcd_parse_return

bcd_parse_bad:
    MOV AL, 1
    STC
bcd_parse_return:
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    RET
bcd_parse ENDP

; Purpose: Format a six-byte packed-BCD value as a decimal amount.
; Inputs: DS:SI points to packed BCD; DS:DI points to a 14-byte output buffer.
; Outputs: Writes a '$'-terminated value with two decimals and no leading integer
;          zeroes (minimum "0.00").
; Registers: Preserves all general and segment registers.
; Flags: Unspecified.
; ISA: SHL/SHR by one and based-indexed addressing.
bcd_format PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    XOR BP, BP
    MOV BX, 5
    MOV DX, 5
bcd_format_integer_byte:
    MOV AL, [SI+BX]
    MOV AH, AL
    AND AH, 0F0h
    SHR AH, 1
    SHR AH, 1
    SHR AH, 1
    SHR AH, 1
    OR BP, BP
    JNZ bcd_format_high_digit
    OR AH, AH
    JZ bcd_format_low_digit
    MOV BP, 1
bcd_format_high_digit:
    ADD AH, '0'
    MOV [DI], AH
    INC DI
bcd_format_low_digit:
    AND AL, 0Fh
    OR BP, BP
    JNZ bcd_format_low_store
    OR AL, AL
    JZ bcd_format_next_byte
    MOV BP, 1
bcd_format_low_store:
    ADD AL, '0'
    MOV [DI], AL
    INC DI
bcd_format_next_byte:
    DEC BX
    DEC DX
    JNZ bcd_format_integer_byte
    OR BP, BP
    JNZ bcd_format_point
    MOV BYTE PTR [DI], '0'
    INC DI
bcd_format_point:
    MOV BYTE PTR [DI], '.'
    INC DI
    MOV AL, [SI]
    MOV AH, AL
    AND AH, 0F0h
    SHR AH, 1
    SHR AH, 1
    SHR AH, 1
    SHR AH, 1
    ADD AH, '0'
    MOV [DI], AH
    INC DI
    AND AL, 0Fh
    ADD AL, '0'
    MOV [DI], AL
    INC DI
    MOV BYTE PTR [DI], '$'
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
bcd_format ENDP
