# TDDFT GPU Experiment Log

Last updated: 2026-07-24

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
| 44 | Split NONLOCF projector preparation | 108.715013981 (one diagnostic run) | measurement | diagnostic |
| 45 | Keep COEF resident across the complete time-step loop | 108.782176018 | rejected | `da24adf` / `c406a4a` |
| 46 | Validate SEPPOTF device ownership | 107.869318008 (one diagnostic run) | measurement | `edfafed` / `3e2c630` |
| 47 | Offload the tutorial non-partitioned s/p SEPPOTF path | 107.722885132 | rejected | `0252da9` / `35f8542` |
| 48 | Re-profile the restored Step 41 source with Nsight Systems | 110.223116875 (diagnostic trace) | measurement | `adf4d5b` |
| 49 | Decompose FRPRMN host preparation | 107.879790783 (one diagnostic run) | measurement | `dcb686e` |
| 50 | Split Part1to5 and VPJ_GEN timing | 107.682908058 (diagnostic; VPJ_GEN scope mixed) | measurement | `6bc6770` |
| 51 | Scope VPJ_GEN timing to Part1to5 | 108.201426983 (one diagnostic run) | measurement | `c880d0c` |
| 52 | Offload Part1to5 VPJ radial integration | 73.4374880791 | accepted baseline | `22aad92` |
| 53 | Re-profile the accepted Step 52 source | 76.0769960680 (diagnostic trace) | measurement | `84a7af8` |
| 54 | Decompose the remaining FRPRMN host envelope | 74.2483499050 (one diagnostic run) | measurement | `e44a602` |
| 55 | Split VRHO preparation | 74.3233120441 (one diagnostic run) | measurement | `5d6d71b` |
| 56 | Split Vloc preparation | 73.4618239403 (one diagnostic run) | measurement | `ea13406` |
| 57 | Offload LOCPOT G-vector construction | 71.2909028530 | accepted baseline | `8646707` |
| 58 | Re-profile the accepted Step 57 source | 74.2175440788 (diagnostic trace) | measurement | `797ba4f` |
| 59 | Measure the accepted-source LOCPOT envelope | 71.1150200367 (one diagnostic run) | measurement | `03ec9bd` |
| 60 | Split the remaining VRHO host control | 70.9675290585 (one diagnostic run) | measurement | `fad4d11` |
| 61 | Split the VRHO corrector region | 71.7462480068 (one diagnostic run) | measurement | `817b955` |
| 62 | Skip redundant failed-correction host COEF restore | 68.5734798908 | accepted baseline | `7475ccb` |
| 63 | Re-measure current FRPRMN envelopes | 68.9920969009 (one diagnostic run) | measurement | `16cea8a` |
| 64 | Re-measure current Part1to5 children | 68.8858208656 (one diagnostic run) | measurement | `f69aeac` |
| 65 | Split VPJ integral scope | 70.3901228905 (one diagnostic run) | measurement | `2c6227f` |
| 66 | Split VPJ kernel wait and D2H | 68.8903579712 (one diagnostic run) | measurement | `25ede22` |
| 67 | Use VPJ vector length 128 | 68.3616518974 | accepted baseline | `39a181e` |
| 68 | Use VPJ vector length 64 | 68.7983009815 (run 01) | rejected | `c7028e0` / `a3bc131` |
| 69 | Build EXTAU tables with grouped OpenACC | 69.0177049637 (run 01) | rejected | `d5e76b7` / `a4947d4` |
| 70 | Re-profile current Step 67 source | 71.0379288197 (diagnostic trace) | measurement | `d596361` |
| 71 | Split FRPRMN energy envelope | 68.9183897972 (one diagnostic run) | measurement | `b379f69` |
| 72 | Split expectation envelope | 68.6513030529 (one diagnostic run) | measurement | `10a1d50` |
| 73 | Split off-diagonal envelope | 69.2815968990 (one diagnostic run) | measurement | `6fdbecb` |
| 74 | Reuse band-independent NONLOC YLM preparation | 68.0681188811 | accepted baseline | `3687243` |
| 78 | Temporarily offload remaining data-parallel host loops together | 68.3785300255 (run 01) | rejected | `94e7176` + `cc65c3c` / result rollback |

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
replace the official baseline. Implementation `da24adf` was reverted by
`c406a4a`, after which the CPU/FFTW fallback full link passed.

## Step 46 Detail

Step 46 diagnostic implementation `edfafed`, completed by enforcement commit
`3e2c630`, established the COEF lifetime from FRPRMN through ELECTF and mapped
the NONLOCF parent objects around the k-point loop. A no-op serial OpenACC
region in SEPPOTF required all tutorial s/p projector dummy sections to be
present. No projector arithmetic was moved to the device. CPU/FFTW full link
and independent ownership review passed before A100 validation.

- Archive: `nvhpc_cufft_1rank_02_STEP46_OWNERSHIP_01`
- Diagnostic wall: `107.869318008` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- Steps: 100
- Present/partial-present error: none
- `SEPPOTF ownership probe failed`: absent

The run proves that COEF, G2, YLM, VPJ, VPP, EXTAU, WORK2-column aliases, and
DCOEF resolve inside their mapped parent objects at the real SEPPOTF call
site. The probe adds transfers and a serial kernel, so its wall time is
diagnostic evidence only. The official Step 41 median remains unchanged.
The next single hypothesis is a tutorial-only non-partitioned s/p GPU path
with a complete host fallback for unsupported projector shapes.

## Step 47 Detail

Step 47 implementation `0252da9` moved the tutorial non-partitioned s/p
SEPPOTF phase and band reductions to one-gang-per-band OpenACC kernels. The
original ITY, atom, s, then p order and MPI boundary were retained. All active
types were gated as one unit, while FFTW and unsupported projector shapes used
the complete original host path. CPU/FFTW full link and independent review
passed before A100 execution.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_01` | 107.598769903 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_02` | 107.722885132 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_03` | 107.848846912 | PASS | PASS |

- Median: `107.722885132` sec
- Run-to-run range: `0.250077009` sec
- Difference from Step 41: `-0.031327963` sec (`-0.0291%`)

The median advantage is far smaller than the run range and does not justify
the approximately 250-line specialized path. Step 47 is rejected and does
not replace the official Step 41 baseline. The implementation and its Step 46
diagnostic scaffold are to be rolled back before another hypothesis begins.

Rollback commit `35f8542` removes both the Step 47 implementation and the
completed Step 46 diagnostic source, restoring the accepted Step 41 source
for the affected files. The CPU/FFTW fallback full link passed afterward.

## Step 48 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP48_STEP41_NSYS_01`
- Tested revision: `adf4d5b128e0a4a502304f033f7b9edae18a8d3f`
- Diagnostic wall: `110.223116875` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- H2D: 37,560 copies, `30,576.426` MB, `2.637303759` sec
- D2H: 5,348 copies, `5,592.769` MB, `0.440437627` sec
- CUDA kernels: about `12.48` sec total
- CUDA API: about `17.56` sec total; synchronization calls account for about
  `15.72` sec (`89.5%`)
- In-run MPI collectives: `0.260338098` sec

