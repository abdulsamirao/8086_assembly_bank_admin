# Stage 0 design notes

This stage establishes the project toolchain and proves the headless DOSBox workflow.

## Bootstrapping the assembler

The VS Code MASM/TASM extension bundles TASM 4.1 and TLINK 7.1 in `resources\TASM.jsdos`. Before testing, `TOOLS\RUNHOST.PS1` invokes `TOOLS\BOOT86.PS1`. If both `TASM.EXE` and `TLINK.EXE` are already in `TOOLS\TASM`, bootstrap is skipped. Otherwise the script finds the newest installed `xsro.masm-tasm-*` extension under `%USERPROFILE%\.vscode\extensions` and copies only `TASM.EXE`, `TLINK.EXE`, `RTM.EXE`, and `DPMI16BI.OVL` from its archive. Missing the extension produces an explicit install-the-MASM/TASM-extension error. The extracted files stay local and `TOOLS\TASM\` is ignored; DOSBox runs the tools rather than relying on a Windows assembler.

## Headless launch

`TOOLS\HEADLESS.CONF` provides DOSBox's `[autoexec]` commands: disable command echo, mount the project as `C:`, select that drive, call `TOOLS\RUNTEST.BAT`, and exit. Launch DOSBox Staging from the project root with `-conf TOOLS\HEADLESS.CONF`; the configuration file avoids quoting problems with repeated `-c` arguments.

Run the workflow from the project root with `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`. The host runner starts DOSBox with the single argument `-conf TOOLS\HEADLESS.CONF`, waits up to 30 seconds, and terminates it if it hangs. It discovers tests by enumerating `TESTS\*.IN`; every input must have a same-stem `.EXP` file. An optional same-stem `.PGM` file names the executable basename, such as `TDRV`; without it, the runner preserves the existing same-stem tool-executable fallback and then uses `BANK.EXE`. An optional `.RC` file specifies the expected DOS exit code (0 through 4); the runner compares it with the captured code. It also compares each produced `.OUT` byte-for-byte with its `.EXP`. Complete DOSBox stdout/stderr is printed from `HEADLESS.OUT` and `HEADLESS.LOG`.

`TOOLS\BUILD.BAT` assembles and links the Stage 0 tools and `SRC\BANK.ASM` and `SRC\TDRV.ASM` with the extension's TASM/TLINK. Both application sources include `IO.INC` from the same source directory; the headless build assembles them from `C:\SRC`. BANK is the product shell, while TDRV owns the I/O regression dispatcher. `TOOLS\RUNHOST.PS1` discovers each test input and creates a temporary `RUNCASES.BAT`; the generated commands run the selected executable with stdin/stdout redirection and record its DOS errorlevel. `TOOLS\RUNTEST.BAT` writes the `START`/`END` markers to `TOOLS\STAGE0.LOG`.

## What the proof checks

`HELLO.ASM` prints `Hello from DOSBox!` using DOS `INT 21h/AH=09h`, then exits with `AX=4C02h`. The runner records the DOS exit code as `2` in `HELLO.ERR` using the DOS `IF ERRORLEVEL` syntax.

`READKEY.ASM` consumes one no-echo key with `INT 21h/AH=08h`, reads a buffered line with `INT 21h/AH=0Ah`, and prints the captured line. The input file begins with `Y` for AH=08h, followed by `HELLO` and Enter for AH=0Ah. DOS echoes the buffered line to redirected stdout; the test's expected output includes that echo and the displayed result. `READKEY.ERR` records successful termination as `0`.

## Stage 0 entry procedures

- `HELLO.ASM` / `MAIN`: Loads `DS` for its message, writes the `$`-terminated string through DOS function 09h, then exits through function 4Ch with return code 2. `AX` selects each DOS function and carries the exit code; `DX` points to the message. The procedure has no caller to return to, so it does not preserve the registers or flags.
- `READKEY.ASM` / `MAIN`: Sets `DS` and `ES` for the data segment, consumes one key without echo through function 08h, and reads the following buffered line through function 0Ah. It writes a line feed after DOS echoes the input, then uses function 09h to print a label and the captured `$`-terminated text. Function 02h writes the CR/LF terminator. `AX` selects the DOS calls, `DX` supplies their pointers/characters, `BX` indexes the buffer terminator, and `SI` points into the buffer. It ends through function 4Ch with exit code 0; no registers or flags are preserved.

In DOSBox's DOS batch shell, `%ERRORLEVEL%` is not expanded as in Windows CMD; it prints `Echo is off.` instead. The runner therefore captures the return values with `IF ERRORLEVEL`, which is the DOS-compatible mechanism.

Stage 0 was verified with `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`: DOSBox exited without waiting at a prompt, the `START` and `END` markers were present, both output files matched their expected files byte-for-byte, and the captured program exit codes were `2` and `0`.

## Stage 1 foundation and Stage 2 separation

Stage 1 established the shared I/O and command-tail routines in `IO.INC`. After Stage 2, the product shell is [BANK.ASM](../SRC/BANK.ASM), and the separate regression program is [TDRV.ASM](../SRC/TDRV.ASM); each includes the same `IO.INC`. BANK treats `/T` as its product test-mode switch and contains no I/O test dispatcher. TDRV accepts `/T <selector>` and calls `RUN_IO_TEST`. The runner appends the exact `.ARG` text (apart from its final CR/LF) to the DOS command. `.PGM` explicitly selects a program for a test, while tests without `.PGM` keep the original same-stem tool-executable/BANK fallback.

### EOF and masked-input policy

`READ_LINE` and `READ_PIN` first use DOS IOCTL function 44h to tell a console handle from a redirected file handle. Console line input uses function 0Ah and intentionally waits for the user; console PIN input uses function 08h and masks each accepted digit with `*`. With redirected input, the procedures read standard handle 0 through function 3Fh so they can observe an actual zero-byte read. The file-input line rule is shared by both routines: CR ends a line, and an LF encountered as the first byte read by a file-mode call is discarded. This consumes the LF left after a CR without treating LF as a line terminator; it also lets a line-reading call hand the following CRLF PIN line to `READ_PIN`. `READ_LINE` returns AL=1 and prints `EOF` when no bytes remain before a line; `READ_PIN` returns AL=1 and prints `PIN INPUT ENDED` when the stream ends before any digit. Partial PINs are invalid, and neither redirected EOF case waits for more input. The empty `S05.IN` and `S07.IN` cases verify both paths. `L02` reads two consecutive CRLF lines, `L03` reads a blank CRLF line followed by text, and `L04` reads an account-number line then a PIN line from one CRLF input file.

### Procedure walk-through

- BANK `MAIN` obtains the PSP segment with DOS function 62h before changing `DS`, saves it in `PSP_SEGMENT`, sets `DS`/`ES` to the program data segment, then calls `PARSE_COMMAND`. `/T`, `/I`, and `/B` still reach the Stage 2 product-shell responses; unsupported switches, including retired `/U`, print `Unknown switch` and return code 1. `AX`, `BX`, `SI`, `DS`, and `ES` matter during PSP setup; it exits through function 4Ch.
- TDRV `MAIN` performs the same PSP and segment setup, calls `PARSE_COMMAND`, then reads the test selector with `NEXT_TOKEN`. It copies that selector into `TEST_OPERATION` using forward `REP MOVSB`, dispatches through `RUN_IO_TEST`, and exits with `NUMBER_STATUS`. A missing selector remains an unknown-test case. `AX`, `BX`, `CX`, `SI`, `DI`, `DS`, and `ES` matter; the copy relies on `CLD` and temporarily setting `ES=DS`.
- `RUN_IO_TEST` compares `TEST_OPERATION` against the NUL-terminated selector constants with `TOKEN_EQUALS`, then calls the associated I/O routine or prints `UNKNOWN TEST`. Its selector comparisons use `SI`, `DI`, `CX` and the comparison result in ZF; input-test status is returned through `NUMBER_STATUS`. For example, `/T DECIMAL 305` leaves `DECIMAL` as the selector, consumes `305` as the next token, converts it to AX, prints `305`, and records status 0. This routine is test-only and is not assembled into BANK.
- `PRINT_STRING` sends the `$`-terminated string at `DS:DX` through function 09h. `DX` is the pointer and `AX` selects the DOS call; it destroys `AX`.
- `PRINT_CHAR` sends `DL` through function 02h. `DL` is the character; it destroys `AX`.
- `PRINT_NUL` prints a NUL-terminated string by loading each byte with `LODSB` and sending nonzero bytes through DOS function 02h. `DS:SI` identifies the string; it saves/restores `AX`, `DX`, and `SI`, and uses `CLD` so the string instruction advances toward the terminator.
- `PRINT_NEWLINE` calls `PRINT_CHAR` once for CR and once for LF, saving/restoring `AX` and `DX` so its caller's character/pointer state survives. Its ISA examples are DOS `INT 21h/AH=02h`, near `CALL`, and `PUSH`/`POP`.
- `READ_LINE` uses function 0Ah for interactive buffered input. For redirected files it reads one byte with function 3Fh until CR/LF, Ctrl-Z, or EOF, echoes the characters, enforces the line buffer limit, and returns AL=0/1/2 for success/EOF/too-long. `BX` indexes the buffer, `DX` supplies DOS buffers, and the status in `AL` is the caller-visible result.
- `READ_PIN` gets four decimal digits without echoing the digits; accepted bytes are saved in `PIN_BUFFER` and each is replaced on screen by `*`. Console reads use function 08h; redirected reads use function 3Fh to make EOF observable. `BX` indexes the 4-byte buffer, and AL reports success/EOF/invalid input.
- `PRINT_DECIMAL` repeatedly divides unsigned AX by 10, pushes remainders, then pops and emits them in reverse order. The explicit zero case avoids printing no digits. `BX` holds 10, `CX` counts digits for `LOOP`, and `DX:AX` is the DIV dividend.
- `NEXT_TOKEN` loads `ES` from `PSP_SEGMENT` on entry, scans the PSP tail using `ES:SI`, skips spaces, uppercases ASCII lowercase letters, and writes a NUL-terminated token. `CMD_POSITION`/`CMD_REMAINING` carry the parse cursor across calls; CF distinguishes no token or an overlong token. It preserves the caller's `ES`.
- `PARSE_COMMAND` initializes the cursor from PSP offset 80h/81h and recognizes `/T`, `/I`, and `/B`. `/T` only identifies the product test-mode switch; TDRV separately reads its test selector. `/U` is no longer recognized and follows the normal unknown-switch path. The parser preserves the caller's `ES`.
- `TOKEN_EQUALS` compares NUL-terminated strings with `REPE CMPSB`; it temporarily sets `ES=DS` and executes `CLD` so traversal proceeds forward. ZF reports equality.
- `PARSE_U16` converts a decimal token into AX and detects 16-bit overflow by checking the high word from `MUL`; it retains the validated digit in `CX` between the multiply and accumulation instead of rescanning the token. CF marks invalid input.
- `RUN_IO_TEST` maps the selector token to string, character, newline, line, two-line, account/PIN, PIN, decimal, or PSP verification. It records nonzero EOF/error status for TDRV `MAIN` to return through DOS function 4Ch.

### Stage 1 regressions and retired switch

The old Stage 1 `/U` placeholder is retired rather than becoming account-unlock behavior. SW03 (`/U`), SW06 (`/U 1001`), and SW07 (`/u 1001`) remain as regressions: all must print `Unknown switch` and return code 1. Their `.EXP` output is specified by the retired-switch contract, and `.RC` independently checks the process status. The lower-case test also verifies that switch parsing remains case-insensitive.

The I/O test cases use `.PGM` files containing `TDRV`; unrelated Stage 0 tests retain their previous executable selection. Tests without `.PGM` continue using the old fallback.

### 8086 checks and linter limits

The temp-only `.8086` check confirms TASM 4.1 rejects `PUSHA`. It does **not** reject `SHL AX,4`, and also accepts `PUSH 1234h`; those are actual observed assembler behaviors, not accepted project source. With `/L`, TASM lists the shift expansion as four `D1 E0` encodings (`SHL AX,1`), which are 8086-valid. The listing splits the last opcode byte over a continuation line. In the combined throwaway instruction file, TASM rejected `POPA`, `IMUL AX,BX,5`, `ENTER`, `LEAVE`, `BOUND`, `INSB`, `OUTSB`, `MOVZX`, `MOVSX`, `MOV EAX,EBX`, `SETZ`, and `MOV AX,FS`. The throwaway sources and listings are created under ignored `TOOLS\CHK8086` during `RUNHOST.PS1` and removed after a successful run.

`TOOLS\LINT8086.PS1` therefore checks actual source text as well as the assembler result. It flags forbidden mnemonics/registers, immediate `PUSH`/`IMUL`, and shift/rotate count literals other than 1. It checks `.ASM`/`.INC` sources under `SRC`; it is not a full MASM/TASM parser and does not evaluate macros, `EQU`-defined immediates, conditional assembly, generated code, or all possible arithmetic expressions. It flags an explicitly written `Jcc NEAR`, but does not calculate every branch distance; TASM's assembler diagnostics remain the check for a branch that cannot reach its target.

Stage 1 established the decimal, switch, PSP, masked PIN, redirected EOF, and CRLF input regression cases. Stage 2 moves the tests to TDRV and keeps `/U` cases as unknown-switch regressions. Each historical case retains its independent `.EXP`; `.RC` files assert the expected process status where specified.

## Stage 3 packed-BCD library

`SRC\BCD.INC` stores a value in six bytes, least-significant byte first. Each byte contains two decimal digits: its low nibble is the less significant digit and its high nibble is the next digit. The value has two implied decimal places, so the two least-significant digits are the fractional cents. The maximum representable value is `9,999,999,999.99`.

### Procedures and calling conventions

- `bcd_add`: `DS:SI` points to the addend and `DS:DI` to the destination, which is replaced in place. It visits six bytes from least to most significant and returns `CF=1` if a decimal carry leaves the top byte. All registers are preserved. `ADC` and `DAA` perform the packed-decimal addition. After each `DAA`, only `MOV`, `INC`, and `LOOP` occur before the next `ADC`; those instructions preserve CF, so the decimal carry reaches the next byte intact.
- `bcd_sub`: `DS:SI` points to the subtrahend and `DS:DI` to the destination, which is replaced in place. It returns `CF=1` for a borrow out of the top byte and preserves all registers. `SBB` and `DAS` handle one byte at a time. As with addition, only flag-neutral instructions run between `DAS` and the next `SBB`.
- `bcd_cmp`: `DS:SI` and `DS:DI` identify the two six-byte values. It compares from byte 5 down to byte 0, because the highest differing decimal pair determines the unsigned order. All registers are preserved; `CF=1` means the first value is less, and `ZF=1` means equal. The flags from the decisive `CMP` survive the final branch, `LOOP`, and register restores.
- `bcd_parse`: `DS:SI` points to the input bytes, `CX` is their exact length, and `DS:DI` points to the six-byte destination. It returns `AL=0, CF=0` for success and `AL=1, CF=1` for invalid input; other registers are preserved. It accepts exactly the lexical form `^[0-9]{1,10}(\.[0-9]{1,2})?$`, including zero. It does not impose the application-specific 50,000.00 or transaction non-zero rules; callers apply those policies. The exact input length lets it reject embedded terminators and whitespace instead of silently accepting a prefix. Each digit shifts the existing packed decimal value one decimal place and inserts the new digit; a one-digit fractional part gets one trailing zero, and an integer gets two. Repeated one-bit shifts keep the implementation within the 8086 instruction set.
- `bcd_format`: `DS:SI` points to six packed-BCD bytes and `DS:DI` to a 14-byte destination. It writes a `$`-terminated decimal string with two fractional digits and suppressed leading integer zeroes (`0.00` for zero). It preserves all registers. Reading the integer nibbles from most to least significant makes leading-zero suppression straightforward; the final two fractional nibbles are always emitted.
- TDRV `RUN_BCD_TEST` reads one generated operation per redirected input line, invokes the library, and prints the result. `READ_LINE` echoes each vector before the result, which is why the oracle-generated expected output includes those input lines. TDRV `BCD_TEST_LOAD` converts twelve decimal characters, low-order byte first, into six packed-BCD bytes; it advances `SI` and `DI`, preserves the other registers, and returns `CF=1` for non-digits. Neither test hook is included in `BANK.EXE`.

### Hand trace: `99.99 + 0.01`

The values are `[99h, 99h, 00h, 00h, 00h, 00h]` and `[01h, 00h, 00h, 00h, 00h, 00h]`, respectively. The destination begins as `99.99`; the addend is read through `DS:SI`.

| Byte (low to high) | ADC input | Before DAA | DAA result | CF after DAA |
|---|---|---:|---:|---:|
| 0 | `99h + 01h + 0` | `9Ah` | `00h` | 1 |
| 1 | `99h + 00h + 1` | `9Ah` | `00h` | 1 |
| 2 | `00h + 00h + 1` | `01h` | `01h` | 0 |
| 3 | `00h + 00h + 0` | `00h` | `00h` | 0 |
| 4 | `00h + 00h + 0` | `00h` | `00h` | 0 |
| 5 | `00h + 00h + 0` | `00h` | `00h` | 0 |

The final bytes are `[00h, 00h, 01h, 00h, 00h, 00h]`, which format as `100.00`. After each `DAA`, `MOV [DI],AL`, `INC SI`, `INC DI`, and `LOOP` do not modify CF; therefore the first two decimal carries reach the next byte's `ADC`.

### Stage 3 vectors and verification

`TOOLS\ORACLE.PY` generates `TESTS\T20.IN` and `TESTS\T20.EXP` from independent Python `decimal` arithmetic and the exact FR-11 regular expression. It is run with `python TOOLS\ORACLE.PY`; the expected output is not derived from the assembly program. The 35 vectors cover six-byte carry and borrow, zero arithmetic, equal and ordered comparisons, overflow and underflow status, formatting, parse/format results, and every specified lexical acceptance/rejection example (including leading/trailing spaces, signs, separators, empty input, and the 10-digit integer boundary). Zero is accepted by `bcd_parse`; callers enforce transaction non-zero and 50,000.00 policies.

Stage 3 verification ran `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`. TASM assembled both programs, the 8086 lint passed, all existing regression cases passed, and `T20.OUT` matched the oracle-generated `T20.EXP` with exit code 0.
