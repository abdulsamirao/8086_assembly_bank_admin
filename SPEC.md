SPEC v2: 8086 Bank Admin Console (CALD Lab 13 CEA)

Audience: an AI coding agent (VS Code Agent Mode) working with a student. Read .github/copilot-instructions.md first; it holds the hard rules and the working style.

Priority tags: [MUST] required for submission, [SHOULD] do after all MUSTs pass, [STRETCH] only if time remains.

0. Status and what changed

The instructor re-scoped the project from a customer-side ATM to the admin side of a banking app. This file replaces the old SPEC.md.

Stage 0 (headless build/test harness): DONE. Reuse as is.
Stage 1 (I/O library): DONE. SRC\IO.INC provides print string/char/newline/decimal, line input, masked 4-digit PIN input, and command-tail parsing. Reuse as is.
Stages 2-8 below are new.
Known rework: the /T <operation> test dispatcher currently lives inside SRC\BANK.ASM and must move to a separate test driver (Stage 2). The Stage 1 /U <acct> switch was a parsing placeholder; it is retired as a product feature (Stage 2 decides how to retire its tests).
1. Goal

A text-mode (no GUI) back-office console in real-mode 8086 assembly for DOS. A bank administrator logs in with an admin ID and PIN, then manages customer accounts: list and view, create, lock/unlock, reset a customer PIN, post balance adjustments, see a summary report, and review an audit log. Features are chosen to exercise 8086-specific capabilities: packed-BCD money arithmetic, string instructions, DOS file I/O, and a hooked timer interrupt.

Real-world framing for the report: back-office access control, account lifecycle management, decimal-exact money handling (why packed decimal exists in financial systems), an audit trail of admin actions, and session timeout. It is an educational project, not real security.

Grading criteria (2 marks each): correctness, efficiency/optimization, code clarity/documentation, real-world relevance, use of ISA features.