Relative to Step 38, H2D fell by 6,606 calls (`14.96%`) and `657.599` MB
(`2.105%`); D2H count and bytes were unchanged. The count difference is
consistent with Step 41 reducing repeated metadata transfers, but summary data
alone cannot assign every removed call site. The fused nonlocal kernel remained
effectively unchanged at `8.312052815` sec over 9,440 calls.

The MPI collective total is only about `0.55%` of the official `47.476614` sec
FRPRMN residual. CUDA synchronization is substantial, but the summary includes
TMEVL and cannot be exclusively charged to the residual. OS-runtime waits are
also process-tree and helper-thread totals with overlap. The trace therefore
rules out MPI and allocation as the main residual cause but does not separate
host preparation from device-runtime waiting. The next measurement is a
default-off diagnostic that times only COEF setup, GDUMP preparation,
`Part1to5`, and EXTAU preparation inside FRPRMN. No optimization is authorized
by this result.

## Step 49 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP49_FRPRMN_TIMERS_01`
- Tested revision: `fe7cbd176821b87c0345bbb356ef61ef51d486fa`
- Diagnostic wall: `107.879790783` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `99.052600` sec
- `tmevl_total`: `51.533216` sec
- FRPRMN residual outside TMEVL: `47.519384` sec
- `frprmn_part1to5`: 200 calls, `36.452430` sec (`76.71%` of residual)
- `frprmn_extau_prepare`: 944 calls, `1.475016` sec
- `frprmn_coef_setup`: 472 calls, `0.527652` sec
- `frprmn_gdump_prepare`: 200 calls, `0.134014` sec
- Previously available residual timers: `frprmn_rhoofk=0.527746`,
  `frprmn_rhoget=0.242919`, and `frprmn_coef_sync=0.241847` sec

The measured non-TMEVL components total `39.601624` sec, leaving `7.917760`
sec (`16.66%`) unclassified. `Part1to5` alone accounts for `76.71%` of the
residual and calls five `GETYLM` plus five `VPJ_GEN` operations per invocation.
Across this run that is 1,000 calls to each routine. `VPJ_GEN` performs a
host-only radial-mesh integration, one `MPI_Allreduce` per active orbital/type,
and host post-reduction smoothing. Step 48 bounded all in-run MPI collectives
at only `0.260338098` sec, so MPI cannot explain the `36.452430` sec timer.
The dominant classification is therefore CPU computation with corresponding
GPU idle, not transfer, allocation, MPI, or GPU kernel execution.

The next measurement remains diagnostic only. It separates `GETYLM`, the
`VPJ_GEN` CPU integral, `MPI_Allreduce`, and post-reduction processing with
compile-time-default-off timers. No optimization is authorized by Step 49.

## Step 50 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP50_PART1TO5_TIMERS_01`
- Tested revision: `6bc6770e7ef39429a792e4fa09d7746ea4bfb01e`
- Diagnostic wall: `107.682908058` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- FRPRMN residual outside TMEVL: `47.367733` sec
- `frprmn_part1to5`: 200 calls, `36.310625` sec (`76.66%` of residual)
- `part1to5_getylm`: 1,000 calls, `0.057162` sec
- Unscoped `vpjgen_cpu_integral`: 3,888 calls, `70.229142` sec
- Unscoped `vpjgen_mpi_allreduce`: 3,888 calls, `0.075660` sec
- Unscoped `vpjgen_postreduce`: 3,888 calls, `0.125680` sec

The correctness result and the `Part1to5`/`GETYLM` timers are valid. The three
`VPJ_GEN` timers are not a `Part1to5` decomposition: `VPJ_GEN` is also called
from TMEVL, so those timers combine both call sites. This is why the reported
CPU integral exceeds its intended parent timer. The combined MPI value remains
useful as an upper bound and confirms that MPI is negligible, but the CPU and
post-reduction values must not be assigned to the FRPRMN residual.

Step 51 corrects measurement scope only. In diagnostic builds, the caller
marks `Part1to5` calls for timing and TMEVL calls as excluded. Preprocessing
removes the selector argument and all timers from normal builds. No arithmetic,
loop order, MPI boundary, or OpenACC region changes.

## Step 51 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP51_PART1TO5_SCOPED_01`
- Tested revision: `c880d0c2e3fb04b9ad1605ad3e1fc98809caf8c9`
- Diagnostic wall: `108.201426983` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- FRPRMN residual outside TMEVL: `47.546135` sec
- `frprmn_part1to5`: 200 calls, `36.306091` sec (`76.36%` of residual)
- `part1to5_getylm`: 1,000 calls, `0.053936` sec
- Scoped `vpjgen_cpu_integral`: 2,000 calls, `36.132464` sec
- Scoped `vpjgen_mpi_allreduce`: 2,000 calls, `0.037303` sec
- Scoped `vpjgen_postreduce`: 2,000 calls, `0.060445` sec

The scoped children total `36.284148` sec, leaving only `0.021943` sec of
`Part1to5` overhead. The CPU radial integral accounts for `99.52%` of
`Part1to5` and `75.99%` of the FRPRMN residual; MPI accounts for only `0.10%`
of `Part1to5`. Together with Step 48, this completes the requested
classification: the dominant component is CPU computation with corresponding
GPU idle, while MPI, runtime/API setup, explicit synchronization, and
allocation are secondary.

## Step 52 Hypothesis

Offload only the scoped `VPJ_GEN` radial integration called by `Part1to5`.
Parallelize independent G vectors on the GPU while preserving the radial-mesh
accumulation order within each G vector and retaining the existing host
`MPI_Allreduce` boundary. Keep TMEVL on the original CPU path. Keep the static
pseudopotential tables resident across the time-step loop, map all five phase
G arrays once per `Part1to5` call, and download the contiguous `VPJWORK` result
immediately before MPI. This is one bounded implementation hypothesis.

The first A100 run is a correctness gate with diagnostics off. If check and
relaxed compare pass, collect runs 02 and 03 and compare their median against
the official Step 41 baseline `107.754213095` sec. Reject and revert Step 52 if
the three-run result has no supported performance advantage.

## Step 52 Detail

- Tested revision: `22aad921f8ea490ac5d25d2d201ca0473e62957c`

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_01` | 72.9733359814 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_02` | 73.4374880791 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_03` | 73.4901540279 | PASS | PASS |

- Median: `73.4374880791` sec
- Run-to-run range: `0.5168180465` sec
- Improvement from Step 41: `34.3167250159` sec (`31.8472%`)
- Median-run `frprmn`: `64.618912` sec
- Median-run `tmevl_total`: `51.468926` sec
- Median-run FRPRMN residual outside TMEVL: `13.149986` sec

All three diagnostic-off runs passed both correctness gates. The improvement
is large relative to the run range and is supported by the targeted FRPRMN
residual reduction. Step 52 is accepted as the official performance baseline.
The next bounded task is a current-source Nsight Systems trace of Step 52; do
not begin another optimization before that trace is classified.

## Step 53 Plan

Run one diagnostic-only Nsight Systems trace of the accepted Step 52 source
with `tools/run_tddft_step53_nsys.sh`. The helper rebuilds only TDDFT with
diagnostics off, traces CUDA, OpenACC, OS runtime, and MPI, runs both correctness
checks, archives locally, and prints bounded terminal summaries. The returned
evidence is photographs or manually typed text only. Do not use trace wall as
a baseline and do not implement another optimization before classification.

## Step 53 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP53_STEP52_NSYS_01`
- Tested revision: `84a7af8a5529eb33fb08adfcc8eaea6061ab0bb584`
- Diagnostic wall: `76.0769960680` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `67.152672` sec
- `tmevl_total`: `53.543927` sec
- FRPRMN residual outside TMEVL: `13.608745` sec
- Top fused kernel: `8.297507928` sec (`58.2%` of CUDA kernel time)
- `vpj_gen_acc_integral_406_gpu`: `1.793293070` sec over 2,000 launches
- Estimated aggregate CUDA kernel time: about `14.26` sec (`18.7%` of trace wall)
- H2D: 38,564 copies / `30,745.626` MB / `2.565299787` sec
- D2H: 7,348 copies / `5,846.065` MB / `0.466224230` sec
- CUDA API `cuStreamSynchronize`: `15.940432501` sec
- CUDA API `cudaEventSynchronize`: `1.672755884` sec
- OpenACC VPJ compute/wait: `1.837147688` / `1.816791731` sec

