# Step 120 Xeon Generation MPI/OpenMP Screens

These measurements are independent CPU/FFTW platform screens. They do not
replace the formal Xeon 6980P, A100, or H100 baselines. A one-run screen selects
a candidate configuration; a formal platform value requires three equivalent
runs, the median, and the range.

## Xeon Platinum 8468, dual socket

- Returned: 2026-08-05
- Tested revision: `013845d3227f24cdfbe3e3d525a24ff239e754c2`
- CPU: Intel Xeon Platinum 8468, 2 sockets
- Online logical CPUs: 96
- Physical cores: 96
- Compiler: ifx/mpiifx 2026.1.0
- MPI: Intel MPI 2021.18.0
- Binding: `I_MPI_PIN=1`, `I_MPI_PIN_DOMAIN=omp`,
  `I_MPI_PIN_ORDER=compact`, `KMP_AFFINITY=granularity=fine,compact,1,0`
- Runs per configuration: 1
- Diagnostic: OFF
- Correctness: every measured configuration passed the normal check and x86
  relaxed comparison; reaching the final ranked summary is conditional on
  those gates
- Build note: an initially reused stale executable caused abnormal progress;
  the returned screen followed a forced Intel/FFTW rebuild

| MPI ranks | OpenMP threads | total physical threads | wall_sec | normal | relaxed |
|---:|---:|---:|---:|---|---|
| 32 | 3 | 96 | 21.0896489620 | PASS | PASS |
| 16 | 6 | 96 | 29.4878950119 | PASS | PASS |
| 8 | 12 | 96 | 49.3604290485 | PASS | PASS |
| 4 | 24 | 96 | 88.6823518276 | PASS | PASS |

The clear candidate is 32 MPI x 3 OpenMP. Relative to that candidate, 16 x 6
was `1.398x`, 8 x 12 was `2.341x`, and 4 x 24 was `4.205x` in elapsed ratio.
Increasing the OpenMP team size while reducing MPI ranks therefore regressed
this tutorial case monotonically.

The one-run 32 x 3 value was `13.0193159580` sec (`38.1698%`) shorter than the
formal H100 median `34.1089649200` sec. Conversely, it was `4.5503668785` sec
(`27.5125%`) longer than the formal dual-socket Xeon 6980P median
`16.5392820835` sec. These cross-platform comparisons remain provisional until
the 8468 candidate completes a controlled three-run series.

The archive labels were not visible in the returned photograph and are not
guessed here. The user-operated host retains the exact `runs.tsv`, ranked
summary, archives, and provenance paths emitted by the helper.

### Controlled 32 MPI x 3 OpenMP candidate

- Returned: 2026-08-05
- Tested revision: `094ebd1f421d1cb181aa404b28eb28edd350bbd9`
- Runs: 3
- Configuration: 32 MPI x 3 OpenMP = 96 physical threads
- Median: `20.5968229771` sec
- Range: `0.0558128357` sec
- Normal check: PASS for all runs
- x86 relaxed comparison: PASS for all runs
- Run-01 strict comparison: PASS for runs 02 and 03
- Diagnostic: OFF

The final helper summary establishes the three-run median and range. Individual
run walls and archive labels were outside the returned photograph and remain
pending as a targeted provenance return; they are not guessed here. Until the
user explicitly approves adoption, this is an 8468 baseline candidate rather
than the formal 8468 baseline.

The candidate is `13.5121419429` sec (`39.6146%`) faster than the formal H100
median, so the H100 wall is `1.656x` the 8468 wall for this tutorial case. It
is `4.0575408936` sec (`24.5328%`) slower than the formal dual-socket Xeon
6980P median. The controlled median is `0.4928259849` sec (`2.3368%`) shorter
than the initial one-run 8468 screen value.

## Xeon Platinum 8592+, dual socket

Pending. Use the same helper after updating to revision `071b986` or later so
cached executable artifacts are fingerprint-validated before reuse.
