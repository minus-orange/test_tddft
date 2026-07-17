# TDDFT GPU Experiment Log

Last updated: 2026-07-17

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
| 33 | Batch post-TMEVL charge-density FFTs | 116.124675989 | accepted | `b2a43c9` |
| 34 | Defer coefficient downloads across corrections | 113.561361074 | accepted | `83a030c` |
| 35 | Re-profile the accepted Step 34 path with Nsight Systems | 116.000924826 (diagnostic trace) | measurement | `7567ae8` |
| 36 | Right-size nonlocal staging columns to the maximum active NGNL | 113.083628893 | accepted | `24e1cc3` |
| 37 | Allocate dynamic TDDFT host data in pinned memory | 108.096301079 | accepted baseline | `9cbb6bc` |
| 38 | Re-profile the accepted pinned-allocation build | 110.78916502 (diagnostic trace) | measurement | `643e639` |
| 40 | Specialize the fused nonlocal kernel by direction | 107.751713037 | rejected | `ea81633` / `0726e26` |
| 41 | Keep static J2G/OCC metadata resident | 107.754213095 | accepted baseline | `4aaa33c` |
| 42 | Keep Vloc resident across FRPRMN corrections | 107.809727907 | rejected | `d56815e` / `afa1678` |
| 43 | Decompose the host-side ELECTF region | 107.821303844 (one diagnostic run) | measurement | `e90c80a` |

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

## Step 34 Detail

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_01` | 113.896168210 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_02` | 113.491595984 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_03` | 113.561361074 | PASS | PASS |

- Median: `113.561361074` sec
- Run-to-run range: `0.404572226` sec
- Improvement from Step 33: `2.563314915` sec (`2.2074%`)
- Run 01 `frprmn_coef_sync`: 103 calls, `0.638588` sec
- Run 01 `tmevl_p_exit`: inactive
- Run 01 `tmevl_total`: `55.375345` sec

All runs passed both correctness checks. The deferred synchronization reduced
the 944 per-TMEVL coefficient downloads to 103 verified host-consumer or final
FRPRMN synchronizations in run 01. Step 34 is accepted as the new baseline.

## Step 35 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP35_NSYS_01`
- Source revision: `7567ae83e520a79e480ee6eaaa83842526938465`
- Trace wall: `116.000924826` sec (diagnostic; not a baseline)
- Correctness: check PASS; relaxed compare PASS
- H2D: 44,166 copies, `32,307.014` MB, about `5.026` sec
- D2H: 5,348 copies, `5,592.769` MB, about `0.831` sec

Relative to the Step 30 trace, H2D fell by 28,320 copies and `13,918.755` MB,
while D2H fell by 30,105 copies and `24,461.806` MB. The dominant GPU kernel
remains `exnlp_gemm_body_fused_2387_gpu`: 9,440 launches and about `8.303` sec,
or 66.5% of reported CUDA-kernel time. The largest repeated actionable upload
is still the line-1913 `work2_` update: 4,720 OpenACC updates taking about
`3.728` sec in the OpenACC summary, including about `1.264` sec of enqueue
upload time. Direct device construction remains high risk because YLM, VPJ,
and EXTAU ownership previously caused severe regressions and can replace one
bulk transfer with larger or finer-grained transfers.

## Step 36 Detail

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_01` | 113.023494005 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_02` | 113.083628893 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_03` | 113.681638956 | PASS | PASS |

- Median: `113.083628893` sec
- Run-to-run range: `0.658144951` sec
- Improvement from Step 34: `0.477732181` sec (`0.4207%`)
- Run 01 `exnlp_work1_enter`: `3.759735` sec
- Run 01 `s2_nonlocal`: `13.758056` sec
- Run 01 `tmevl_total`: `55.183834` sec

All runs passed both correctness checks. The implementation uses the maximum
active `NGNL` as the `work2_` leading dimension instead of `NGcont`, removing
unused column tails without changing the transfer count, projector equations,
or sequential `ia` order. It is accepted as the new official baseline.

## Step 37 Detail

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_01` | 108.676812287 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_02` | 107.854416847 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_03` | 108.096301079 | PASS | PASS |

- Median: `108.096301079` sec
- Run-to-run range: `0.822395440` sec
- Improvement from Step 36: `4.987327814` sec (`4.4103%`)
- Run 01 `exnlp_work1_enter`: `1.542147` sec
- Run 01 `s2_nonlocal`: `11.489188` sec
- Run 01 `tmevl_total`: `51.654634` sec

All runs passed both correctness checks. The build retains separate host and
device memory and adds NVHPC 26.5 `-gpu=mem:separate:pinnedalloc`, causing
dynamically allocated TDDFT host arrays to use pinned memory. Step 37 is
accepted as the new official build configuration and performance baseline.