Relative to Step 48, Step 52 adds exactly 1,004 H2D calls and 2,000 D2H calls.
The H2D increment matches five phase arrays per 200 `Part1to5` calls plus four
static tables; the D2H increment matches one VPJ result download per 2,000
calls. Transfer duration remains only `3.031524017` sec in aggregate and may
overlap. Allocation/free is setup-scale; the largest row is one
`cuMemHostAlloc` of `0.275726650` sec.

The Step 53 `mpi_sum` report contained no rows, so it supplies no new MPI
number. Existing evidence remains authoritative: Step 48 bounded all in-run
MPI collectives at `0.260338098` sec, and Step 51 measured scoped VPJ MPI at
`0.037303` sec. MPI is not a principal residual component.

Classification of the `13.608745` sec trace residual is therefore:

- GPU computation: `1.793293070` sec in the new VPJ kernel.
- CPU computation/host orchestration plus unresolved waits: at most about
  `11.815452` sec after subtracting that kernel; this is the dominant remaining
  envelope but is not yet a pure CPU timer.
- MPI: negligible under the prior `0.260338098` sec whole-run bound.
- Runtime/API and synchronization: significant but overlapping; stream plus
  event synchronization totals `17.613188385` sec across the complete trace,
  while the VPJ-specific OpenACC wait is `1.816791731` sec.
- GPU idle/non-kernel wall: aggregate kernels occupy only about `18.7%` of the
  trace wall, leaving about `61.82` sec outside CUDA kernels. This is not an
  additive idle timer, but confirms that host work and synchronous boundaries
  still dominate utilization.

Step 53 completes the current-source trace but does not isolate the remaining
host envelope inside FRPRMN. Step 54 should be diagnostic only: use default-off
coarse timers to split predictor/corrector control, energy/reduction, density,
and update blocks not covered by the existing COEF/GDUMP/Part1to5/EXTAU timers.
Do not select another optimization before that result.

## Step 54 Plan

Add compile-time, default-off coarse timers for the remaining FRPRMN host
envelope. The new rows split Vloc preparation, density/potential mixing,
energy/expectation work, initial density, iteration initialization, work before
and after TMEVL, density initialization, and exit-data cleanup. Remaining
predictor/corrector control is obtained as the unaccounted residual.
Existing COEF synchronization is excluded from the new energy timer so the
reported components can be summed without that known overlap.

Run the single diagnostic with `tools/run_tddft_step54.sh`. The helper builds
only TDDFT with the required pinned NVHPC flags, runs Si111-H for 100 steps,
archives the result, requires normal check and relaxed compare to pass, and
prints the complete bounded timer summary for photograph-only return. This is
measurement code only; its wall time is not a performance baseline. Do not
implement another optimization before classifying the Step 54 result.

## Step 54 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP54_FRPRMN_HOST_TIMERS_01`
- Tested revision: `e44a602d57e7f5155ac5c83ab44977fc28963f02`
- Diagnostic wall: `74.2483499050` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `65.464335` sec
- `tmevl_total`: `52.369940` sec
- FRPRMN residual outside TMEVL: `13.094395` sec

The non-TMEVL component timers sum to `13.084581` sec. Only `0.009814` sec
is unaccounted, so the decomposition covers `99.9251%` of the FRPRMN residual.
Predictor/corrector control outside the measured blocks is negligible here.

The largest measured blocks are `frprmn_vrho_mix` at `3.923983` sec
(`29.9669%` of the residual), `frprmn_vloc_prepare` at `2.940147` sec
(`22.4535%`), `frprmn_part1to5` at `2.135653` sec (`16.3097%`),
`frprmn_extau_prepare` at `1.452314` sec (`11.0911%`), and
`frprmn_energy_diag` at `0.902628` sec (`6.8932%`). Every other individual
row is below `0.562` sec. Iteration initialization, pre/post-TMEVL work,
density initialization, and exit cleanup are negligible.

The VRHO and Vloc rows are mixed host/GPU-runtime envelopes because they
contain host array loops and cuFFT-backed potential transforms; their complete
wall must not be classified as pure CPU time. Step 55 should remain diagnostic
only and split the largest `frprmn_vrho_mix` row into VOFRHO,
smoothing/FFT, and interpolation/convergence subregions. Do not change data
ownership or equations before that classification.

## Step 55 Plan

Keep the Step 54 parent timer and add default-off, measurement-only child
timers that partition `frprmn_vrho_mix` into the `VOFRHO` call, potential
smoothing plus its cuFFT-backed transform, and all remaining
interpolation/convergence/control work. The three child rows are exclusive;
their sum is compared with the parent to detect missed work.

Run `tools/run_tddft_step55.sh`. It builds only TDDFT with the accepted pinned
NVHPC configuration, runs the 100-step case, archives it, requires both
correctness checks, and prints only the parent and three child rows for a
single photograph. Do not use diagnostic wall as a baseline or implement an
optimization before the split is classified.

## Step 55 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP55_VRHO_TIMERS_01`
- Tested revision: `5d6d71ba57f5336ffaa8cbe31ce8d47468c0cf7e`
- Diagnostic wall: `74.3233120441` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `65.549690` sec
- `tmevl_total`: `52.372085` sec
- FRPRMN residual outside TMEVL: `13.177605` sec
- `frprmn_vrho_mix`: `3.943543` sec
- `frprmn_vrho_vofrho`: `0.937779` sec
- `frprmn_vrho_smooth_fft`: `0.161545` sec
- `frprmn_vrho_mix_control`: `2.841719` sec

The three children total `3.941043` sec, covering `99.9366%` of the parent
with a `0.002500` sec timer-boundary gap. Interpolation, convergence, coefficient
copy, and related host control account for `72.0600%` of VRHO and `21.5648%`
of the full FRPRMN residual. VOFRHO accounts for `23.7801%` of VRHO. The
smoothing loops plus cuFFT-backed transform account for only `4.0964%`, so
that transform is not the principal VRHO cost.

Step 55 classifies VRHO as predominantly host computation/orchestration with
corresponding GPU idle, not FFT execution. MPI is absent from this scoped
region. The next largest unresolved mixed envelope is the Step 54
`frprmn_vloc_prepare` value of `2.940147` sec, slightly larger than VRHO host
control. Step 56 should remain diagnostic only and split Vloc preparation into
LOCPOT, smoothing/FFT, and remaining interpolation/Vloc-generation work.

