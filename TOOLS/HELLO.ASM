.8086
.model small
.stack 256

.data
MSG DB 'Hello from DOSBox!$'

.code
; Purpose: Print the Stage 0 greeting and return DOS errorlevel 2.
; Inputs: None.
; Outputs: Writes MSG to standard output.
; Registers: Destroys AX and DX; preserves none.
; Flags: Unspecified on return to DOS.
; ISA: INT 21h/AH=09h string output and AH=4Ch process termination.
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    MOV DX, OFFSET MSG
    MOV AH, 09h
    INT 21h

    MOV AX, 4C02h
    INT 21h
MAIN ENDP
END MAIN