## Step 38 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP38_PINNED_NSYS_01`
- Source revision: `643e639d45a163499a71355ecee33d7dba8466a3`
- Trace wall: `110.78916502` sec (diagnostic; not a baseline)
- Correctness: check PASS; relaxed compare PASS
- H2D: 44,166 copies, `31,234.025` MB, `1.272192545` sec
- D2H: 5,348 copies, `5,592.769` MB, `0.440373299` sec
- `work2_` OpenACC update: 4,720 calls, `1.617571795` sec
- Fused nonlocal kernel: 9,440 launches, `8.311268224` sec
- Pinned host pool allocation: one `cuMemHostAlloc`, `0.273495492` sec

Relative to Step 35, H2D time fell by `74.6861%`, D2H time by `46.9758%`, and
the `work2_` update by `56.6159%`. H2D bytes fell only `3.3212%`, primarily
from Step 36 right-sizing, while D2H bytes and both copy counts were unchanged.
The fused kernel changed by only `+0.1036%`, confirming that pinned allocation
accelerated transfers rather than its arithmetic. The earlier Step 35 record
of `5.830` sec for this kernel was a transcription error corrected above from
the archived screenshot value of `8.302662687` sec.

## Step 39 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP39_FUSED_NCU_01`
- Tool: Nsight Compute 2026.1.0, `--set full`, one selected launch
- Input: Si111-H, 2 steps
- Diagnostic wall: `11.1839032173` sec (not a baseline)
- Correctness: normal check PASS; relaxed comparison not run
- Kernel: `exnlp_gemm_body_fused_2399_gpu`
- Launch: grid 32, block 256, 63 registers/thread, `915.52 us`
- Occupancy: theoretical `50.0%`, achieved `12.5%`, waves/SM `0.07`
- Throughput: Compute (SM) `4.27%`, memory `16.35%`, DRAM `0.45%`
- Cache/access: L1/TEX hit `84.31%`; about `15.5 / 32` useful bytes per
  global-load/store sector and about 51% excess sectors

The manifest revision is blank because the diagnostic was run as root and Git
rejected the repository as an unsafe directory. The result nevertheless
profiles the accepted Step 37 executable; it does not establish a new source
or performance baseline. The main structural constraint is one gang per local
band: 32 blocks cannot fill the A100's 108 SMs. Step 26 already rejected a
simple increase to vector length 512. Because 32 bands are the smallest
operational case expected, a small-band-only multi-gang path is out of scope.
The current path will instead be evaluated on medium and production-sized
inputs, where its grid grows with the local band count, before any shared
kernel bottleneck is selected for another source experiment.

## Step 40 Detail

Step 40 implementation `ea81633` split the fused nonlocal kernel into explicit
forward and reverse routines. It removed the per-projector direction branch
while retaining the existing forward and reverse sequential `ia` orders.
The CPU/FFTW full link passed before A100 validation.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_01` | 107.751713037 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_02` | 107.828091860 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_03` | 107.690500021 | PASS | PASS |

- Median: `107.751713037` sec
- Run-to-run range: `0.137591839` sec
- Apparent wall improvement from Step 37: `0.344588042` sec (`0.3188%`)
- `exnlp_gemm_dot` median: `8.545724` sec, `+0.103917` sec (`+1.2310%`)
  versus Step 37 run 01
- `s2_nonlocal` median: `11.571148` sec, `+0.081960` sec (`+0.7134%`)
  versus Step 37 run 01
- `tmevl_total` median: `51.656927` sec, effectively unchanged (`+0.0044%`)

All three diagnostic-off runs passed both correctness checks. However, the
timer targeted by the branch specialization regressed consistently, and the
small wall-time difference is below 1% and is not supported by the target
timer. The duplicated forward/reverse implementation is therefore rejected as
not justified by the measured effect. Step 37 remains the official baseline.
Implementation `ea81633` was reverted by `0726e26`, after which the CPU/FFTW
fallback full link passed.

## Step 41 Detail

Step 41 implementation `4aaa33c` moves the read-only `J2G` and `OCC`
OpenACC ownership boundary outside the time-step loop. The S2 and batched
RHOOFK regions now use `present` instead of repeated `copyin` clauses. This
does not change equations, kernel loop structure, array shapes, or sequential
`ia` order. The CPU/FFTW fallback full link and independent review passed.

An initial archive, `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_01`, passed
both correctness checks but took `115.517135143` sec. Its standard manifest
did not capture the tested revision or build flags. It remains recorded as a
pre-rebuild provenance anomaly and is excluded from the controlled series.
After an explicit diagnostic-off NVHPC OpenACC + cuFFT rebuild with
`-gpu=mem:separate:pinnedalloc`, the following runs were collected:

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_02` | 107.783477068 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_03` | 107.718405008 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_04` | 107.754213095 | PASS | PASS |