## Step 56 Plan

Keep the Step 54 `frprmn_vloc_prepare` parent and add default-off aggregate
timers around the six LOCPOT calls and the six smoothing/cuFFT blocks. Derive
interpolation, Vloc generation, and other control as parent minus those two
measured children. No equations, ordering, data ownership, or performance path
changes are allowed in this diagnostic.

Run `tools/run_tddft_step56.sh`. It builds only TDDFT with the accepted pinned
NVHPC configuration, runs and archives the 100-step case, requires normal
check and relaxed compare, and prints the parent, two measured children, and
derived remainder in one photograph-sized summary. Diagnostic wall is not a
performance baseline.

## Step 56 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP56_VLOC_TIMERS_01`
- Tested revision: `ea1340602aaf7bcf8082cf1613c7543cf49ec201`
- Diagnostic wall: `73.4618239403` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `64.658469` sec
- `tmevl_total`: `51.537011` sec
- FRPRMN residual outside TMEVL: `13.121458` sec
- `frprmn_vloc_prepare`: `2.947276` sec
- `frprmn_vloc_locpot`: `2.764985` sec
- `frprmn_vloc_smooth_fft`: `0.152869` sec
- Derived remaining Vloc work: `0.029422` sec

The children exactly reproduce the parent at six-decimal report precision.
LOCPOT accounts for `93.8149%` of Vloc preparation and `21.0722%` of the
FRPRMN residual. Smoothing/cuFFT is only `5.1868%` of Vloc, and interpolation,
Vloc generation, and other control are `0.9983%`.

LOCPOT has no OpenACC or CUDA work. Its body consists of host G-vector loops,
one MPI communicator query, and one MPI Allreduce followed by a host scaling
loop. The Step 48 whole-run MPI bound of `0.260338098` sec bounds even the
entire LOCPOT MPI contribution, leaving at least about `2.504647` sec of the
Step 56 LOCPOT envelope as host computation/orchestration. LOCPOT is therefore
CPU-dominant with corresponding GPU idle.

The next bounded hypothesis may be a performance implementation: parallelize
only LOCPOT G vectors on the GPU while preserving each G vector's original
ITY/K/IA accumulation order and retaining the host MPI boundary. Avoid the
rejected Step 42 Vloc-residency form. Correctness run 01 must pass before runs
02 and 03, and adoption still requires a diagnostic-off three-run median.

## Step 57 Plan

Implement one bounded performance hypothesis in LOCPOT only. Under OpenACC,
one GPU thread owns one nonzero G vector and performs the original ITY/K/IA
sequence serially, preserving the floating-point accumulation order within
that G vector. The G=0 contribution remains on the host. The computed local
potential returns to the host immediately before the unchanged MPI Allreduce;
no cross-call Vloc residency is introduced. CPU/FFTW builds retain the original
loop nest.

Use `tools/run_tddft_step57.sh 01` for the first diagnostic-off correctness and
performance gate. Only after normal check and relaxed compare pass may runs 02
and 03 be executed together. Compare their three-run median with the accepted
Step 52 baseline `73.4374880791` sec and inspect the FRPRMN reduction before
adoption.

## Step 57 Detail

- Tested revision: `864670794698786a36a217d88a64c5ee3967cbfc`

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP57_LOCPOT_ACC_01` | 71.2373509407 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP57_LOCPOT_ACC_02` | 71.2909028530 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP57_LOCPOT_ACC_03` | 71.3753330708 | PASS | PASS |

- Median: `71.2909028530` sec
- Run-to-run range: `0.1379821301` sec
- Improvement from Step 52: `2.1465852261` sec (`2.9230%`)
- Improvement from Step 41: `36.4633102420` sec (`33.8393%`)
- Median-run `frprmn`: `62.501628` sec
- Median-run `tmevl_total`: `52.011855` sec
- Median-run FRPRMN residual outside TMEVL: `10.489773` sec

All three diagnostic-off runs passed both correctness gates, the wall range is
small, and the `2.117284` sec median FRPRMN reduction supports the targeted
LOCPOT hypothesis. Step 57 is accepted as the official performance baseline.
The next bounded task is a diagnostic-only Nsight Systems trace of the accepted
Step 57 source; no further optimization is selected before that trace is
classified.

## Step 58 Plan

Run one diagnostic-only Nsight Systems trace of the accepted Step 57 source
with `tools/run_tddft_step58_nsys.sh`. The helper rebuilds only TDDFT with
diagnostics off, traces CUDA, OpenACC, OS runtime, and MPI, archives the trace,
requires normal check and relaxed compare, and prints photograph-sized report
summaries. Compare the LOCPOT kernel, aggregate kernels, transfers, CUDA/OpenACC
API synchronization, MPI, and non-kernel wall with Step 53. Do not use trace
wall as a baseline and do not implement another optimization before the trace
is classified.

## Step 58 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP58_STEP57_NSYS_01`
- Tested revision: `797ba4f5db70c426308f9180d9d4334d4cfcbf4e`
- Diagnostic wall: `74.2175440788` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `65.345528` sec
- `tmevl_total`: `54.075784` sec
- FRPRMN residual outside TMEVL: `11.269744` sec
- Top fused kernel: `8.304842909` sec (`58.1%` of CUDA kernel time)
- VPJ kernel: `1.793326009` sec over 2,000 launches
- Estimated aggregate CUDA kernel time: about `14.29` sec
- H2D: 45,320 copies / `31,590.245` MB / `2.749026591` sec
- D2H: 7,954 copies / `6,127.482` MB / `0.490787616` sec
- CUDA API `cuStreamSynchronize`: `16.039053567` sec
- CUDA API `cudaEventSynchronize`: about `1.661177234` sec
- OpenACC VPJ compute/wait: `1.833629702` / `1.816349445` sec
- MPI report: no rows

Compared with Step 53, H2D increased by 6,756 calls, `844.619` MB, and
`0.183726804` sec; D2H increased by exactly 606 calls, `281.417` MB, and
`0.024563386` sec. The 606 D2H increment matches the six LOCPOT calls across
101 FRPRMN invocations. Combined transfer duration increased by only
`0.208290190` sec. Aggregate kernel time and the established fused and VPJ
kernels remain essentially stable, and MPI remains negligible.

The LOCPOT kernel was not separately identifiable in the photograph-visible
kernel/OpenACC summary rows, so Step 58 does not provide its exact duration.
Before selecting another optimization, Step 59 should enable only the existing
default-off FRPRMN timers and directly measure the accepted Step 57 LOCPOT and
Vloc envelopes. No source algorithm or ownership change is required.

## Step 59 Plan

Run `tools/run_tddft_step59.sh` once. It rebuilds only TDDFT with the accepted
flags and existing FRPRMN timers enabled, runs and archives the 100-step case,
requires both correctness checks, and prints the current Vloc parent, LOCPOT,
smoothing/FFT, and derived remainder in one photograph. Its diagnostic wall is
not a baseline. Do not implement another optimization before this result.

