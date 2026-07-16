# TDDFT GPU Performance Baseline

Last updated: 2026-07-16

## Official Baseline

- Logical step: Step 36
- Implementation commit: `24e1cc3`
- Result record commit: this documentation update
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_01` | 113.023494005 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_02` | 113.083628893 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_03` | 113.681638956 | PASS | PASS |

Official three-run median: `113.083628893` sec.

## Step 36 Run 01 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 113.308043 |
| `frprmn` | 104.361496 |
| `electf_force` | 8.894750 |
| `tmevl_total` | 55.183834 |
| `tmevl_s2` | 18.751777 |
| `s2_nonlocal` | 13.758056 |
| `s2_fft_local` | 4.976766 |
| `fft_wrapper` | 3.363625 |
| `exnlp_gemm_dot` | 8.440092 |
| `tmevl_p_enter` | 0.001204 |
| `exnlp_work1_enter` | 3.759735 |
| `frprmn_rhoofk` | 0.724047 |
| `frprmn_rhoget` | 0.438241 |
| `frprmn_coef_sync` | 0.638728 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

Step 36 is `0.477732181` sec (`0.4207%`) faster than the Step 34 median,
`3.041047096` sec (`2.6188%`) faster than Step 33, and `15.991857290` sec
(`12.3895%`) faster than the former Step 28 median.

Step 32 was a single measurement run (`129.658223152` sec) with additional
density-rebuild timers. It is diagnostic evidence, not a replacement baseline.

Step 35 was an Nsight Systems diagnostic trace of the accepted Step 34 source.
Its `116.000924826` sec trace wall is also not a baseline. It passed both
correctness checks and confirmed that aggregate D2H fell from the Step 30 value
of 35,453 copies / `30,054.575` MB to 5,348 copies / `5,592.769` MB.
