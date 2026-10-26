.8086

.code
; Purpose: Time repeated packed-BCD and binary-cent additions and save results.
; Inputs: BENCH_ITERATIONS is the common operation count.
; Outputs: AL=0 on success; AL=1 if the result file cannot be written.
; Registers: Preserves BX, CX, DX, SI, DI, BP, DS, and ES; destroys AX.
; Flags: Unspecified.
; ISA: ADD/ADC, INT 1Ah, near CALL/RET, direct, and register operands.
BENCH_RUN PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    PUSH ES
    PUSH DS
    POP ES

    MOV WORD PTR BENCH_ACCUM, 0
    MOV WORD PTR BENCH_ACCUM+2, 0
    MOV WORD PTR BENCH_ACCUM+4, 0
    MOV AH, 00h
    INT 1Ah
    MOV BENCH_START_TICK, DX
    MOV BP, BENCH_ITERATIONS
BENCH_RUN_LOOP_ADD:
    MOV SI, OFFSET BENCH_ADDEND
    MOV DI, OFFSET BENCH_ACCUM
    CALL bcd_add
    DEC BP
    JNZ BENCH_RUN_LOOP_ADD
    MOV AH, 00h
    INT 1Ah
    SUB DX, BENCH_START_TICK
    MOV BENCH_LOOP_TICKS, DX

    MOV WORD PTR BENCH_ACCUM, 0
    MOV WORD PTR BENCH_ACCUM+2, 0
    MOV WORD PTR BENCH_ACCUM+4, 0
    MOV AH, 00h
    INT 1Ah
    MOV BENCH_START_TICK, DX
    MOV BP, BENCH_ITERATIONS
BENCH_RUN_UNROLLED_ADD:
    MOV SI, OFFSET BENCH_ADDEND
    MOV DI, OFFSET BENCH_ACCUM
    CALL BENCH_BCD_ADD_UNROLLED
    DEC BP
    JNZ BENCH_RUN_UNROLLED_ADD
    MOV AH, 00h
    INT 1Ah
    SUB DX, BENCH_START_TICK
    MOV BENCH_UNROLL_TICKS, DX

    MOV AH, 00h
    INT 1Ah
    MOV BENCH_START_TICK, DX
    XOR BX, BX
    XOR DX, DX
    MOV BP, BENCH_ITERATIONS
BENCH_RUN_BINARY_ADD:
    ADD BX, 1
    ADC DX, 0
    DEC BP
    JNZ BENCH_RUN_BINARY_ADD
    MOV BENCH_BINARY_LO, BX
    MOV BENCH_BINARY_HI, DX
    CALL BENCH_BINARY_FORMAT
    MOV AH, 00h
    INT 1Ah
    SUB DX, BENCH_START_TICK
    MOV BENCH_BINARY_TICKS, DX

    CALL BENCH_BUILD_OUTPUT
    CALL BENCH_SAVE_OUTPUT
    POP ES
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    RET
BENCH_RUN ENDP

; Purpose: Add six packed-BCD bytes with the byte loop fully unrolled.
; Inputs: DS:SI points to the addend; DS:DI points to the destination.
; Outputs: Destination receives the sum; CF=1 if a carry leaves byte 5.
; Registers: Preserves all general and segment registers.
; Flags: CF reports overflow; other flags unspecified.
; ISA: ADC, DAA, and register-indirect addressing.
BENCH_BCD_ADD_UNROLLED PROC NEAR
    PUSH AX
    PUSH SI
    PUSH DI
    CLC
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    POP DI
    POP SI
    POP AX
    RET
BENCH_BCD_ADD_UNROLLED ENDP

; Purpose: Convert an unsigned 32-bit cent value to dollars and cents text.
; Inputs: BENCH_BINARY_HI:BENCH_BINARY_LO holds the unsigned cents value.
; Outputs: BENCH_BINARY_TEXT is '$'-terminated; length is in BENCH_BINARY_LENGTH.
;          The input pair is reduced to zero while the decimal digits are extracted.
; Registers: Preserves all general and segment registers.
; Flags: Unspecified.
; ISA: DIV, PUSH/POP, LOOP, STOSB, and based-indexed addressing.
BENCH_BINARY_FORMAT PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    PUSH ES
    PUSH DS
    POP ES
    MOV WORD PTR BENCH_DIGIT_COUNT, 0
    MOV AX, BENCH_BINARY_LO
    OR AX, BENCH_BINARY_HI
    JNZ BENCH_BINARY_DIVIDE
    XOR DX, DX
    PUSH DX
    INC BENCH_DIGIT_COUNT
    JMP BENCH_BINARY_DIGITS_READY
