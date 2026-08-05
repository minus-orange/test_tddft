# Step 119 A100 and H100 Timer Tree Values

Recorded from the terminal photographs returned on 2026-08-05. These are
independent one-run instrumentation validations. They do not replace the
formal A100 Step 107 or H100 Step 115 baselines.

## Common provenance

- Revision: `24ae7127805ce4da63078c31bbd91e3456e84b44`
- Driver: 595.45.04
- Execution: 1 GPU x 1 MPI rank x 1 OpenMP thread
- Diagnostics: off
- Memory mode: separate with pinned allocation
- Case: Si111-H, 100 TDDFT time steps
- Both runs: normal check PASS and relaxed compare PASS

## Platform runs

| platform | device | target | archive label | wall_sec |
|---|---|---|---|---:|
| A100 | NVIDIA A100-PCIE-40GB | cc80 | `nvhpc_cufft_1rank_02_STEP119_A100_TIMER_TREE_20260805_135009_24ae7127805c_01` | 63.9410018921 |
| H100 | NVIDIA H100 PCIe | cc90 | `nvhpc_cufft_1rank_02_STEP119_H100_TIMER_TREE_20260805_135328_24ae7127805c_01` | 34.0914211273 |

The A100 instrumentation wall is `0.7274799347` sec (`1.150830%`) above the
formal A100 median. The H100 instrumentation wall is `0.0175437927` sec
(`0.051435%`) below the formal H100 median. Each is a single run, so neither
difference is an adoption measurement. The single-run A100/H100 wall ratio is
`1.875575x`.

## Timer trees

All elapsed values are inclusive rank-0 times transcribed from the returned
trees. The call count was identical on A100 and H100 for every displayed path.

| call path | called | A100 sec | H100 sec | A100/H100 |
|---|---:|---:|---:|---:|
| `startup_before_steps` | 1 | 2.415 | 0.814 | 2.967x |
| `startup_before_steps > fft_plan_init` | 1 | 1.454 | 0.274 | 5.307x |
| `startup_before_steps > fft_wrapper` | 3 | 0.001 | 0.000 | n/a |
| `startup_before_steps > prenon` | 1 | 0.089 | 0.051 | 1.745x |
| `time_step_total` | 101 | 64.136 | 34.187 | 1.876x |
| `time_step_total > g_vector_update` | 101 | 0.036 | 0.017 | 2.118x |
| `time_step_total > ion_md` | 101 | 0.000 | 0.000 | n/a |
| `time_step_total > frprmn` | 101 | 57.580 | 30.239 | 1.904x |
| `time_step_total > frprmn > fft_wrapper` | 2,842 | 0.373 | 0.158 | 2.361x |
| `time_step_total > frprmn > tmevl_total` | 944 | 50.933 | 27.195 | 1.873x |
| `time_step_total > frprmn > tmevl_total > tmevl_p_enter` | 944 | 0.000 | 0.000 | n/a |
| `time_step_total > frprmn > tmevl_total > tmevl_exkin` | 9,440 | 0.631 | 0.297 | 2.125x |
| `time_step_total > frprmn > tmevl_total > tmevl_exkin > exkin_acc_kernel` | 9,440 | 0.623 | 0.291 | 2.141x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2` | 4,720 | 15.398 | 6.671 | 2.308x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal` | 9,440 | 11.431 | 4.799 | 2.382x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_make` | 9,440 | 1.310 | 0.977 | 1.341x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm` | 9,440 | 10.101 | 3.808 | 2.653x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_work1_enter` | 4,720 | 1.540 | 0.442 | 3.484x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_meta_enter` | 4,720 | 0.081 | 0.054 | 1.500x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_gemm_data` | 9,440 | 8.458 | 3.298 | 2.565x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_gemm_data > exnlp_gemm_dot` | 9,440 | 8.445 | 3.290 | 2.567x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local` | 4,720 | 3.948 | 1.866 | 2.116x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel` | 14,160 | 1.806 | 0.890 | 2.029x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_zero_rho2` | 4,720 | 0.190 | 0.091 | 2.088x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_scatter_p` | 4,720 | 0.469 | 0.239 | 1.962x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_vg_build` | 4,720 | 0.084 | 0.055 | 1.527x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_local_multiply` | 4,720 | 0.379 | 0.184 | 2.060x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_gather_p` | 4,720 | 0.654 | 0.297 | 2.202x |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > fft_wrapper` | 9,440 | 1.705 | 0.776 | 2.197x |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation` | 8 | 0.270 | 0.142 | 1.901x |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > fft_wrapper` | 512 | 0.031 | 0.015 | 2.067x |
| `time_step_total > frprmn > frprmn_rhoofk` | 472 | 0.526 | 0.249 | 2.112x |
| `time_step_total > frprmn > frprmn_rhoofk > fft_wrapper` | 944 | 0.170 | 0.076 | 2.237x |
| `time_step_total > frprmn > frprmn_rhoget` | 472 | 0.235 | 0.122 | 1.926x |
| `time_step_total > frprmn > frprmn_rhoget > fft_wrapper` | 944 | 0.160 | 0.076 | 2.105x |
| `time_step_total > frprmn > frprmn_coef_sync` | 103 | 0.241 | 0.058 | 4.155x |
| `time_step_total > electf_force` | 101 | 6.367 | 3.921 | 1.624x |
| `time_step_total > force_energy_update` | 101 | 0.000 | 0.000 | n/a |
| `TOTAL (inclusive regions)` | 140,957 | 252.269 | 125.921 | 2.003x |

The six displayed `fft_wrapper` paths sum to 14,685 calls on both platforms,
matching the established aggregate profile count. Their displayed inclusive
times sum to `2.440` sec on A100 and `1.101` sec on H100. The timer trees have
identical paths and call counts, confirming the same logical instrumentation
flow on both GPU platforms.

The largest A100/H100 ratios among dominant compute regions are
`s2_nonlocal_gemm` at `2.653x`, `exnlp_gemm_dot` at `2.567x`, and
`s2_nonlocal` at `2.382x`. These are one-run inclusive timer comparisons, not
independent kernel timings or baseline speedups.