## Step 59 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP59_LOCPOT_TIMERS_01`
- Tested revision: `03ec9bdba15c51fa4e9b11b70468f3e30640ee08`
- Diagnostic wall: `71.1150200367` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `62.280906` sec
- `tmevl_total`: `51.589839` sec
- FRPRMN residual outside TMEVL: `10.691067` sec
- `frprmn_vloc_prepare`: `0.484717` sec
- `frprmn_vloc_locpot`: `0.305052` sec
- `frprmn_vloc_smooth_fft`: `0.151038` sec
- Derived remaining Vloc work: `0.028627` sec

Relative to Step 56, accepted-source LOCPOT fell by `2.459933` sec
(`88.9673%`) and the complete Vloc envelope fell by `2.462559` sec
(`83.5537%`). LOCPOT now accounts for `62.9340%` of Vloc but only `2.8533%`
of the current FRPRMN residual. This directly confirms that the Step 57
performance improvement came from the bounded LOCPOT offload.

The largest known remaining host envelope is the Step 55
`frprmn_vrho_mix_control` value of `2.841719` sec. Step 60 should remain
diagnostic only and partition it into exclusive seed/coefficient-copy,
predictor/extrapolation, and corrector/interpolation/convergence regions.

## Step 60 Plan

Use compile-time default-off timers only; do not change equations, loops, MPI,
OpenACC ownership, or the diagnostic-off performance path. Run the single
diagnostic with `tools/run_tddft_step60.sh`. It builds only TDDFT, archives the
100-step run, requires both correctness checks, and prints the VRHO control
parent and its three exclusive children in one photograph. Diagnostic wall is
not a baseline, and no optimization is selected before this result.

## Step 60 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP60_VRHO_CONTROL_01`
- Tested revision: `fad4d1135a571e54c49ed8cd4b0d5829149e64b6`
- Diagnostic wall: `70.9675290585` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `62.197659` sec
- `tmevl_total`: `51.533552` sec
- FRPRMN residual outside TMEVL: `10.664107` sec
- `frprmn_vrho_mix`: `3.909993` sec
- `frprmn_vrho_mix_control`: `2.787119` sec
- Seed/coefficient-copy control: `0.552540` sec
- Predictor/extrapolation control: `0.016408` sec
- Corrector/interpolation/convergence control: `2.215861` sec
- Derived timer-boundary gap: `0.002310` sec

The children cover `99.9171%` of the parent. Corrector control accounts for
`79.5036%` of VRHO control and `20.7787%` of the current FRPRMN residual;
seed control is `19.8248%`, and predictor control is only `0.5887%`.

Step 61 should remain diagnostic only and divide the corrector parent into
interpolation arithmetic, `VGCONV` convergence calculation, and post-failure
COEF/VGOLD restoration. No equation, loop order, MPI, OpenACC ownership, or
diagnostic-off behavior may change.

## Step 61 Plan

Run `tools/run_tddft_step61.sh` once. It builds only TDDFT, archives the
100-step result, requires normal check and relaxed compare, and prints the
corrector parent and three exclusive children in one photograph. Diagnostic
wall is not a baseline. Select no optimization before the result is classified.

## Step 61 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP61_VRHO_CORRECTOR_01`
- Tested revision: `817b95583bc3eb2efd8c7853b08b6facadc52eb4`
- Diagnostic wall: `71.7462480068` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `62.968263` sec
- `tmevl_total`: `52.336084` sec
- FRPRMN residual outside TMEVL: `10.632179` sec
- VRHO control: `2.815006` sec
- Corrector parent: `2.240276` sec
- Interpolation arithmetic: `0.057358` sec over 472 calls
- `VGCONV`: `0.014480` sec over 472 calls
- COEF/VGOLD restoration: `2.158536` sec over 372 calls
- Derived timer-boundary gap: `0.009902` sec

The children cover `99.5580%` of the corrector parent. Restoration accounts
for `96.3513%` of the corrector and `20.3019%` of the current FRPRMN residual;
interpolation and convergence are only `2.5603%` and `0.6463%` of the parent.

Source ownership confirms that `COEF` and unchanged restart state `COEF0`
remain resident for the complete predictor-corrector sequence. On OpenACC, the
next correction already restores `COEF` from device `COEF0` with a present
kernel. The measured host `coefcp` updates only host state and is not consumed
on a failed correction; CPU/FFTW still requires it. Step 62 therefore tests one
bounded hypothesis: compile that host copy only outside `_OPENACC`, while
retaining VGOLD restoration, device restart, MPI, and all arithmetic order.

## Step 62 Plan

Use `tools/run_tddft_step62.sh 01` as the diagnostic-off correctness gate. If
normal check and relaxed compare pass, collect both remaining runs with one
command: `tools/run_tddft_step62.sh 02-03`. Adoption requires all three checks
and a median advantage over the Step 57 baseline `71.2909028530` sec. Reject
and revert if the target reduction is not supported.

## Step 62 Run 01

- Archive: `nvhpc_cufft_1rank_02_STEP62_SKIP_HOST_COEFCP_01`
- Tested revision: `7475ccb858b23d3aabe257483d617c2eaeb7ed8e`
- Wall: `68.66669352055` sec
- Correctness: check PASS; relaxed compare PASS
- `time_step_total`: `68.884401` sec
- `frprmn`: `59.829844` sec
- `tmevl_total`: `51.392415` sec
- FRPRMN residual outside TMEVL: `8.437429` sec

Run 01 is `2.62420933245` sec (`3.6810%`) faster than the accepted Step 57
median, but no adoption decision is made from one run. Collect runs 02 and 03
with `tools/run_tddft_step62.sh 02-03`, require both correctness checks in all
three runs, and decide from the three-run median.

## Step 62 Runs 02/03 and Adoption

| run | wall_sec | check | relaxed compare |
|---|---:|---|---|
| 01 | `68.66669352055` | PASS | PASS |
| 02 | `68.4877460003` | PASS | PASS |
| 03 | `68.5734798908` | PASS | PASS |

- Three-run median: `68.5734798908` sec
- Run-to-run range: `0.17894752025` sec
- Improvement from Step 57 median: `2.7174229622` sec (`3.811739%`)
- Median-wall run `frprmn`: `59.785449` sec
- Median-wall run `tmevl_total`: `51.398970` sec
- Median-wall run FRPRMN residual: `8.386479` sec
- Residual reduction from Step 57 median-wall run: `2.103294` sec

All correctness and median-performance gates pass. The residual reduction is
consistent with the Step 61 `2.158536` sec restore envelope, so the bounded
hypothesis is supported and Step 62 is adopted as the official baseline.

## Step 63 Plan

Before selecting another optimization, re-run the existing broad default-off
FRPRMN timers on the accepted Step 62 source. Use
`tools/run_tddft_step63.sh` once. It builds only TDDFT, requires both
correctness checks, archives the result, and prints the current major host
envelopes in one compact summary. Diagnostic wall is not a baseline. Choose no
new implementation until the current `8.386479` sec FRPRMN residual is
reclassified.

