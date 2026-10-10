# SPEC: 8086 Banking Terminal (CALD Lab 13 CEA)

Audience: an AI coding agent (VS Code Agent Mode) working with a student. Read `.github/copilot-instructions.md` first; it holds the hard rules and the working style.

Priority tags: **[MUST]** required for submission, **[SHOULD]** do after all MUSTs pass, **[STRETCH]** only if time remains.

## 1. Goal

An ATM-style terminal in real-mode 8086 assembly for DOS: PIN login, balance check, deposit, withdraw, exit, plus extras that exercise features specific to the 8086: packed-BCD money arithmetic, string instructions, hooked interrupts, DOS file I/O, and port I/O.

Real-world framing for the report: decimal-exact money arithmetic (why packed decimal exists in financial systems), authentication, data persistence, and interrupt-driven session timeout. It is an educational project, not real security.

Grading criteria (2 marks each): correctness, efficiency/optimization, code clarity/documentation, real-world relevance, use of ISA features.

## 2. Platform and toolchain

- Run under DOSBox (Staging) through the VS Code MASM/TASM extension. The extension assembles with MASM or TASM; code must assemble with both.
- Prefer a single assembly unit: `SRC\BANK.ASM` with `INCLUDE` files for modules, so the extension's one-file build works.
- Suggested layout:
  ```
  SRC\    BANK.ASM  IO.INC  BCD.INC  ACCT.INC  FILES.INC  ISR.INC
  TOOLS\  BUILD.BAT  RUNTEST.BAT  (plus a PowerShell wrapper that launches DOSBox headless)
  TESTS\  T01.IN  T01.EXP  ...
  DOCS\   DESIGN.md  ISA_FEATURES.md  BENCH.md
  ```
- Memory model: small. Entry saves the PSP segment before changing `DS`.

## 3. Functional requirements

### 3.1 Authentication
- **FR-1 [MUST]** Prompt for a 4-digit account number, then a 4-digit PIN. PIN input is masked with `*`, read with INT 21h AH=08h, digits only.
- **FR-2 [MUST]** PINs are never stored in plaintext. Store a 16-bit salted hash (salt = account number; use `ROL` by 1, `XOR`, `ADD`, and one `MUL`; the design is yours but must be documented as non-cryptographic). Verify by hashing the input and comparing. Clear the PIN buffer with `REP STOSB` after use.
- **FR-3 [MUST]** After 3 failed attempts print "Account locked", sound the alert (FR-21), and exit to DOS with ERRORLEVEL 2.
- **FR-4 [SHOULD]** The lock persists in the data file. The `/U <acct>` switch unlocks (simulates a branch override).
- **FR-5 [MUST]** An unknown account number counts as a failed attempt and shows the same message as a wrong PIN (no account enumeration).

### 3.2 Menu and transactions
- **FR-6 [MUST]** Menu: `1 Balance  2 Deposit  3 Withdraw  4 Mini statement  5 Change PIN  6 Exit`. An invalid choice re-prompts.
- **FR-7 [MUST]** Balance displays as `1234.56` with leading zeros suppressed. **[SHOULD]** thousands separators (`1,234.56`).
- **FR-8 [MUST]** Deposit: amount is typed as decimal text with 0-2 decimals (`125`, `125.5`, `125.50`). Reject empty, non-numeric, more than 2 decimals, zero, negative, and anything above 50,000.00 per transaction. Rejection never changes the balance.
- **FR-9 [MUST]** Withdraw: same parsing and limits. Reject if the amount exceeds the balance (insufficient funds), detected from the borrow out of the BCD subtraction. Balance is unchanged on failure.
- **FR-10 [MUST]** Reject a deposit whose result would exceed 9,999,999,999.99 (carry out of the top BCD byte).
- **FR-11 [SHOULD]** Mini statement: the last 5 transactions of the logged-in account, read from the log into a circular buffer (index wraps).
- **FR-12 [SHOULD]** Change PIN: old PIN, then new PIN twice; update the hash and save.
- **FR-13 [MUST]** Exit: save data, restore interrupt vectors, return with AH=4Ch, ERRORLEVEL 0.
- **FR-14 [STRETCH]** Transfer between two accounts, atomic with respect to the data file.

