# Step 120 Xeon Generation MPI/OpenMP Screens

These measurements are independent CPU/FFTW platform series. They do not
replace the formal Xeon 6980P, A100, or H100 baselines. A one-run screen selects
a candidate configuration; a formal platform value requires three equivalent
runs, the median, the range, and explicit user approval.

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
`16.5392820835` sec. These were provisional one-run comparisons; the
controlled three-run result below supersedes them for formal comparison.

The user-operated host retains the exact `runs.tsv`, ranked summary, archives,
and provenance paths emitted by the helper.

### Official 32 MPI x 3 OpenMP baseline

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

| run | wall_sec | normal | relaxed | run-01 strict | archive label |
|---:|---:|---|---|---|---|
| 01 | 20.5968229771 | PASS | PASS | SELF | `x86_mpi_omp_20260805_151026_094ebd1f421d_32mpi_3omp_01` |
| 02 | 20.6482338905 | PASS | PASS | PASS | `x86_mpi_omp_20260805_151026_094ebd1f421d_32mpi_3omp_02` |
| 03 | 20.5924210548 | PASS | PASS | PASS | `x86_mpi_omp_20260805_151026_094ebd1f421d_32mpi_3omp_03` |

The targeted provenance return confirms all three individual walls and the
archive-label prefix. The final two-digit archive suffix follows the visible
run column and the helper's deterministic label format. Sorting the walls
reproduces the reported median and range exactly. The user explicitly approved
adoption on 2026-08-05, making this the formal independent Xeon 8468 baseline.

The candidate is `13.5121419429` sec (`39.6146%`) faster than the formal H100
median, so the H100 wall is `1.656x` the 8468 wall for this tutorial case. It
is `4.0575408936` sec (`24.5328%`) slower than the formal dual-socket Xeon
6980P median. The controlled median is `0.4928259849` sec (`2.3368%`) shorter
than the initial one-run 8468 screen value.

### Hierarchical timer-tree sample

The returned photograph does not show an archive label beside the timer tree,
so the table is preserved as an unassigned sample from the formal 8468 32 MPI
x 3 OpenMP series. Values are rank-0 inclusive elapsed seconds rounded to
three decimals. They must not be summed as exclusive wall-time components.

| call path | called | elapsed_sec |
|---|---:|---:|
| `startup_before_steps` | 1 | 0.434 |
| `startup_before_steps > fft_plan_init` | 1 | 0.114 |
| `startup_before_steps > fft_wrapper` | 3 | 0.001 |
| `startup_before_steps > prenon` | 1 | 0.006 |
| `time_step_total` | 101 | 20.620 |
| `time_step_total > g_vector_update` | 101 | 0.045 |
| `time_step_total > ion_md` | 101 | 0.001 |
| `time_step_total > frprmn` | 101 | 19.869 |
| `frprmn > fft_wrapper` | 1,748 | 0.363 |
| `frprmn > hlocal_zero` | 78 | 0.002 |
| `frprmn > hlocal_scatter` | 78 | 0.003 |
| `frprmn > hlocal_inverse_fft` | 78 | 0.015 |
| `frprmn > hlocal_inverse_fft > fft_wrapper` | 78 | 0.015 |
| `frprmn > hlocal_vg_multiply` | 78 | 0.005 |
| `frprmn > hlocal_forward_fft` | 78 | 0.016 |
| `frprmn > hlocal_forward_fft > fft_wrapper` | 78 | 0.015 |
| `frprmn > hlocal_gather` | 78 | 0.004 |
| `frprmn > tmevl_total` | 936 | 13.234 |
| `tmevl_total > tmevl_p_enter` | 936 | 0.000 |
| `tmevl_total > tmevl_exkin` | 9,360 | 1.234 |
| `tmevl_exkin > exkin_acc_kernel` | 9,360 | 1.227 |
| `tmevl_total > tmevl_s2` | 4,680 | 10.270 |
| `tmevl_s2 > s2_nonlocal` | 9,360 | 6.746 |
| `s2_nonlocal > s2_nonlocal_make` | 9,360 | 1.673 |
| `s2_nonlocal > s2_nonlocal_gemm` | 9,360 | 5.059 |
| `s2_nonlocal_gemm > exnlp_work1_enter` | 4,680 | 0.000 |
| `s2_nonlocal_gemm > exnlp_meta_enter` | 4,680 | 0.000 |
| `s2_nonlocal_gemm > exnlp_gemm_data` | 9,360 | 5.044 |
| `exnlp_gemm_data > exnlp_gemm_dot` | 9,360 | 5.033 |
| `tmevl_s2 > s2_fft_local` | 4,680 | 3.513 |
| `s2_fft_local > s2_acc_kernel` | 14,040 | 1.622 |
| `s2_acc_kernel > s2_zero_rho2` | 4,680 | 0.176 |
| `s2_acc_kernel > s2_scatter_p` | 4,680 | 0.389 |
| `s2_acc_kernel > s2_vg_build` | 4,680 | 0.570 |
| `s2_acc_kernel > s2_local_multiply` | 4,680 | 0.242 |
| `s2_acc_kernel > s2_gather_p` | 4,680 | 0.222 |
| `s2_fft_local > fft_wrapper` | 9,360 | 1.815 |
| `tmevl_total > tmevl_expectation` | 8 | 0.015 |
| `tmevl_expectation > hlocal_zero` | 8 | 0.000 |
| `tmevl_expectation > hlocal_scatter` | 8 | 0.000 |
| `tmevl_expectation > hlocal_inverse_fft` | 8 | 0.002 |
| `tmevl_expectation > hlocal_inverse_fft > fft_wrapper` | 8 | 0.002 |
| `tmevl_expectation > hlocal_vg_multiply` | 8 | 0.001 |
| `tmevl_expectation > hlocal_forward_fft` | 8 | 0.002 |
| `tmevl_expectation > hlocal_forward_fft > fft_wrapper` | 8 | 0.002 |
| `tmevl_expectation > hlocal_gather` | 8 | 0.001 |
| `frprmn > frprmn_rhoofk` | 468 | 0.711 |
| `frprmn_rhoofk > fft_wrapper` | 936 | 0.184 |
| `frprmn > frprmn_rhoget` | 468 | 0.282 |
| `frprmn_rhoget > fft_wrapper` | 936 | 0.179 |
| `frprmn > frprmn_coef_sync` | 103 | 0.000 |
| `time_step_total > electf_force` | 101 | 0.698 |
| `time_step_total > force_energy_update` | 101 | 0.000 |
| `TOTAL (inclusive regions)` | 138,879 | 101.678 |