## Step 63 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP63_CURRENT_FRPRMN_01`
- Tested revision: `16cea8a41bcaa5a9ffe234bb10a96bd2d343019c`
- Diagnostic wall: `68.9920969009` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `60.112452` sec
- `tmevl_total`: `51.565000` sec
- FRPRMN residual outside TMEVL: `8.547452` sec
- Broad-envelope sum: `8.507974` sec (`99.5381%` coverage)
- Timer-boundary gap: `0.039478` sec
- `frprmn_part1to5`: `2.137278` sec (`25.0049%` of residual)
- `frprmn_vrho_mix`: `1.801928` sec (`21.0815%`)
- `frprmn_extau_prepare`: `1.468457` sec (`17.1801%`)
- `frprmn_energy_diag`: `0.933094` sec (`10.9166%`)
- `frprmn_vrho_mix_control`: `0.671477` sec (child of VRHO mix)

The current residual is again essentially closed. `part1to5` is the largest
exclusive envelope, so the next diagnostic should re-run its existing GETYLM,
VPJ integral, MPI, and post-reduction child timers on accepted Step 62 source
before selecting an optimization.

## Step 64 Plan

Run `tools/run_tddft_step64.sh` once. It reuses the existing compile-time
default-off `part1to5` child timers and changes no equations, OpenACC ownership,
or diagnostic-off behavior. Require normal check and relaxed compare, and
classify GETYLM, VPJ integral, MPI all-reduce, post-reduction work, and the
remaining parent gap before selecting one bounded optimization.

## Step 64 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP64_CURRENT_PART1TO5_01`
- Tested revision: `f69aeac4d71759d1ce0d823d344706e3b75a21c3`
- Diagnostic wall: `68.8858208656` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- FRPRMN residual outside TMEVL: `8.449381` sec
- `frprmn_part1to5`: `2.140208` sec
- `part1to5_getylm`: `0.054554` sec (`2.5490%` of parent)
- Legacy-named `vpjgen_cpu_integral`: `1.910793` sec (`89.2807%`)
- `vpjgen_mpi_allreduce`: `0.039413` sec (`1.8415%`)
- `vpjgen_postreduce`: `0.088664` sec (`4.1428%`)
- Derived parent gap: `0.046784` sec (`2.1860%`)
- Child coverage: `97.8140%`

The legacy timer name is stale on OpenACC: its scope contains host VPJWORK/VPJ
zeroing, VPP2 initialization, the GPU integral kernel, and the required D2H
update before MPI. MPI is not dominant. Step 65 should remain measurement-only
and split that scope into host zeroing, VPP2 initialization, and GPU
kernel-plus-D2H synchronization before any optimization is selected.

## Step 65 Plan

Add compile-time default-off timers only. Partition the legacy VPJ integral
scope into host VPJWORK/VPJ zeroing, VPP2 zeroing, and the OpenACC integral
kernel plus required D2H update. Preserve every loop, equation, MPI boundary,
and diagnostic-off path. Run `tools/run_tddft_step65.sh` once and require both
correctness checks. Diagnostic wall is not a baseline.

## Step 65 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP65_VPJ_INTEGRAL_SPLIT_01`
- Tested revision: `2c6227ffb3f20eb12f6b49013c7958b733379215`
- Diagnostic wall: `70.3901228905` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- Legacy VPJ integral parent: `1.920204` sec
- Host VPJWORK/VPJ zeroing: `0.037640` sec (`1.9602%`)
- VPP2 zeroing: `0.001753` sec (`0.0913%`)
- OpenACC kernel plus D2H: `1.872989` sec (`97.5411%`)
- Derived gap: `0.007822` sec (`0.4074%`)
- Child coverage: `99.5926%`

Host initialization is too small to justify an optimization. The remaining
bounded diagnostic is to separate kernel completion from the required D2H
update. Step 66 should add an explicit wait only in the diagnostic build at the
existing synchronous update boundary, timing kernel-plus-wait and D2H
separately while leaving the diagnostic-off path unchanged.

## Step 66 Plan

Add two compile-time default-off timers inside the existing Step 65 parent.
For diagnostic builds only, wait at the already synchronous D2H boundary so
the GPU kernel completion and D2H update can be timed separately. The
diagnostic-off instruction stream remains unchanged. Run
`tools/run_tddft_step66.sh` once and require both correctness checks; its wall
is not a baseline.

## Step 66 Detail

- Archive: `nvhpc_cufft_1rank_02_STEP66_VPJ_KERNEL_D2H_01`
- Tested revision: `25ede22579bdc97bbbba4a9ad4bef273e4b315c8`
- Diagnostic wall: `68.8903579712` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- Kernel-plus-D2H parent: `1.886449` sec
- GPU kernel completion: `1.831545` sec (`97.0896%`)
- D2H update: `0.047825` sec (`2.5352%`)
- Derived gap: `0.007079` sec (`0.3753%`)
- Child coverage: `99.6247%`

The required D2H transfer is not the limiting component; the VPJ kernel itself
dominates. A bounded next performance hypothesis is to reduce only this
kernel's vector length from 256 to 128. The sequential radial accumulation,
equations, data ownership, D2H, and MPI boundary remain unchanged. Evaluate it
with diagnostics off and the standard three-run gate; reject and revert if the
median does not beat the Step 62 baseline.

## Step 67 Plan

Change only `VPJ_GEN_ACC_INTEGRAL` from `vector_length(256)` to
`vector_length(128)`. Preserve all equations, the sequential radial reduction,
data mappings, D2H, and MPI. Use `tools/run_tddft_step67.sh 01` as the first
diagnostic-off correctness/performance gate. If both checks pass, collect runs
02/03 with `tools/run_tddft_step67.sh 02-03`. Adopt only if the three-run median
beats the Step 62 baseline `68.5734798908` sec; otherwise revert.

## Step 67 Run 01

- Archive: `nvhpc_cufft_1rank_02_STEP67_VPJ_VL128_01`
- Tested revision: `39a181ea402498f9e90b73f0183df1c881905094`
- Wall: `68.4441161156` sec
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `59.595911` sec
- `tmevl_total`: `51.405188` sec
- FRPRMN residual outside TMEVL: `8.190723` sec

Run 01 is `0.1293637752` sec (`0.188650%`) faster than the Step 62 median, but
the advantage is smaller than the Step 62 run range `0.17894752025` sec. This
single run is inconclusive. Collect runs 02/03 with one command and decide only
from the three-run median and range.

## Step 67 Runs 02/03 and Adoption

| run | wall_sec | check | relaxed compare |
|---|---:|---|---|
| 01 | `68.4441161156` | PASS | PASS |
| 02 | `68.2400159836` | PASS | PASS |
| 03 | `68.3616518974` | PASS | PASS |

- Three-run median: `68.3616518974` sec
- Run-to-run range: `0.2041001320` sec
- Improvement from Step 62: `0.2118279934` sec (`0.308907%`)
- Separation from Step 62 ranges: slowest Step 67 is `0.0436298847` sec faster
  than fastest Step 62
- Median-wall run FRPRMN residual: `8.168622` sec
- Residual reduction from Step 62 median-wall run: `0.217857` sec

All correctness and performance gates pass, and the non-overlapping observed
ranges support the small median advantage. Step 67 is adopted as the official
baseline.

## Step 68 Plan

Continue the same one-parameter VPJ launch-shape search by changing only
`vector_length(128)` to `vector_length(64)`. Preserve all arithmetic,
sequential radial accumulation, mappings, D2H, and MPI. Use
`tools/run_tddft_step68.sh 01` first; if both checks pass, use
`tools/run_tddft_step68.sh 02-03`. Compare the three-run median with the new
Step 67 baseline `68.3616518974` sec and revert if no advantage is supported.

