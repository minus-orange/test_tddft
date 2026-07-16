# TDDFT GPU Performance Baseline

Last updated: 2026-07-16

## Official Baseline

- Logical step: Step 28
- Implementation commit: `c3552af`
- Result record commit: `ccdd4a2`
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_01` | 129.075486183 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_02` | 127.753921986 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_03` | 129.260547161 | PASS | PASS |

Official three-run median: `129.075486183` sec.

## Step 28 Run 01 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 129.361618 |
| `frprmn` | 120.448163 |
| `electf_force` | 8.862440 |
| `tmevl_total` | 58.329469 |
| `tmevl_s2` | 19.172283 |
| `s2_nonlocal` | 14.141850 |
| `s2_fft_local` | 5.013571 |
| `fft_wrapper` | 13.495301 |
| `exnlp_gemm_dot` | 8.449663 |
| `tmevl_p_enter` | 0.001273 |
| `tmevl_p_exit` | 2.825121 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

The rejected Step 31 median was `129.250354052` sec, `0.174867869` sec
(`0.1355%`) slower than this baseline. It does not replace Step 28.

Step 32 was a single measurement run (`129.658223152` sec) with additional
density-rebuild timers. It is diagnostic evidence, not a replacement baseline.
