# Report evidence pack

This document collects implementation and test evidence for the 8086 Bank Admin
Console report. Status means implementation status unless the row explicitly
describes test coverage. `PARTIAL` distinguishes an implemented behavior whose
specified test evidence is incomplete or manual; `CUT` means the feature was
deliberately omitted.

## 1. SPEC requirement status and evidence

### Functional requirements

| ID | Status | Implementation and evidence |
|---|---|---|
| FR-1 | DONE | `SRC\ADMIN.INC`: `ADMIN_LOGIN`, `ADMIN_READ_ID`; `SRC\IO.INC`: `READ_LINE`, `READ_PIN`. A four-digit ID is line-read and the four-digit PIN is masked. Tested by `T01`-`T03`. |
| FR-2 | DONE | `SRC\DATA.INC`: `PIN_HASH`, `PIN_VERIFY`; `SRC\ADMIN.INC`: `ADMIN_CLEAR_PIN`. The stored value is a 16-bit salted demonstration hash, and the PIN bytes are cleared with `REP STOSB`. Hash evidence is `T09`, `P05`, and `Z09`. |
| FR-3 | DONE | `SRC\ADMIN.INC`: `ADMIN_LOGIN`, `AUDIT_WRITE`; `SRC\BANK.ASM`: `MAIN`. Three failures print the required lock message and return code 2; unknown IDs use the same failure path. Tested by `T02`, `T03`, and the failed-login audit fixture `Z15`. |
| FR-4 | DONE | `SRC\ADMIN.INC`: `ADMIN_MENU`. It displays the nine specified choices and repeats after invalid input. Menu paths are exercised by `T01`-`T07` and `Z08A`-`Z19`. |
| FR-5 | DONE | `SRC\ADMIN.INC`: `ADMIN_LIST`, `ADMIN_PRINT_RECORD`; `SRC\BCD.INC`: `bcd_format`. The header, columns, two decimals, and suppressed leading integer zeroes match the required format. `T04` compares the listing. The optional thousands separators are omitted. |
| FR-6 | DONE | `SRC\ADMIN.INC`: `ADMIN_VIEW`, `ADMIN_READ_ID`, `ADMIN_LOOKUP`, `ADMIN_PRINT_RECORD`. `ADMIN_LOOKUP` uses `REPE CMPSB`; unknown and malformed IDs show `Account not found`. Tested by `T05`. |
| FR-7 | DONE | `SRC\ADMIN.INC`: `ADMIN_CREATE`, `ADMIN_LOOKUP`; `SRC\DATA.INC`: `PIN_HASH`, `DATA_SAVE`; `SRC\BCD.INC`: `bcd_parse`. Validates four digits, duplicates, capacity, and opening balance; stores the hash rather than the PIN. Tested by `T06`, `T07`, and `Z17`/`Z19`. The optional second PIN confirmation is omitted. |
| FR-8 | DONE | `SRC\ADMIN.INC`: `ADMIN_LOCK`; `SRC\DATA.INC`: `DATA_SAVE`; `SRC\ADMIN.INC`: `AUDIT_WRITE`. The status toggles, persists, and logs only after a successful save. Tested across `Z08A`/`Z08B` and in `Z19`. |
| FR-9 | DONE | `SRC\ADMIN.INC`: `ADMIN_RESET_PIN`; `SRC\DATA.INC`: `PIN_HASH`, `DATA_SAVE`. Hashes and persists a masked new PIN. Tested by `Z09` with an expected data-image comparison. Optional double entry is omitted. |
| FR-10 | DONE | `SRC\ADMIN.INC`: `ADMIN_ADJUST`; `SRC\BCD.INC`: `bcd_add`, `bcd_sub`; `SRC\DATA.INC`: `DATA_SAVE`; `SRC\ADMIN.INC`: `AUDIT_WRITE`. Carry/borrow rejection restores the previous balance. `Z12` tests a multi-byte credit carry, `Z13` maximum-balance overflow, `Z16` exact-balance debit, and `Z11` zero/overdraw rejection. Locked accounts remain adjustable. |
| FR-11 | DONE | `SRC\BCD.INC`: `bcd_parse`; `SRC\ADMIN.INC`: `ADMIN_CREATE`, `ADMIN_ADJUST`. Parser enforces the specified lexical form; callers enforce the 50,000.00 limit and transaction non-zero rule while allowing a zero opening balance. `T20` covers 35 parser/arithmetic vectors; `T07` rejects a 50,000.01 opening balance. See test-coverage caveat for `T14`. |
| FR-12 | DONE | `SRC\ADMIN.INC`: `ADMIN_REPORT`, `ADMIN_FORMAT_TOTAL`; `SRC\BCD.INC`: `bcd_add`. Counts account status and sums balances in a seventh packed-BCD byte. `Z14` tests the seed report; `Z18` tests a wide total. Optional `HIGHEST` output is omitted. |
| FR-13 | DONE | `SRC\ADMIN.INC`: `ADMIN_MENU`, `ADMIN_RUN`; `SRC\ISR.INC`: `ISR_RESTORE`; `SRC\BANK.ASM`: `MAIN`. Mutations are saved synchronously by each write operation, exit appends `EXIT`, restores an installed timer vector, and returns code 0. No separate final save is needed because there is no deferred in-memory mutation. |
| FR-14 | CUT | No close-account or status-search procedure exists in `SRC\ADMIN.INC`; this is the explicitly optional stretch feature. |
| FR-15 | DONE | `SRC\BCD.INC`: `bcd_add`, `bcd_sub`, `bcd_cmp`, `bcd_parse`, `bcd_format`. Six-byte little-endian packed BCD is used for money; `T20` supplies independent-oracle vectors. |
| FR-16 | DONE | `SRC\DATA.INC`: `DATA_INIT`, `DATA_LOAD`, `DATA_SAVE`; `SRC\BANK.ASM`: `MAIN`. `/I` creates seed data and removes an old audit log; missing/corrupt files produce their specified messages and code 3. `I05`, `T18`, `T19`, and `T22` cover these paths. |
| FR-17 | DONE | `SRC\DATA.INC`: `DATA_SAVE`, `DATA_LOAD`, `DATA_COMPUTE_CHECKSUM`; `TOOLS\ORACLE.PY`: independent seed-image oracle. The finalized offsets and checksum are documented below. `I05` compares the initialized bytes; `T18` damages and rejects a checksum. |
| FR-18 | DONE | `SRC\ADMIN.INC`: `AUDIT_WRITE`, `AUDIT_WRITE_TWO`, `AUDIT_WRITE_YEAR`; action callers include `ADMIN_LOGIN`, `ADMIN_CREATE`, `ADMIN_LOCK`, `ADMIN_RESET_PIN`, `ADMIN_ADJUST`, `ADMIN_REPORT`, `ADMIN_MENU`, and `ADMIN_TIMEOUT`. It timestamps with DOS date/time except in `/T`, and appends via DOS file calls. Expected audit files are compared in the Stage 6 cases. |
| FR-19 | CUT | The last-ten-lines viewer and circular buffer are not implemented. `SRC\ADMIN.INC`: `ADMIN_MENU` prints the permitted fallback, `Audit log: see AUDIT.LOG`. Tested by `Z14`. |
| FR-20 | PARTIAL | Implemented in `SRC\ISR.INC`: `ISR_SAVE_VECTOR`, `ISR_INSTALL`, `ISR_RESTORE`, `TIMER_ISR`; and `SRC\ADMIN.INC`: `ADMIN_READ_MENU`, `ADMIN_TIMEOUT`, `ADMIN_RUN`. The threshold is 546 ticks (about 30 seconds); `/T` disables the hook. The interactive timeout and vector restoration remain manual DOSBox/debugger checks, not automated elapsed-time tests. |
| FR-21 | CUT | No INT 23h or INT 1Bh handlers are installed. This best-effort SHOULD item was left out; Ctrl-C/Ctrl-Break protection is not claimed. |
| FR-22 | CUT | No PIT/speaker port programming is present. The STRETCH beep was left out; there are no product `IN`/`OUT` instructions. |
| FR-23 | DONE | `SRC\IO.INC`: `PARSE_COMMAND`; `SRC\BANK.ASM`: `MAIN`. `/T`, `/I`, and `/B` dispatch to their implementations; retired `/U` and other unknown switches report `Unknown switch` with code 1. `SW01`-`SW07` exercise switch parsing. |