BENCH_BINARY_DIVIDE:
    XOR CX, CX
    MOV BX, 10
BENCH_BINARY_DIVIDE_NEXT:
    MOV AX, BENCH_BINARY_HI
    XOR DX, DX
    DIV BX
    MOV BP, AX
    MOV AX, BENCH_BINARY_LO
    DIV BX
    MOV BENCH_BINARY_HI, BP
    MOV BENCH_BINARY_LO, AX
    PUSH DX
    INC CX
    MOV AX, BENCH_BINARY_LO
    OR AX, BENCH_BINARY_HI
    JNZ BENCH_BINARY_DIVIDE_NEXT
    MOV BENCH_DIGIT_COUNT, CX
BENCH_BINARY_DIGITS_READY:
    MOV BX, OFFSET BENCH_DIGITS
    XOR SI, SI
    MOV CX, BENCH_DIGIT_COUNT
BENCH_BINARY_POP_DIGITS:
    POP AX
    ADD AL, '0'
    MOV [BX+SI], AL
    INC SI
    LOOP BENCH_BINARY_POP_DIGITS

    MOV DI, OFFSET BENCH_BINARY_TEXT
    MOV CX, BENCH_DIGIT_COUNT
    CMP CX, 2
    JA BENCH_BINARY_INTEGER_PART
    MOV AL, '0'
    STOSB
    JMP BENCH_BINARY_POINT
BENCH_BINARY_INTEGER_PART:
    SUB CX, 2
    XOR SI, SI
BENCH_BINARY_INTEGER_DIGIT:
    MOV AL, [BX+SI]
    STOSB
    INC SI
    LOOP BENCH_BINARY_INTEGER_DIGIT
BENCH_BINARY_POINT:
    MOV AL, '.'
    STOSB
    CMP WORD PTR BENCH_DIGIT_COUNT, 1
    JNE BENCH_BINARY_FRACTION_PAIR
    MOV AL, '0'
    STOSB
    XOR SI, SI
    MOV AL, [BX+SI]
    STOSB
    JMP BENCH_BINARY_TERMINATE
BENCH_BINARY_FRACTION_PAIR:
    MOV SI, BENCH_DIGIT_COUNT
    SUB SI, 2
    MOV AL, [BX+SI]
    STOSB
    MOV AL, [BX+SI+1]
    STOSB
BENCH_BINARY_TERMINATE:
    MOV AL, '$'
    STOSB
    SUB DI, OFFSET BENCH_BINARY_TEXT
    DEC DI
    MOV BENCH_BINARY_LENGTH, DI
    POP ES
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
BENCH_BINARY_FORMAT ENDP

; Purpose: Assemble the four benchmark result lines in a DOS-writable buffer.
; Inputs: Tick counts and formatted binary result are in benchmark state.
; Outputs: BENCH_OUTPUT contains text; BENCH_OUTPUT_LENGTH gives its byte count.
; Registers: Preserves all general and segment registers.
; Flags: Unspecified.
; ISA: REP MOVSB, CLD, direct memory addressing, and near CALL/RET.
BENCH_BUILD_OUTPUT PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES
    PUSH DS
    POP ES
    CLD
    MOV DI, OFFSET BENCH_OUTPUT
    MOV SI, OFFSET BENCH_LABEL_LOOP
    CALL BENCH_COPY_TEXT
    MOV AX, BENCH_LOOP_TICKS
    CALL BENCH_APPEND_DECIMAL
    CALL BENCH_APPEND_CRLF
    MOV SI, OFFSET BENCH_LABEL_UNROLLED
    CALL BENCH_COPY_TEXT
    MOV AX, BENCH_UNROLL_TICKS
    CALL BENCH_APPEND_DECIMAL
    CALL BENCH_APPEND_CRLF
    MOV SI, OFFSET BENCH_LABEL_BINARY
    CALL BENCH_COPY_TEXT
    MOV SI, OFFSET BENCH_BINARY_TEXT
    MOV CX, BENCH_BINARY_LENGTH
    REP MOVSB
    MOV SI, OFFSET BENCH_LABEL_TICKS
    CALL BENCH_COPY_TEXT
    MOV AX, BENCH_BINARY_TICKS
    CALL BENCH_APPEND_DECIMAL
    CALL BENCH_APPEND_CRLF
    MOV AX, DI
    SUB AX, OFFSET BENCH_OUTPUT
    MOV BENCH_OUTPUT_LENGTH, AX
    POP ES
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
BENCH_BUILD_OUTPUT ENDP

