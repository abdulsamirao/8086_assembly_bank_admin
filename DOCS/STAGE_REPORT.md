# Stage 4 report

## 1. New routines

- `PIN_HASH` combines the four ASCII ID and PIN digits into a documented 16-bit salted teaching hash, then clears the PIN bytes.
- `PIN_VERIFY` compares a freshly computed hash with the stored word and inherits the PIN clearing behavior.
- `DATA_COMPUTE_CHECKSUM` adds the file-image bytes, excluding the checksum field, into a 16-bit sum.
- `DATA_SAVE` validates the customer count, stores the checksum, and writes the bounded image through DOS file calls.
- `DATA_LOAD` reads and checks the header, exact file size, and checksum, distinguishing missing, corrupt, and I/O-error results.
- `DATA_INIT` creates the admin and three customer seed records, hashes their PINs, removes the old audit log, and saves the image.
- `TEST_PIN_HASH` and `TEST_PIN_VERIFY` exercise the seed hash plus matching and mismatching PIN verification.
- `TEST_DATA_PERSIST` checks seed save/reload; `TEST_DATA_CORRUPT` damages a checksum; `TEST_DATA_MISSING` checks the missing-file status.

## 2. Files created or changed

- Created `SRC\DATA.INC`; changed `SRC\BANK.ASM` and `SRC\TDRV.ASM`.
- Changed `DOCS\DESIGN.md` and `DOCS\ISA_FEATURES.md`.
- Added `TESTS\I04.*`, `TESTS\P04.*`, `TESTS\P05.*`, `TESTS\T09.*`, `TESTS\T18.*`, and `TESTS\T19.*`.
- Added `TESTS\T22.IN`, `TESTS\T22.EXP`, `TESTS\T22.PGM`, and `TESTS\T22.RC`.
- Created this report at `DOCS\STAGE_REPORT.md`.

## 3. Exact RUNHOST.PS1 result

Command: `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`

Process exit code: `0`.

Runner output: `8086 lint passed: 5 ASM/INC sources checked.`; `PASS: LINT8086.PS1 flags the throwaway forbidden-instruction cases.`; TASM/TLINK build passed; all output comparisons passed with these captured DOS exit codes:

```text
D00=0 D01=0 D02=0 D03=0 D04=0
HELLO=2 I04=0
L02=0 L03=0 L04=0
P04=0 P05=0 READKEY=0
S01=0 S02=0 S03=0 S04=0 S05=1 S06=0 S07=1
SW01=0 SW02=1 SW03=1 SW04=0 SW05=0 SW06=1 SW07=1
T09=0 T18=0 T19=0 T20=0 T22=3
```

The runner also printed `PASS: .8086 rejects BADPUSHA.ASM.` and `PASS: TASM accepts the source syntax but emits four 8086-valid D1 E0 (SHL AX,1) instructions.`

## 4. Anything unsure about

None. The hash is explicitly educational and non-cryptographic; its algorithm and seed values are documented in `DOCS\DESIGN.md`.

## 5. Student questions

1. **Why is the customer count limited to eight?** The fixed image reserves exactly eight 16-byte customer records.
2. **How is the file length computed for three customers?** `24 + (3 * 16) = 72` bytes, including the header, admin record, and checksum.
3. **Which file bytes contribute to the checksum?** Every byte before the final two-byte checksum field.
4. **What status does `DATA_LOAD` return for a missing file versus a checksum mismatch?** AL=1 for missing and AL=2 for corrupt.
5. **Why does hashing overwrite the PIN buffer?** To avoid retaining plaintext PIN digits after the calculation.

# Stage 5 report and Stage 4 seed correction

## 1. New routines

- `ADMIN_RUN` starts authentication and enters the menu only after success.
- `ADMIN_LOGIN` checks salted admin credentials and locks the console after three failures.
- `ADMIN_READ_ID` accepts exactly four decimal ID characters and distinguishes malformed input from EOF.
- `ADMIN_CLEAR_PIN` erases rejected or partial PIN input with `REP STOSB`.
- `ADMIN_MENU` prints and dispatches the nine specified choices; choices 4-8 await Stage 6.
- `ADMIN_LIST` prints all account rows with packed-BCD balances formatted by `bcd_format`.
- `ADMIN_LOOKUP` scans four-byte IDs with `REPE CMPSB` and returns the matching record offset.
- `ADMIN_PRINT_RECORD` prints one account's ID, status, and balance.
- `ADMIN_VIEW` handles known, unknown, and malformed account-number lookups.
- `ADMIN_CREATE` validates a new ID/PIN/opening amount, writes the record, and saves the data image.

## 2. Files created or changed

