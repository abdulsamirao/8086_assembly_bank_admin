.8086
.model small
.stack 256

.data
PSP_SEGMENT     DW 0
SWITCH_KIND     DB 0
PARSE_STATUS    DB 0
TOKEN_BUFFER    DB 33 DUP(0)
LINE_BUFFER     DB 80, 0, 80 DUP(0)
LINE_STATUS     DB 0
LINE_COUNT      DW 0
LINE_CHAR       DB 0
LINE_TOO_LONG   DB 0
PIN_BUFFER      DB 4 DUP(0)
PIN_STATUS      DB 0
PIN_COUNT       DW 0
PIN_CHAR        DB 0
NUMBER_VALUE    DW 0
NUMBER_STATUS   DB 0
CMD_POSITION    DW 0
CMD_REMAINING   DW 0

MSG_USAGE       DB 'Use /T, /I, or /B', 0Dh, 0Ah, '$'
MSG_UNKNOWN     DB 'Unknown switch', 0Dh, 0Ah, '$'
MSG_TEST_MODE   DB 'TEST MODE', 0Dh, 0Ah, '$'
MSG_INIT        DB 'INIT SWITCH', 0Dh, 0Ah, '$'
MSG_BENCH       DB 'BENCH SWITCH', 0Dh, 0Ah, '$'

.code
; Purpose: Save the DOS PSP segment, establish the data segments, then parse
;          product command switches.
; Inputs: DOS command tail at the PSP offset 80h.
; Outputs: Prints the product-shell response and exits DOS.
; Registers: Destroys AX, BX, CX, DX, SI, DI, ES; preserves none.
; Flags: Unspecified on return to DOS.
; ISA: INT 21h/AH=62h, segment initialization, and INCLUDEd procedures.
MAIN PROC
    MOV AH, 62h
    INT 21h
    MOV SI, BX

    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX
    MOV PSP_SEGMENT, SI
    CLD

    CALL PARSE_COMMAND
    CMP PARSE_STATUS, 0
    JNE MAIN_PARSE_ERROR

    CMP SWITCH_KIND, 'T'
    JE MAIN_TEST
    CMP SWITCH_KIND, 'I'
    JE MAIN_INIT
    CMP SWITCH_KIND, 'B'
    JE MAIN_BENCH
    MOV DX, OFFSET MSG_USAGE
    CALL PRINT_STRING
    JMP MAIN_EXIT_OK

MAIN_TEST:
    MOV DX, OFFSET MSG_TEST_MODE
    CALL PRINT_STRING
    JMP MAIN_EXIT_OK

MAIN_INIT:
    MOV DX, OFFSET MSG_INIT
    CALL PRINT_STRING
    JMP MAIN_EXIT_OK

MAIN_BENCH:
    MOV DX, OFFSET MSG_BENCH
    CALL PRINT_STRING
    JMP MAIN_EXIT_OK

MAIN_PARSE_ERROR:
    MOV DX, OFFSET MSG_UNKNOWN
    CALL PRINT_STRING
    MOV AX, 4C01h
    INT 21h

MAIN_EXIT_OK:
    MOV AX, 4C00h
    INT 21h

MAIN_EXIT:
    MOV AL, NUMBER_STATUS
    MOV AH, 4Ch
    INT 21h
MAIN ENDP

INCLUDE IO.INC

END MAIN