## Step 68 Result and Rejection

- Archive: `nvhpc_cufft_1rank_02_STEP68_VPJ_VL64_01`
- Tested revision: `c7028e0e18c8bb999d92da9b7a7e649152bc3afc75`
- Wall: `68.7983009815` sec
- Correctness: check PASS; relaxed compare PASS
- Regression from Step 67 median: `0.4366490841` sec (`0.638734%`)
- Regression / Step 67 run range: `2.1394x`
- FRPRMN residual outside TMEVL: `8.173828` sec

The first run is slower by more than twice the accepted run range, so spending
two more A100 runs is not justified. Step 68 is rejected and the VPJ vector
length is restored to the accepted value 128. Keep the helper and result as
history; do not retry vector length 64 in the same form.

## Step 69 Plan

Test one bounded implementation hypothesis for the current `1.468457` sec
EXTAU preparation scope. Under `_OPENACC`, compute its five independent phase
tables on the GPU in one data region, grouping the G21..G25 and TAU1..TAU5
inputs and retaining one EXTAU copyout for the existing host consumer. Preserve
the original CPU/FFTW loops, TMEVL ownership, equations, MPI, and VPJ vector
length 128. Run `tools/run_tddft_step69.sh 01` first. If correctness passes and
there is no clear regression, obtain runs 02/03 with
`tools/run_tddft_step69.sh 02-03` and compare the median with
`68.3616518974` sec.

## Step 69 Result and Rejection

- Archive: `nvhpc_cufft_1rank_02_STEP69_EXTAU_ACC_01`
- Tested revision: `d5e76b752c2fd4034f9e7fe215eb048928ebcfccb`
- Wall: `69.0177049637` sec
- Correctness: check PASS; relaxed compare PASS
- Regression from Step 67 median: `0.6560530663` sec (`0.959680%`)
- Regression / Step 67 run range: `3.2144x`
- FRPRMN residual outside TMEVL: `7.622023` sec

The residual was `0.546599` sec below the Step 67 median-wall residual, but
TMEVL and the complete wall regressed. The whole-program regression is over
three accepted run ranges, so runs 02/03 are intentionally skipped. Restore
the accepted host EXTAU preparation and retain this grouped-transfer form only
as rejected history. The next task is a current Step 67 source Nsight Systems
trace before choosing another implementation.

## Step 70 Plan

Run one diagnostic-only Nsight Systems trace of the restored current Step 67
source. Build TDDFT only with diagnostics off and the accepted pinned NVHPC
flags. Collect CUDA kernels, H2D/D2H time and size, CUDA API, OpenACC, OS
runtime, and MPI summaries. Require both correctness checks, print only the
bounded photograph-return summary, and do not use trace wall as a baseline.
Use `tools/run_tddft_step70_nsys.sh` once; select no implementation before its
kernel, synchronization, runtime/API, transfer, MPI, and non-kernel envelopes
are classified.

## Step 70 Result

