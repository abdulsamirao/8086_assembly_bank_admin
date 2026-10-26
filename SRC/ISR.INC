.8086

.code
ISR_TICKS          DW 0
ISR_OLD_OFFSET     DW 0
ISR_OLD_SEGMENT    DW 0
ISR_HOOKED         DB 0

ISR_TIMEOUT_TICKS  EQU 546

; Purpose: Save the original INT 1Ch vector at program startup.
; Inputs: DS and ES identify the program data segment.
; Outputs: AL=0; the original vector is retained in CS-resident words.
; Registers: Preserves BX, CX, DX, SI, DI, BP, DS, and ES; destroys AX.
; Flags: Unspecified.
; ISA: INT 21h/AH=35h, segment-register moves, and CS override.
ISR_SAVE_VECTOR PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    PUSH DS
    PUSH ES
    MOV AX, 351Ch
    INT 21h
    MOV CS:ISR_OLD_OFFSET, BX
    MOV AX, ES
    MOV CS:ISR_OLD_SEGMENT, AX
    MOV CS:ISR_HOOKED, 0
    POP ES
    POP DS
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    XOR AL, AL
    RET
ISR_SAVE_VECTOR ENDP

; Purpose: Install TIMER_ISR using the vector saved at program startup.
; Inputs: ISR_OLD_OFFSET and ISR_OLD_SEGMENT contain the original vector.
; Outputs: AL=0; INT 1Ch now points to TIMER_ISR.
; Registers: Preserves BX, CX, DX, SI, DI, BP, DS, and ES; destroys AX.
; Flags: Unspecified.
; ISA: INT 21h/AH=25h, segment-register moves, and CS override.
ISR_INSTALL PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    PUSH DS
    PUSH ES
    MOV CS:ISR_TICKS, 0
    PUSH CS
    POP DS
    MOV DX, OFFSET TIMER_ISR
    MOV AX, 251Ch
    INT 21h
    MOV CS:ISR_HOOKED, 1
    POP ES
    POP DS
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    XOR AL, AL
    RET
ISR_INSTALL ENDP

; Purpose: Restore the original INT 1Ch vector if this program installed one.
; Inputs: The saved vector and hook flag are in this code segment.
; Outputs: AL=0; INT 1Ch is restored to its entry-time target.
; Registers: Preserves BX, CX, DX, SI, DI, BP, DS, and ES; destroys AX.
; Flags: Unspecified.
; ISA: INT 21h/AH=25h, segment-register moves, and CS override.
ISR_RESTORE PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    PUSH DS
    PUSH ES
    CMP BYTE PTR CS:ISR_HOOKED, 0
    JE ISR_RESTORE_DONE
    MOV AX, CS:ISR_OLD_SEGMENT
    MOV DS, AX
    MOV DX, CS:ISR_OLD_OFFSET
    MOV AX, 251Ch
    INT 21h
    MOV CS:ISR_HOOKED, 0
ISR_RESTORE_DONE:
    POP ES
    POP DS
    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    XOR AL, AL
    RET
ISR_RESTORE ENDP

; Purpose: Count timer ticks, then chain through the saved INT 1Ch handler.
; Inputs: CPU interrupt frame; saved vector is in this code segment.
; Outputs: Preserves registers and incoming flags before chaining and IRET.
; Registers: Preserves AX; does not modify other registers.
; Flags: Restored before chaining; the chained handler's IRET restores caller flags.
; ISA: CS override, PUSHF/POPF, far indirect CALL, and IRET.
TIMER_ISR PROC FAR
    PUSHF
    PUSH AX
    MOV AX, CS:ISR_TICKS
    INC AX
    MOV CS:ISR_TICKS, AX
    POP AX
    POPF
    PUSHF
    CALL DWORD PTR CS:ISR_OLD_OFFSET
    IRET
TIMER_ISR ENDP