### Non-functional requirements

| ID | Status | Implementation and evidence |
|---|---|---|
| NFR-1 | DONE | All application source modules begin with `.8086`; `TOOLS\LINT8086.PS1` is run by `TOOLS\RUNHOST.PS1`. The final run also confirmed the linter rejects its forbidden-instruction fixtures. |
| NFR-2 | DONE | `SRC\BANK.ASM` and `SRC\TDRV.ASM`: `MAIN` save the PSP before changing `DS`, then set `DS`/`ES`; `SRC\ISR.INC`: `TIMER_ISR` accesses its state through `CS:`. Timeout/vector lifecycle is implemented but still needs the manual debugger verification noted for FR-20. |
| NFR-3 | DONE | Every procedure in `SRC\*.ASM` and `SRC\*.INC` has a purpose/inputs/outputs/registers/flags/ISA header. Header accuracy is source-level evidence; the linter does not validate prose. |
| NFR-4 | DONE | `DOCS\ISA_FEATURES.md` records the implemented instructions and addressing forms. The source search confirmed actual uses for the excerpts below and no product use of `XLAT`, `CLI`, `STI`, `IN`, or `OUT`. |
| NFR-5 | DONE | Natural examples appear in the code: immediate/register/direct in `BANK.MAIN`; register-indirect in `bcd_add`; based `[BX+disp]` in `ADMIN_PRINT_RECORD`; indexed `[SI+disp]` in `DATA_LOAD`; based-indexed `[BX+SI]` and `[BX+SI+disp]` in `BENCH_BINARY_FORMAT`. |

