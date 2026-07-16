# TDDFT GPU Experiment Log

Last updated: 2026-07-16

The performance baseline is defined in `PERFORMANCE_BASELINE.md`. Detailed
implementation and timer notes are in the bilingual progress summaries.

| step | hypothesis | median_sec | result | implementation / rollback |
|---|---|---:|---|---|
| 21 | Batch the device-resident S2 local cuFFT calls | 146.540076017 | accepted | `bad046f` |
| 22 | Persist nonlocal staging-buffer device allocations | 146.268707991 | accepted | `1b98197` |
| 23 | Reuse staging buffers in the reverse nonlocal phase | 140.840327024 | accepted | `f911621` |
| 24 | Fuse nonlocal projector kernels across `ia` | 133.268284082 | accepted | `b3559f1` |
| 25 | Use vector length 256 in the fused nonlocal kernel | 130.607889175 | accepted | `825697a` |
| 26 | Increase the fused kernel vector length to 512 | 130.834260225 | rejected | `a8b4db0` / `336422e` |
| 28 | Keep COEF/COEF0 resident across corrections | 129.075486183 | accepted | `c3552af` |
| 29 | Initialize resident COEF0 on the device | 130.160923958 | rejected | `94e0e0e` / `bd53a88` |
| 31 | Reuse GDUMP mappings across TMEVL kinetic stages | 129.250354052 | rejected | `f8b6188` / `8ef55bb` |
| 32 | Measure post-TMEVL density rebuild | 129.658223152 (one diagnostic run) | measurement | `13f9e98` |
| 33 | Batch post-TMEVL charge-density FFTs | 116.124675989 | accepted baseline | `b2a43c9` |

## Other Rejected Experiments

- B1 YLM ownership: correctness passed; median about `174.30` sec; rolled back
  by `a40ddd6`.
- Step 19 caller-side nonlocal-input lifetime: correctness passed;
  `178.063332081` sec; rejected.
- Step 20 fine-grained lookup copies: correctness passed; `819.404727936` sec;
  rejected because repeated transfers dominated `s2_nonlocal_make`.

## Step 31 Detail

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_01` | 129.635676146 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_02` | 128.958827972 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_03` | 129.250354052 | PASS | PASS |

- Median: `129.250354052` sec
- Run-to-run range: `0.676848174` sec
- Difference from Step 28: `+0.174867869` sec (`+0.1355%`)
- Run 01 `tmevl_gdump_enter`: 944 calls, `0.294118` sec
- Run 01 `tmevl_gdump_exit`: 944 calls, `0.002970` sec
- Run 01 `exkin_acc_kernel`: 9,440 calls, `0.348747` sec
- Run 01 `tmevl_total`: `57.794941` sec

The mapping change was correct but did not improve the three-run median, so it
was reverted. Step 28 remains the official baseline.

## Step 32 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP32_DENSITY_TIMERS_01`
- Wall: `129.658223152` sec
- Correctness: check PASS; relaxed compare PASS
- `frprmn_rhoofk`: 472 calls, `14.509684` sec
- `frprmn_rhoget`: 472 calls, `0.440581` sec
- `frprmn_sumchr`: inactive because `NPFL=0`
- `tmevl_p_exit`: 944 calls, `2.819788` sec

This measurement identifies resident-coefficient charge-density construction
as a higher-value next target than returning directly to the rejected
fine-grained `work2_` lookup-transfer design.

## Step 33 Detail

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_01` | 116.124675989 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_02` | 117.093669176 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_03` | 115.763577938 | PASS | PASS |

- Median: `116.124675989` sec
- Run-to-run range: `1.330091238` sec
- Improvement from Step 28: `12.950810194` sec (`10.0335%`)
- Run 01 `frprmn_rhoofk`: 472 calls, `0.729800` sec
- Run 01 `fft_wrapper`: 14,685 calls, `3.402723` sec
- Run 01 `tmevl_p_exit`: 944 calls, `2.880805` sec

All runs passed both correctness checks. Batching the post-TMEVL density FFTs
reduced `frprmn_rhoofk` by about 94.97% relative to Step 32 run 01. Step 33 is
accepted and becomes the official performance baseline.
