# TDDFT GPU Performance Baseline

Last updated: 2026-07-16

## Official Baseline

- Logical step: Step 37
- Source implementation commit: `24e1cc3`
- Pinned-allocation build-mode commit: `9cbb6bc`
- Result record commit: this documentation update
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Memory mode: `-gpu=mem:separate:pinnedalloc`
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_01` | 108.676812287 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_02` | 107.854416847 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_03` | 108.096301079 | PASS | PASS |

Official three-run median: `108.096301079` sec.

## Step 37 Run 01 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 108.927643 |
| `frprmn` | 99.861167 |
| `electf_force` | 9.015143 |
| `tmevl_total` | 51.654634 |
| `tmevl_s2` | 16.091806 |
| `s2_nonlocal` | 11.489188 |
| `s2_fft_local` | 4.586517 |
| `fft_wrapper` | 2.642859 |
| `exnlp_gemm_dot` | 8.441807 |
| `tmevl_p_enter` | 0.001209 |
| `exkin_acc_kernel` | 0.632053 |
| `exnlp_work1_enter` | 1.542147 |
| `frprmn_rhoofk` | 0.557789 |
| `frprmn_rhoget` | 0.234999 |
| `frprmn_coef_sync` | 0.241963 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

Step 37 is `4.987327814` sec (`4.4103%`) faster than the Step 36 median,
`5.465059995` sec (`4.8124%`) faster than Step 34, and `20.979185104` sec
(`16.2534%`) faster than the former Step 28 median.

Step 32 was a single measurement run (`129.658223152` sec) with additional
density-rebuild timers. It is diagnostic evidence, not a replacement baseline.

Step 35 was an Nsight Systems diagnostic trace of the accepted Step 34 source.
Its `116.000924826` sec trace wall is also not a baseline. It passed both
correctness checks and confirmed that aggregate D2H fell from the Step 30 value
of 35,453 copies / `30,054.575` MB to 5,348 copies / `5,592.769` MB.

Step 38 was an Nsight Systems diagnostic trace of the pinned Step 37 build. Its
`110.78916502` sec trace wall is not a baseline. Both correctness checks passed.
It measured H2D at `1.272192545` sec and D2H at `0.440373299` sec, reductions of
`74.6861%` and `46.9758%` from Step 35, respectively. The fused nonlocal kernel
was essentially unchanged at `8.311268224` sec.

Step 39 was a two-step Nsight Compute diagnostic of one fused nonlocal kernel
launch. Its `11.1839032173` sec wall is not a baseline. The normal check passed;
the relaxed comparison was not run. The launch used 32 blocks of 256 threads
with 63 registers/thread, achieving `12.5%` occupancy and only `0.07` waves/SM
on the 108-SM A100. Because 32 bands are the smallest operational case expected,
no small-band-only kernel path is planned; scaling will be checked with larger
band counts. This diagnosis does not replace the Step 37 median.