### SPEC test plan IDs

| ID | Status | Implemented coverage and evidence |
|---|---|---|
| T01 | DONE | `SRC\ADMIN.INC`: `ADMIN_LOGIN`, `ADMIN_MENU`, `ADMIN_RUN`; `TESTS\T01.*` verifies valid login and normal exit, code 0. |
| T02 | DONE | `SRC\ADMIN.INC`: `ADMIN_LOGIN`; `SRC\BANK.ASM`: `MAIN`; `TESTS\T02.*` verifies three wrong PINs, lock message, and code 2. |
| T03 | DONE | `SRC\ADMIN.INC`: `ADMIN_LOGIN`, `ADMIN_READ_ID`; `TESTS\T03.*` verifies an unknown ID fails without a distinct response before a successful login. |
| T04 | DONE | `SRC\ADMIN.INC`: `ADMIN_LIST`, `ADMIN_PRINT_RECORD`; `SRC\BCD.INC`: `bcd_format`; `TESTS\T04.*` compares the exact seed listing. |
| T05 | DONE | `SRC\ADMIN.INC`: `ADMIN_VIEW`, `ADMIN_LOOKUP`, `ADMIN_PRINT_RECORD`; `TESTS\T05.*` covers existing, unknown, and malformed IDs. |
| T06 | DONE | `SRC\ADMIN.INC`: `ADMIN_CREATE`, `ADMIN_VIEW`; `SRC\DATA.INC`: `PIN_HASH`, `DATA_SAVE`; `TESTS\T06.*` creates and views an account. |
| T07 | DONE | `SRC\ADMIN.INC`: `ADMIN_CREATE`, `ADMIN_LOOKUP`; `SRC\BCD.INC`: `bcd_parse`; `TESTS\T07.*` covers malformed/duplicate IDs, opening-balance limit, and full-table rejection. |
| T08 | DONE | `SRC\ADMIN.INC`: `ADMIN_LOCK`, `ADMIN_VIEW`; `SRC\DATA.INC`: `DATA_SAVE`, `DATA_LOAD`; `TESTS\Z08A.*`/`Z08B.*` check persistence across two processes. |
| T09 | DONE | `SRC\DATA.INC`: `PIN_HASH`; `SRC\TDRV.ASM`: `TEST_PIN_HASH`; `SRC\ADMIN.INC`: `ADMIN_RESET_PIN`; `TESTS\T09.*` checks the seed hash and `Z09.*` compares the reset-PIN image to the independent fixture. |
| T10 | DONE | `SRC\ADMIN.INC`: `ADMIN_ADJUST`; `SRC\BCD.INC`: `bcd_add`; `TESTS\Z12.*` verifies `99999.99 + 0.01` carries to `100000.00`. |
| T11 | DONE | `SRC\ADMIN.INC`: `ADMIN_ADJUST`; `SRC\BCD.INC`: `bcd_sub`; `TESTS\Z16.*` debits the exact `0.01` balance to zero. |
| T12 | DONE | `SRC\ADMIN.INC`: `ADMIN_ADJUST`; `SRC\BCD.INC`: `bcd_sub`; `TESTS\Z11.*` rejects zero and overdraw debits without changing the balance. |
| T13 | DONE | `SRC\ADMIN.INC`: `ADMIN_ADJUST`; `SRC\BCD.INC`: `bcd_add`; `TESTS\Z13.*` rejects a credit beyond `9,999,999,999.99`. |
| T14 | PARTIAL | `SRC\BCD.INC`: `bcd_parse`; `SRC\ADMIN.INC`: `ADMIN_CREATE`, `ADMIN_ADJUST`; `SRC\TDRV.ASM`: `RUN_BCD_TEST`. `TESTS\T20.*` checks malformed lexical inputs, `T07.*` rejects a `50000.01` opening amount, and `Z11.*` checks zero/overdraw transactions. No caller-level transaction case checks every listed bad amount, especially `50000.01` on `ADMIN_ADJUST`. |
| T15 | PARTIAL | `SRC\ADMIN.INC`: `ADMIN_REPORT`, `ADMIN_FORMAT_TOTAL`; `TESTS\Z14.*` checks the seed summary and `Z18.*` a wide total. No current case makes several changes and then compares the resulting report. |
| T16 | DONE | `SRC\ADMIN.INC`: `AUDIT_WRITE` and its login/account-operation callers; `TESTS\Z08A.*`, `Z08B.*`, `Z09.*`, `Z10.*`, `Z15.*`-`Z19.*` compare fixed-timestamp audit snapshots. |
| T17 | DONE | `SRC\DATA.INC`: `DATA_SAVE`, `DATA_LOAD`; `SRC\ADMIN.INC`: `ADMIN_LOCK`, `ADMIN_VIEW`; `TESTS\Z08A.*`/`Z08B.*` check persisted status in separate processes. |
| T18 | DONE | `SRC\DATA.INC`: `DATA_LOAD`, `DATA_COMPUTE_CHECKSUM`; `SRC\TDRV.ASM`: `TEST_DATA_CORRUPT`; `TESTS\T18.*` flips a checksum bit and requires corruption detection. |
| T19 | DONE | `SRC\DATA.INC`: `DATA_LOAD`; `SRC\BANK.ASM`: `MAIN`; `SRC\TDRV.ASM`: `TEST_DATA_MISSING`; `TESTS\T19.*` checks the missing-file guidance. |
| T20 | DONE | `SRC\BCD.INC`: all five BCD procedures; `SRC\TDRV.ASM`: `RUN_BCD_TEST`, `BCD_TEST_LOAD`; `TESTS\T20.*` contains 35 independent-oracle vectors from `TOOLS\ORACLE.PY`. |

