# Stage 0 design notes

This stage establishes the project toolchain and proves the headless DOSBox workflow.

## Bootstrapping the assembler

The VS Code MASM/TASM extension bundles TASM 4.1 and TLINK 7.1 in `resources\TASM.jsdos`. Before testing, `TOOLS\RUNHOST.PS1` invokes `TOOLS\BOOT86.PS1`. If both `TASM.EXE` and `TLINK.EXE` are already in `TOOLS\TASM`, bootstrap is skipped. Otherwise the script finds the newest installed `xsro.masm-tasm-*` extension under `%USERPROFILE%\.vscode\extensions` and copies only `TASM.EXE`, `TLINK.EXE`, `RTM.EXE`, and `DPMI16BI.OVL` from its archive. Missing the extension produces an explicit install-the-MASM/TASM-extension error. The extracted files stay local and `TOOLS\TASM\` is ignored; DOSBox runs the tools rather than relying on a Windows assembler.

## Headless launch

`TOOLS\HEADLESS.CONF` provides DOSBox's `[autoexec]` commands: disable command echo, mount the project as `C:`, select that drive, call `TOOLS\RUNTEST.BAT`, and exit. Launch DOSBox Staging from the project root with `-conf TOOLS\HEADLESS.CONF`; the configuration file avoids quoting problems with repeated `-c` arguments.

Run the workflow from the project root with `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`. The host runner starts DOSBox with the single argument `-conf TOOLS\HEADLESS.CONF`, waits up to 30 seconds, and terminates it if it hangs. It discovers tests by enumerating `TESTS\*.IN`; every input must have a same-stem `.EXP` file. DOS batch files use a same-stem `.EXE` when available, otherwise fall back to `BANK.EXE`. The host runner compares each produced `.OUT` byte-for-byte with its `.EXP`. Adding a case therefore requires only an input/expected-output pair. Complete DOSBox stdout/stderr is printed from `HEADLESS.OUT` and `HEADLESS.LOG`.

`TOOLS\BUILD.BAT` assembles and links the Stage 0 tools and `SRC\BANK.ASM` with the extension's TASM/TLINK. `BANK.ASM` includes `IO.INC` from the same source directory; the headless build assembles it from `C:\SRC`, and TASM reports no include or assembly errors. `TOOLS\RUNHOST.PS1` discovers each test input and creates a temporary `RUNCASES.BAT`; the generated commands run the selected executable with stdin/stdout redirection and record its DOS errorlevel. `TOOLS\RUNTEST.BAT` writes the `START`/`END` markers to `TOOLS\STAGE0.LOG`.

## What the proof checks

`HELLO.ASM` prints `Hello from DOSBox!` using DOS `INT 21h/AH=09h`, then exits with `AX=4C02h`. The runner records the DOS exit code as `2` in `HELLO.ERR` using the DOS `IF ERRORLEVEL` syntax.

`READKEY.ASM` consumes one no-echo key with `INT 21h/AH=08h`, reads a buffered line with `INT 21h/AH=0Ah`, and prints the captured line. The input file begins with `Y` for AH=08h, followed by `HELLO` and Enter for AH=0Ah. DOS echoes the buffered line to redirected stdout; the test's expected output includes that echo and the displayed result. `READKEY.ERR` records successful termination as `0`.

## Stage 0 entry procedures

- `HELLO.ASM` / `MAIN`: Loads `DS` for its message, writes the `$`-terminated string through DOS function 09h, then exits through function 4Ch with return code 2. `AX` selects each DOS function and carries the exit code; `DX` points to the message. The procedure has no caller to return to, so it does not preserve the registers or flags.
- `READKEY.ASM` / `MAIN`: Sets `DS` and `ES` for the data segment, consumes one key without echo through function 08h, and reads the following buffered line through function 0Ah. It writes a line feed after DOS echoes the input, then uses function 09h to print a label and the captured `$`-terminated text. Function 02h writes the CR/LF terminator. `AX` selects the DOS calls, `DX` supplies their pointers/characters, `BX` indexes the buffer terminator, and `SI` points into the buffer. It ends through function 4Ch with exit code 0; no registers or flags are preserved.

In DOSBox's DOS batch shell, `%ERRORLEVEL%` is not expanded as in Windows CMD; it prints `Echo is off.` instead. The runner therefore captures the return values with `IF ERRORLEVEL`, which is the DOS-compatible mechanism.

Stage 0 was verified with `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`: DOSBox exited without waiting at a prompt, the `START` and `END` markers were present, both output files matched their expected files byte-for-byte, and the captured program exit codes were `2` and `0`.

## Stage 1: I/O and command-tail behavior

The application test executable is `TOOLS\BANK.EXE`, built from [BANK.ASM](../SRC/BANK.ASM). The assembly unit uses `INCLUDE IO.INC`; this relative include resolved in the headless build from `C:\SRC`. Each test basename selects `TOOLS\<basename>.EXE` if that source exists, otherwise the runner selects `TOOLS\BANK.EXE`. A test chooses its routine using its optional `.ARG` command-tail file, for example `/T DECIMAL 65535`, `/T LINE`, or `/T PSP`. The runner appends the exact argument text (apart from the file's final CR/LF) to the generated DOS command; absent `.ARG` means no command arguments. Adding a test case does not require editing the runner.

### EOF and masked-input policy

`READ_LINE` and `READ_PIN` first use DOS IOCTL function 44h to tell a console handle from a redirected file handle. Console line input uses function 0Ah and intentionally waits for the user; console PIN input uses function 08h and masks each accepted digit with `*`. With redirected input, the procedures read standard handle 0 through function 3Fh so they can observe an actual zero-byte read. The file-input line rule is shared by both routines: CR ends a line, and an LF encountered as the first byte read by a file-mode call is discarded. This consumes the LF left after a CR without treating LF as a line terminator; it also lets a line-reading call hand the following CRLF PIN line to `READ_PIN`. `READ_LINE` returns AL=1 and prints `EOF` when no bytes remain before a line; `READ_PIN` returns AL=1 and prints `PIN INPUT ENDED` when the stream ends before any digit. Partial PINs are invalid, and neither redirected EOF case waits for more input. The empty `S05.IN` and `S07.IN` cases verify both paths. `L02` reads two consecutive CRLF lines, `L03` reads a blank CRLF line followed by text, and `L04` reads an account-number line then a PIN line from one CRLF input file.

### Procedure walk-through

- `MAIN` obtains the PSP segment with DOS function 62h before changing `DS`, saves it in `PSP_SEGMENT`, then sets `DS`/`ES` to the program data segment. Its test dispatcher sends `/T` selectors to the corresponding I/O routine; `/I`, `/B`, and `/U` are recognized and reported without implementing later-stage actions. `AX`, `BX`, `SI`, `DS`, and `ES` matter during PSP setup; it exits through function 4Ch.
- `PRINT_STRING` sends the `$`-terminated string at `DS:DX` through function 09h. `DX` is the pointer and `AX` selects the DOS call; it destroys `AX`.
- `PRINT_CHAR` sends `DL` through function 02h. `DL` is the character; it destroys `AX`.
- `PRINT_NUL` prints a NUL-terminated string by loading each byte with `LODSB` and sending nonzero bytes through DOS function 02h. `DS:SI` identifies the string; it saves/restores `AX`, `DX`, and `SI`, and uses `CLD` so the string instruction advances toward the terminator.
- `PRINT_NEWLINE` calls `PRINT_CHAR` once for CR and once for LF, saving/restoring `AX` and `DX` so its caller's character/pointer state survives. Its ISA examples are DOS `INT 21h/AH=02h`, near `CALL`, and `PUSH`/`POP`.
- `READ_LINE` uses function 0Ah for interactive buffered input. For redirected files it reads one byte with function 3Fh until CR/LF, Ctrl-Z, or EOF, echoes the characters, enforces the line buffer limit, and returns AL=0/1/2 for success/EOF/too-long. `BX` indexes the buffer, `DX` supplies DOS buffers, and the status in `AL` is the caller-visible result.
- `READ_PIN` gets four decimal digits without echoing the digits; accepted bytes are saved in `PIN_BUFFER` and each is replaced on screen by `*`. Console reads use function 08h; redirected reads use function 3Fh to make EOF observable. `BX` indexes the 4-byte buffer, and AL reports success/EOF/invalid input.
- `PRINT_DECIMAL` repeatedly divides unsigned AX by 10, pushes remainders, then pops and emits them in reverse order. The explicit zero case avoids printing no digits. `BX` holds 10, `CX` counts digits for `LOOP`, and `DX:AX` is the DIV dividend.
- `NEXT_TOKEN` loads `ES` from `PSP_SEGMENT` on entry, scans the PSP tail using `ES:SI`, skips spaces, uppercases ASCII lowercase letters, and writes a NUL-terminated token. `CMD_POSITION`/`CMD_REMAINING` carry the parse cursor across calls; CF distinguishes no token or an overlong token. It preserves the caller's `ES`.
- `PARSE_COMMAND` initializes the cursor from PSP offset 80h/81h, recognizes `/T`, `/I`, `/B`, `/U`, and requires an argument after `/U`. It uses `REP MOVSB` to copy the selected test/account token into its destination, temporarily setting `ES=DS` for the copy, and restores the caller's original `ES` on return.
- `TOKEN_EQUALS` compares NUL-terminated strings with `REPE CMPSB`; it temporarily sets `ES=DS` and executes `CLD` so traversal proceeds forward. ZF reports equality.
- `PARSE_U16` converts a decimal token into AX and detects 16-bit overflow by checking the high word from `MUL`; it retains the validated digit in `CX` between the multiply and accumulation instead of rescanning the token. CF marks invalid input.
- `RUN_IO_TEST` maps the selector token to string, character, newline, line, two-line, account/PIN, PIN, decimal, or PSP verification. It records nonzero EOF/error status for `MAIN` to return through DOS function 4Ch.

### Stage 1 switch and line regression cases

`/U <acct>` is currently only a Stage 1 command-tail parsing placeholder; Stage 5 will replace it with FR-4 account unlock behavior. The Stage 1 output contract for `/U 1001` is `UNLOCK 1001` followed by CRLF, with exit code 0. `SW06` tests `/U 1001`; `SW07` tests lowercase `/u 1001` and requires the same output. `SW03` keeps the missing-argument case `/U`, requiring exit code 1. Their `.EXP` files are authored from this contract, not captured from program output, and byte-for-byte comparison rejects any extra trailing bytes. `TESTS\SW06.EXP` is exactly 13 bytes:

```text
55 4E 4C 4F 43 4B 20 31 30 30 31 0D 0A
```

### 8086 checks and linter limits

The temp-only `.8086` check confirms TASM 4.1 rejects `PUSHA`. It does **not** reject `SHL AX,4`, and also accepts `PUSH 1234h`; those are actual observed assembler behaviors, not accepted project source. With `/L`, TASM lists the shift expansion as four `D1 E0` encodings (`SHL AX,1`), which are 8086-valid. The listing splits the last opcode byte over a continuation line. In the combined throwaway instruction file, TASM rejected `POPA`, `IMUL AX,BX,5`, `ENTER`, `LEAVE`, `BOUND`, `INSB`, `OUTSB`, `MOVZX`, `MOVSX`, `MOV EAX,EBX`, `SETZ`, and `MOV AX,FS`. The throwaway sources and listings are created under ignored `TOOLS\CHK8086` during `RUNHOST.PS1` and removed after a successful run.

`TOOLS\LINT8086.PS1` therefore checks actual source text as well as the assembler result. It flags forbidden mnemonics/registers, immediate `PUSH`/`IMUL`, and shift/rotate count literals other than 1. It checks `.ASM`/`.INC` sources under `SRC`; it is not a full MASM/TASM parser and does not evaluate macros, `EQU`-defined immediates, conditional assembly, generated code, or all possible arithmetic expressions. It flags an explicitly written `Jcc NEAR`, but does not calculate every branch distance; TASM's assembler diagnostics remain the check for a branch that cannot reach its target.

Stage 1 was verified through `TOOLS\RUNHOST.PS1`: all `.IN`/`.EXP` output cases matched, including decimal values 0, 9, 10, 305, and 65535; lowercase switch parsing; unknown and missing switches; extra spaces; PSP preservation; masked PIN; redirected EOF; CRLF multi-line, blank-line, and account/PIN streams; and the `/U` placeholder and lowercase variant. The run also built `BANK.ASM` with `IO.INC`, verified the TASM listing, classified the forbidden-opcode probes, and passed the source linter.
