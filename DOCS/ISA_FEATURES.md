# 8086 ISA features used

This list records instructions and addressing forms present in the Stage 0/1 project sources. It intentionally does not list features that are planned for later stages but are not yet used.

| Feature | Procedure/source | Why it fits |
|---|---|---|
| `.8086` processor directive | `SRC\BANK.ASM`, `SRC\IO.INC` | Asks TASM to reject processor extensions where its assembler checks them. The source linter supplements gaps in TASM's checks. |
| Small-model segments and deliberate `DS`/`ES` setup | `MAIN` | Establishes the data segment after saving the PSP segment. |
| `INT 21h` DOS services | `MAIN`, `PRINT_STRING`, `PRINT_CHAR`, `READ_LINE`, `READ_PIN` | Uses DOS for console output, redirected input, process information, and program termination. |
| Immediate operands and register operands | All I/O procedures | DOS function numbers, characters, counts, and segment setup are naturally expressed as immediates and register values. |
| Direct memory addressing | `MAIN`, `PARSE_COMMAND` | Stores PSP, switch, status, and command-tail state in named data variables. |
| Register-indirect and indexed addressing | `NEXT_TOKEN`, `PARSE_U16` | SI walks PSP/token bytes; BX/SI address byte buffers and tokens. |
| Based with displacement: `[BX+disp]` | `READ_LINE` | `LINE_BUFFER[BX+2]` stores data after the two-byte DOS buffered-input header. |
| Based-indexed: `[BX+DI]` | `NEXT_TOKEN` | DI points at the token buffer and BX indexes each next byte. |
| Segment override `ES:` | `NEXT_TOKEN`, `PARSE_COMMAND` | Reads the PSP command tail through the saved PSP segment without assuming `DS` points there. |
| `REP MOVSB` | `PARSE_COMMAND` | Copies the normalized switch argument into its destination buffer. `CLD` guarantees forward copying. |
| `REPE CMPSB` | `TOKEN_EQUALS` | Compares selector strings until a byte differs or both NUL terminators match. |
| `CLD` | `MAIN`, `TOKEN_EQUALS`, `PARSE_COMMAND` | Makes the direction of string operations explicit before string instructions. |
| `DIV` | `PRINT_DECIMAL` | Repeated division by ten produces decimal digits from an unsigned 16-bit value. |
| `MUL` | `PARSE_U16` | Multiplies the accumulated decimal value by ten; the high word detects overflow. |
| `LOOP` | `PRINT_DECIMAL` | Emits the stack of decimal remainders from most significant digit to least. |
| `PUSH`/`POP` of registers and digit remainders | I/O procedure prologues; `PRINT_DECIMAL` | Preserves caller state and reverses the order of remainders without 32-bit registers. |
| Conditional branches and inverse-condition-plus-`JMP` | `READ_LINE`, `READ_PIN`, `RUN_IO_TEST` | Handles decisions while respecting the 8086 short range of conditional jumps. |

Not yet used: packed-BCD `DAA`/`DAS`, `ADC`/`SBB`, `XLAT`, `IRET`, interrupt-vector hooks, `PUSHF`/`POPF`, `CLI`/`STI`, `IN`/`OUT`, and BIOS/DOS date/time services. These will be listed when a later stage adds real uses.