The SPEC's manual checks are separate from T01-T20. Interactive idle timeout is
implemented but still needs a live wait/debugger check; INT 23h/INT 1Bh handling
was cut, so the Ctrl-C/Ctrl-Break check is not applicable; vector restoration
also remains a debugger/manual verification item.

## 2. Verbatim 8086 source evidence

Each code excerpt below was verified against its named source location by source
search. The displayed code is verbatim; each excerpt is no longer than 15 lines.
The optional mnemonics `XLAT`, `CLI`, `STI`, `IN`, and `OUT` were searched for
and are absent from the application source, so they are not represented as
implemented features.

### Addressing forms

**Immediate, register, and direct memory** — `SRC\BANK.ASM`, `MAIN`, lines 64-71:

```asm
    MOV AH, 62h
    INT 21h
    MOV SI, BX

    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX
    MOV PSP_SEGMENT, SI
```

**Register-indirect** — `SRC\BCD.INC`, `bcd_add`, lines 17-23:

```asm
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    LOOP bcd_add_byte
```

**Based `[BX+disp]`** — `SRC\ADMIN.INC`, `ADMIN_PRINT_RECORD`, line 666:

```asm
    CMP BYTE PTR [BX+12], 1
```

**Indexed `[SI+disp]`** — `SRC\DATA.INC`, `DATA_LOAD`, line 337:

```asm
    CMP DH, [SI+1]
```

**Based-indexed `[BX+SI]`** — `SRC\BENCH.INC`, `BENCH_BINARY_FORMAT`, line 190:

```asm
    MOV [BX+SI], AL
```

**Based-indexed with displacement `[BX+SI+disp]`** — `SRC\BENCH.INC`,
`BENCH_BINARY_FORMAT`, line 225:

```asm
    MOV AL, [BX+SI+1]
```

### Arithmetic, adjustment, and control-flow instructions

**Packed-BCD addition (`ADC`/`DAA`) and `LOOP`** — `SRC\BCD.INC`, `bcd_add`,
lines 17-23:

```asm
    MOV AL, [SI]
    ADC AL, [DI]
    DAA
    MOV [DI], AL
    INC SI
    INC DI
    LOOP bcd_add_byte
```

`MOV`, pointer `INC`, and `LOOP` preserve CF between `DAA` and the next byte's
`ADC`.

**Packed-BCD subtraction (`SBB`/`DAS`)** — `SRC\BCD.INC`, `bcd_sub`, lines 45-51:

```asm
    MOV AL, [DI]
    SBB AL, [SI]
    DAS
    MOV [DI], AL
    INC SI
    INC DI
    LOOP bcd_sub_byte
```

