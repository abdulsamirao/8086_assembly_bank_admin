# Stage 0 design notes

This stage establishes the project toolchain and proves the headless DOSBox workflow.

## Bootstrapping the assembler

The VS Code MASM/TASM extension bundles TASM 4.1 and TLINK 7.1 in `resources\TASM.jsdos`. The extracted `tasm` directory contains the DOS executables and their runtime files; these are staged under `TOOLS\TASM`. The build script runs those tools inside DOSBox rather than relying on a Windows assembler.

## Headless launch

`TOOLS\HEADLESS.CONF` provides DOSBox's `[autoexec]` commands: disable command echo, mount the project as `C:`, select that drive, call `TOOLS\RUNTEST.BAT`, and exit. Launch DOSBox Staging from the project root with `-conf TOOLS\HEADLESS.CONF`; the configuration file avoids quoting problems with repeated `-c` arguments.

Run the workflow from the project root with `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`. The host runner starts DOSBox with the single argument `-conf TOOLS\HEADLESS.CONF`, waits up to 30 seconds, and terminates it if it hangs. It then checks the marker file, compares output files byte-for-byte against the expected files, verifies the captured exit codes, and prints all DOSBox stdout/stderr.

`TOOLS\BUILD.BAT` changes to `C:\TOOLS` before invoking TASM and TLINK so their generated `.OBJ` and `.EXE` files land beside the sources. `TOOLS\RUNTEST.BAT` then runs the proof executables with redirected streams and writes `START`/`END` markers to `TOOLS\STAGE0.LOG`.

## What the proof checks

`HELLO.ASM` prints `Hello from DOSBox!` using DOS `INT 21h/AH=09h`, then exits with `AX=4C02h`. The runner records the DOS exit code as `2` in `HELLO.ERR` using the DOS `IF ERRORLEVEL` syntax.

`READKEY.ASM` consumes one no-echo key with `INT 21h/AH=08h`, reads a buffered line with `INT 21h/AH=0Ah`, and prints the captured line. The input file begins with `Y` for AH=08h, followed by `HELLO` and Enter for AH=0Ah. DOS echoes the buffered line to redirected stdout; the test's expected output includes that echo and the displayed result. `READKEY.ERR` records successful termination as `0`.

## Stage 0 entry procedures

- `HELLO.ASM` / `MAIN`: Loads `DS` for its message, writes the `$`-terminated string through DOS function 09h, then exits through function 4Ch with return code 2. `AX` selects each DOS function and carries the exit code; `DX` points to the message. The procedure has no caller to return to, so it does not preserve the registers or flags.
- `READKEY.ASM` / `MAIN`: Sets `DS` and `ES` for the data segment, consumes one key without echo through function 08h, and reads the following buffered line through function 0Ah. It writes a line feed after DOS echoes the input, then uses function 09h to print a label and the captured `$`-terminated text. Function 02h writes the CR/LF terminator. `AX` selects the DOS calls, `DX` supplies their pointers/characters, `BX` indexes the buffer terminator, and `SI` points into the buffer. It ends through function 4Ch with exit code 0; no registers or flags are preserved.

In DOSBox's DOS batch shell, `%ERRORLEVEL%` is not expanded as in Windows CMD; it prints `Echo is off.` instead. The runner therefore captures the return values with `IF ERRORLEVEL`, which is the DOS-compatible mechanism.

Stage 0 was verified with `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`: DOSBox exited without waiting at a prompt, the `START` and `END` markers were present, both output files matched their expected files byte-for-byte, and the captured program exit codes were `2` and `0`.
