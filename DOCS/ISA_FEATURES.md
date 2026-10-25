# 8086 ISA features used

This list records instructions and addressing forms present in the Stage 0-3 project sources. It intentionally does not list features that are planned for later stages but are not yet used.

| Feature | Procedure/source | Why it fits |
|---|---|---|
| `.8086` processor directive | `SRC\BANK.ASM`, `SRC\TDRV.ASM`, `SRC\IO.INC`, `SRC\BCD.INC` | Asks TASM to reject processor extensions where its assembler checks them. The source linter supplements gaps in TASM's checks. |
| Small-model segments and deliberate `DS`/`ES` setup | BANK `MAIN`, TDRV `MAIN` | Establishes the data segment after saving the PSP segment. |
| `INT 21h` DOS services | BANK `MAIN`, TDRV `MAIN`, `PRINT_STRING`, `PRINT_CHAR`, `READ_LINE`, `READ_PIN`, `RUN_IO_TEST` | Uses DOS for console output, redirected input, process information, and program termination. |
| Immediate operands and register operands | All I/O procedures | DOS function numbers, characters, counts, and segment setup are naturally expressed as immediates and register values. |
| Direct memory addressing | BANK `MAIN`, TDRV `MAIN`, `PARSE_COMMAND` | Stores PSP, switch, status, and command-tail state in named data variables. |
| Register-indirect and indexed addressing | `NEXT_TOKEN`, `PARSE_U16` | SI walks PSP/token bytes; BX/SI address byte buffers and tokens. |
| Based with displacement: `[BX+disp]` | `READ_LINE` | `LINE_BUFFER[BX+2]` stores data after the two-byte DOS buffered-input header. |
| Based-indexed: `[BX+DI]` | `NEXT_TOKEN` | DI points at the token buffer and BX indexes each next byte. |
| Segment override `ES:` | `NEXT_TOKEN`, `PARSE_COMMAND` | Reads the PSP command tail through the saved PSP segment without assuming `DS` points there. |
| `REP MOVSB` | TDRV `MAIN` | Copies the normalized test selector into its destination buffer. `CLD` guarantees forward copying. |
| `REPE CMPSB` | `TOKEN_EQUALS` | Compares selector strings until a byte differs or both NUL terminators match. |
| `CLD` | BANK `MAIN`, TDRV `MAIN`, `TOKEN_EQUALS`, `PARSE_COMMAND` | Makes the direction of string operations explicit before string instructions. |
| `DIV` | `PRINT_DECIMAL` | Repeated division by ten produces decimal digits from an unsigned 16-bit value. |
| `MUL` | `PARSE_U16` | Multiplies the accumulated decimal value by ten; the high word detects overflow. |
| `ADC` and `DAA` | `bcd_add` in `SRC\BCD.INC` | Adds one packed-BCD byte at a time and decimal-adjusts the result while carrying CF to the next byte. |
| `SBB` and `DAS` | `bcd_sub` in `SRC\BCD.INC` | Subtracts one packed-BCD byte at a time and decimal-adjusts the result while carrying the borrow in CF. |
| `CMP`, `CF`, and `ZF` | `bcd_cmp` in `SRC\BCD.INC` | Compares the most significant differing packed byte and reports ordering/equality in flags. |
| `SHL` and `SHR` by one | `bcd_parse`, `bcd_format` in `SRC\BCD.INC`; `BCD_TEST_LOAD` in `SRC\TDRV.ASM` | Moves decimal nibbles without using a non-8086 multi-bit immediate shift. |
| `LOOP` | `PRINT_DECIMAL`, `bcd_add`, `bcd_sub`, `bcd_cmp`, `bcd_parse`, and `BCD_TEST_LOAD` | Repeats bounded digit/byte walks with the 8086 count register. |
| `PUSH`/`POP` of registers and digit remainders | I/O procedure prologues; `PRINT_DECIMAL`; TDRV `MAIN` | Preserves caller state, temporarily sets `ES=DS`, and reverses the order of remainders without 32-bit registers. |
| Register-indirect and based-indexed byte access | `bcd_add`, `bcd_sub`, `bcd_cmp`, `bcd_parse`, `bcd_format` in `SRC\BCD.INC` | Walks the six-byte little-endian values and places nibbles in the output buffer. |
| Conditional branches and inverse-condition-plus-`JMP` | `READ_LINE`, `READ_PIN`, TDRV `MAIN`, `RUN_IO_TEST`, `RUN_BCD_TEST`, `bcd_parse` | Handles decisions while respecting the 8086 short range of conditional jumps. |

Not yet used: `XLAT`, `IRET`, interrupt-vector hooks, `PUSHF`/`POPF`, `CLI`/`STI`, `IN`/`OUT`, and BIOS/DOS date/time services. These will be listed when a later stage adds real uses.