**Rotate, XOR, ADD, MUL, and loop** — `SRC\DATA.INC`, `PIN_HASH`, lines 38-49:

```asm
    MOV AX, 6D31h
    MOV CX, 4
PIN_HASH_NEXT:
    ROL AX, 1
    XOR AL, [SI]
    ADD AX, 0137h
    XOR AH, [DI]
    INC SI
    INC DI
    LOOP PIN_HASH_NEXT
    MOV BX, 251
    MUL BX
```

**`DIV`** — `SRC\BENCH.INC`, `BENCH_BINARY_FORMAT`, lines 169-176:

```asm
    MOV AX, BENCH_BINARY_HI
    XOR DX, DX
    DIV BX
    MOV BP, AX
    MOV AX, BENCH_BINARY_LO
    DIV BX
    MOV BENCH_BINARY_HI, BP
    MOV BENCH_BINARY_LO, AX
```

**One-bit shifts** — `SRC\BCD.INC`, `bcd_parse`, lines 148-161:

```asm
    MOV AL, [DI+BX]
    MOV AH, AL
    AND AL, 0Fh
    SHL AL, 1
    SHL AL, 1
    SHL AL, 1
    SHL AL, 1
    OR AL, DL
    MOV [DI+BX], AL
    MOV DL, AH
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
```

**Variable-count shift** — `SRC\DATA.INC`, `DATA_SAVE`, lines 141-144:

```asm
    XOR AH, AH
    MOV CL, 4
    SHL AX, CL
    ADD AX, 24
```

The 8086 variable-count form is used instead of an immediate shift count greater
than one.

### String instructions

**`REPE CMPSB`** — `SRC\ADMIN.INC`, `ADMIN_LOGIN`, lines 192-196:

```asm
    MOV SI, OFFSET ADMIN_ID_BUFFER
    MOV DI, OFFSET DATA_IMAGE+DATA_ADMIN_OFFSET
    MOV CX, 4
    REPE CMPSB
    POP ES
```

**`REP MOVSB`** — `SRC\ADMIN.INC`, `ADMIN_CREATE`, lines 808-810:

```asm
    MOV SI, OFFSET ADMIN_ID_BUFFER
    MOV CX, 4
    REP MOVSB
```

**`REP STOSB`** — `SRC\DATA.INC`, `PIN_HASH`, lines 52-57:

```asm
    PUSH DS
    POP ES
    MOV CX, 4
    XOR AL, AL
    CLD
    REP STOSB
```

**`LODSB`/`STOSB`** — `SRC\ADMIN.INC`, `AUDIT_COPY_DOLLAR`, lines 1579-1584:

```asm
AUDIT_COPY_DOLLAR_NEXT:
    LODSB
    CMP AL, '$'
    JE AUDIT_COPY_DOLLAR_DONE
    STOSB
    JMP AUDIT_COPY_DOLLAR_NEXT
```

### Interrupts, segment override, and flags

**DOS `INT 21h`** — `SRC\BANK.ASM`, `MAIN`, line 65:

```asm
    INT 21h
```

**BIOS `INT 1Ah`** — `SRC\BENCH.INC`, `BENCH_RUN`, line 25:

```asm
    INT 1Ah
```

**`CS:` override, `PUSHF`/`POPF`, far chain, and `IRET`** — `SRC\ISR.INC`,
`TIMER_ISR`, lines 121-130:

```asm
    PUSHF
    PUSH AX
    MOV AX, CS:ISR_TICKS
    INC AX
    MOV CS:ISR_TICKS, AX
    POP AX
    POPF
    PUSHF
    CALL DWORD PTR CS:ISR_OLD_OFFSET
    IRET
```

**`ES:` override** — `SRC\ADMIN.INC`, `AUDIT_WRITE_TWO`, line 1602:

```asm
    MOV ES:[DI], AL
```

## 3. Data-file record layout and PIN hash

`ACCOUNTS.DAT` has a 6-byte header, one 16-byte admin record, `count` 16-byte
customer records, then a two-byte checksum. All word/checksum values are
little-endian. The current maximum file size is 152 bytes.

| File offset | Size | Meaning |
|---:|---:|---|
| 0 | 4 | ASCII magic `CALD` |
| 4 | 1 | Version `01h` |
| 5 | 1 | Customer count, 0 through 8 |
| 6 | 4 | Admin ID, four ASCII digits |
| 10 | 2 | Admin PIN hash |
| 12 | 10 | Reserved zero bytes |
| 22 | 16 × count | Customer records, one record per account |
| 22 + 16 × i | 4 | Customer account number, four ASCII digits |
| 26 + 16 × i | 2 | Customer PIN hash |
| 28 + 16 × i | 6 | Packed-BCD balance, least-significant byte first, two implied decimals |
| 34 + 16 × i | 1 | Status: `01h` active, `00h` locked |
| 35 + 16 × i | 3 | Reserved zero bytes |
| 22 + 16 × count | 2 | Additive checksum of every preceding byte, modulo 65,536 |

