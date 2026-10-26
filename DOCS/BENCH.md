# Stage 8 benchmark

Run `BANK.EXE /B` (the `B00` headless case exercises this switch through `TOOLS\RUNHOST.PS1`). The benchmark performs 50,000 additions per variant and writes the observed BIOS tick counts to `BENCH.OUT` in the current directory. The console output is deterministic and includes the binary result, `500.00`, so the test can verify the conversion without comparing variable timings.

## Theoretical timing analysis

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

## Empirical timing

Each result is a difference of the low 16-bit BIOS tick counter (`INT 1Ah/AH=00h`) around its benchmark section. The BIOS tick is about 54.9 ms (roughly 18.2 ticks/second); small elapsed times are quantized and can read as zero. A 16-bit modulo difference is sufficient because each measured interval is far below 65,536 ticks.

**DOSBox timings are relative only, not real 8086 cycle counts.** Host load, DOSBox configuration, timer phase, and emulator scheduling affect these measurements. The counts below are the actual result from the Stage 8 `RUNHOST.PS1` run; they are observations, not guaranteed expected values.

| Variant | Work timed | BIOS ticks |
|---|---|---:|
| BCD loop | 50,000 six-byte `bcd_add` calls | 18 |
| BCD unrolled | 50,000 six-byte unrolled BCD adds | 14 |
| Binary add + format | 50,000 32-bit additions plus one final decimal conversion | 1 |

The recorded BCD loop result was **18 ticks**. The unrolled routine used 14 ticks in this run, and the binary additions plus one final conversion used 1 tick. The four-tick BCD difference corresponds to about 0.22 seconds at the BIOS tick rate, but this is one DOSBox run and not a portable performance guarantee. BIOS tick resolution is coarse, so equal or zero counts do not establish equal or zero execution cost. Compare repeated runs only as relative DOSBox observations.
