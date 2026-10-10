# Copilot / Agent Instructions: 8086 Banking Terminal

Project: a DOS banking terminal in real-mode **8086** assembly (university CALD lab, graded on correctness, efficiency/optimization, code clarity/documentation, real-world relevance, use of ISA features). Full requirements are in `SPEC.md`. Read it before doing anything.

## The human's goal (this changes how you work)
The student is using this project to practice AI-assisted development AND must explain every routine in a live demo. So:
- Work **one stage at a time** (see SPEC.md section 7). Before writing code for a stage, post a short plan and wait for approval.
- Keep diffs small. Never rewrite a whole file to change one routine.
- After each stage, add a plain-English explanation of every new procedure to `docs/DESIGN.md` (what it does, why it is written that way, which registers/flags matter). Write it so a student can explain it aloud.
- Do not start the next stage until the current stage's tests pass and the human says go.
- If a requirement is ambiguous or you would have to guess, ask instead of guessing.
- Never claim something works without running it. Report the actual command output.

## Hard technical constraints
- Target CPU is a real **Intel 8086**. Start every source file with `.8086` so the assembler rejects newer instructions.
- Forbidden (80186+/386+): `PUSHA`, `POPA`, `PUSH imm`, `IMUL r,imm`, `ENTER`, `LEAVE`, `BOUND`, `INS`/`OUTS`, shifts/rotates by an immediate greater than 1 (use count 1, or load `CL`), 32-bit registers (`EAX` etc.), `MOVZX`/`MOVSX`, `SETcc`, `FS`/`GS`, near conditional jumps.
- Conditional jumps (`Jcc`) reach only -128..+127 bytes. For farther targets use the inverse condition around a `JMP`.
- No FPU instructions.
- Syntax must assemble with both MASM and TASM (the VS Code extension uses whichever is selected). Use simplified segment directives (`.model small`, `.stack`, `.data`, `.code`). Avoid assembler-specific extensions (no `.if`/`invoke` macros, no TASM-only `jumps`).
- All files that DOS, the assembler, or tests touch use **8.3 filenames** with no spaces (e.g. `BANK.ASM`, `ACCOUNTS.DAT`).
- All console I/O goes through **INT 21h** (not INT 16h, not direct video memory) so tests can redirect stdin/stdout. Use AH=08h for no-echo input, AH=0Ah for buffered lines, AH=09h/02h for output.
- Preserve the **carry flag** between bytes of BCD arithmetic: only flag-neutral instructions (`MOV`, `INC`/`DEC` on pointers, `LOOP`) may sit between one `DAA`/`DAS` and the next `ADC`/`SBB`. Never use `CMP`/`ADD`/`SUB` inside the chain.
- ISRs: save and restore every register they touch, reach their own data through a `CS:` override (never assume `DS`), chain to the previous handler where specified, and end with `IRET`.
- Save the original interrupt vectors at startup and restore them on **every** exit path.

## Code style and documentation
- Every procedure starts with a header comment: purpose, inputs, outputs, registers preserved/destroyed, flags on return, and an `ISA:` line naming the notable instructions or addressing modes it demonstrates.
- Calling convention: arguments in registers as documented in the header; callee preserves all registers except documented outputs; balanced `PUSH`/`POP`; near `PROC`/`RET`.
- Comment the *why*, not the *what* (`; carry must survive: no CMP here` beats `; add`).
- Use the full range of 8086 features where they are the natural solution (string instructions with `REP`/`REPE`, `XLAT`, `LOOP`, `DAA`/`DAS`, segment overrides, all addressing modes). Do not force a feature in artificially. Record each real use in `docs/ISA_FEATURES.md`.

## Build and test
- Build and test must run **headless from the VS Code terminal** via scripts in `tools/` (see SPEC.md Stage 0), with program output redirected to files and compared against expected output in `tests/`.
- Do not use cycle counts or timing figures from memory. Cite the Intel 8086 instruction-timing tables for any analysis, and label empirical DOSBox timings as relative only.