The fixed 24-byte prefix includes the header and admin record; file length is
`24 + (count × 16)`. For the seed count of three, the file is 72 bytes. The seed
checksum is `0822h`, stored as bytes `22 08`. `DATA_LOAD` checks magic, version,
count bounds, exact file size, and checksum before accepting the file.

The PIN hash is a deterministic, **non-cryptographic** 16-bit demonstration
hash. `PIN_HASH` begins with `AX=6D31h`. For each of four positions, it rotates
AX left by one, XORs the ASCII ID byte into AL, adds `0137h`, then XORs the
ASCII PIN byte into AH. It multiplies the final AX by 251 and keeps the low
word. The four intermediate states for admin ID `9001` and PIN `1357` are
`EA92h`, `E54Ch`, `FEE0h`, and `C827h`; `C827h × 251` yields low word `3E3Dh`.
The four PIN-buffer bytes are zeroed with `REP STOSB` after hashing. This
algorithm is not suitable for production authentication.

## 4. Benchmark results and 8086 timing analysis

Run `BANK.EXE /B` (the `B00` headless case exercises this switch through
`TOOLS\RUNHOST.PS1`). The benchmark performs 50,000 additions per variant and
writes the observed BIOS tick counts to `BENCH.OUT` in the current directory.
The console output is deterministic and includes the binary result, `500.00`,
so the test can verify the conversion without comparing variable timings.

The text below reproduces `DOCS\BENCH.md`'s timing method, calculations,
observations, and caveats.

### Theoretical timing analysis

The estimates below use the base clock counts and effective-address costs in Intel Corporation, *8086 Family User's Manual*, order number 9800722-03 (October 1979), instruction execution-time and effective-address calculation tables. They are 8086 clock counts, not measured DOSBox time.

For the `bcd_add` byte loop, the memory references use `[SI]` and `[DI]`, each with a 5-clock effective-address calculation. The table gives `MOV reg,mem` as 8+EA, `ADC reg,mem` as 9+EA, `MOV mem,reg` as 9+EA, `DAA` as 4, and `INC r16` as 3. A taken `LOOP` costs 17 clocks and the final not-taken `LOOP` costs 5.

| Part of one six-byte add | Calculation | Base clocks |
|---|---:|---:|
| One non-final byte, including pointer increments and taken `LOOP` | (8+5) + (9+5) + 4 + (9+5) + 3 + 3 + 17 | 68 |
| Final byte, with not-taken `LOOP` | (8+5) + (9+5) + 4 + (9+5) + 3 + 3 + 5 | 56 |
| Six-byte loop body | 5 × 68 + 56 | 396 |
| Inner-loop control removed by unrolling | 5 × 17 + 5 | 90 saved |

These totals exclude the same routine-call, register-save, outer-repeat, bus-wait, and instruction-prefetch effects for both variants. Unrolling removes the six inner `LOOP` instructions, but makes the routine larger; the Intel tables do not predict DOSBox host scheduling or all prefetch interactions.

The binary version uses the register/immediate `ADD BX,1` and `ADC DX,0` to add one cent to a 32-bit unsigned count; its repeated arithmetic is smaller than six packed-decimal byte operations. It then formats the final amount. `BENCH_BINARY_FORMAT` performs two 16-bit `DIV` operations for each decimal digit (divide the high word, then divide the low word with the high-word remainder). The DIV entry in the Intel timing table is much more costly than register addition, but this benchmark formats only once after the 50,000 additions, so that conversion cost is amortized over the run. A workload that formatted after every addition would have a materially different comparison.

The Intel effective-address table also lists `[BX+SI]` at 7 clocks and `[BX+SI+disp]` at 11; the benchmark formatter uses these forms to index its converted digit buffer. This is separate from the `[SI]`/`[DI]` memory operands in the BCD add.

### Empirical timing

Each result is a difference of the low 16-bit BIOS tick counter (`INT 1Ah/AH=00h`) around its benchmark section. The BIOS tick is about 54.9 ms (roughly 18.2 ticks/second); small elapsed times are quantized and can read as zero. A 16-bit modulo difference is sufficient because each measured interval is far below 65,536 ticks.