The displayed `fft_wrapper` paths total 13,155 calls and `2.576` sec after
three-decimal rounding. Both that aggregate count and the total inclusive call
count exactly match the formal Xeon 6980P Step 119 tree, so the two CPU trees
have directly comparable path structure and call multiplicity.

## Xeon Platinum 8592+, dual socket

- Returned: 2026-08-05
- Tested revision: `1e3762587ede0b92cc3791446cf092ef79b15ca5`
- CPU: Intel Xeon Platinum 8592+, 2 sockets
- Online logical CPUs: 128
- Physical cores: 128
- Compiler: ifx/mpiifx 2026.1.0
- MPI: Intel MPI 2021.18.0
- Binding: `I_MPI_PIN=1`, `I_MPI_PIN_DOMAIN=omp`,
  `I_MPI_PIN_ORDER=compact`, `KMP_AFFINITY=granularity=fine,compact,1,0`
- Runs per configuration: 1
- Diagnostic: OFF
- Correctness: every measured configuration passed the normal check and x86
  relaxed comparison; reaching the final ranked summary is conditional on
  those gates
- Build note: the valid screen followed a complete local Intel/FFTW rebuild;
  the earlier GLIBC-incompatible attempt supplied no measurement

| MPI ranks | OpenMP threads | total physical threads | wall_sec | normal | relaxed |
|---:|---:|---:|---:|---|---|
| 32 | 4 | 128 | 19.6031851768 | PASS | PASS |
| 16 | 8 | 128 | 28.6397459507 | PASS | PASS |
| 8 | 16 | 128 | 49.3092470169 | PASS | PASS |
| 4 | 32 | 128 | 90.9068999290 | PASS | PASS |

The clear candidate is 32 MPI x 4 OpenMP. Relative to that candidate, 16 x 8
was `1.461x`, 8 x 16 was `2.515x`, and 4 x 32 was `4.637x`. As on the 8468,
larger OpenMP teams and fewer MPI ranks regressed this tutorial case
monotonically.

The one-run candidate is `14.5057797432` sec (`42.5278%`) shorter than the
formal H100 median, `0.9936378003` sec (`4.8242%`) shorter than the formal
8468 median, and `3.0639030933` sec (`18.5250%`) longer than the formal 6980P
median. These comparisons are provisional: the 8592+ value remains a one-run
screen until 32 x 4 completes three equivalent validated runs and is explicitly
adopted. Archive labels were outside the returned photograph and are not
inferred.
