# 8086 ISA features used

This list records instructions and addressing forms present in the Stage 0-8 project sources. It intentionally does not list features that are planned for later stages but are not yet used.

| Feature | Procedure/source | Why it fits |
|---|---|---|
| `.8086` processor directive | `SRC\BANK.ASM`, `SRC\TDRV.ASM`, `SRC\IO.INC`, `SRC\BCD.INC`, `SRC\DATA.INC`, `SRC\ADMIN.INC`, `SRC\ISR.INC`, `SRC\BENCH.INC` | Asks TASM to reject processor extensions where its assembler checks them. The source linter supplements gaps in TASM's checks. |
| Small-model segments and deliberate `DS`/`ES` setup | BANK `MAIN`, TDRV `MAIN` | Establishes the data segment after saving the PSP segment. |
| `INT 21h` DOS services | BANK `MAIN`, TDRV `MAIN`, I/O procedures, `DATA_SAVE`, `DATA_LOAD`, `DATA_INIT`, Stage 4 TDRV data checks, `AUDIT_WRITE`, `BENCH_SAVE_OUTPUT` | Uses DOS for console output, redirected input, process information, program termination, file operations, and system date/time. |
| `INT 21h/AH=35h` and `AH=25h` | `ISR_SAVE_VECTOR`, `ISR_INSTALL`, `ISR_RESTORE` in `SRC\ISR.INC` | Saves the original INT 1Ch vector at startup, installs the timer handler after login, and restores the original vector after the menu returns. |
| `INT 1Ch` | `TIMER_ISR` in `SRC\ISR.INC` | Counts timer ticks for the roughly 30-second idle interval, then chains through the prior handler. |
| BIOS `INT 1Ah/AH=00h` | `BENCH_RUN` in `SRC\BENCH.INC` | Samples BIOS clock ticks before and after each benchmark variant. |
| Immediate operands and register operands | All I/O procedures | DOS function numbers, characters, counts, and segment setup are naturally expressed as immediates and register values. |
| Direct memory addressing | BANK `MAIN`, TDRV `MAIN`, `PARSE_COMMAND`, `DATA_SAVE`, `DATA_LOAD`, `DATA_INIT`, `ADMIN_*`, `BENCH_*` | Stores PSP, switch, status, command-tail state, menu state, benchmark state, and fixed-layout account fields in named variables. |
| Register-indirect and indexed addressing | `NEXT_TOKEN`, `PARSE_U16`, `PIN_HASH`, `DATA_COMPUTE_CHECKSUM`, `DATA_LOAD`, `ADMIN_LOOKUP`, `ADMIN_ADJUST`, `ADMIN_REPORT`, `AUDIT_WRITE`, `BENCH_BINARY_FORMAT` | SI/DI walk text, PIN, account IDs, balances, audit fields, decimal digits, and binary-image bytes without copying complete tables into temporary structures. |
| Based with displacement: `[BX+disp]` | `READ_LINE`, `ADMIN_PRINT_RECORD`, `ADMIN_CREATE`, `ADMIN_LOCK`, `ADMIN_RESET_PIN`, `ADMIN_ADJUST`, `ADMIN_REPORT` | Accesses buffered-input bytes and fields at fixed offsets within account records. |
| Indexed with displacement: `[SI+disp]` | `DATA_LOAD`, `ADMIN_REPORT` | Accesses checksum bytes and account-record status fields at fixed offsets from an index register. |
| Based-indexed: `[BX+DI]`, `[BX+SI]`, `[BX+SI+disp]` | `NEXT_TOKEN`, `BENCH_BINARY_FORMAT` | Uses a base pointer plus a variable index for token and decimal-digit buffers; the displacement form fetches the next fractional digit. |
| Segment overrides `ES:` and `CS:` | `NEXT_TOKEN`, `PARSE_COMMAND`, `AUDIT_COPY_DOLLAR`, `AUDIT_WRITE_TWO`, `AUDIT_WRITE_YEAR`, `ADMIN_READ_MENU`, `ISR_SAVE_VECTOR`, `ISR_INSTALL`, `ISR_RESTORE`, `TIMER_ISR` | Reads the PSP command tail, writes audit text, and lets the timer ISR access its own tick count and saved vector without assuming `DS`. |
| `REP MOVSB` | TDRV `MAIN`, `ADMIN_READ_ID`, `ADMIN_CREATE`, `ADMIN_SET_AUDIT_ACCOUNT`, `AUDIT_WRITE`, `BENCH_BUILD_OUTPUT` | Copies the normalized selector, validated IDs, fixed-size account fields, audit IDs, or the known-length formatted benchmark result. `CLD` guarantees forward copying. |
| `REPE CMPSB` | `TOKEN_EQUALS`, `ADMIN_LOGIN`, `ADMIN_LOOKUP` | Compares selector strings, the candidate admin ID, or account IDs and stops at the first mismatch. |
| `CLD` | BANK `MAIN`, TDRV `MAIN`, `TOKEN_EQUALS`, `PARSE_COMMAND`, `ADMIN_SET_AUDIT_ACCOUNT`, `ADMIN_ADJUST`, `ADMIN_REPORT`, `AUDIT_WRITE`, `AUDIT_COPY_DOLLAR`, `BENCH_BUILD_OUTPUT` | Makes the direction of string operations explicit before string instructions. |
| `DIV` | `PRINT_DECIMAL`, `AUDIT_WRITE_TWO`, `AUDIT_WRITE_YEAR`, `BENCH_BINARY_FORMAT`, `BENCH_APPEND_DECIMAL` | Produces decimal digits for numeric output, audit date fields, and the benchmark's 32-bit binary-to-decimal conversion. |
| `MUL` | `PARSE_U16`, `PIN_HASH` | `PARSE_U16` detects decimal overflow from the high word; `PIN_HASH` multiplies its salted 16-bit state by 251 and keeps the low word. |
| `ROL` by one | `PIN_HASH` in `SRC\DATA.INC` | Mixes each of the four account-ID bytes into the non-cryptographic salted PIN hash using a 16-bit rotate. |
| `XOR` and `ADD` | `PIN_HASH` in `SRC\DATA.INC`; `ADMIN_REPORT` | Mixes ID/PIN bytes into the demonstration hash state and advances the high BCD total when the six-byte sum carries. |
| Binary `ADD` and `ADC` | `BENCH_RUN` in `SRC\BENCH.INC` | Adds one cent to a two-word unsigned binary accumulator, carrying from BX into DX. |
| `ADC` and `DAA` | `bcd_add` in `SRC\BCD.INC`, `BENCH_BCD_ADD_UNROLLED`; `ADMIN_REPORT` through `bcd_add` | Adds one packed-BCD byte at a time and decimal-adjusts the result while carrying CF to the next byte; the report adds a seventh BCD carry byte. |
| `SBB` and `DAS` | `bcd_sub` in `SRC\BCD.INC`; `ADMIN_ADJUST` through `bcd_sub` | Subtracts one packed-BCD byte at a time and decimal-adjusts the result while carrying the borrow in CF. |
| `CMP`, `CF`, and `ZF` | `bcd_cmp` in `SRC\BCD.INC`, `PIN_VERIFY` in `SRC\DATA.INC` | Compares packed values for ordering/equality and compares a candidate PIN hash with its stored word. |
| `SHL` and `SHR` by one | `bcd_parse`, `bcd_format` in `SRC\BCD.INC`; `BCD_TEST_LOAD` in `SRC\TDRV.ASM`; `ADMIN_FORMAT_TOTAL` | Moves decimal nibbles without using a non-8086 multi-bit immediate shift. |
| `REP STOSB` | `PIN_HASH`, `DATA_INIT` in `SRC\DATA.INC`; `ADMIN_CLEAR_PIN`, `ADMIN_CREATE` | Clears PIN input and zero-initializes a new fixed-size account record or the bounded data image. |
| `SHL` by `CL` | `DATA_SAVE`, `DATA_LOAD` in `SRC\DATA.INC`; `ADMIN_CREATE` | Converts the account count into a byte offset by shifting four places with `CL=4`, an 8086-supported variable-count form. |
| DOS file functions `3Ch`, `3Dh`, `3Eh`, `3Fh`, `40h`, `41h`, `42h` | `DATA_SAVE`, `DATA_LOAD`, `DATA_INIT`, `AUDIT_WRITE` | Creates, opens, reads, writes, seeks, closes, and removes the data and audit files through DOS handles. |
| DOS date/time functions `2Ah`, `2Ch` | `AUDIT_WRITE` | Uses the DOS calendar and clock to timestamp real audit entries; `/T` selects the fixed test timestamp. |
| `LOOP` | `PRINT_DECIMAL`, `bcd_add`, `bcd_sub`, `bcd_cmp`, `bcd_parse`, `BCD_TEST_LOAD`, `DATA_COMPUTE_CHECKSUM`, `ADMIN_READ_ID`, `ADMIN_LIST`, `ADMIN_PRINT_RECORD`, `ADMIN_FORMAT_TOTAL`, `AUDIT_WRITE_YEAR`, `BENCH_BINARY_FORMAT`, `BENCH_APPEND_DECIMAL` | Repeats bounded digit, byte, account, date, checksum, or decimal-conversion walks with the 8086 count register. |
| `PUSH`/`POP` of registers and digit remainders | I/O, data, admin, and benchmark procedure prologues; `PRINT_DECIMAL`; `AUDIT_WRITE_YEAR`; `BENCH_BINARY_FORMAT`; `BENCH_APPEND_DECIMAL`; TDRV `MAIN` | Preserves caller state, temporarily sets `ES=DS`, and reverses the order of remainders without 32-bit registers. |
| `PUSHF`/`POPF` | `AUDIT_COPY_DOLLAR`, `TIMER_ISR` | Preserves flags while forcing forward string direction, and restores the interrupted flags before chaining the timer handler. |
| Far indirect `CALL` and `IRET` | `TIMER_ISR` in `SRC\ISR.INC` | Calls the prior interrupt handler with a synthetic interrupt frame, then returns through the current interrupt frame. |
| `INT 21h/AH=0Bh` and `AH=08h` | `ADMIN_READ_MENU` in `SRC\ADMIN.INC` | Polls interactive stdin without blocking, then consumes the available key to reset the idle counter. |
| `LODSB`/`STOSB` | `AUDIT_COPY_DOLLAR`, `BENCH_COPY_TEXT`, `BENCH_APPEND_CRLF`, `BENCH_BINARY_FORMAT` | Copies sentinel-terminated fields and appends formatted digits or line endings through sequential string addressing. |
| Register-indirect and based-indexed byte access | `bcd_add`, `bcd_sub`, `bcd_cmp`, `bcd_parse`, `bcd_format`, `PIN_HASH`, `DATA_COMPUTE_CHECKSUM` | Walks the six-byte little-endian values, PIN digits, and binary image bytes. |
| Conditional branches and inverse-condition-plus-`JMP` | `READ_LINE`, `READ_PIN`, BANK/TDRV `MAIN`, `RUN_IO_TEST`, `RUN_BCD_TEST`, `bcd_parse`, `DATA_SAVE`, `DATA_LOAD`, `ADMIN_*`, `BENCH_*` | Handles validation and dispatch while respecting the 8086 short range of conditional jumps. |

Not yet used: `XLAT`, `CLI`/`STI`, and `IN`/`OUT`. These will be listed if a later stage adds real uses.