**DOSBox timings are relative only, not real 8086 cycle counts.** Host load, DOSBox configuration, timer phase, and emulator scheduling affect these measurements. The counts below are the actual result from the Stage 8 `RUNHOST.PS1` run; they are observations, not guaranteed expected values.

| Variant | Work timed | BIOS ticks |
|---|---|---:|
| BCD loop | 50,000 six-byte `bcd_add` calls | 18 |
| BCD unrolled | 50,000 six-byte unrolled BCD adds | 14 |
| Binary add + format | 50,000 32-bit additions plus one final decimal conversion | 1 |

The recorded BCD loop result was **18 ticks**. The unrolled routine used 14 ticks in this run, and the binary additions plus one final conversion used 1 tick. The four-tick BCD difference corresponds to about 0.22 seconds at the BIOS tick rate, but this is one DOSBox run and not a portable performance guarantee. BIOS tick resolution is coarse, so equal or zero counts do not establish equal or zero execution cost. Compare repeated runs only as relative DOSBox observations.

## 5. Final RUNHOST output and test-case inventory

The final validation command was:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File TOOLS\RUNHOST.PS1
```

Observed result: exit status `0`; all 55 discovered `.IN` cases matched their
`.EXP` files and configured return codes; 15 data snapshots and 13 audit-log
snapshots matched byte-for-byte. The command wrapper reported:

```text
RUNHOST_EXIT=0; CASE_OUTPUT_PASSES=55; DATA_SNAPSHOT_PASSES=15; AUDIT_SNAPSHOT_PASSES=13
```

The run output included:

```text
PASS: TASM.EXE and TLINK.EXE already exist; bootstrap skipped.
PASS: LINT8086.PS1 flags the throwaway forbidden-instruction cases.
PASS: .8086 rejects BADPUSHA.ASM.
PASS: TASM accepts the source syntax but emits four 8086-valid D1 E0 (SHL AX,1) instructions.
Stage 0 headless proof passed.
```

The harness also reported its individual `PASS:` comparison line for every
case, and passed the persisted-file and audit-file comparisons. The following
list gives one line per discovered case; the observed result for every listed
case was PASS.

DOSBox stderr also logged a file-delete warning during `Z09`:
`FS: Failed to move 'C:\practical\CALD_PROJECT\SRC\AUDIT.LOG' to temp file
'C:\practical\CALD_PROJECT\SRC\$DB7D52.tmp' before delete.` The runner still
completed with exit status 0 and all output, data, and audit comparisons passed.

- `B00` — `/B` benchmark smoke test; stable console result includes `500.00`.
- `D00` — TDRV unsigned decimal output for 0.
- `D01` — TDRV unsigned decimal output for 9.
- `D02` — TDRV unsigned decimal output for 10.
- `D03` — TDRV unsigned decimal output for 305.
- `D04` — TDRV unsigned decimal output for 65,535.
- `HELLO` — Stage 0 DOSBox smoke program; prints its greeting and exits with code 2.
- `I04` — `/I` seed initialization smoke test.
- `I05` — `/I` output compared byte-for-byte with the independent 72-byte seed image.
- `L02` — TDRV reads two consecutive CRLF lines.
- `L03` — TDRV reads a blank CRLF line followed by a second line.
- `L04` — TDRV reads an account line and then a masked PIN from one CRLF stream.
- `P04` — TDRV data initialization, reload, and seed-record persistence assertions.
- `P05` — TDRV PIN-verify match/mismatch checks against the documented hash.
- `READKEY` — Stage 0 no-echo key and buffered-line input smoke test.
- `S01` — TDRV NUL-terminated string output.
- `S02` — TDRV character output.
- `S03` — TDRV newline output.
- `S04` — TDRV redirected line input.
- `S05` — TDRV line-input EOF handling.
- `S06` — TDRV masked four-digit PIN input.
- `S07` — TDRV PIN-input EOF handling.
- `SW01` — Case-insensitive `/t` switch and string selector.
- `SW02` — Unknown `/X` switch returns code 1.
- `SW03` — Retired `/U` switch is rejected with code 1.
- `SW04` — Whitespace-tolerant command-tail token parsing.
- `SW05` — Saved PSP segment check.
- `SW06` — Retired `/U 1001` switch is rejected with code 1.
- `SW07` — Lowercase `/u 1001` is rejected with code 1.
- `T00` — Reset seed data with `/I`.
- `T01` — Valid login and normal menu exit, code 0.
- `T02` — Three wrong PINs, lockout message, code 2.
- `T03` — Unknown admin ID fails without a distinct response, then valid login.
- `T04` — Exact seed account listing.
- `T05` — Existing, unknown, and malformed account view.
- `T06` — Create an account and view the new record.
- `T07` — Reject malformed/duplicate IDs, over-limit opening amount, and a full table.
- `T09` — Print the independently documented admin PIN hash (`15933` decimal).
- `T18` — Corrupt checksum is detected.
- `T19` — Missing data-file status and `/I` guidance.
- `T20` — 35 independent-oracle packed-BCD arithmetic, comparison, formatting, and parsing vectors.
- `T22` — Product launch without `ACCOUNTS.DAT` prints initialization guidance and exits code 3.
- `Z08A` — Lock account 1001 and persist its status.
- `Z08B` — In a second process, view the locked status and unlock the account.
- `Z09` — Reset customer 1001 PIN and compare the stored data image with the independent fixture.
- `Z10` — Credit 25.50, debit 10.25, and view the resulting balance.
- `Z11` — Reject zero debit and debit greater than the balance without changing it.
- `Z12` — Carry `99999.99 + 0.01` across packed-BCD bytes to `100000.00`.
- `Z13` — Reject credit overflow at the maximum six-byte BCD balance.
- `Z14` — Check the seed summary and the audit-view fallback.
- `Z15` — Audit a failed login followed by successful login and exit.
- `Z16` — Debit the exact `0.01` balance to zero.
- `Z17` — Create account 1004 and view it.
- `Z18` — Format the report total for two maximum-balance accounts.
- `Z19` — Create account 1004, lock it, and verify the displayed status.

## 6. Source line counts

Counts are physical lines in the eight application assembly source files at the
time this evidence pack was prepared. They do not include generated binaries,
data, test fixtures, or tools.

| Source file | Lines |
|---|---:|
| `SRC\ADMIN.INC` | 1,641 |
| `SRC\BANK.ASM` | 179 |
| `SRC\BCD.INC` | 326 |
| `SRC\BENCH.INC` | 405 |
| `SRC\DATA.INC` | 467 |
| `SRC\IO.INC` | 556 |
| `SRC\ISR.INC` | 131 |
| `SRC\TDRV.ASM` | 949 |

## 7. Known limitations and cut/best-effort items

- The PIN hash is non-cryptographic. It is present to demonstrate salted hashing
  and PIN-buffer clearing, not to protect real accounts.
- The customer table is fixed at eight records. There is no close-account or
  account-status search feature.
- Menu item 8 deliberately uses `Audit log: see AUDIT.LOG`; the last-ten-lines
  circular-buffer viewer is cut.
- INT 23h/INT 1Bh Ctrl-C/Ctrl-Break handlers and PIT/speaker beep output are cut.
- The idle-timeout ISR is implemented for interactive sessions, but its timed
  firing and vector restoration remain manual checks. `/T` intentionally turns
  off the timeout for deterministic redirected tests.
- The optional thousands separators, second PIN confirmation, and report
  `HIGHEST` line are not implemented.
- DOSBox benchmark tick counts are coarse host/emulator-relative measurements,
  not hardware timing guarantees.
- T14 caller-level amount coverage and T15's "after several changes" report
  scenario are incomplete as detailed in the test table; the underlying parser,
  adjustment, and report code is present.

## 8. Development problems and fixes

- **Toolchain availability:** TASM/TLINK are distributed with the VS Code
  MASM/TASM extension rather than assumed to be on the host PATH. `BOOT86.PS1`
  extracts the tools into the ignored local `TOOLS\TASM` directory, and DOSBox
  runs them through the headless build.
- **DOS batch exit-code expansion:** DOSBox's DOS shell does not expand
  `%ERRORLEVEL%` as Windows CMD does. The runner records exit status using DOS
  `IF ERRORLEVEL` branches.
- **Assembler accepts a non-8086 shift spelling:** TASM accepts `SHL AX,4` and
  its listing expands it into four `SHL AX,1` instructions. The project keeps
  `LINT8086.PS1` as the actual guard, tests the assembler behavior in
  `RUNHOST.PS1`, and uses explicit `MOV CL,4` / `SHL AX,CL` in application code.
- **Seed record inconsistency:** An earlier `DATA_INIT` encoded customer 1001
  as 250.75 instead of the specified 1000.00, while the old persistence
  assertion repeated the same mistaken bytes. The balance was corrected to
  `00 00 10 00 00 00`; `TOOLS\ORACLE.PY` now independently derives the seed
  image and `I05` compares all 72 bytes, while persistence assertions check all
  seeded account data.
- **Product/test separation:** The test dispatcher was moved from `BANK.ASM` to
  `TDRV.ASM`; `.PGM` metadata selects the executable per fixture. This keeps
  test hooks out of `BANK.EXE`.
