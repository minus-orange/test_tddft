# TDDFT GPU Performance Baseline

Last updated: 2026-07-16

## Official Baseline

- Logical step: Step 34
- Implementation commit: `83a030c`
- Result record commit: this documentation update
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_01` | 113.896168210 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_02` | 113.491595984 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_03` | 113.561361074 | PASS | PASS |

Official three-run median: `113.561361074` sec.

## Step 34 Run 01 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 114.176747 |
| `frprmn` | 104.778852 |
| `electf_force` | 8.945334 |
| `tmevl_total` | 55.375345 |
| `tmevl_s2` | 19.051133 |
| `s2_nonlocal` | 14.055285 |
| `s2_fft_local` | 4.978761 |
| `fft_wrapper` | 3.345579 |
| `exnlp_gemm_dot` | 8.435714 |
| `tmevl_p_enter` | 0.001195 |
| `frprmn_rhoofk` | 0.739567 |
| `frprmn_rhoget` | 0.436578 |
| `frprmn_coef_sync` | 0.638588 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

Step 34 is `2.563314915` sec (`2.2074%`) faster than the Step 33 median and
`15.514125109` sec (`12.0194%`) faster than the former Step 28 median.

Step 32 was a single measurement run (`129.658223152` sec) with additional
density-rebuild timers. It is diagnostic evidence, not a replacement baseline.

Step 35 was an Nsight Systems diagnostic trace of the accepted Step 34 source.
Its `116.000924826` sec trace wall is also not a baseline. It passed both
correctness checks and confirmed that aggregate D2H fell from the Step 30 value
of 35,453 copies / `30,054.575` MB to 5,348 copies / `5,592.769` MB.