2. Platform and toolchain (already built)
DOSBox Staging, TASM/TLINK extracted from the VS Code MASM/TASM extension by TOOLS\BOOT86.PS1. Code must also assemble with MASM syntax.
Run everything through TOOLS\RUNHOST.PS1 (build, run all TESTS\*.IN cases, byte-compare against .EXP, lint for 8086 conformance).
Layout (extend, don't reorganize):
  SRC\    BANK.ASM (product)  TDRV.ASM (test driver)  IO.INC  BCD.INC  DATA.INC  ADMIN.INC  ISR.INC
  TOOLS\  existing scripts (+ ORACLE.PY and similar test generators)
  TESTS\  *.IN  *.EXP  *.ARG  (plus an optional file naming which program a test runs; propose the simplest scheme in Stage 2)
  DOCS\   DESIGN.md  ISA_FEATURES.md  BENCH.md
Product binary BANK.EXE contains no test code. TDRV.EXE includes the same .INC modules and exposes test operations.
3. Functional requirements
3.1 Admin authentication
FR-1 [MUST] Prompt for a 4-digit admin ID (line input), then the admin PIN (masked * input, digits only, reuse the Stage 1 routines).
FR-2 [MUST] PINs are never stored in plaintext. Store a 16-bit salted hash (salt = the 4-digit ID; use ROL by 1, XOR, ADD, and one MUL; the exact design is yours but must be documented in DESIGN.md as non-cryptographic). Verify by hashing the input and comparing. Clear the PIN buffer with REP STOSB after use.
FR-3 [MUST] 3 failed logins end the program with "Login failed. Console locked." and exit code 2. An unknown admin ID counts as a failed attempt with the same message as a wrong PIN (no ID enumeration). Every failed login is written to the audit log (FR-18).
3.2 Menu and account operations
FR-4 [MUST] After login, show: 1 List accounts  2 View account  3 Create account  4 Lock/Unlock  5 Reset customer PIN  6 Adjust balance  7 Summary report  8 Audit log  9 Exit. An invalid choice re-prompts.
FR-5 [MUST] List accounts, in this exact format (so tests are deterministic):
  ACCT  STATUS  BALANCE
  1001  ACTIVE  1000.00
  1003  LOCKED  0.00

Balance shows leading zeros suppressed, always two decimals. [SHOULD] thousands separators (1,234.56) as long as the format stays fixed and documented.

FR-6 [MUST] View account: ask for a 4-digit account number, show account, status, and balance. An unknown or malformed number prints "Account not found" and returns to the menu. Lookup uses a string instruction (REPE CMPSB) over the record table.
FR-7 [MUST] Create account: ask for a new 4-digit account number (reject non-digits and duplicates), a customer PIN (masked), and an opening balance (FR-11 parsing and limits). Reject when the table is full (maximum 8 customer accounts). Store only the PIN hash. [SHOULD] ask for the PIN twice and require a match.
FR-8 [MUST] Lock/Unlock: toggle an account's status, print the new status, persist it.
FR-9 [MUST] Reset customer PIN: ask for an account number and a new masked 4-digit PIN, store the new hash, persist it. [SHOULD] confirm twice.
FR-10 [MUST] Adjust balance: ask for an account number, C (credit) or D (debit), and an amount.
Credit: add with ADC+DAA; reject if the result would exceed 9,999,999,999.99 (carry out of the top byte).
Debit: subtract with SBB+DAS; reject if it would overdraw (borrow out of the top byte); the balance is unchanged on any rejection.
Locked accounts can still be adjusted (admins may correct them), and the audit entry records the amount.
FR-11 [MUST] Amounts are typed as digits, optionally followed by a decimal point and one or two digits (125, 125.5, 125.50). Input must match ^[0-9]{1,10}(\.[0-9]{1,2})?$; a trailing point (125.), a leading point (.5), signs, spaces, separators, and more than 10 integer digits are rejected. The parser accepts zero; the 50,000.00 limit and the non-zero rule are enforced by the callers. Reject empty, non-numeric, more than 2 decimals, zero, negative, and anything above 50,000.00. Opening balances use the same rules (zero is allowed for an opening balance).
FR-12 [MUST] Summary report, in this exact format:
  ACCOUNTS: 3
  ACTIVE: 2
  LOCKED: 1
  TOTAL: 1250.75

TOTAL is the packed-BCD sum of all balances. [SHOULD] add HIGHEST: <acct> <balance> using bcd_cmp.

FR-13 [MUST] Exit: save data, restore interrupt vectors, return to DOS with ERRORLEVEL 0.
FR-14 [STRETCH] Close account (only when the balance is zero), and/or search by status.
3.3 Money arithmetic
FR-15 [MUST] Balances are 6 bytes of packed BCD, little-endian (lowest digits first), with 2 implied decimals (12 digits). Provide bcd_add, bcd_sub, bcd_cmp, bcd_parse (text to BCD), and bcd_format (BCD to text). Add with ADC+DAA; subtract with SBB+DAS; one byte at a time, preserving the carry flag as described in the instructions file.
3.4 Persistence and audit
FR-16 [MUST] ACCOUNTS.DAT (binary) is loaded at start and saved after every change. If it is missing, print "Run with /I to initialize" and exit with code 3. /I creates the seed data:
admin 9001, PIN 1357
customer 1001, PIN 1234, balance 1000.00, ACTIVE
customer 1002, PIN 4321, balance 250.75, ACTIVE
customer 1003, PIN 1111, balance 0.00, LOCKED
FR-17 [MUST] File layout: header (magic bytes, version, customer count), one 16-byte admin record, up to 8 customer records of 16 bytes, then a 16-bit checksum. Suggested customer record: account number (4 ASCII digits), PIN hash (word), balance (6 bytes BCD), status byte, 3 reserved. Suggested admin record: ID (4 ASCII digits), PIN hash (word), 10 reserved. Document the final layout in DESIGN.md before using it. On checksum mismatch print "Data file corrupted" and exit with code 3.
FR-18 [MUST] AUDIT.LOG is an append-only text file with one line per admin event: <date> <time> <admin-id> <ACTION> <acct> <detail>. Actions: LOGIN, FAILED (admin ID as typed, or ---- if not 4 digits), CREATE, LOCK, UNLOCK, RESETPIN, CREDIT, DEBIT, REPORT, EXIT, TIMEOUT. Use DOS file functions (create/open, seek to end, write, close) and AH=2Ah/2Ch for date and time. Unused fields print -.
FR-19 [SHOULD] Menu item 8 shows the last 10 audit lines using a 10-slot circular buffer (index wraps), reading the log sequentially. If this is cut, menu item 8 prints "Audit log: see AUDIT.LOG".
3.5 Interrupts, I/O, and switches
FR-20 [MUST] Idle timeout: hook INT 1Ch with an ISR that increments a tick counter (about 18.2 ticks/s). While waiting for menu input, the main loop polls stdin status (AH=0Bh) and, after 30 s with no key, logs TIMEOUT, saves, restores vectors, prints "Session timed out", and exits with code 4. The counter resets on any key. ISR rules are in the instructions file.
FR-21 [SHOULD] Hook INT 23h (Ctrl-C) and INT 1Bh (Ctrl-Break) during the session so they cannot be used to bypass the login. The handler prints a notice and returns with IRET. Restore the original vectors on every exit path. Best-effort under DOSBox.
FR-22 [STRETCH] Beep on failed login via PIT channel 2 (OUT to ports 43h/42h) and the speaker gate on port 61h (IN/OUT), then switch the speaker off.
FR-23 [MUST] Command-line switches (already parsed by Stage 1):
/T test mode: idle timeout off, no beep, audit timestamps fixed to 2000-01-01 00:00:00
/I initialize data files (also deletes any existing AUDIT.LOG)
/B run the benchmark (section 5)
/U retired (see section 0)
Unknown switch: message and exit code 1.

Exit codes: 0 normal, 1 bad switch or usage, 2 admin lockout, 3 data file missing or corrupt, 4 idle timeout.

4. Non-functional requirements
NFR-1 8086-only code, enforced by .8086 and TOOLS\LINT8086.PS1.
NFR-2 Segment hygiene: DS/ES set deliberately, ES equals DS except where documented, PSP segment saved, CS: override for ISR data.
NFR-3 Every procedure has the header comment from the instructions file, with an accurate ISA: line.
NFR-4 DOCS\ISA_FEATURES.md lists each 8086 feature actually used (each addressing mode, string instructions with REP/REPE, XLAT if used, DAA/DAS, ADC/SBB, MUL/DIV, shifts/rotates, LOOP, INT/IRET, PUSHF/POPF, CLI/STI, segment overrides, and IN/OUT if FR-22 is done) with the procedure where it is used and why it fits. Do not list a feature the code does not use.
NFR-5 Addressing modes appear where natural: immediate, register, direct, register indirect, based ([BX+disp]), indexed ([SI+disp]), based-indexed ([BX+SI]), and based-indexed with displacement (for example, field access inside an account record).
5. Efficiency and optimization (graded criterion)

Implement /B to compare these variants over many iterations (for example 5,000 repeats):

6-byte packed-BCD add with a LOOP.
The same add with the loop unrolled.
Binary 32-bit add (ADD/ADC) followed by binary-to-decimal conversion for display.

Write DOCS\BENCH.md with (a) theoretical analysis from the Intel 8086 instruction-timing tables, including effective-address costs, and (b) empirical timings using the BIOS tick counter, stating that DOSBox timings are relative and not real 8086 cycle counts. Report honest conclusions even if the "optimized" variant is not faster. A second small comparison is welcome if cheap: the shift-by-1 sequence the assembler emits versus MOV CL,n + SHL r,CL.

6. Test plan

All tests run with /T, stdin redirected, stdout compared byte-for-byte. Expected files come from independent oracles (a Python decimal script for money, a Python mirror of the documented hash, or hand derivation from this spec).

ID	Scenario	Expected
T01	Login 9001/1357, exit	success, exit code 0
T02	Wrong PIN three times	"Console locked", exit code 2
T03	Unknown admin ID	same message as a wrong PIN
T04	List accounts on seed data	exact format from FR-5
T05	View existing, unknown, and malformed account numbers	correct output or "Account not found"
T06	Create account, then view it	correct record and balance
T07	Create a duplicate account number; create when the table is full	each rejected
T08	Lock then unlock; lock persists across two runs	status as expected
T09	Reset PIN	stored hash matches the oracle's value for the new PIN
T10	Credit that carries across BCD bytes (99999.99 + 0.01)	exact
T11	Debit the exact balance	0.00
T12	Debit more than the balance	rejected, balance unchanged
T13	Credit past 9,999,999,999.99	rejected by the overflow check
T14	Bad amounts: empty, abc, 1.234, -5, 0, 50000.01	each rejected
T15	Summary report after several changes	matches the oracle's totals
T16	Audit log after a mixed session	exact lines with fixed timestamps
T17	Two runs in a row	all changes persisted
T18	Tampered ACCOUNTS.DAT	refuses to start, exit code 3
T19	Missing ACCOUNTS.DAT	message, exit code 3
T20	BCD unit vectors (carry across all 6 bytes, borrow across all 6, zero, equal compare, parse/format round-trips)	oracle-generated

Manual checks (not scriptable): idle timeout fires after 30 s, Ctrl-C/Ctrl-Break ignored if FR-21 is done, interrupt vectors match their original values after exit (verify in the debugger).

7. Stages

One stage at a time. Each ends with passing tests, updated DOCS\DESIGN.md, and human approval.

Stage 2: reconcile and refactor. Compare the existing code, tests, and DESIGN.md against this spec and list any conflicts. Move the test dispatcher out of BANK.ASM into TDRV.ASM, leaving BANK.ASM as the product shell. Extend the runner with the simplest scheme for choosing which program a test runs. Retire the /U product behavior and decide what happens to its tests. Everything that passed before must still pass.
Stage 3: BCD library. bcd_add, bcd_sub, bcd_cmp, bcd_parse, bcd_format, tested with oracle-generated vectors (T20).
Stage 4: data model and persistence. Record layout, PIN hash and verify, /I seeding, load/save with checksum, corrupt/missing file handling (T09's hash check, T18, T19, part of T17).
Stage 5: login, menu, and read/create operations. Admin login with lockout, menu loop, list, view, create (T01-T07).
Stage 6: write operations, report, audit. Lock/unlock, reset PIN, adjust balance, summary report, audit log append (and view if FR-19 is kept) (T08-T17).
Stage 7: interrupts. INT 1Ch idle timeout, vector save/restore on every exit path; then FR-21 if time allows.
Stage 8: optimization and documentation. /B benchmark, DOCS\BENCH.md, finish DOCS\ISA_FEATURES.md and DOCS\DESIGN.md, and collect screenshots (manual DOSBox runs) for the report.
8. If time runs short: cut in this order

STRETCH items, then FR-22, then FR-21, then the audit viewer (FR-19), then the "SHOULD" extras in 3.2. Do not cut the BCD arithmetic, persistence, audit append, or the idle-timeout ISR; they carry the ISA-features and real-world marks. Stages 2-6 alone give a complete, submittable admin console; Stage 7 adds the interrupt marks, Stage 8 the optimization and report marks.

9. Definition of done

All MUST items implemented, tests passing, procedures documented, ISA_FEATURES.md accurate, BENCH.md written, and the student can explain every procedure and trace a BCD carry and a BCD borrow by hand.