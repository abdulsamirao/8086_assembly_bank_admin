# Live demonstration and screenshot script

Use a built `BANK.EXE` in `SRC` and do not pass `/T`: `/T` disables the idle
timeout and fixes audit timestamps for automated tests. Account and audit files
are relative to DOS's current directory, so run from `C:\SRC`.

## Start DOSBox and initialize

From PowerShell, launch DOSBox Staging and mount the repository. The final
command runs `/I` before returning to the DOS prompt:

```powershell
& "C:\Users\abdul\AppData\Local\Programs\DOSBox Staging\dosbox.exe" -c "mount c C:\practical\CALD_PROJECT" -c "c:" -c "cd \SRC" -c "BANK /I"
```

Equivalent DOSBox prompt commands:

```text
MOUNT C C:\practical\CALD_PROJECT
C:
CD \SRC
BANK /I
```

Expected:

```text
Data initialized
C:\SRC>
```

This creates `ACCOUNTS.DAT` with admin ID `9001` / PIN `1357`, and customers
1001 (`1234`, 1000.00, active), 1002 (`4321`, 250.75, active), and 1003 (`1111`,
0.00, locked). `/I` also removes an existing `AUDIT.LOG`.

## Interactive session

At `C:\SRC>`, run `BANK`. Enter the choices below at each `Choice:` prompt.
Each menu operation returns to the same menu; the menu text is shown in full in
step 2 and is not repeated in every expected-output block.

### 1. Admin login and menu

```text
C:\SRC> BANK
Admin ID: 9001
Admin PIN: ****
Login successful
```

The PIN is typed as `1357`; only asterisks should appear. The menu is:

```text
1 List accounts
2 View account
3 Create account
4 Lock/Unlock
5 Reset customer PIN
6 Adjust balance
7 Summary report
8 Audit log
9 Exit
Choice:
```

**Screenshot:** capture the successful login and complete menu. The masked PIN
should be visible as `****`, not the digits.

### 2. List accounts

Enter `1`.

```text
Choice: 1
ACCT  STATUS  BALANCE
1001  ACTIVE  1000.00
1002  ACTIVE  250.75
1003  LOCKED  0.00
```

**Screenshot:** good evidence for exact columns, formatting, and seeded statuses.

### 3. View an account

Enter `2`, then account number `1001`.

```text
Choice: 2
Account number: 1001
1001  ACTIVE  1000.00
```

Optionally repeat with `1003` to show `LOCKED  0.00`, or `9999` to show
`Account not found`.

### 4. Create a customer account

Enter `3`, then account `1004`, PIN `2468`, and opening balance `49999.99`.
This amount is within the 50,000.00 opening-balance limit and lets the next
step demonstrate a carry across packed-BCD bytes.

```text
Choice: 3
Account number: 1004
Customer PIN: ****
Opening balance: 49999.99
Account created
```

**Screenshot:** good evidence for account creation, masked customer PIN, and
the accepted opening balance.

### 5. Lock and unlock the account

Enter `4`, then `1004`. Repeat the same menu choice and account number to undo
the lock.

```text
Choice: 4
Account number: 1004
Account locked
```

Then:

```text
Choice: 4
Account number: 1004
Account unlocked
```

Each change is saved immediately. A list or view afterward should show account
1004 as `ACTIVE`.

### 6. Reset the customer PIN

Enter `5`, account `1004`, and new PIN `8642`.

```text
Choice: 5
Account number: 1004
Customer PIN: ****
Customer PIN reset
```

The entered digits are masked and are never displayed as plaintext.

### 7. Credit with a packed-BCD carry

Enter `6`, account `1004`, operation `C`, and amount `0.01`.

```text
Choice: 6
Account number: 1004
C (credit) or D (debit): C
Amount: 0.01
Balance adjusted
```

View account 1004 afterward:

```text
1004  ACTIVE  50000.00
```

The six-byte packed-BCD addition carries through the trailing `99` decimal
pairs: `49999.99 + 0.01 = 50000.00`.

**Screenshot:** capture the amount and resulting 50000.00 balance together if
possible.

### 8. Debit and reject an overdraw

Enter `6`, account `1004`, operation `D`, and amount `50000.00`.

```text
Choice: 6
Account number: 1004
C (credit) or D (debit): D
Amount: 50000.00
Balance adjusted
```

The balance is now `0.00`. Attempt a debit of `0.01`:

```text
Choice: 6
Account number: 1004
C (credit) or D (debit): D
Amount: 0.01
Insufficient funds
```

