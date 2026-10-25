Copilot / Agent Instructions: 8086 Bank Admin Console

Project: an admin-side (back-office) banking console in real-mode 8086 assembly for DOS, for a university CALD lab. It is graded on correctness, efficiency/optimization, code clarity/documentation, real-world relevance, and use of ISA features. Full requirements are in SPEC.md. Read it before doing anything.

Status: this is NOT a fresh project

Stages 0 and 1 are complete. They produced a working, tested foundation that you must build on, not rewrite: the headless DOSBox/TASM build-and-test harness (TOOLS\), the I/O library (SRC\IO.INC: print string/char/newline/decimal, line input, masked PIN input, command-tail parsing), the test cases in TESTS\, the 8086 lint, and the docs in DOCS\. DOCS\DESIGN.md is the authoritative description of what exists. The project was re-scoped by the instructor from a customer ATM to an admin console, so SPEC.md is new. When code, tests, or DESIGN.md conflict with SPEC.md, report the conflict and wait for the human's decision. Do not silently change either.

The human's goal (this changes how you work)

The student is practicing AI-assisted development AND must explain every routine in a live demo. So:

Work one stage at a time (SPEC.md section 7). Before changing anything for a stage, post a short plan (20 lines or fewer) and wait for approval.
Keep diffs small. Never rewrite a whole file to change one routine.
After each stage, add plain-English explanations of every new procedure to DOCS\DESIGN.md (what it does, why it is written that way, which registers and flags matter), written so a student can explain them aloud. Include one hand-traced worked example for any non-trivial routine.
Do not start the next stage until this stage's tests pass and the human says go.
If a requirement is ambiguous or you would have to guess, ask.
Never claim something works without running it. Report the actual output.
You may not run git commit or git add, or change git config. The human commits.
Hard technical constraints
Target CPU is a real Intel 8086. Every source file starts with .8086.
Forbidden (80186+/386+): PUSHA, POPA, PUSH imm, IMUL r,imm, ENTER, LEAVE, BOUND, INS/OUTS, shifts/rotates by an immediate greater than 1 (use count 1, or load CL), 32-bit registers, MOVZX/MOVSX, SETcc, FS/GS, near conditional jumps. The assembler does not reliably reject all of these (it silently expanded SHL AX,4), so TOOLS\LINT8086.PS1 is the real guard. Never weaken or bypass it.
Jcc reaches only -128..+127 bytes. For farther targets invert the condition around a JMP.
No FPU instructions.
Syntax must assemble with both MASM and TASM. Use simplified segment directives. Avoid assembler-specific extensions.
All files that DOS, the assembler, or tests touch use 8.3 filenames with no spaces.
All console I/O goes through INT 21h (never INT 16h, never direct video memory), so tests can redirect stdin and stdout.
Preserve the carry flag across BCD byte chains: between one DAA/DAS and the next ADC/SBB, use only flag-neutral instructions (MOV, INC/DEC on pointers, LOOP). Never CMP/ADD/SUB inside the chain.
ISRs: save and restore every register they touch, reach their own data through a CS: override (never assume DS), chain to the previous handler where specified, end with IRET.
Save original interrupt vectors at startup and restore them on every exit path.
Conventions established in Stages 0-1 (keep them)
ES equals DS everywhere except inside a routine that sets it for a reason and restores it before returning.
The PSP segment is saved on entry (PSP_SEGMENT) before DS is changed.
A CR ends an input line. An LF at the start of a file-mode read is discarded. LF-only input is unsupported.
PRINT_STRING prints $-terminated text. Use the NUL-terminated print routine for NUL-terminated text. Never print a buffer that lacks its terminator.
Input routines must handle end-of-input without hanging, and return the documented status in AL.
Source and test files use CRLF line endings (pinned by .gitattributes).
Testing rules
Run tests only through TOOLS\RUNHOST.PS1. It discovers TESTS\*.IN with a same-stem .EXP (and an optional .ARG for arguments).
Expected output must come from an independent oracle: a small Python script (for example using decimal), or values derived by hand from SPEC.md. Never copy program output into an .EXP. Never edit an .EXP to make a failing test pass. If you believe an .EXP is wrong, stop and explain why.
Product binaries contain no test code. Test hooks live in a separate test-driver program that includes the same .INC modules.
Any test that could hang must be killed by the runner's timeout and reported as a failure.
Cost discipline
Do not re-read files you have already read this session. Do not paste huge outputs into the chat.
After 3 failed attempts at the same problem, stop and ask the human instead of looping.
Prefer one targeted fix and one full test run over repeated exploratory runs.
Code style and documentation
Every procedure starts with a header comment: purpose, inputs, outputs, registers preserved/destroyed, flags on return, and an ISA: line naming the real instructions or addressing modes it uses (not the DOS service names). Keep these accurate.
Calling convention: arguments in registers as documented; callee preserves all registers except documented outputs; balanced PUSH/POP; near PROC/RET.
Comment the why, not the what.
Use 8086 features where they are the natural solution (string instructions with REP/REPE, XLAT, LOOP, DAA/DAS, segment overrides, all addressing modes). Do not force a feature in. Record each real use in DOCS\ISA_FEATURES.md.
Do not use cycle counts from memory. Cite the Intel 8086 instruction-timing tables, and label DOSBox timings as relative only.