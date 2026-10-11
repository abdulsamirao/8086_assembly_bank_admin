.8086
.model small
.stack 256

.data
BUFFER DB 10, 0, 10 DUP(0)
RESULT DB 'RESULT: $'

.code
; Purpose: Prove redirected single-key and buffered-line input.
; Inputs: Standard input supplies one key followed by a DOS buffered line.
; Outputs: Echoes the buffered line and prints it again to standard output.
; Registers: Destroys AX, BX, DX, SI, DS, and ES; preserves none.
; Flags: Unspecified on return to DOS.
; ISA: INT 21h/AH=08h, AH=0Ah, AH=09h, and AH=02h console services.
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

    MOV AH, 08h
    INT 21h

    MOV DX, OFFSET BUFFER
    MOV AH, 0Ah
    INT 21h

    MOV DL, 0Ah
    MOV AH, 02h
    INT 21h

    MOV BL, [BUFFER + 1]
    MOV BH, 0
    MOV SI, OFFSET BUFFER + 2
    MOV AL, '$'
    MOV [SI + BX], AL

    MOV DX, OFFSET RESULT
    MOV AH, 09h
    INT 21h

    MOV DX, OFFSET BUFFER + 2
    MOV AH, 09h
    INT 21h

    MOV DL, 0Dh
    MOV AH, 02h
    INT 21h
    MOV DL, 0Ah
    MOV AH, 02h
    INT 21h

    MOV AX, 4C00h
    INT 21h
MAIN ENDP
END MAIN