- Created `SRC\ADMIN.INC`; updated `SRC\BANK.ASM` to load data and run the new admin workflow.
- Corrected the 1001 seed balance in `SRC\DATA.INC`; expanded `SRC\TDRV.ASM` persistence assertions to check every seeded ID, hash, balance, and status.
- Updated `TOOLS\ORACLE.PY` to independently derive PIN hashes, packed-BCD seed values, checksum, and Stage 5 fixture expectations.
- Updated `TOOLS\RUNHOST.PS1` to snapshot `.DAT` test outputs immediately and compare the full binary image.
- Updated `DOCS\DESIGN.md` with the seed correction, corrected checksum, runner sidecar behavior, procedure explanations, and the account lookup hand trace; updated `DOCS\ISA_FEATURES.md` for Stage 5 uses.
- Appended this report to `DOCS\STAGE_REPORT.md`.
- Created `TESTS\I05.IN`, `.EXP`, `.ARG`, `.PGM`, `.RC`, and oracle-generated `.DAT` for the whole `/I` image comparison.
- Created `TESTS\T00.IN`, `.EXP`, `.ARG`, `.PGM`, `.RC`, and oracle-generated `.DAT` to reset seed state before account workflow tests.
- Created `TESTS\T01` through `T07` `.IN`, `.EXP`, `.ARG`, `.PGM`, and `.RC` files for login, lockout, list/view/create, and rejection cases.
- Re-generated the existing `TESTS\T20` fixtures from the unchanged Stage 3 oracle vectors.

The Stage 4 false positive was in `TEST_DATA_PERSIST` in `SRC\TDRV.ASM`, which compared 1001's balance against `75 50 02`. P04.EXP only contains `PERSISTENCE OK`; no existing `.EXP` contained the incorrect numeric balance, and no expected output was copied from program output. The original test passed because its assertion repeated the seed bug. The new oracle independently computes the four hashes and balances and checks all 72 file bytes.

## 3. Exact RUNHOST.PS1 result

Command: `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`

Process exit code: `0`.

Runner output included:

```text
8086 lint passed: 6 ASM/INC sources checked.
PASS: LINT8086.PS1 flags the throwaway forbidden-instruction cases.
PASS: C:\practical\CALD_PROJECT\TOOLS\I05.ACT matches C:\practical\CALD_PROJECT\TESTS\I05.DAT byte-for-byte.
PASS: C:\practical\CALD_PROJECT\TOOLS\T00.ACT matches C:\practical\CALD_PROJECT\TESTS\T00.DAT byte-for-byte.
PASS: C:\practical\CALD_PROJECT\TOOLS\T01.OUT matches C:\practical\CALD_PROJECT\TESTS\T01.EXP; exit code 0 captured.
PASS: C:\practical\CALD_PROJECT\TOOLS\T02.OUT matches C:\practical\CALD_PROJECT\TESTS\T02.EXP; exit code 2 captured.
PASS: C:\practical\CALD_PROJECT\TOOLS\T03.OUT matches C:\practical\CALD_PROJECT\TESTS\T03.EXP; exit code 0 captured.
PASS: C:\practical\CALD_PROJECT\TOOLS\T04.OUT matches C:\practical\CALD_PROJECT\TESTS\T04.EXP; exit code 0 captured.
PASS: C:\practical\CALD_PROJECT\TOOLS\T05.OUT matches C:\practical\CALD_PROJECT\TESTS\T05.EXP; exit code 0 captured.
PASS: C:\practical\CALD_PROJECT\TOOLS\T06.OUT matches C:\practical\CALD_PROJECT\TESTS\T06.EXP; exit code 0 captured.
PASS: C:\practical\CALD_PROJECT\TOOLS\T07.OUT matches C:\practical\CALD_PROJECT\TESTS\T07.EXP; exit code 0 captured.
Stage 0 headless proof passed.
```

All 41 input/output comparisons passed; TASM/TLINK built both programs, and the runner emitted no errors.

Captured DOS exit codes:

```text
D00=0 D01=0 D02=0 D03=0 D04=0 HELLO=2 I04=0 I05=0
L02=0 L03=0 L04=0 P04=0 P05=0 READKEY=0
S01=0 S02=0 S03=0 S04=0 S05=1 S06=0 S07=1
SW01=0 SW02=1 SW03=1 SW04=0 SW05=0 SW06=1 SW07=1
T00=0 T01=0 T02=2 T03=0 T04=0 T05=0 T06=0 T07=0
T09=0 T18=0 T19=0 T20=0 T22=3
```

## 4. Anything unsure about

FR-3 requires each failed login to be appended to AUDIT.LOG. The stage plan assigns audit append to Stage 6, so this Stage 5 implementation reports failures generically and locks after three attempts, but does not yet persist failed-login audit rows. Stage 6 must complete that requirement. Menu choices 4-8 are also intentionally unavailable until Stage 6.

