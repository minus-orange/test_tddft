# TDDFT GPU Performance Baseline

Last updated: 2026-07-16

## Official Baseline

- Logical step: Step 33
- Implementation commit: `b2a43c9`
- Result record commit: this documentation update
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_01` | 116.124675989 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_02` | 117.093669176 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_03` | 115.763577938 | PASS | PASS |

Official three-run median: `116.124675989` sec.

## Step 33 Run 01 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 116.417091 |
| `frprmn` | 107.344084 |
| `electf_force` | 9.021958 |
| `tmevl_total` | 58.338570 |
| `tmevl_s2` | 19.102467 |
| `s2_nonlocal` | 14.105342 |
| `s2_fft_local` | 4.980389 |
| `fft_wrapper` | 3.402723 |
| `exnlp_gemm_dot` | 8.418079 |
| `tmevl_p_enter` | 0.001267 |
| `tmevl_p_exit` | 2.880805 |
| `frprmn_rhoofk` | 0.729800 |
| `frprmn_rhoget` | 0.444423 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

Step 33 is `12.950810194` sec (`10.0335%`) faster than the former Step 28
median of `129.075486183` sec. Step 28 remains the historical comparison point
for experiments performed before Step 33.

Step 32 was a single measurement run (`129.658223152` sec) with additional
density-rebuild timers. It is diagnostic evidence, not a replacement baseline.