; Purpose: Copy a NUL-terminated benchmark label to the output buffer.
; Inputs: DS:SI points to the label; ES:DI points to output space; DF=0.
; Outputs: SI and DI advance past the copied label.
; Registers: Preserves AX; SI and DI are outputs.
; Flags: Unspecified.
; ISA: LODSB, STOSB, and register-indirect addressing.
BENCH_COPY_TEXT PROC NEAR
    PUSH AX
BENCH_COPY_TEXT_NEXT:
    LODSB
    OR AL, AL
    JZ BENCH_COPY_TEXT_DONE
    STOSB
    JMP BENCH_COPY_TEXT_NEXT
BENCH_COPY_TEXT_DONE:
    POP AX
    RET
BENCH_COPY_TEXT ENDP

; Purpose: Append an unsigned 16-bit decimal number to the result buffer.
; Inputs: AX is the number; ES:DI points to available output space.
; Outputs: Decimal digits are appended; DI advances past them.
; Registers: Preserves BX, CX, DX; AX and DI are outputs.
; Flags: Unspecified.
; ISA: DIV, PUSH/POP, LOOP, ADD, and STOSB.
BENCH_APPEND_DECIMAL PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    XOR CX, CX
    MOV BX, 10
    OR AX, AX
    JNZ BENCH_APPEND_DECIMAL_DIVIDE
    MOV AL, '0'
    STOSB
    JMP BENCH_APPEND_DECIMAL_DONE
BENCH_APPEND_DECIMAL_DIVIDE:
    XOR DX, DX
    DIV BX
    PUSH DX
    INC CX
    OR AX, AX
    JNZ BENCH_APPEND_DECIMAL_DIVIDE
BENCH_APPEND_DECIMAL_DIGIT:
    POP DX
    ADD DL, '0'
    MOV AL, DL
    STOSB
    LOOP BENCH_APPEND_DECIMAL_DIGIT
BENCH_APPEND_DECIMAL_DONE:
    POP DX
    POP CX
    POP BX
    RET
BENCH_APPEND_DECIMAL ENDP

; Purpose: Append CR/LF to the benchmark output buffer.
; Inputs: ES:DI points to available output space.
; Outputs: CR/LF are appended; DI advances by two.
; Registers: Preserves AX; DI is an output.
; Flags: Unspecified.
; ISA: STOSB and immediate operands.
BENCH_APPEND_CRLF PROC NEAR
    PUSH AX
    MOV AL, 0Dh
    STOSB
    MOV AL, 0Ah
    STOSB
    POP AX
    RET
BENCH_APPEND_CRLF ENDP

; Purpose: Create and write BENCH.OUT, checking the complete write and close.
; Inputs: BENCH_OUTPUT and BENCH_OUTPUT_LENGTH contain the result text.
; Outputs: AL=0 on success or AL=1 on a DOS error or short write.
; Registers: Preserves BX, CX, DX; destroys AX.
; Flags: Unspecified.
; ISA: INT 21h, direct memory addressing, and conditional branches.
BENCH_SAVE_OUTPUT PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    MOV DX, OFFSET BENCH_FILE_NAME
    XOR CX, CX
    MOV AH, 3Ch
    INT 21h
    JC BENCH_SAVE_OUTPUT_FAIL
    MOV BX, AX
    MOV CX, BENCH_OUTPUT_LENGTH
    MOV DX, OFFSET BENCH_OUTPUT
    MOV AH, 40h
    INT 21h
    JC BENCH_SAVE_OUTPUT_CLOSE_FAIL
    CMP AX, CX
    JNE BENCH_SAVE_OUTPUT_CLOSE_FAIL
    MOV AH, 3Eh
    INT 21h
    JC BENCH_SAVE_OUTPUT_FAIL
    XOR AL, AL
    JMP BENCH_SAVE_OUTPUT_RETURN
BENCH_SAVE_OUTPUT_CLOSE_FAIL:
    MOV AH, 3Eh
    INT 21h
BENCH_SAVE_OUTPUT_FAIL:
    MOV AL, 1
BENCH_SAVE_OUTPUT_RETURN:
    POP DX
    POP CX
    POP BX
    RET
BENCH_SAVE_OUTPUT ENDP