## 5. Student questions

1. **How does admin login avoid revealing whether an ID exists?** It always asks for a PIN and gives the same generic failure response for an unknown ID or wrong PIN.
2. **Why does `ADMIN_LOOKUP` use `REPE CMPSB`?** It compares the fixed four-byte account IDs and stops at the first differing byte.
3. **How is the nth account record located?** At `DATA_ACCOUNT_OFFSET + 16*n`; each record is 16 bytes.
4. **Why is a customer PIN cleared after hashing?** The plaintext digits should not remain in the shared input buffer.
5. **How does create enforce the opening-balance limit?** `bcd_parse` converts the text, then `bcd_cmp` rejects values above the packed-BCD 50,000.00 limit; zero is allowed.

# Stage 6 report

## 1. New routines

- `ADMIN_SET_AUDIT_ACCOUNT` copies a fixed four-digit account ID into the audit field.
- `ADMIN_LOCK` toggles and saves account status, then audits LOCK or UNLOCK.
- `ADMIN_RESET_PIN` hashes and saves a customer PIN without retaining its plaintext.
- `ADMIN_ADJUST` validates and applies bounded BCD credits/debits, restoring rejected changes.
- `ADMIN_REPORT` counts account states and totals balances in seven packed-BCD bytes.
- `ADMIN_FORMAT_TOTAL` formats the seven-byte summary total with two decimals.
- `AUDIT_WRITE` timestamps and appends one event line to `AUDIT.LOG`.
- `AUDIT_COPY_DOLLAR` copies a terminated audit field while preserving caller flags.
- `AUDIT_WRITE_TWO` emits a two-digit decimal field for the audit timestamp.
- `AUDIT_WRITE_YEAR` emits the four-digit year using reversed DIV remainders.

## 2. Files created or changed

- Changed `SRC\ADMIN.INC` with Stage 6 operations, audit append, seven-byte report total, and menu dispatch.
- Changed `TOOLS\RUNHOST.PS1` to sort test cases, apply `.INI` account fixtures, compare `.LOG` snapshots, and allow a 60-second whole-suite timeout.
- Changed `.gitattributes` to keep `.INI`/`.DAT` fixtures binary and audit `.LOG` fixtures CRLF.
- Changed `DOCS\DESIGN.md` with each new procedure's calling behavior, the audit layout, a BCD carry trace, and the test-fixture workflow.
- Changed `DOCS\ISA_FEATURES.md` to record the Stage 6 instructions, addressing forms, DOS date/time, and file operations.
- Created `TOOLS\OR6.PY` and Stage 6 fixtures `TESTS\Z08A` through `Z18` (`.IN`, `.EXP`, `.ARG`, `.PGM`, `.RC`, plus `.INI`, `.DAT`, and `.LOG` where applicable).
- Added `TESTS\Z19` to reproduce creating and locking a non-seed account in one session; its view and persisted status are checked.
- Preserved the existing T09 hash test and all earlier `.IN` and `.EXP` files; the reset-PIN case is `Z09`.
- Appended this section to `DOCS\STAGE_REPORT.md`.

## 3. Exact RUNHOST.PS1 result

Command: `powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1`

Process exit code: `0`. TASM/TLINK built the programs; the runner reported `8086 lint passed: 6 ASM/INC sources checked.` and `PASS: LINT8086.PS1 flags the throwaway forbidden-instruction cases.` It passed all 53 `.OUT`/`.EXP` comparisons, all 14 `.DAT` binary comparisons, and all 12 `.LOG` audit comparisons; every captured DOS exit code matched its `.RC` where provided. The final runner line was:

```text
Stage 0 headless proof passed.
```

## 4. Anything unsure about

The T09 label conflict was resolved as directed: the existing T09 `/T HASH` regression remains unchanged, and reset-PIN persistence is covered by the new Z09 case. No other Stage 6 behavior remains unresolved. The audit viewer is not implemented; menu choice 8 uses the explicit FR-19 fallback `Audit log: see AUDIT.LOG`.

## 5. Student questions

1. **Which record byte represents account status?** Offset 12: `01h` is active and `00h` is locked.
2. **How does an adjustment reject overflow or overdraft without changing the balance?** It snapshots six bytes, checks CF from `bcd_add`/`bcd_sub`, and restores the snapshot on rejection.
3. **Why is the PIN buffer safe to reuse after reset?** `PIN_HASH` clears its four input bytes with `REP STOSB`.
4. **How does `/T` make audit tests deterministic?** `AUDIT_WRITE` uses `2000-01-01 00:00:00` instead of DOS clock values.
5. **Why does the summary use a seventh BCD byte?** Eight valid six-byte balances can carry beyond the six-byte range; the extra byte retains that carry.