- Archive: `nvhpc_cufft_1rank_02_STEP70_STEP67_NSYS_01`
- Tested revision: `d59636195927e5dfa2675ac5fcc92d4d7bacc3f0`
- Trace wall: `71.0379288197` sec (diagnostic; not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `62.122339` sec; `tmevl_total`: `53.291200` sec
- FRPRMN residual outside TMEVL: `8.831139` sec
- Estimated aggregate CUDA kernels: about `13.96` sec (`19.65%` of trace wall)
- Fused nonlocal kernel: `8.247974033` sec (`59.1%` of kernel time)
- VPJ kernel: `1.574436754` sec (`11.3%` of kernel time)
- H2D: 45,230 copies / `31,590.245` MB / `2.742187068` sec
- D2H: 7,954 copies / `6,127.482` MB / `0.488619796` sec
- CUDA stream/event synchronization: `17.372092065` sec total
- MPI summary: no rows

The approximately `57.08` sec outside CUDA kernels is not a pure GPU-idle
timer, because CPU work, synchronization, runtime, and trace overhead overlap,
but it confirms that kernel execution still occupies only about one fifth of
the trace wall. Direct transfer device time is only about `3.231` sec and MPI
is not a principal target. The fused nonlocal kernel remains the largest GPU
kernel, but its unchanged source was already diagnosed by Step 39: the
tutorial has only 32 blocks for 108 A100 SMs. Do not repeat the same NCU or add
a tutorial-only small-band kernel without production input. The next bounded
diagnostic should split the current `frprmn_energy_diag` host envelope before
another implementation is selected.

## Step 71 Plan

Add default-off timers only and split `frprmn_energy_diag` into the always-run
VG assembly loop, conditional E-field work, and the initial/final expectation
plus off-diagonal path. The existing COEF host synchronization remains outside
the parent timer. Equations, loops, OpenACC ownership, MPI, and the
diagnostic-off instruction path are unchanged. Run `tools/run_tddft_step71.sh`
once, require both correctness checks, and classify the three children plus
the parent gap before selecting an implementation. Its wall is diagnostic.

## Step 71 Result

- Archive: `nvhpc_cufft_1rank_02_STEP71_ENERGY_SPLIT_01`
- Tested revision: `b379f698eeaa3807a5b6629f31cfb5c940980e18`
- Diagnostic wall: `68.9183897972` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn_energy_diag`: `0.871809` sec
- VG assembly: `0.054056` sec
- Conditional E-field: `0.004286` sec
- Expectation plus off-diagonal: `0.809350` sec
- Parent gap: `0.004117` sec

Expectation plus off-diagonal work accounts for `92.84%` of the measured
energy envelope. VG assembly and E-field are too small to justify an
implementation experiment. Split the `0.809350` sec expectation envelope
before selecting another optimization.

## Step 72 Plan

Add default-off timers only around diagonal HLOCAL, diagonal NONLOC, diagonal
dot products, EE communication, and the complete off-diagonal conditional
path. Preserve equations, loops, OpenACC ownership, MPI, and the
diagnostic-off instruction path. Run `tools/run_tddft_step72.sh` once and use
the five children plus parent gap to select the next single implementation
hypothesis. Its wall is diagnostic.

## Step 72 Result

- Archive: `nvhpc_cufft_1rank_02_STEP72_EXPECT_SPLIT_01`
- Tested revision: `10a1d50485fc1cfdd757b3ba6ea483f704dce68e`
- Diagnostic wall: `68.6513030529` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- Expectation parent: `0.816429` sec
- Diagonal HLOCAL: `0.239888` sec (`29.38%`)
- Diagonal NONLOC: `0.299706` sec (`36.71%`)
- Diagonal dot products: `0.012768` sec (`1.56%`)
- EE communication: `0.000014` sec
- Off-diagonal total: `0.258875` sec (`31.71%`)
- Parent gap: `0.005178` sec

Dot products and EE communication are not worthwhile targets. HLOCAL, NONLOC,
and off-diagonal work have similar weights. Split the off-diagonal envelope
once to determine whether its HLOCAL/NONLOC calls form one combined
optimization target with the diagonal calls.

## Step 73 Plan

Add default-off timers only around all HLOCAL calls, all NONLOC calls, matrix
dot products, communication/copy, and gather/output within the current
off-diagonal conditional path. Preserve equations, loops, output, MPI,
OpenACC ownership, and the diagnostic-off instruction path. Run
`tools/run_tddft_step73.sh` once. Use the combined diagonal plus off-diagonal
HLOCAL/NONLOC ceilings to decide whether to optimize this branch or stop it.

## Step 73 Result

- Archive: `nvhpc_cufft_1rank_02_STEP73_OFFDIAG_SPLIT_01`
- Tested revision: `6fdbecb1bc54da9538f39b84633db5d8582f5032`
- Diagnostic wall: `69.2815968990` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- Off-diagonal parent: `0.264491` sec
- HLOCAL: `0.080938` sec
- NONLOC: `0.099967` sec
- Matrix dot products: `0.079395` sec
- Communication/copy: `0.000005` sec
- Gather/output: `0.002409` sec
- Parent gap: `0.001777` sec

Communication and gather/output are not worthwhile targets. Combined with
Step 72 diagonal work, the measured HLOCAL ceiling is about `0.320826` sec
and the NONLOC ceiling about `0.399673` sec. NONLOC redundantly rebuilds YLM
for every band even though G2 is unchanged within a k-point. Test reuse of
that band-independent preparation next; preserve the first preparation for
each k-point and all coefficient-dependent work.

## Step 74 Plan

Add an explicit NONLOC reuse argument. In each TDDFT expectation loop, the
first local band still rebuilds YLM from the current k-point G2; subsequent
bands and off-diagonal calls reuse it. Kinetic DCOEF construction and SEPPOT
remain executed for every coefficient. Reset reuse at every k-point and every
TMEVL expectation event. Preserve MPI, equations, output, OpenACC ownership,
and CPU/FFTW behavior. Run `tools/run_tddft_step74.sh 01` first. If both
checks pass and the result is not a clear regression, collect runs 02/03 with
`tools/run_tddft_step74.sh 02-03` and compare the median with the official
Step 67 median `68.3616518974` sec.

## Step 74 Result and Acceptance

| run | wall_sec | check | relaxed compare |
|---|---:|---|---|
| 01 | `68.1138920784` | PASS | PASS |
| 02 | `68.0681188811` | PASS | PASS |
| 03 | `68.0592751503` | PASS | PASS |

- Tested revision: `3687243228e08ad290f779ec8df5ec934a44b009`
- Three-run median: `68.0681188811` sec
- Run range: `0.0546169281` sec
- Improvement from Step 67: `0.2935330163` sec (`0.429383%`)

All three Step 74 runs are faster than the fastest Step 67 run and pass both
correctness checks. The bounded reuse preserves one YLM rebuild per k-point
and every coefficient-dependent operation. Step 74 is accepted as the new
official source and performance baseline.

## Step 75 Plan

Do not add another optimization yet. Re-run the existing broad default-off
FRPRMN timers on accepted Step 74 source and print the current residual,
classified children, and unclassified gap. This updates the target selection
after YLM reuse without changing equations, MPI, OpenACC ownership, or the
diagnostic-off path. Run `tools/run_tddft_step75.sh` once. Its wall is
diagnostic and cannot replace the Step 74 baseline.

## Step 76 Result

- Archive: `nvhpc_cufft_1rank_02_STEP76_STEP74_VRHO_01`
- Tested revision: `5a4b9c75acf59b9a11575e239a1e62d1171d2bc07`
- Diagnostic wall: `68.4871740341` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- VRHO parent: `1.762396` sec
- VOFRHO: `0.956957` sec (`54.2986%` of parent)
- smoothing/FFT: `0.156599` sec (`8.8856%`)
- mix control: `0.646548` sec (`36.6857%`)
- control seed: `0.549649` sec (`85.0129%` of control)
- predictor: `0.016261` sec
- corrector: `0.078602` sec
- coefficient restore: `0.002889` sec
- parent/control/corrector gaps: `0.002292`, `0.002036`, `0.009319` sec

The Step 62 OpenACC host-copy removal remains effective: the old Step 61
coefficient-restore measurement of `2.158536` sec is now only `0.002889` sec.
The next diagnostic target is VOFRHO, not the already small restore path.

## Step 77 Plan

Add default-off child timers inside VOFRHO for exchange-correlation, FFT,
Hartree zeroing, Hartree construction, and Hartree addition. This changes no
equations, loop order, MPI, OpenACC ownership, or diagnostic-off execution.
Run `tools/run_tddft_step77.sh` once. Its wall is diagnostic and cannot replace
the Step 74 baseline.

## Step 78 Temporary Maximum-Offload Result and Rejection

At the user's request, one temporary combined experiment was run before Step 77
to obtain a quick upper-bound result. Under OpenACC it additionally offloaded
EXTAU table generation, VRHO array/control loops, expectation and off-diagonal
dot products, and the convergence reduction. MPI calls and scalar branch
control remained on the host. The first revision `94e7176` required the
follow-up lifetime fix `cc65c3c`, which placed COEF in one enclosing data
region for the expectation/off-diagonal interval.

- Archive: `nvhpc_cufft_1rank_02_STEP78_MAX_OFFLOAD_01`
- Tested revision: `cc65c3c88738e9b49cfc0307665444dbb60ccce9`
- Wall: `68.3785300255` sec
- Correctness: check PASS; relaxed compare PASS
- Step 74 median difference: `+0.3104111444` sec (`+0.456030%`)
- Difference relative to the Step 74 run range: `5.6834x`

The combined change is correct but clearly slower than the official Step 74
median. Runs 02/03 are intentionally skipped. The added source and one-run
helper are reverted in the same result-record commit, restoring the accepted
Step 74 execution path. This result also reinforces the existing conclusion
that increasing the number of offloaded loops without extending coherent
device ownership can add transfer and launch overhead. Resume the bounded
workflow with the still-pending Step 77 VOFRHO diagnostic.

## Step 75 Result

- Archive: `nvhpc_cufft_1rank_02_STEP75_STEP74_FRPRMN_01`
- Tested revision: `30c8623cdd89fd2661f758432265db5ce6fbd809`
- Diagnostic wall: `68.4886379242` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- FRPRMN residual outside TMEVL: `8.203100` sec
- Classified children: `8.163520` sec (`99.5175%`)
- Unclassified gap: `0.039580` sec
- `frprmn_part1to5`: `1.939650` sec
- `frprmn_vrho_mix`: `1.799974` sec
- `frprmn_extau_prepare`: `1.438920` sec
- `frprmn_energy_diag`: `0.842511` sec

Part1to5 is already GPU-kernel dominated and the tested VPJ vector-length-64
alternative was rejected. The grouped EXTAU form was also rejected. Re-split
current VRHO next: the old Step 60/61 children include the host COEF restore
removed by Step 62 and cannot be attributed to current source unchanged.

## Step 76 Plan

Re-run the existing VRHO child timers on the accepted Step 74 source. This is a
diagnostic-only build and changes no equations, loop order, MPI, or OpenACC
ownership. The summary reports the parent, VOFRHO, smoothing/FFT, control,
seed, predictor, corrector, interpolation, convergence, coefficient restore,
and their three nesting gaps. Run `tools/run_tddft_step76.sh` once. Its wall is
diagnostic and cannot replace the Step 74 baseline.