View account 1004 to confirm that its balance remains `0.00`.

**Screenshot:** good evidence for both successful debit and rejected overdraw;
include the unchanged zero balance.

### 9. Summary report

Enter `7`.

```text
Choice: 7
ACCOUNTS: 4
ACTIVE: 3
LOCKED: 1
TOTAL: 1250.75
```

The total is the sum of customer balances after the preceding transactions:
1001 is 1000.00, 1002 is 250.75, 1003 is 0.00, and 1004 is 0.00.

**Screenshot:** good evidence for status counts and the packed-BCD total.

### 10. Audit log

Enter `8`. The viewer is intentionally cut, so the program prints:

```text
Choice: 8
Audit log: see AUDIT.LOG
```

Choose `9` to exit, then display the append-only file:

```text
Choice: 9
C:\SRC> TYPE AUDIT.LOG
```

Expected line shape:

```text
YYYY-MM-DD HH:MM:SS 9001 LOGIN ---- -
YYYY-MM-DD HH:MM:SS 9001 CREATE 1004 49999.99
YYYY-MM-DD HH:MM:SS 9001 LOCK 1004 -
YYYY-MM-DD HH:MM:SS 9001 UNLOCK 1004 -
YYYY-MM-DD HH:MM:SS 9001 RESETPIN 1004 -
YYYY-MM-DD HH:MM:SS 9001 CREDIT 1004 0.01
YYYY-MM-DD HH:MM:SS 9001 DEBIT 1004 50000.00
YYYY-MM-DD HH:MM:SS 9001 REPORT ---- -
YYYY-MM-DD HH:MM:SS 9001 EXIT ---- -
```

Each timestamp is the live DOS date/time, so its exact value depends on when
the demo is run. The rejected overdraw is not a successful account event and
does not append a CREDIT/DEBIT line.

**Screenshot:** the fallback message is a good screenshot; `TYPE AUDIT.LOG`
is useful as a second screenshot showing persisted audit entries.

## Separate exit-path demonstrations

The following steps launch separate processes. Run `/I` between demonstrations
to clear the prior account/audit state.

### 11. Failed-login lockout

```text
C:\SRC> BANK /I
Data initialized
C:\SRC> BANK
Admin ID: 9001
Admin PIN: ****
Login failed
Admin ID: 9001
Admin PIN: ****
Login failed
Admin ID: 9001
Admin PIN: ****
Login failed. Console locked.
C:\SRC> IF ERRORLEVEL 2 ECHO EXIT CODE 2
EXIT CODE 2
```

Type `0000` at each masked PIN prompt. `IF ERRORLEVEL` is used because this DOS
shell does not expand Windows CMD's `%ERRORLEVEL%` syntax. The failed attempts
are appended to `AUDIT.LOG`.

**Screenshot:** good evidence for the third-failure lockout message.

### 12. Interactive idle timeout

Reset first, then log in correctly and do not press a key after the menu's
`Choice:` prompt:

```text
C:\SRC> BANK /I
Data initialized
C:\SRC> BANK
Admin ID: 9001
Admin PIN: ****
Login successful
... menu ...
Choice:
```

Wait approximately 30 seconds. The INT 1Ch counter reaches 546 ticks and the
program should print:

```text
Session timed out
C:\SRC> IF ERRORLEVEL 4 ECHO EXIT CODE 4
EXIT CODE 4
```

The timeout path appends a `TIMEOUT` audit event, saves account data, and
restores the original INT 1Ch vector. Do not use `/T` for this demonstration;
`/T` intentionally disables the timer hook. This is a manual DOSBox check, not
part of the redirected automated suite.

**Screenshot:** capture `Session timed out`; the approximately 30-second wait
can be omitted from the image.

### 13. Benchmark

At the DOS prompt, run:

```text
C:\SRC> BANK /B
Benchmark complete. Results: BENCH.OUT
Binary total: 500.00
C:\SRC> TYPE BENCH.OUT
```

`BENCH.OUT` has these three lines, with observed tick values:

```text
BCD LOOP (ticks): <value>
BCD UNROLLED (ticks): <value>
BINARY ADD + FORMAT 500.00 (ticks): <value>
```

The recorded Stage 8 run in `DOCS\BENCH.md` observed 18, 14, and 1 ticks,
respectively. A live DOSBox run may differ; these are coarse relative emulator
timings, not real 8086 cycle counts.

**Screenshot:** good evidence for the stable `500.00` result and the generated
`BENCH.OUT`; include a caption that tick counts vary by DOSBox run.