- Median: `107.754213095` sec
- Run-to-run range: `0.065072060` sec
- Improvement from Step 37: `0.342087984` sec (`0.3165%`)
- Run 02 `frprmn_rhoofk`: `0.528846` sec, `5.19%` below Step 37 run 01
- Run 02 `s2_nonlocal`: `11.489951` sec, effectively unchanged
- Run 02 `exnlp_gemm_dot`: `8.441246` sec, effectively unchanged

At source level, 4,720 S2 `J2G` copyins plus 472 RHOOFK `J2G` and 472
RHOOFK `OCC` copyins are replaced by two outer-loop copyins, a net reduction
of up to 5,662 repeated H2D operations. Nsight Systems has not yet remeasured
the actual runtime copy count. All controlled runs passed both correctness
checks, the median is faster, the run range is small, and the change directly
advances the time-step-loop transfer-reduction objective. Step 41 is accepted
as the official source and performance baseline.

## Step 42 Detail

Step 42 implementation `d56815e` copied `Vloc(:,1:5)` to the device once per
FRPRMN predictor-corrector sequence and changed the repeated S2 mapping to
`present`. It did not change equations, array shapes, kernel loops, or the
sequential `ia` order. The CPU/FFTW fallback full link and independent review
passed before A100 validation.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_01` | 107.732875109 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_02` | 107.809727907 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_03` | 107.831543922 | PASS | PASS |

- Median: `107.809727907` sec
- Run-to-run range: `0.098668813` sec
- Difference from Step 41: `+0.055514812` sec (`+0.0515%`)

All three diagnostic-off runs passed both correctness checks. The source-level
transfer boundary is cleaner, but the three-run median has no performance
advantage over Step 41, and no transfer profile was collected to demonstrate a
runtime benefit. Under the project acceptance rule, Step 42 is rejected and
does not replace the Step 41 baseline. Implementation `d56815e` was reverted
by `afa1678`, after which the CPU/FFTW fallback full link passed.

## Step 43 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP43_ELECTF_TIMERS_01`
- Diagnostic wall: `107.821303844` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `electf_force`: 101 calls, `9.012769` sec
- `electf_locpotf`: 101 calls, `4.071556` sec (`45.1754%` of ELECTF)
- `electf_nonlocf`: 101 calls, `4.939849` sec (`54.8094%` of ELECTF)
- `nonlocf_coef_kin_mpi`: 202 calls, `0.846204` sec
- `nonlocf_projector_mpi`: 202 calls, `4.091718` sec

The top-level residual is only `0.001364` sec. Within NONLOCF, the host
coefficient kinetic/current section is `17.1302%`, while the combined GETYLM
and SEPPOTF/projector section is `82.8308%` and `45.3991%` of the complete
ELECTF timer. The 202 inner calls reflect two k points per ELECTF call. The
next diagnostic separates GETYLM from SEPPOTF before a GPU port is selected.

## Step 44 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP44_NONLOCF_TIMERS_01`
- Diagnostic wall: `108.715013981` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `electf_force`: 101 calls, `8.913402` sec
- `electf_locpotf`: 101 calls, `4.071603` sec
- `electf_nonlocf`: 101 calls, `4.840488` sec
- `nonlocf_coef_kin_mpi`: 202 calls, `0.746292` sec
- `nonlocf_projector_mpi`: 202 calls, `4.092541` sec
- `nonlocf_getylm`: 202 calls, `0.009894` sec
- `nonlocf_seppotf`: 202 calls, `4.068364` sec

`SEPPOTF` accounts for `99.4092%` of the measured projector section,
`84.0486%` of NONLOCF, and `45.6432%` of the complete ELECTF timer. `GETYLM`
is only `0.2418%` of the projector section. This timer-enabled run is
diagnostic evidence only; the official Step 41 median remains unchanged.

## Step 45 Detail

Step 45 implementation `da24adf` retained the COEF device allocation across
the complete time-step loop. FRPRMN continued to synchronize COEF to the host
before ELECTF and retained per-sequence COEF0 ownership. The intended effect
was to remove the next-step COEF H2D copyin without changing SEPPOTF, MPI,
equations, or arithmetic order. CPU/FFTW full link and independent review
passed.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_01` | 108.508744955 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_02` | 108.782176018 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_03` | 111.340812922 | PASS | PASS |

- Median: `108.782176018` sec
- Run-to-run range: `2.832067967` sec
- Difference from Step 41: `+1.027962923` sec (`+0.9540%`)

All three diagnostic-off runs passed both correctness checks. The intended
transfer-count reduction was not profiled with Nsight Systems, and the median
has no performance advantage over Step 41. Step 45 is rejected and does not
replace the official baseline.