### 3.3 Money arithmetic
- **FR-15 [MUST]** Balances are 6 bytes of packed BCD, little-endian (lowest digits first), 2 implied decimals (12 digits total). Add with `ADC` then `DAA`; subtract with `SBB` then `DAS`, one byte at a time in a loop. Provide `bcd_add`, `bcd_sub`, `bcd_cmp`, `bcd_parse` (text to BCD), and `bcd_format` (BCD to text).

### 3.4 Persistence
- **FR-16 [MUST]** `ACCOUNTS.DAT` (binary) is loaded at start and saved after every successful transaction. If it is missing, print a message to run with `/I`. `/I` creates three seed accounts:
  - 1001, PIN 1234, balance 1000.00
  - 1002, PIN 4321, balance 250.75
  - 1003, PIN 1111, balance 0.00
- **FR-17 [MUST]** File layout: header (magic bytes, record count), records, 16-bit checksum. Suggested 16-byte record: account number (4 ASCII digits), PIN hash (word), balance (6 bytes BCD), status byte, 3 reserved. Document the final layout in `DOCS\DESIGN.md` before using it. On checksum mismatch refuse to start with "data file corrupted".
- **FR-18 [MUST]** `TXN.LOG` is an append-only text file, one line per transaction: account, type (D/W/P), amount, resulting balance, date, time. Use INT 21h file functions (3Ch, 3Dh, 3Eh, 3Fh, 40h, 42h) and AH=2Ah/2Ch for date and time.

### 3.5 Interrupts, I/O, and switches
- **FR-19 [MUST]** Idle timeout: hook INT 1Ch with an ISR that increments a tick counter (about 18.2 ticks/s). While waiting for input, the main loop polls stdin status (AH=0Bh) and logs the user out after 30 s with no key. The counter resets on any key. ISR rules are in the instructions file (save/restore registers, `CS:` data access, chain to old handler, `IRET`).
- **FR-20 [MUST]** Hook INT 23h (Ctrl-C) and INT 1Bh (Ctrl-Break) so they cannot be used to bypass login. The handler prints a notice and returns with `IRET`. Original vectors are saved with AH=35h and restored with AH=25h on every exit path (normal exit, lockout, timeout, error).
- **FR-21 [SHOULD]** Audible alert on a failed PIN and on lockout: program PIT channel 2 (`OUT` to ports 43h/42h), gate the speaker through port 61h, wait briefly, then switch the speaker off (`IN`/`OUT`).
- **FR-22 [MUST]** Command-line switches parsed from the PSP command tail (offset 80h, length byte first, using string instructions):
  - `/T` test mode: idle timeout off, no beep, timestamps fixed to 2000-01-01 00:00:00
  - `/I` initialize data files
  - `/B` run the benchmark (section 5)
  - `/U <acct>` unlock an account

## 4. Non-functional requirements
- **NFR-1** 8086-only code, enforced by `.8086` (see the forbidden list in the instructions file).
- **NFR-2** Segment hygiene: `DS`/`ES` set deliberately, PSP segment saved, `ES` used for string destinations, `CS:` override for ISR data.
- **NFR-3** Every procedure has the header comment defined in the instructions file.
- **NFR-4** `DOCS\ISA_FEATURES.md` lists each 8086 feature used (each addressing mode, string instructions with `REP`/`REPE`, `XLAT`, `DAA`/`DAS`, `ADC`/`SBB`, `MUL`/`DIV`, shifts/rotates, `LOOP`, `INT`/`IRET`, `PUSHF`/`POPF`, `CLI`/`STI`, `IN`/`OUT`, segment overrides) with the procedure where it is used and why it fits. Do not add a feature to the list unless the code really uses it.
- **NFR-5** Addressing modes should appear naturally in the code: immediate, register, direct, register indirect, based (`[BX+disp]`), indexed (`[SI+disp]`), based-indexed (`[BX+SI]`), and based-indexed with displacement (for example, record field access in the account table).

