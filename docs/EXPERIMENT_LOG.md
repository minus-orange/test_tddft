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
| 28 | Keep COEF/COEF0 resident across corrections | 129.075486183 | accepted baseline | `c3552af` |
| 29 | Initialize resident COEF0 on the device | 130.160923958 | rejected | `94e0e0e` / `bd53a88` |
| 31 | Reuse GDUMP mappings across TMEVL kinetic stages | 129.250354052 | rejected | `f8b6188` / `8ef55bb` |

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
