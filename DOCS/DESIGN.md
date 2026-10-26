# Stage 0 design notes

This stage establishes the project toolchain and proves the headless DOSBox workflow.

## Bootstrapping the assembler

The VS Code MASM/TASM extension bundles TASM 4.1 and TLINK 7.1 in `resources\TASM.jsdos`. Before testing, `TOOLS\RUNHOST.PS1` invokes `TOOLS\BOOT86.PS1`. If both `TASM.EXE` and `TLINK.EXE` are already in `TOOLS\TASM`, bootstrap is skipped. Otherwise the script finds the newest installed `xsro.masm-tasm-*` extension under `%USERPROFILE%\.vscode\extensions` and copies only `TASM.EXE`, `TLINK.EXE`, `RTM.EXE`, and `DPMI16BI.OVL` from its archive. Missing the extension produces an explicit install-the-MASM/TASM-extension error. The extracted files stay local and `TOOLS\TASM\` is ignored; DOSBox runs the tools rather than relying on a Windows assembler.

## Headless launch

`TOOLS\HEADLESS.CONF` provides DOSBox's `[autoexec]` commands: disable command echo, mount the project as `C:`, select that drive, call `TOOLS\RUNTEST.BAT`, and exit. Launch DOSBox Staging from the project root with `-conf TOOLS\HEADLESS.CONF`; the configuration file avoids quoting problems with repeated `-c` arguments.

Run the workflow from the project root with `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`. The host runner starts DOSBox with the single argument `-conf TOOLS\HEADLESS.CONF`, runs test inputs in sorted filename order, waits up to 60 seconds, and terminates it if it hangs. It discovers tests by enumerating `TESTS\*.IN`; every input must have a same-stem `.EXP` file. An optional same-stem `.PGM` file names the executable basename, such as `TDRV`; without it, the runner preserves the existing same-stem tool-executable fallback and then uses `BANK.EXE`. An optional `.RC` file specifies the expected DOS exit code (0 through 4); the runner compares it with the captured code. An optional `.INI` file supplies the exact initial `ACCOUNTS.DAT` bytes for that case and clears the prior `AUDIT.LOG`. An optional `.DAT` file asks the runner to snapshot and byte-compare the generated `ACCOUNTS.DAT` immediately after that case. An optional `.LOG` file similarly checks the generated audit log. It also compares each produced `.OUT` byte-for-byte with its `.EXP`. Complete DOSBox stdout/stderr is printed from `HEADLESS.OUT` and `HEADLESS.LOG`.

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

- BANK `MAIN` obtains the PSP segment with DOS function 62h before changing `DS`, saves it in `PSP_SEGMENT`, sets `DS`/`ES` to the program data segment, then calls `PARSE_COMMAND`. `/I` now calls `DATA_INIT`; a no-switch launch calls `DATA_LOAD` and reports missing or corrupt data with exit code 3. `/T` and `/B` remain product-shell responses until their later stages; unsupported switches, including retired `/U`, print `Unknown switch` and return code 1. `AX`, `BX`, `SI`, `DS`, and `ES` matter during PSP setup; it exits through function 4Ch.
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

## Stage 4 data file format

`ACCOUNTS.DAT` is a compact little-endian binary file. Its six-byte header is the four ASCII bytes `CALD`, version byte `01h`, and one-byte customer count. It is followed by one 16-byte admin record and `count` 16-byte customer records; the final two bytes are a little-endian 16-bit additive checksum of every preceding file byte. The checksum is the unsigned sum modulo 65,536. The maximum file size is 152 bytes.

The admin record contains a four-byte ASCII admin ID, a two-byte PIN hash, and ten reserved zero bytes. Each customer record contains a four-byte ASCII account number, a two-byte PIN hash, six little-endian packed-BCD balance bytes with two implied decimal places, one status byte (`01h` active, `00h` locked), and three reserved zero bytes. This fixed layout leaves no PIN in plaintext. A reader rejects incorrect magic, version, count, exact file size, or checksum. Missing files and corrupt files are reported separately.

The 16-bit PIN hash is intentionally non-cryptographic. Starting at `6D31h`, for each of the four positions it rotates AX left by one, XORs the ASCII ID byte into AL, adds `0137h`, then XORs the ASCII PIN byte into AH. It multiplies the final AX by 251 and keeps the low word. The PIN buffer is overwritten with zeroes after hashing. For `9001` / `1357`, the four intermediate AX values are `EA92h`, `E54Ch`, `FEE0h`, and `C827h`; multiplying `C827h` by 251 leaves `3E3Dh`. This is a deterministic demonstration hash, not a security mechanism.

### Procedures and calling conventions

- `PIN_HASH` takes `DS:SI` to four ASCII ID digits and `DS:DI` to four ASCII PIN digits. It returns the low product word in AX, preserves BX/CX/DX/SI/DI/ES, and zeroes the four PIN bytes using `REP STOSB`; flags are unspecified. The routine expects digit validation from its caller and uses the account ID as the salt.
- `PIN_VERIFY` takes the same ID and candidate-PIN pointers plus the stored hash in BX. It returns AL=1 for a match and AL=0 otherwise, preserves BX/CX/DX/SI/DI/ES, and inherits the input-clearing behavior from `PIN_HASH`; flags are unspecified.
- `DATA_COMPUTE_CHECKSUM` reads `DATA_LENGTH` bytes of `DATA_IMAGE` except its final two checksum bytes. It returns the 16-bit sum in DX, preserves AX/CX/SI, and leaves the other flags unspecified.
- `DATA_SAVE` derives the image length from the one-byte account count, rejects counts above eight, calculates and stores the little-endian checksum, then creates/truncates and writes `ACCOUNTS.DAT`. It returns AL=0 for a complete write and close, or AL=1 for a format or DOS error. It preserves BX/CX/DX/SI/DI.
- `DATA_LOAD` opens the current-directory `ACCOUNTS.DAT`, checks its physical length, reads the header before calculating the expected full image size, then validates magic, version, count, exact size, and checksum. AL returns 0 for success, 1 for a missing file, 2 for corrupt data, and 3 for another DOS I/O failure; BX/CX/DX/SI/DI/ES are preserved.
- `DATA_INIT` clears the shared image, writes the fixed admin and three customer records, hashes each seed PIN, calls `DATA_SAVE`, then deletes an existing `AUDIT.LOG` (a missing log is allowed). Saving first avoids discarding the old log if the new account file cannot be written. AL is 0 for success and 1 for a DOS failure; BX/CX/DX/SI/DI/ES are preserved.
- TDRV `TEST_PIN_HASH` calls `PIN_HASH` with the admin seed and prints its returned word in decimal; it intentionally confirms the PIN input buffer was the only copy and is cleared.
- TDRV `TEST_PIN_VERIFY` checks that `9001` / `1357` matches the documented hash and that `9001` / `1358` does not; both candidate buffers are cleared.
- TDRV `TEST_DATA_PERSIST` initializes, reloads, and checks the seed count, admin hash, and first balance, then removes the file. It reports failure through a nonzero TDRV exit code.
- TDRV `TEST_DATA_CORRUPT` initializes the file, flips one checksum bit on disk, and checks that `DATA_LOAD` returns status 2 before removing it. TDRV `TEST_DATA_MISSING` removes the file, checks for status 1, and prints the same initialization guidance used by BANK.

### Hand trace: seed creation and reload

The initialized count is 3, so `DATA_SAVE` computes `24 + (3 << 4) = 72` bytes (`0048h`). `DATA_LOAD` reads the 6-byte header, derives the same 72-byte size from the count, and reads the remaining 66 bytes. With the specified 1001 balance of 1000.00, the independent sum of the preceding 70 bytes is `0822h`, so the file ends with checksum bytes `22 08`. On load, the checksum routine sums those same 70 bytes into DX; comparing DL=`22h` and DH=`08h` with the stored bytes accepts the image. If the final high checksum byte is changed to `09h`, the second comparison fails and the routine returns AL=2.

Stage 4 verification ran `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`. TASM built both programs, the 8086 lint passed, and all 32 input/output comparisons passed, including the product `/I` test, hash/verify tests, persistence round-trip, checksum rejection, missing-file handling, and the Stage 3 BCD vectors. `BANK` returned code 3 for the no-switch missing-file case.

### Seed-value verification correction

The original `DATA_INIT` assigned bytes `75 50 02` to customer 1001's balance, which is 250.75, not the required 1000.00. TDRV's `TEST_DATA_PERSIST` asserted those same incorrect bytes, so P04 reported `PERSISTENCE OK` while accepting the wrong seed. P04.EXP only contains that generic status; no existing `.EXP` encodes the wrong numeric balance, and no expected output was copied from the program. The earlier Stage 4 run passed because its persistence check repeated the same mistake and the Stage 3 oracle did not model seed records.

The corrected seed values were independently checked with the documented hash and packed-BCD rules:

| Record | ID | Hash word (file bytes) | Balance bytes, low to high | Status |
|---|---|---|---|---|
| Admin | 9001 | `3E3D` (`3D 3E`) | n/a | n/a |
| Customer | 1001 | `187D` (`7D 18`) | `00 00 10 00 00 00` | active |
| Customer | 1002 | `546E` (`6E 54`) | `75 50 02 00 00 00` | active |
| Customer | 1003 | `D973` (`73 D9`) | `00 00 00 00 00 00` | locked |

`TOOLS\ORACLE.PY` now mirrors the written PIN-hash algorithm and derives each packed-BCD balance from `decimal.Decimal`. It generates the 72-byte seed image, including checksum `0822h` (`22 08`), as `TESTS\I05.DAT`. The runner snapshots the product's `/I` output immediately after that test and compares every byte with the oracle file. `TEST_DATA_PERSIST` also checks all four IDs/hashes and all customer balances/statuses.

## Stage 5 login, menu, and account operations

`BANK.ASM` now loads the data image for both normal and `/T` launches, enters `ADMIN_RUN`, and exits with the returned DOS code. `/I` remains the explicit seed operation. `/T` uses the ordinary menu with redirected input; the later timeout and audit features are not part of this stage.

### Procedures and calling conventions

- `ADMIN_RUN` calls the login loop and, only after successful authentication, the menu. It returns AL=0 for normal exit or EOF and AL=2 for lockout; it preserves the other general registers and leaves flags unspecified.
- `ADMIN_LOGIN` gives every ID the same PIN prompt and failure response. It hashes the candidate PIN with `PIN_HASH` (which clears its four input bytes), compares the four ID bytes and stored hash, and stops after three failures. AL is 0 for success, 1 for EOF, and 2 for lockout; other registers are preserved and flags are unspecified.
- `ADMIN_READ_ID` prints the prompt in DX, reads one line, and accepts exactly four ASCII digits. It returns AL=0/1/2 for valid/EOF/malformed input and stores a four-byte placeholder on invalid input. BX, CX, DX, SI, DI, BP, DS, and ES are preserved; flags are unspecified.
- `ADMIN_CLEAR_PIN` uses `REP STOSB` to clear all four shared PIN bytes, including partial or rejected input. It preserves every register; flags are unspecified.
- `ADMIN_MENU` prints all nine specified choices and dispatches list, view, create, lock/unlock, PIN reset, balance adjustment, summary, audit-view fallback, and exit. Choice 9 appends EXIT before returning; EOF returns without an EXIT event. It destroys AX, preserves the other registers, and leaves flags unspecified.
- `ADMIN_LIST` prints the fixed header and walks the validated records. It calls `ADMIN_PRINT_RECORD` per row and preserves all registers; flags are unspecified.
- `ADMIN_LOOKUP` scans the customer table with `REPE CMPSB`, resetting the query pointer for each four-byte ID. AX returns the record offset or zero; all other registers are preserved, and flags are unspecified.
- `ADMIN_PRINT_RECORD` prints the four-character ID, status, and a balance formatted by `bcd_format`. SI is the record pointer; the procedure preserves all registers and leaves flags unspecified.
- `ADMIN_VIEW` validates the requested account number, calls `ADMIN_LOOKUP`, and prints its row or `Account not found` for unknown or malformed input. It destroys AX, preserves the other registers, and leaves flags unspecified.
- `ADMIN_CREATE` rejects malformed and duplicate IDs and a full table, reads a masked PIN and opening amount, parses the amount with `bcd_parse`, and rejects values above 50,000.00. It creates a zero-initialized 16-byte record, hashes and clears the PIN, saves the data image, and appends a CREATE event only after the save succeeds; it destroys AX, preserves the other registers, and leaves flags unspecified.

### Hand trace: finding account 1002

The validated table begins at offset 22 and each record is 16 bytes. The first record's ID is `1001`, so `REPE CMPSB` matches the first three bytes of query `1002`, then stops at `1` versus `2`. DI has advanced four bytes; adding 12 skips the remainder of that record and reaches offset 38. The second comparison matches all four bytes and leaves DI at offset 42. Subtracting four returns record offset 38 in AX. SI, DI, CX, and ZF matter during the comparison; the lookup's return flags are unspecified because it computes the returned offset afterward.

Stage 5 tests T01-T07 exercise successful login/exit, three-failure lockout, unknown IDs, exact listing, existing/unknown/malformed lookup, account creation and view, malformed/duplicate IDs, invalid opening balance, and table-full rejection. T00 reinitializes the seed after earlier persistence tests so the Stage 5 cases begin from known data.

Stage 5 supplied the authentication and read/create foundations. Stage 6 completes failed-login auditing and connects the remaining menu operations to persistence and audit append.

## Stage 6 write operations, report, and audit

`ADMIN_MENU` now calls `ADMIN_LOCK`, `ADMIN_RESET_PIN`, `ADMIN_ADJUST`, and `ADMIN_REPORT` for menu choices 4-7. Choice 8 prints `Audit log: see AUDIT.LOG`, the allowed FR-19 fallback. The account status byte is `01h` when active and `00h` when locked; lock and unlock both save immediately. Reset-PIN hashes and clears the entered PIN before saving. A failed save restores the changed status, hash, or balance in memory and reports the failure.

### New procedure explanations

- `ADMIN_SET_AUDIT_ACCOUNT` takes `DS:SI` pointing to four account digits, copies them into `AUDIT_ACCOUNT`, and adds its `$` terminator. It preserves all registers and leaves flags unspecified. `REP MOVSB` is used because the field is a fixed four bytes.
- `ADMIN_LOCK` reads and looks up an account, toggles its status, persists the image, and emits LOCK or UNLOCK only after a successful save. It preserves BX/CX/DX/SI/DI/BP/DS/ES and destroys AX; flags are unspecified. It uses `[BX+12]`, the status byte in the record, so memory and disk use the same value.
- `ADMIN_RESET_PIN` reads an account and masked PIN, hashes the PIN against that account ID, and persists the new word at record offset 4. It restores the previous hash on save failure. It preserves BX/CX/DX/SI/DI/BP/DS/ES and destroys AX; flags are unspecified. `PIN_HASH` clears the input buffer as part of hashing.
- `ADMIN_ADJUST` validates account, C/D operation, amount grammar, nonzero amount, and the 50,000.00 transaction cap. It snapshots the six balance bytes, uses `bcd_add` or `bcd_sub`, and restores the snapshot on overflow, underflow, or save failure. It preserves BX/CX/DX/SI/DI/BP/DS/ES and destroys AX; flags are unspecified. CF from the BCD routine decides whether the trial balance is representable and nonnegative.
- `ADMIN_REPORT` counts statuses and accumulates balances in a seven-byte packed-BCD total, then writes the required four output lines and a REPORT audit event. The seventh byte captures carries when up to eight six-byte balances are summed. It preserves BX/CX/DX/SI/DI/BP/DS/ES and destroys AX; flags are unspecified.
- `ADMIN_FORMAT_TOTAL` converts the seven-byte little-endian total into a `$`-terminated amount with suppressed integer zeroes and exactly two fractional digits. It preserves all general registers and leaves flags unspecified. It scans integer nibbles from most to least significant and always emits the final two fractional nibbles.
- `AUDIT_WRITE` builds `YYYY-MM-DD HH:MM:SS admin-id ACTION acct detail` plus CR/LF, opens or creates `AUDIT.LOG`, seeks to its end, writes the complete line, and closes the handle. Under `/T` it uses `2000-01-01 00:00:00`; otherwise it reads DOS date/time. It returns AL=0/1 and prints an explicit error on failure; BX/CX/DX/SI/DI/BP/DS/ES are preserved and flags are unspecified.
- `AUDIT_COPY_DOLLAR` copies bytes before `$` from `DS:SI` to `ES:DI`, leaving both pointers at their terminators. It preserves other registers, changes SI/DI as documented, and preserves flags with PUSHF/POPF. `LODSB`/`STOSB` fit the sequential string copy.
- `AUDIT_WRITE_TWO` takes AL from 0 through 99, writes two ASCII digits at `ES:DI`, and advances DI by two. It preserves BX/CX/DX/SI/BP/DS/ES; AX and DI are outputs, and flags are unspecified. Byte DIV by 10 supplies quotient and remainder without a lookup table.
- `AUDIT_WRITE_YEAR` takes the year in AX, emits four digits at `ES:DI`, and advances DI by four. It preserves BX/CX/DX/SI/BP/DS/ES; AX and DI are outputs, and flags are unspecified. Four DIV remainders are pushed and popped in reverse order to print most-significant digit first.

### Hand trace: credit carry and summary total

For the Stage 6 carry case, `99999.99` is stored low byte first as `99 99 99 09 00 00`; `0.01` is `01 00 00 00 00 00`. `ADMIN_ADJUST` copies the original balance before calling `bcd_add`.

| Byte | ADC inputs | Before DAA | After DAA | CF |
|---|---|---:|---:|---:|
| 0 | `99h + 01h + 0` | `9Ah` | `00h` | 1 |
| 1 | `99h + 00h + 1` | `9Ah` | `00h` | 1 |
| 2 | `99h + 00h + 1` | `9Ah` | `00h` | 1 |
| 3 | `09h + 00h + 1` | `0Ah` | `10h` | 0 |
| 4-5 | `00h + 00h + 0` | `00h` | `00h` | 0 |

The result bytes are `00 00 00 10 00 00`, which `bcd_format` displays as `100000.00`. If the carry left byte 5, `ADMIN_ADJUST` would restore its six-byte snapshot and reject the credit. `ADMIN_REPORT` also keeps carry out of byte 5 by incrementing its seventh BCD byte; with eight accounts, that high byte can only rise to `07h`.

### Stage 6 tests

`TOOLS\OR6.PY` creates the `Z08A`-`Z19` cases from independent account/hash/BCD models, without rewriting the existing T09 hash regression or any earlier `.IN`/`.EXP`. The pair `Z08A`/`Z08B` checks that lock state survives separate DOS process runs; `Z19` creates account 1004, locks it in the same session, and verifies the displayed and saved status. Other cases check PIN-hash persistence, account creation, credit/debit persistence, exact-balance debit, zero and overdraw rejection, a carry across BCD bytes, maximum-balance overflow rejection, ordinary and wide summary totals, the audit-view fallback, fixed audit timestamps, and failed-login records. `.INI` fixture images reset the starting table for each independent case; `.DAT` and `.LOG` snapshots compare persisted bytes and audit lines.