## 5. Efficiency and optimization (graded criterion)
Implement `/B` to compare these variants over many iterations (for example 5,000 repeats):
1. 6-byte packed-BCD add with a `LOOP`.
2. The same add with the loop unrolled.
3. Binary 32-bit add (`ADD`/`ADC`) followed by binary-to-decimal conversion for display.

Write `DOCS\BENCH.md` with: (a) theoretical analysis from the Intel 8086 instruction-timing tables, including effective-address costs, and (b) empirical timings using the BIOS tick counter. State clearly that DOSBox timings are relative, not real 8086 cycle counts. Report honest conclusions even if the "optimized" variant is not faster.

## 6. Test plan
Tests run with `/T`, stdin redirected from `TESTS\*.IN`, stdout redirected to a file, diffed against `TESTS\*.EXP`. Minimum cases:

| ID | Scenario | Expected |
|---|---|---|
| T01 | Login 1001/1234, balance, exit | shows 1000.00 |
| T02 | Wrong PIN three times | locked, ERRORLEVEL 2 |
| T03 | Unknown account | same message as wrong PIN |
| T04 | Deposit 100.50 | balance increases correctly |
| T05 | Withdraw more than balance | rejected, balance unchanged |
| T06 | Withdraw exact balance | 0.00 |
| T07 | Deposit that carries across BCD bytes (e.g. 99999.99 + 0.01) | exact carry |
| T08 | Deposit past 9,999,999,999.99 | rejected by overflow check |
| T09 | Bad amounts: empty, `abc`, `1.234`, `-5`, `0`, `50000.01` | each rejected |
| T10 | Two runs in a row | balance persisted |
| T11 | Tampered `ACCOUNTS.DAT` | refuses to start |
| T12 | Mini statement after 7 transactions | last 5, correct order |
| T13 | Change PIN then re-login | old PIN fails, new works |
| T14 | `/U` after lockout | account usable again |

Manual checks (not scriptable): idle timeout fires after 30 s, Ctrl-C/Ctrl-Break are ignored at login, and the interrupt vectors match their original values after exit (verify in the debugger).

## 7. Stages
Do one stage at a time. Each ends with passing tests, updated `DOCS\DESIGN.md`, and human approval.

- **Stage 0: toolchain and headless loop.** Find the MASM/TASM tools the VS Code extension uses (probably inside the extension's install folder under `%USERPROFILE%\.vscode\extensions`) and write `TOOLS\BUILD.BAT` and a runner that launches DOSBox headless (`-c` commands, program output redirected to a file, `exit` at the end). Prove it with a hello-world. Then prove stdin redirection with INT 21h AH=08h/0Ah. If headless DOSBox or stdin redirection does not work, stop and report; the fallback is manual runs with screenshots.
- **Stage 1: I/O library.** Print string/char/newline, read line, read masked PIN, print decimal, command-line parsing.
- **Stage 2: BCD library.** `bcd_add`, `bcd_sub`, `bcd_cmp`, `bcd_parse`, `bcd_format`, tested with known vectors (carry across all 6 bytes, borrow across all 6 bytes).
- **Stage 3: accounts and login.** In-memory account table, lookup with `REPE CMPSB`, salted PIN hash, 3-attempt limit, lockout.
- **Stage 4: menu and transactions.** Balance, deposit, withdraw, exit, with all validation. Tests T01-T09.
- **Stage 5: persistence.** `ACCOUNTS.DAT` with checksum, `TXN.LOG`, mini statement, change PIN, unlock. Tests T10-T14.
- **Stage 6: interrupts and I/O.** INT 1Ch idle-timeout ISR, INT 23h/1Bh hooks, vector restore on all exits, speaker alert.
- **Stage 7: optimization and documentation.** `/B` benchmark, `DOCS\BENCH.md`, finalize `DOCS\ISA_FEATURES.md` and `DOCS\DESIGN.md`, and collect screenshots for the report.

## 8. Definition of done
All MUST items implemented, tests passing, procedures documented, `ISA_FEATURES.md` accurate, `BENCH.md` written, and the student can explain every procedure and trace the BCD add/sub by hand.
