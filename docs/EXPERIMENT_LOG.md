# TDDFT GPU Experiment Log

Last updated: 2026-09-03

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
| 75 | Re-measure accepted-source FRPRMN envelopes | 68.4886379242 (one diagnostic run) | measurement | `30c8623` |
| 76 | Re-measure accepted-source VRHO children | 68.4871740341 (one diagnostic run) | measurement | `5a4b9c7` |
| 77 | Split accepted-source VOFRHO | 69.1326959133 (one diagnostic run) | measurement | `a371d4d` |
| 78 | Temporarily offload remaining data-parallel host loops together | 68.3785300255 (run 01) | rejected | `94e7176` + `cc65c3c` / result rollback |
| 79 | Split G2VXC2 exchange-correlation path | 69.1785750389 (one diagnostic run) | inactive-path measurement | `0f3b066` |
| 80 | Offload active LDA S2VXC2 grid loop | 67.4207620621 median | accepted baseline | `59686f0` |
| 82 | Initialize predictor-corrector COEF0 seed on device | 66.6539101601 median | accepted baseline | `2b7f5ba` |
| 84 | Fuse redundant NONLOC kinetic host pass | 66.7368218899 median | rejected | `9ad48b4` / restored in `0494fe5` |
| 85 | Split all current HLOCAL stages | 66.9716517925 (one diagnostic run) | measurement | `0494fe5` |
| 86 | Keep HLOCAL transforms and loops on device | 66.5019950867 median | accepted baseline | `9dd8c20` |
| 98 | Offload EWALD G-space atom pairs | 66.1477772789 median | accepted baseline | `6ef8676` |
| 99 | Map EWALD pairs to gangs and G vectors to vector reduction | 64.3024969101 median | accepted baseline | `6b4099f` |
| 102 | Precompute the band-independent S2 local phase | 63.8388190269 median | accepted baseline | `d021066` |
| 104 | Precompute the band-independent kinetic phase | 64.0659618378 run 01 | rejected / early stop | `c5bec01` / result rollback |
| 105 | Split current ELECTF NONLOCF | 70.5463471413 (one diagnostic run) | measurement | `91f27a0` |
| 106 | Split current SEPPOTF | 70.2937791348 (one diagnostic run) | measurement | `9ef703b` |
| 107 | Batch nonpartitioned s/p SEPPOTF reductions and bound COEF residency | 63.2135219574 median | accepted baseline; batch later proved inactive, gain attributed to COEF residency | `c46cfa9` |
| 108 | Re-profile the accepted Step 107 source | 70.2021420002 (one diagnostic run) | measurement | `4ccf7dc` |
| 109 | Split the batched SEPPOTF path | 69.1963171959 (diagnostic; legacy path observed) | measurement | `f3d6082` |
| 110 | Enable the batched SEPPOTF path for signed `NUMTY` | 63.7820260525 (run 01) | rejected; early stop and restored | `3536127` / `d8ae16e` |
| 111 | Split NONLOCF kinetic/current plus MPI | 69.0858860016 (one diagnostic run) | measurement | `2415d30` |
| 112 | Fuse NONLOCF kinetic/current and A-vector energy passes | 63.6258358955 (run 01) | rejected; early stop and restored | `1aa31fd` / `330bd1c` |
| 113 | Screen isolated NVHPC compiler options | 63.7448709011 best one-run wall (`fastmath`) | screening; no baseline change | `05fd3c4` |
| 114 | Screen NVHPC memory modes | 130.1395111080 best alternative (`managed`) | rejected; >2x control wall | `3fe68c1` |
| 115 | Establish current-source H100 cc90 baseline | 34.1089649200 median | accepted H100-only baseline | `e6ad059` |

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
with `tools/history/tddft_steps/run_tddft_step53_nsys.sh`. The helper rebuilds only TDDFT with
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

Run the single diagnostic with `tools/history/tddft_steps/run_tddft_step54.sh`. The helper builds
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

Run `tools/history/tddft_steps/run_tddft_step55.sh`. It builds only TDDFT with the accepted pinned
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

Run `tools/history/tddft_steps/run_tddft_step56.sh`. It builds only TDDFT with the accepted pinned
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

Use `tools/history/tddft_steps/run_tddft_step57.sh 01` for the first diagnostic-off correctness and
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
with `tools/history/tddft_steps/run_tddft_step58_nsys.sh`. The helper rebuilds only TDDFT with
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

Run `tools/history/tddft_steps/run_tddft_step59.sh` once. It rebuilds only TDDFT with the accepted
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
diagnostic with `tools/history/tddft_steps/run_tddft_step60.sh`. It builds only TDDFT, archives the
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

Run `tools/history/tddft_steps/run_tddft_step61.sh` once. It builds only TDDFT, archives the
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

Use `tools/history/tddft_steps/run_tddft_step62.sh 01` as the diagnostic-off correctness gate. If
normal check and relaxed compare pass, collect both remaining runs with one
command: `tools/history/tddft_steps/run_tddft_step62.sh 02-03`. Adoption requires all three checks
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
with `tools/history/tddft_steps/run_tddft_step62.sh 02-03`, require both correctness checks in all
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
`tools/history/tddft_steps/run_tddft_step63.sh` once. It builds only TDDFT, requires both
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

Run `tools/history/tddft_steps/run_tddft_step64.sh` once. It reuses the existing compile-time
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
and diagnostic-off path. Run `tools/history/tddft_steps/run_tddft_step65.sh` once and require both
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
`tools/history/tddft_steps/run_tddft_step66.sh` once and require both correctness checks; its wall
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
data mappings, D2H, and MPI. Use `tools/history/tddft_steps/run_tddft_step67.sh 01` as the first
diagnostic-off correctness/performance gate. If both checks pass, collect runs
02/03 with `tools/history/tddft_steps/run_tddft_step67.sh 02-03`. Adopt only if the three-run median
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
`tools/history/tddft_steps/run_tddft_step68.sh 01` first; if both checks pass, use
`tools/history/tddft_steps/run_tddft_step68.sh 02-03`. Compare the three-run median with the new
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
length 128. Run `tools/history/tddft_steps/run_tddft_step69.sh 01` first. If correctness passes and
there is no clear regression, obtain runs 02/03 with
`tools/history/tddft_steps/run_tddft_step69.sh 02-03` and compare the median with
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
Use `tools/history/tddft_steps/run_tddft_step70_nsys.sh` once; select no implementation before its
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
diagnostic-off instruction path are unchanged. Run `tools/history/tddft_steps/run_tddft_step71.sh`
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
diagnostic-off instruction path. Run `tools/history/tddft_steps/run_tddft_step72.sh` once and use
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
`tools/history/tddft_steps/run_tddft_step73.sh` once. Use the combined diagonal plus off-diagonal
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
and CPU/FFTW behavior. Run `tools/history/tddft_steps/run_tddft_step74.sh 01` first. If both
checks pass and the result is not a clear regression, collect runs 02/03 with
`tools/history/tddft_steps/run_tddft_step74.sh 02-03` and compare the median with the official
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
diagnostic-off path. Run `tools/history/tddft_steps/run_tddft_step75.sh` once. Its wall is
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
Run `tools/history/tddft_steps/run_tddft_step77.sh` once. Its wall is diagnostic and cannot replace
the Step 74 baseline.

## Step 77 Result

- Archive: `nvhpc_cufft_1rank_02_STEP77_VOFRHO_SPLIT_01`
- Tested revision: `a371d4d1f237d9d77d3e7ed77a807edd2c3ce68b`
- Diagnostic wall: `69.1326959133` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- VRHO parent: `1.793642` sec
- VOFRHO parent: `0.962422` sec
- Exchange-correlation: `0.653802` sec (`67.9329%` of VOFRHO)
- Final potential FFT: `0.111733` sec (`11.6095%`)
- Hartree zeroing: `0.013661` sec
- Hartree construction: `0.161106` sec (`16.7396%`)
- Hartree addition: `0.017956` sec
- VOFRHO gap: `0.004164` sec

Exchange-correlation is the clear next diagnostic target. It contains
reciprocal-space derivative setup, nine derivative FFTs, exchange work,
correlation work, and final assembly. Split those five children before
changing OpenACC ownership or loop placement.

## Step 79 Plan

Add default-off child timers only inside G2VXC2 for derivative setup, the nine
derivative FFT calls, exchange, correlation, and final potential assembly.
Preserve equations, loop order, FFT calls, MPI, OpenACC ownership, and the
diagnostic-off path. Run `tools/history/tddft_steps/run_tddft_step79.sh` once. Its wall is
diagnostic and cannot replace the Step 74 baseline.

## Step 79 Result

- Archive: `nvhpc_cufft_1rank_02_STEP79_XC_SPLIT_01`
- Tested revision: `0f3b066`
- Diagnostic wall: `69.1785750389` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- VOFRHO parent: `0.960509` sec
- XC parent: `0.655301` sec
- All G2VXC2 children: inactive
- Derived G2VXC2 gap: `0.655301` sec

The complete parent appearing as the gap proves that this Si111-H input does
not execute the GGA G2VXC2 branch. It executes the LDA S2VXC2 branch instead.
Do not optimize the inactive G2VXC2 derivative/FFT path for this benchmark.
S2VXC2 is one independent grid-point loop, so test only that loop next.

## Step 80 Plan

Under OpenACC, offload only the active S2VXC2 grid-point loop with RHO copied
in and VCSR copied out. Preserve its branch conditions, formulas, iteration
order per point, caller FFT, Hartree work, MPI, and CPU/FFTW behavior. Run
`tools/history/tddft_steps/run_tddft_step80.sh 01` first. If both checks pass and it is not a clear
regression, collect runs 02/03 with `tools/history/tddft_steps/run_tddft_step80.sh 02-03` and
compare the three-run median with the official Step 74 median.

## Step 80 Three-Run Result

- Archive: `nvhpc_cufft_1rank_02_STEP80_S2VXC_ACC_01`
- Tested revision: `59686f06731feb089ac21d6caa11331dd81051f7`
- Run 01: `67.4321370125` sec; check PASS; relaxed compare PASS
- Run 02: `67.2197408676` sec; check PASS; relaxed compare PASS
- Run 03: `67.4207620621` sec; check PASS; relaxed compare PASS
- Three-run median: `67.4207620621` sec
- Run range: `0.2123961449` sec
- Step 74 median improvement: `0.6473568190` sec (`0.951043%`)
- Median-wall run 03 `time_step_total`: `67.624276` sec
- Median-wall run 03 `frprmn`: `58.618044` sec
- Median-wall run 03 `tmevl_total`: `51.152267` sec
- Median-wall run 03 `s2_nonlocal`: `11.383827` sec
- Median-wall run 03 `s2_nonlocal_gemm`: `10.032972` sec
- Median-wall run 03 `exnlp_gemm_dot`: `8.364374` sec

All three diagnostic-off runs are correct. The median advantage satisfies the
performance gate, and the user approved formal adoption. Step 80 supersedes
Step 74 as the official baseline. Step 81 will re-run the broad FRPRMN timers
on the accepted source before another optimization is selected.

## Step 81 Plan

Make no source optimization. Re-run the existing broad exclusive FRPRMN
timers on the accepted Step 80 source and report the residual, classified
children, and unclassified gap. Run `tools/history/tddft_steps/run_tddft_step81.sh` once. Its
diagnostic wall must not replace the Step 80 baseline.

## Step 81 Result

- Archive: `nvhpc_cufft_1rank_02_STEP81_STEP80_FRPRMN_01`
- Tested revision: `ace50970fa6454b286bd0024dc36d8cf3a1d5d24`
- Diagnostic wall: `68.5029249191` sec
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `59.345574` sec
- `tmevl_total`: `51.466798` sec
- FRPRMN residual: `7.878776` sec
- Classified children: `7.833973` sec (`99.4313%`)
- Unclassified: `0.044803` sec
- Largest children: Part1to5 `1.947618` sec, EXTAU preparation
  `1.448376` sec, VRHO `1.173977` sec, and energy diagnostic
  `1.118869` sec

Relative to the Step 75 diagnostic on accepted Step 74 source, VRHO fell by
`0.625997` sec (`34.7781%`). This directly supports the Step 80 S2VXC2
offload and is close to its `0.6473568190` sec formal median-wall advantage.
Part1to5 is already known to be GPU-kernel dominated, and the tested grouped
EXTAU offload regressed. Before selecting another implementation, print the
VRHO and energy child timers already captured in this archive with
`tools/history/tddft_steps/show_tddft_step81_detail.sh`; no rebuild or rerun is required.

The existing-archive detail showed VOFRHO at `0.359571` sec: XC `0.063268`,
final FFT `0.110018`, Hartree zero/build/add `0.011973` / `0.154377` /
`0.016406`, and only `0.003529` sec other. XC is `0.590534` sec
(`90.3231%`) below Step 77, confirming that it is no longer the target.
VRHO control is now the larger remaining VRHO child at `0.657103` sec.

Energy diagnostic was `1.118869` sec: VG build `0.060059`, E-field
`0.248282`, and expectation `0.778436` sec. Expectation remains dominated by
HLOCAL `0.239013`, NONLOC `0.268549`, and off-diagonal work `0.252268` sec;
communication is negligible. Because E-field was only `0.004286` sec in
Step 71 and performs host output work, do not select it or VRHO control from
aggregate times alone. Use `tools/history/tddft_steps/show_tddft_step81_detail.sh control` to
print current call counts and the already-recorded seed/predict/corrector
split. This still performs no build or rerun.

## Step 82 Plan

The Step 81 archive shows VRHO control at `0.657103` sec, dominated by seed
initialization at `0.562341` sec (`85.5773%`). Predictor and corrector control
used only `0.016313` and `0.076263` sec. Test one bounded ownership change:
under OpenACC only, omit the host COEF-to-COEF0 seed copy and the subsequent
COEF0 H2D. At the existing predictor-corrector data entry, copy COEF in,
create COEF0, and initialize COEF0 from COEF with one device kernel.

Keep the same per-sequence allocation lifetime, correction restart, exit,
MPI, equations, and arithmetic order. Preserve the original host copy for
CPU/FFTW. This is not the rejected Step 45 whole-time-step COEF allocation.
Run `tools/history/tddft_steps/run_tddft_step82.sh 01` first. Only after PASS/PASS without a clear
regression, collect runs 02/03 together and decide from the three-run median
against Step 80.

## Step 82 Run 01

- Archive: `nvhpc_cufft_1rank_02_STEP82_COEF0_D2D_SEED_01`
- Tested revision: `2b7f5ba10334cbdf479d9012a75be79366104edd`
- Wall: `66.8839480877` sec
- Correctness: check PASS; relaxed compare PASS
- Step 80 median difference: `-0.5368139744` sec (`-0.796215%`)

The first run is healthy and promising. Its wall reduction is also close to
the Step 81 measured seed cost of `0.562341` sec, consistent with the bounded
hypothesis. This single run does not establish a new baseline. Collect Step 82
runs 02/03 together, then decide from the three-run median.

## Step 82 Final Result

- Run 01: `66.8839480877` sec; check PASS; relaxed compare PASS
- Run 02: `66.6139972210` sec; check PASS; relaxed compare PASS
- Run 03: `66.6539101601` sec; check PASS; relaxed compare PASS
- Three-run median: `66.6539101601` sec
- Run-to-run range: `0.2699508667` sec
- Step 80 median difference: `-0.7668519020` sec (`-1.137412%`)

Every Step 82 run is faster than the official Step 80 median. Accept the
device-local COEF0 seed initialization and supersede Step 80 with Step 82 as
the official baseline. Step 83 is diagnostic only: re-run the existing VRHO
child timers on accepted Step 82 source to confirm the seed/control reduction.

## Step 83 Result

- Archive: `nvhpc_cufft_1rank_02_STEP83_STEP82_VRHO_01`
- Tested revision: `d841f7a25a466fb23c88977e4eaf5e871726655d`
- Diagnostic wall: `67.2204380035` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- VRHO parent: `0.622439` sec
- Seed control: `0.000497` sec
- VRHO control: `0.103696` sec

Relative to the Step 81 archive, seed control fell by `0.561844` sec
(`99.9116%`), VRHO control by `0.553407` sec (`84.2192%`), and the complete
VRHO parent by `0.551538` sec (`46.9803%`). This directly confirms the Step 82
mechanism. Before selecting another implementation, print the current broad
and energy envelopes from this same archive with
`tools/history/tddft_steps/show_tddft_step83_next.sh`; this requires no build or rerun.

## Step 84 Result and Rejection

The current energy envelope is `0.847562` sec. Its diagonal and off-diagonal
NONLOC children total about `0.3578` sec. NONLOC currently makes one complete
host pass over NG2 to stage the band-independent kinetic factor in RHOA, then
immediately makes a second pass that consumes it once. Fuse those two passes
by applying the same GDUMP expression directly in the DCOEF update. Preserve
operation grouping, YLM reuse, HLOCAL, SEPPOT, MPI, OpenACC ownership, and the
CPU/FFTW path.

- Tested revision: `9ad48b4b882c913acb46b1fb1d7e6533bfdb90433`
- Runs 01/02/03: `66.7368218899`, `66.7220189571`, `66.8331620693` sec
- Correctness: all normal checks PASS; all relaxed comparisons PASS
- Median: `66.7368218899` sec
- Range: `0.1111431122` sec
- Step 82 median difference: `+0.0829117298` sec (`+0.124391%`)

The fused pass is correct but provides no performance advantage. Restore the
accepted Step 82 expression and remove the Step 84 run helper. Step 82 remains
the official baseline.

## Step 85 Result

The current diagonal and off-diagonal HLOCAL children are `0.237196` and
`0.080948` sec. Before changing their GPU ownership, split HLOCAL into zero,
scatter, inverse FFT, local-potential multiply, forward FFT, and gather timers.
This is diagnostic only and changes no equations, loop order, MPI, or ownership.

- Archive: `nvhpc_cufft_1rank_02_STEP85_STEP82_HLOCAL_01`
- Tested revision: `0494fe533e3ed2f390d3bafca2962db2c6d024dd`
- Diagnostic wall: `66.9716517925` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- HLOCAL calls: 768 total = 384 diagonal + 128 off-diagonal + 256 TMEVL
- Zero: `0.013984` sec
- Scatter: `0.067270` sec
- Inverse FFT: `0.128601` sec
- Local-potential multiply: `0.040314` sec
- Forward FFT: `0.141528` sec
- Gather: `0.090866` sec
- Classified HLOCAL total: `0.482563` sec

The original helper printed a negative parent gap because it compared all 768
HLOCAL calls with only the 512 diagonal/off-diagonal parent calls. The stage
timers themselves are valid; the completed diagnostic helper is removed so it
cannot be rerun against the Step 86 source. FFTs account for `55.978%` and
scatter/gather for `32.770%` of the complete HLOCAL time.

## Step 86 Final Result

The host-staged cuFFT wrapper performs H2D and D2H for each FFT. Test one
temporary HLOCAL device data region so zero, scatter, both FFTs, the
local-potential multiply, and gather stay on the GPU. Copy only COEF/VG/J2G in
and DCOEF out at the HLOCAL boundary. Keep the existing CPU/FFTW implementation
unchanged. All runs passed both checks:

- Run 01: `66.5019950867` sec
- Run 02: `66.6454100609` sec
- Run 03: `66.3501911163` sec
- Three-run median: `66.5019950867` sec
- Run-to-run range: `0.2952189446` sec
- Step 82 improvement: `0.1519150734` sec (`0.22791%`)

Accept Step 86 as the official A100 baseline.

## Step 87 Plan

Add one default-off parent timer around the accepted device HLOCAL path. Use it
to compare the complete 768-call HLOCAL time with Step 85's `0.482563` sec and
derive diagonal, off-diagonal, and TMEVL contributions. This changes no
diagnostic-off execution. Run `tools/history/tddft_steps/run_tddft_step87.sh` once; its wall time
is diagnostic and is not a baseline.

## Step 87 Result

- Archive: `nvhpc_cufft_1rank_02_STEP87_STEP86_HLOCAL_01`
- Tested revision: `571233b9c3c6bd413e0949514a570f9794f61898`
- Diagnostic wall: `67.6458580494` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- Device HLOCAL total: `0.247780` sec over 768 calls
- Diagonal HLOCAL: `0.128030` sec over 384 calls
- Off-diagonal HLOCAL: `0.040771` sec over 128 calls
- Derived TMEVL HLOCAL: `0.078979` sec over 256 calls
- Step 85 host-staged HLOCAL total: `0.482563` sec
- Reduction: `0.234783` sec (`48.653%`)

The direct HLOCAL reduction confirms the Step 86 mechanism and is consistent
with the smaller end-to-end median improvement. Before another implementation,
print the remaining energy hierarchy from this same archive with
`tools/history/tddft_steps/show_tddft_step87_next.sh`.

## Step 87 Existing-Archive Energy Detail

The current energy expectation is `0.634219` sec. Its largest remaining
component is NONLOC: diagonal `0.274122` plus off-diagonal `0.090716`, for
`0.364838` sec (`57.53%` of expectation). The combined energy HLOCAL time is
`0.168801` sec after Step 86. Dot products, communication, and hierarchy gaps
are smaller. Step 84 already rejected a simple redundant kinetic-pass fusion,
so do not repeat it.

## Step 88 Plan

Add default-off timers inside NONLOC around kinetic coefficient updates, YLM
preparation/reuse, and SEPPOT projector calculation. Measure all NONLOC calls
because the same routine serves TMEVL expectation and energy expectation.
Change no equations, loop order, ownership, MPI, or diagnostic-off path. Run
`tools/history/tddft_steps/run_tddft_step88.sh` once and choose a single implementation only after
the split is known.

## Step 88 Result

- Archive: `nvhpc_cufft_1rank_02_STEP88_STEP86_NONLOC_01`
- Tested revision: `f13e17e8b1410a5a1dd172bd876a0b20908fae69`
- Diagnostic wall: `67.0601370335` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- NONLOC calls: 768
- Kinetic: `0.056220` sec (`10.325%`)
- YLM: `0.003207` sec (`0.589%`)
- SEPPOT: `0.485064` sec (`89.086%`)
- Classified total: `0.544491` sec

SEPPOT is the only material next target. It has separate s/p/d/f branches, so
do not offload all branches at once.

## Step 89 Plan

Add default-off timers around SEPPOT EXTAU phase-table construction and each
s/p/d/f orbital channel. This identifies the active dominant branch before
splitting its projector construction, coefficient reductions, and DCOEF
updates. Run `tools/history/tddft_steps/run_tddft_step89.sh` once; make no optimization yet.

## Step 89 Result

- Archive: `nvhpc_cufft_1rank_02_STEP89_STEP86_SEPPOT_01`
- Tested revision: `917ce1e9b81faf3a267b2b30ac930e982c848c35`
- Diagnostic wall: `67.2417340279` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- SEPPOT parent: `0.547832` sec over 768 NONLOC calls
- EXTAU: `0.188158` sec (`36.414%` of classified time)
- s channel: `0.103150` sec (`19.963%`)
- p channel: `0.225405` sec (`43.623%`)
- d/f channels: inactive for this input
- Classified total: `0.516713` sec; gap: `0.031119` sec

The active p channel is the largest child, but a complete tutorial-specific
s/p offload was already rejected in Step 47. Step 90 therefore adds timers
only around p-channel projector construction, coefficient reduction, and
DCOEF update loops before considering a distinct bounded hypothesis.

## Step 90 Plan

Measure the three existing p-channel loops without changing arithmetic,
ordering, ownership, MPI, or the diagnostic-off path. Run
`tools/history/tddft_steps/run_tddft_step90.sh` once. Do not reintroduce the rejected Step 47
whole-channel implementation.

## Step 90 Result

- Archive: `nvhpc_cufft_1rank_02_STEP90_STEP86_PCHANNEL_01`
- Tested revision: `393507cb63fddb478289fc031f0c59f8a788f61f`
- Diagnostic wall: `68.3954150677` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- p-channel parent: `0.284428` sec over 9,216 calls
- Projector construction: `0.095651` sec (`39.103%`)
- Coefficient reduction: `0.069291` sec (`28.327%`)
- DCOEF update: `0.079670` sec (`32.570%`)
- Classified total: `0.244612` sec; gap: `0.039816` sec

No child dominates, and each is invoked 9,216 times. Separate offload would
have a ceiling below `0.1` sec per child while adding fine-grained launches
and synchronization. Together with the rejected Step 47 whole s/p offload,
this closes the current SEPPOT path without another implementation.

## Step 91 Plan

Re-profile the accepted Step 86 source with diagnostics off. Step 70 predates
the Step 74 YLM reuse, Step 80 LDA loop offload, Step 82 seed ownership, and
Step 86 HLOCAL device region. Use `tools/history/tddft_steps/run_tddft_step91_nsys.sh` once to
update kernel, transfer, CUDA/OpenACC API, synchronization, MPI, and GPU-idle
evidence before selecting another bounded hypothesis. The trace wall is not
a performance baseline.

## Step 91 Result

- Archive: `nvhpc_cufft_1rank_02_STEP91_STEP86_NSYS_01`
- Tested revision: `11691621195fb3e80eb40c825584011dfb1685c4`
- Trace wall: `69.98909358414` sec (diagnostic; not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `frprmn`: `61.133014` sec; `tmevl_total`: `53.969606` sec
- Estimated aggregate CUDA kernels: about `13.90` sec (`19.86%` of trace wall)
- Fused nonlocal kernel: `8.200543838` sec (`59.0%` of kernel time)
- VPJ kernel: `1.559553328` sec (`11.2%` of kernel time)
- H2D: 45,663 copies / `28,361.039` MB / `2.479428511` sec
- D2H: 7,759 copies / `6,036.924` MB / `0.482051802` sec
- CUDA stream/event synchronization: `17.235587864` sec total
- MPI summary: no rows
- Pinned host allocation: one `cuMemHostAlloc`, `0.273660713` sec

Relative to Step 70, H2D plus D2H time fell by `0.269326551` sec and H2D
volume fell by `3,229.206` MB. The fused and VPJ kernels changed by only
`-0.047430195` and `-0.014883426` sec, while overlapping stream plus event
synchronization fell by only `0.136504201` sec. The approximately `56.09` sec
outside reported CUDA kernels is not pure GPU idle because CPU computation,
runtime, waits, and profiler overhead overlap. MPI and allocation remain
non-dominant.

Do not add a new offload yet. First run
`tools/history/tddft_steps/show_tddft_step91_detail.sh` against the existing archive. It performs
no build or rerun and prints only TMEVL OpenACC update/wait rows plus selected
CUDA synchronization/copy rows. Use those source-attributed rows to distinguish
required host-consumer boundaries from avoidable repeated staging before
selecting one bounded ownership hypothesis.

## Step 91 Existing-Archive Transfer/Wait Detail

The line-1930 `work2_` update ran 4,720 times and used `1.609217948` sec,
including a nested Wait row of `1.530650988` sec. The line-1933 `cfac_` and
`ngnl_` metadata update used `0.148298132` sec, including `0.137812074` sec
in its nested Wait row. Together the two Update rows total `1.757516080` sec
and their nested Wait rows total `1.668463062` sec. These inclusive rows must
not be added to each other or to CUDA API synchronization.

The line-2405 fused-kernel completion Wait used `8.360886829` sec over 18,880
events, consistent with the `8.200543838` sec fused CUDA kernel remaining the
dominant GPU computation. Eliminating a host upload alone is not enough:
device construction would still have to reproduce the host `work2_`, `cfac_`,
and `ngnl_` values and preserve the sequential projector order. Previous YLM
ownership and fine-grained lookup-copy forms regressed badly, so do not repeat
them.

Before deciding whether a distinct owner-side generation/fusion shape exists,
run `tools/history/tddft_steps/show_tddft_step91_next.sh`. It reads the existing Step 88 diagnostic
archive and Step 91 Nsight archive only, printing the current host-generation,
update, metadata, and fused-GEMM timers together. No build or rerun is needed.

## Step 91 Existing-Archive Host/Update/Kernel Ceiling

The combined Step 88/91 view reports `s2_nonlocal=11.548827`,
host `s2_nonlocal_make=1.348333`, owner-side `work2_` setup `1.550889`,
owner-side metadata setup `0.088045`, and fused `exnlp_gemm_dot=8.400202`
seconds. Host make plus owner-side setup is therefore `2.987267` seconds,
`25.8668%` of the current nonlocal parent and `4.4919%` of the official
Step 86 wall. Source timers and inclusive Nsight rows overlap, so they must
not be added to the application wall.

Direct device generation is not selected. It needs YLM, VPJ, and EXTAU on the
device and would repeat the rejected B1 YLM ownership shape (`+6.7%`) or the
rejected Step 20 fine-grained lookup copies (`819.404727936` seconds).
Step 92 instead keeps equations and ownership unchanged and counts whether
the complete active `work2_`/`cfac_`/`ngnl_` values repeat exactly between
consecutive TMEVL calls of each Suzuki-Trotter phase. Run
`tools/history/tddft_steps/run_tddft_step92.sh` once and use its equal/changed counts to decide
whether a host-produced cache can remove generation and upload safely.

## Step 92 Exact Nonlocal Reuse Result

Step 92 passed both correctness checks. Every phase reported 944 observations
and 943 comparable consecutive calls. All five phases had zero exact matches
and 943 changes (`0.000%` equal), so complete host-produced `work2_` reuse is
not valid. Its `71.3717830181` second diagnostic wall is not a baseline.

Step 93 makes no optimization. It separates exact equality for `ngnl_`,
`cfac_`, and `work2_`. If only the metadata stays constant, the next bounded
hypothesis may initialize that metadata on the device once; otherwise the
nonlocal staging path remains unchanged.

## Step 93 Component Reuse Result

- Archive: `nvhpc_cufft_1rank_02_STEP93_STEP86_EXNLP_PARTS_01`
- Tested revision: `0c63c848777ee56e52d56569364376ad91fb9336`
- Diagnostic wall: `72.5525600910` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- Comparisons: 943 for each of the five Suzuki-Trotter phases
- `ngnl_` exact equality: `0.000%` in every phase
- `cfac_` exact equality: `0.000%` in every phase
- `work2_` exact equality: `0.000%` in every phase
- Complete tuple exact equality: `0.000%` in every phase

Both metadata components change with the projector values. One-time metadata
device initialization is therefore invalid for this phase-keyed scheme.
Together with Step 92, this closes complete host-produced `work2_` reuse and
metadata-only reuse. Do not retry either cache shape. The official Step 86
diagnostic-off median remains `66.5019950867` sec.

## Step 94 Plan

Re-measure current-source ELECTF `LOCPOTF` before selecting another
implementation. The old Step 43 `4.071556` sec parent combines EWALD, local
G-vector/force construction, MPI, energy, XC, and Hartree work. Add two
default-off timers only: the complete `LOCPOTF` call and the existing local
potential/force construction through its MPI boundary. Derive the remainder
from the two values.

This diagnostic changes no equation, loop order, MPI call, OpenACC ownership,
or diagnostic-off path. Run `tools/history/tddft_steps/run_tddft_step94.sh` once, require normal
check and relaxed compare, and do not use its wall as a baseline. A
local-potential implementation is not selected until the current child share
is known.

## Step 94 Result

- Archive: `nvhpc_cufft_1rank_02_STEP94_STEP86_LOCPOTF_01`
- Tested revision: `f7cf9d78660fdbfbdd1acbb3cc2204f4f0d225e0`
- Diagnostic wall: `72.0893621445` sec (not a baseline)
- Correctness: check PASS; relaxed compare PASS
- `electf_force`: `9.265508` sec
- `electf_locpotf_total`: `4.345268` sec
- `locpotf_local_mpi`: `1.193364` sec (`27.464%`)
- Derived remainder: `3.151904` sec (`72.536%`)

Local G construction, force accumulation, and MPI are not the dominant
`LOCPOTF` section. Do not implement the analogous LOCPOT offload yet. Split the
larger remainder into EWALD, local-energy, XC, Hartree, and unclassified gap
before selecting one performance hypothesis.

## Step 95 Plan

Add default-off child timers around the existing EWALDY call, local-energy
reduction, XC call, and Hartree reduction/final assembly. Keep the Step 94
complete `LOCPOTF` and local-build/MPI timers and derive the four-child total
and unclassified remainder gap.

The timer table grows from 120 to 124 entries, with every initialization,
bound, reduction count, and report loop changed consistently. Equations, loop
order, MPI, OpenACC ownership, CPU/FFTW behavior, and diagnostic-off execution
remain unchanged. Run `tools/history/tddft_steps/run_tddft_step95.sh` once, require both
correctness checks, and do not use its wall as a baseline.

The first A100 run at revision `6952f54` completed and was archived with both
checks passing, but the final summary stopped because the target `awk` reserves
`split` as a function name and rejected its use as a variable. The measured run
remains valid: its diagnostic wall was `72.0551159382` sec under archive label
`nvhpc_cufft_1rank_02_STEP95_STEP86_LOCPOTF_SPLIT_01`.
`tools/history/tddft_steps/report_tddft_step95.sh` rechecks and summarizes that existing archive
without rebuilding or rerunning TDDFT. The diagnostic wall is not a baseline.

## Step 95 Result

- Revision: `6952f54`
- Archive: `nvhpc_cufft_1rank_02_STEP95_STEP86_LOCPOTF_SPLIT_01`
- Correctness: `check=PASS`, `compare=PASS`
- Diagnostic wall: `72.0551159382` sec (not a baseline)
- `electf_locpotf_total`: `4.094380` sec
- `locpotf_local_mpi`: `0.934872` sec
- LOCPOTF remainder: `3.159508` sec
- EWALD: `3.024790` sec (`95.736%` of the remainder)
- Local energy: `0.008415` sec (`0.266%`)
- XC: `0.105457` sec (`3.338%`)
- Hartree: `0.018546` sec (`0.587%`)
- Unclassified gap: `0.002300` sec (`0.073%`)

EWALD alone explains essentially the complete LOCPOTF remainder. Step 96 tests
one bounded hypothesis before implementing a cache: compare every `EWA` and
active-atom `FORCE` output from the 101 fixed-nuclei EWALDY calls exactly
against the preceding call. If all 100 comparisons match, cache only those two
outputs after the first call; otherwise do not implement that reuse path.

## Step 96 Result and Step 97 Plan

Step 96 revision `4902b4f` passed both checks. Its diagnostic wall was
`71.6179108620` sec and is not a baseline. Across 101 observations, all 100
comparisons changed: `EWA`, active-atom `FORCE`, and the combined output each
reported `0.000%` exact equality. Close the EWALD output-cache path.

EWALD remains a measured `3.024790` sec target. Step 97 therefore adds only
three default-off child timers around its G-space sum, R-space sum, and MPI
reductions/broadcast. The remaining setup/AGEN time is derived as a gap.
Whichever compute child dominates becomes the next direct acceleration target;
do not optimize sub-percent LOCPOTF children first.

## Step 97 Result and Step 98 Plan

Step 97 revision `02fa239` passed both checks. Its `72.0625281334` sec wall is
diagnostic only. EWALDY used `3.024816` sec: G-space `2.795064` sec
(`92.404%`), R-space `0.205414` sec (`6.791%`), MPI `0.019249` sec
(`0.636%`), and setup/AGEN gap `0.005089` sec (`0.168%`).

Step 98 directly targets G-space. Under OpenACC it uses one data region per
EWALDY call, parallelizes the rectangular atom-pair space, preserves each
pair's G-vector accumulation order, and uses atomic updates only for shared
force elements. The existing MPI pair assignment is expressed by its exact
triangular sequence formula. CPU/FFTW retains the original loop nest. Run 01
diagnostic-off first; collect runs 02-03 only if it passes both checks and is
promising against the Step 86 median.

## Step 98 Result and Step 99 Plan

All Step 98 runs passed both checks at `66.1477772789`, `66.14293359913`, and
`66.4177260399` sec. The median is `66.1477772789` sec with a
`0.27479244077` sec range, improving on Step 86 by `0.3542178078` sec
(`0.532642%`). Step 98 is accepted as the source and performance baseline.

The gain is much smaller than the original `2.795064` sec G-space host timer.
Step 99 keeps the accepted data region, atomic force updates, MPI assignment,
and pair-local arithmetic, but maps one atom pair to a gang and its G-vector
loop to a vector reduction. Run 01 first and compare against Step 98.

## Step 99 Result and Step 100 Plan

All Step 99 runs passed both checks at `64.5138220787`, `64.2798080444`, and
`64.3024969101` sec. The median is `64.3024969101` sec with a
`0.2340140343` sec range. This improves on Step 98 by `1.8452803688` sec
(`2.789633%`) and on Step 86 by `2.1994981766` sec (`3.307417%`).
Step 99 is accepted as the source and performance baseline.

Step 100 makes no numerical or ownership change. It runs the existing
default-off timers once on the accepted source and prints a compact selection
of the major current intervals. Use the diagnostic result only to choose the
largest remaining actionable hotspot; its wall is not a performance baseline.

## Step 100 Result and Step 101 Existing-Archive Detail

Step 100 passed both checks at revision `f1e22c2`. Its `70.6082198620` sec
diagnostic wall is not a baseline. `tmevl_s2` was `20.759666` sec and
`s2_nonlocal` was `16.100488` sec. The apparent
`16.100488 - 1.432096 - 10.169891 = 4.498501` sec nonlocal gap is the
diagnostic-only full-array reuse observer retained from Steps 92/93; it is
absent from diagnostic-off performance runs and is not an optimization target.

The fused nonlocal kernel remains the largest real child at `8.402617` sec,
but its 32-band/32-block tutorial occupancy limit, vector-length alternatives,
direction specialization, host cache, and metadata cache have already been
classified or rejected. Step 101 therefore reads the existing Step 100
archive without rebuilding or rerunning. It prints the nonlocal transfer
children and the `4.659178` sec S2-local remainder hierarchy before another
single implementation hypothesis is selected.

## Step 101 Result and Step 102 Plan

The existing-archive report confirms `exnlp_gemm_data=8.455729` sec and
`exnlp_gemm_dot=8.402617` sec; the fused-kernel wrapper itself adds little.
The first-phase `work2_` and metadata uploads use `1.551925` and `0.088854`
sec, respectively. The closed cache/direct-generation paths are not retried.

S2 local uses `4.612063` sec. Its measured elementwise kernels total about
`2.334380` sec, leaving `2.277363` sec for FFT/runtime work. The local phase
multiply alone uses `0.917904` sec because the same `COS/SIN` is evaluated for
every band. Step 102 preserves the existing `VG=VGG+Vloc` value and phase
formula but computes its complex phase once per grid point, then reuses that
factor across all local bands. No `ia` order, MPI boundary, FFT ownership, or
CPU/FFTW fallback is changed. The GNU MPI + FFTW fallback full build/link
passes with existing legacy warnings only.

## Step 102 Result and Step 103 Existing-Archive Plan

All Step 102 runs passed both checks at `63.8388190269`, `63.71222411728`,
and `63.9600141048` sec. The median is `63.8388190269` sec with a
`0.24778998752` sec range. This improves on Step 99 by `0.4636778832` sec
(`0.721088%`) and on Step 86 by `2.6631760598` sec (`4.004656%`).
Step 102 is accepted as the source and performance baseline.

Step 103 makes no source or numerical change. It reads the existing Step 100
archive and prints the unchanged `exkin_` parent/kernel ceiling. This checks
whether the same band-independent phase precomputation is large enough to
justify another implementation without spending time on a new diagnostic run.

## Step 103 Result and Step 104 Plan

The existing Step 100 archive reports `tmevl_exkin=0.671559` sec and
`exkin_acc_kernel=0.635902` sec over 9,440 calls, leaving only a
`0.035657` sec wrapper gap. Step 104 changes the independent iteration mapping
from band-by-G collapse to G-vector parallelism with a sequential local-band
inner loop. Each G vector evaluates the identical kinetic phase once and
reuses it for all 32 local bands. Each `P(ig,iib)` update retains the same
formula; MPI, data ownership, call count, and the CPU/FFTW path are preserved.
The GNU MPI + FFTW fallback full build/link passes with existing legacy
warnings only.

## Step 104 Result and Rejection

Run 01 passed both checks but took `64.0659618378` sec, a
`0.2271428109` sec (`0.355807%`) regression from the Step 102 median.
The regression is slightly smaller than the Step 102 run range, but there is
no promising first-run signal, so runs 02/03 are skipped. Reducing phase
evaluations did not compensate for replacing band-by-G collapse with a
sequential band loop. Step 104 is rejected, its source and helper are removed,
and the accepted Step 102 mapping and `63.8388190269` sec baseline are
restored.
The restored GNU MPI + FFTW fallback full build/link passes with existing
legacy warnings only.

## Step 105 Plan

The Step 100 current-source timers report `electf_force=6.249443` sec and
`electf_locpotf_total=1.373461` sec. Their `4.875982` sec difference is
`7.638%` of the official Step 102 median and closely matches the old
ELECTF-side NONLOCF interval. Old Steps 43/44 found SEPPOTF dominant, but the
Step 47 tutorial-specific whole s/p GPU path produced only a noise-level
`0.0291%` median advantage and must not be repeated.

Step 105 is diagnostic only. Default-off timers measure the complete NONLOCF
call and exclusive setup, coefficient kinetic/current plus MPI, GETYLM,
SEPPOTF, and final force/energy assembly sections. The helper derives their
coverage and unclassified gap. It changes no equation, loop order, MPI
boundary, OpenACC ownership, CPU/FFTW behavior, or diagnostic-off execution.
Run `tools/history/tddft_steps/run_tddft_step105.sh` once, require normal check and relaxed
compare, and do not use its diagnostic wall as a performance baseline.

## Step 105 Result

- Archive: `nvhpc_cufft_1rank_02_STEP105_STEP102_NONLOCF_SPLIT_01`
- Tested revision: `91f27a0c3c94a5ec1e5a9d4a82600c9837852a95`
- Diagnostic wall: `70.5463471413` sec (not a baseline)
- Correctness: normal check PASS; relaxed compare PASS
- ELECTF NONLOCF: `4.975987` sec over 101 calls
- setup: `0.000899` sec (`0.018%`)
- coefficient kinetic/current plus MPI: `0.898982` sec (`18.066%`)
- GETYLM: `0.011795` sec (`0.237%`)
- SEPPOTF: `4.061892` sec (`81.630%`)
- finalization: `0.000562` sec (`0.011%`)
- unclassified gap: `0.001857` sec (`0.037%`)

SEPPOTF is also `6.362730%` of the official Step 102 median, so it is the
largest actionable child. The diagnostic wall is not a performance baseline.

## Step 106 Plan

Step 47's rejected tutorial-specific s/p GPU path must not be repeated. A
source comparison found a structural problem in that form: the current host
path generates WORK/DCOEF projector values once per atom/orbital/G vector and
reuses them across local bands, while the Step 47 GPU path recomputed the
projector expressions inside each band reduction.

Step 106 is diagnostic only. Default-off timers split current SEPPOTF into
phase generation, nonpartitioned s projector generation, nonpartitioned s
band reduction, nonpartitioned p projector generation, nonpartitioned p band
reduction, MPI, and an unclassified gap. No equation, loop order, MPI boundary,
OpenACC ownership, CPU/FFTW path, or diagnostic-off execution changes. Run
`tools/history/tddft_steps/run_tddft_step106.sh` once and require both correctness checks. Its wall
is diagnostic only. Consider a structurally different two-stage GPU path only
if the band reductions have a material ceiling; otherwise close or redirect
the SEPPOTF path according to the measured dominant child.

## Step 106 Result

- Archive: `nvhpc_cufft_1rank_02_STEP106_STEP102_SEPPOTF_DETAIL_01`
- Tested revision: `9ef703bd8dd168ed18bfe133d611d383fd557076`
- Diagnostic wall: `70.2937791348` sec (not a baseline)
- Correctness: normal check PASS; relaxed compare PASS
- SEPPOTF: `4.101524` sec over 202 calls
- phase: `0.091686` sec (`2.235%`)
- s projector generation: `0.047953` sec (`1.169%`)
- s band reduction: `1.270594` sec (`30.979%`)
- p projector generation: `0.122658` sec (`2.991%`)
- p band reduction: `2.537915` sec (`61.877%`)
- MPI: `0.000391` sec (`0.010%`)
- unclassified gap: `0.030327` sec (`0.739%`)

The s/p band reductions total `3.808509` sec, `92.856%` of SEPPOTF and
`5.965820%` of the official Step 102 wall. This is a material ceiling, while
projector generation and MPI are not direct targets.

## Step 107 Plan

Implement one structurally different nonpartitioned s/p GPU hypothesis. For
each type, generate projector values once for all atoms and G vectors, reduce
all atom x local-band pairs on the GPU, and finalize each band sequentially in
the original type, atom, and s-then-p order. Reuse the existing EXTAU storage
as the projector scratch and add only a 16-complex-value reduction record per
atom/local-band pair. Unsupported partitioned or d/f shapes use the unchanged
host implementation.

Extend COEF ownership only from FRPRMN through its immediately following
ELECTF call in the same time step, then delete it before the next time step.
This is the previously validated Step 46 call boundary, not the rejected Step
45 whole-time-step lifetime. The GNU MPI + FFTW fallback full build/link must
pass. Run `tools/history/tddft_steps/run_tddft_step107.sh 01` with diagnostics off and require both
checks. Stop on failure or an unpromising first wall; run `02-03` only after a
healthy first result. Compare a completed three-run median with the official
Step 102 median `63.8388190269` sec. Rollback target: `9ef703b`.

## Step 107 Result

All three diagnostic-off A100 runs used revision `c46cfa9`, 1 GPU / 1 MPI
rank, and the Si111-H 100-step case. Every run passed normal check and relaxed
compare.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP107_SEPPOTF_BATCH_01` | 63.1300778389 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP107_SEPPOTF_BATCH_02` | 63.2335109711 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP107_SEPPOTF_BATCH_03` | 63.2135219574 | PASS | PASS |

The median is `63.2135219574` sec and the range is `0.1034331322` sec.
Relative to the official Step 102 median, Step 107 is `0.6252970695` sec
(`0.979493%`) faster. Step 107 is accepted as the new source and performance
baseline.

## Step 108 Plan

Re-run the existing default-off current-source timers on accepted Step 107
without changing equations, loops, MPI, or OpenACC ownership. Report the major
TMEVL/S2, FRPRMN, ELECTF/NONLOCF, HLOCAL, and EWALD intervals in one compact
terminal block. Use the result only to select the next single high-impact
hypothesis; its diagnostic wall cannot replace the Step 107 baseline.

## Step 108 Result and Step 109 Plan

Step 108 at revision `4ccf7dc` passed both checks. Its diagnostic wall was
`70.2021420002` sec and is not a baseline. The largest measured intervals are
S2 NONLOCAL `16.045700` sec, its GEMM wrapper `10.201628` sec, and the fused
EXNLP kernel `8.412670` sec. Those paths already have their safe mapping and
cache variants classified. ELECTF NONLOCF remains `5.076909` sec, of which
the SEPPOTF parent is `4.262210` sec. Step 109 later proved that the proposed
Step 107 batch path was inactive for this tutorial input.

Step 109 changes no numerical path. Default-off timers attempt to split the
proposed batched SEPPOTF parent into projector generation, s and p batch
reductions, final GPU assembly, result download, MPI, and an unclassified gap.
This identifies whether a further bounded SEPPOTF hypothesis has material
ceiling before returning to a lower-ranked interval.

Step 109 at revision `f3d6082` passed both correctness checks, but its compact
report stopped because timer IDs 140--144 were absent. The visible parent and
MPI values were `4.263925` and `0.000369` sec. Before rerunning, use
`tools/history/tddft_steps/report_tddft_step109.sh` to read the existing archive and determine
whether legacy timer IDs 134--138 ran instead. The report performs no build or
simulation.

The existing-archive report proves that the legacy path ran. Its phase,
s-projector, s-band reduction, p-projector, and p-band reduction values were
`0.091407`, `0.048610`, `1.272016`, `0.123364`, and `2.698033` sec.
Startup output reports `NTYPE=2` and signed `NUMTY=12,-2`, with no real-space
partition message. The Step 107 guard incorrectly treated the negative atom
count as unsupported even though the legacy SEPPOTF loops consistently use
`ABS(NUMTY)`. Therefore the accepted Step 107 improvement came from the
FRPRMN-to-ELECTF COEF residency boundary, not from the inactive batch path.

## Step 110 Plan

Change only signed atom-count handling in the batched path: reject zero atom
counts, but use `ABS(NUMTY)` in projector generation and final assembly exactly
as the legacy SEPPOTF path does. Type, atom, and s-then-p accumulation order,
formulas, MPI, partition fallback, d/f fallback, and COEF ownership remain
unchanged. Run diagnostic-off performance run 01 first and require both
correctness checks. Continue to runs 02/03 only if it is correct and promising.
Rollback target: `94bd29e`.

## Step 110 Result and Rejection

Run 01 at revision `3536127` passed both the normal check and relaxed compare
with diagnostics off, but took `63.7820260525` sec. This is
`0.5685040951` sec (`0.899339%`) slower than the official Step 107 median
`63.2135219574` sec, and the difference is `5.496344x` the Step 107 three-run
range. Runs 02/03 are therefore skipped under the early-stop rule.

The signed-count batched SEPPOTF path is rejected. Its three source changes and
one-run helper are removed, restoring the negative-`NUMTY` guard and the
accepted Step 107 execution path in `d8ae16e`. The accepted gain remains
attributed to the bounded FRPRMN-to-ELECTF COEF residency change. Do not retry
this SEPPOTF batch shape for the tutorial input.

## Step 111 Plan

Add default-off timers only inside `nonlocf_kinetic_mpi`, which used
`0.799754` sec in Step 108. Split it into kinetic/current G-vector setup,
kinetic/current band reduction, its MPI exchange, A-vector G-vector setup,
A-vector band reduction, its MPI exchange, and YLM-radius setup. Do not change
equations, loop order, MPI calls, OpenACC ownership, or the diagnostic-off
path. The parent is only `1.265%` of the official Step 107 wall, so consider
an implementation only if one compute child owns a material majority. The
diagnostic wall cannot replace the performance baseline.

## Step 111 Result and Step 112 Plan

Step 111 at revision `2415d30` passed both checks. Its diagnostic wall was
`69.0858860016` sec and is not a baseline. The `nonlocf_kinetic_mpi` parent
used `0.814936` sec. The kinetic/current and A-vector band reductions used
`0.470508` and `0.287670` sec, totaling `0.758178` sec (`93.037%` of the
parent). Both MPI intervals totaled only `0.000745` sec. G-vector setup,
YLM-radius setup, and the unclassified gap were small.

Step 112 is one bounded performance hypothesis: while the existing
kinetic/current band loop already has `WFAC=|COEF|^2`, also accumulate the
A-vector energy from that same `WFAC` and G ordering. Remove the later second
full COEF traversal, but preserve the existing two MPI exchanges and all
downstream ordering. This changes no OpenACC ownership or allocation and has a
measured removable ceiling of about `0.287670` sec (`0.455%` of the official
Step 107 wall). Run diagnostic-off performance run 01 first.
Use the historical `run_tddft_step112.sh 01` helper (removed after rejection);
continue with `02-03` only after a
correct, promising first result. Rollback target: `4f4a276`.

## Step 112 Result and Rejection

Run 01 at revision `1aa31fd` passed both checks with diagnostics off but took
`63.6258358955` sec. This is `0.4123139381` sec (`0.652256%`) slower than the
official Step 107 median, and `3.986285x` the official run range. Runs 02/03
are skipped.

The pass fusion is rejected. The original two reductions and their timer
boundaries are restored, and the Step 112 helper is removed in `330bd1c`.
Together with the earlier rejected Step 84 energy-side pass fusion, this closes
the same COEF-pass fusion strategy for the tutorial input. The remaining large
tutorial intervals have already had their safe high-impact variants classified;
do not continue with low-ceiling micro-optimizations without a new production
input or new profiler evidence.

## Step 113 Compiler-Flag Screen Plan

Keep the accepted numerical source and all runtime conditions fixed. Rebuild
and run once each with the standard `-O2` flags, isolated `-O3`,
`-Mipa=fast,inline`, and GPU `fastmath`. The standard build runs first as a
same-session control; `fastmath`, which has the greatest numerical risk, runs
last. Each diagnostic-off run uses 1 A100, 1 MPI rank, and 100 steps and must
pass normal check and relaxed compare. Also report strict compare without
making it the existing correctness gate.

Use `tools/history/tddft_steps/run_tddft_step113_flags.sh`. Its compact table records exact
compiler/device provenance, walls, deltas from the same-session standard build,
and deltas from the official Step 107 median. This is one-run screening only.
Do not update the standard flags or baseline, and do not mix variants into a
median. Select at most one correct, clearly faster variant for a later
three-run gate.

## Step 113 Screen Result and Pairwise Check Plan

All four diagnostic-off A100 runs at revision `05fd3c4` passed normal check
and relaxed compare:

| variant | wall_sec | delta vs same-session `-O2` | percent | vs official Step 107 |
|---|---:|---:|---:|---:|
| standard `-O2` | 63.9245581627 | 0.0000000000 | 0.000000% | +1.124817% |
| `-O3` | 64.3075950146 | +0.3830368519 | +0.599201% | +1.730758% |
| `-Mipa=fast,inline` | 63.7906529903 | -0.1339051724 | -0.209474% | +0.912987% |
| GPU `fastmath` | 63.7448709011 | -0.1796872616 | -0.281093% | +0.840562% |

`-O3` is not a finalist. IPA and `fastmath` are modestly faster than the
same-session control, but `fastmath` is only `0.0457820892` sec (`0.071769%`)
faster than IPA. Every row reported strict FAIL because that check compared
each archive independently with the default GNU reference; even the unchanged
standard build failed, so it does not isolate option-induced numerical change.
The compiler line was blank because the first wrapper queried the MPI wrapper
with an unsupported version form; device provenance was NVIDIA
A100-PCIE-40GB with driver `595.45.04`.

Before selecting one three-run candidate, run
`tools/history/tddft_steps/report_tddft_step113_flags.sh`. It performs no build or simulation. It
compares O3, IPA, and `fastmath` directly with the same-session standard
archive under relaxed and strict tolerances, prints maximum observable
differences, and recovers compiler/MPI-driver provenance.

## Step 113 Pairwise Result and Disposition

The existing-archive report completed without rebuilding or rerunning. O3,
IPA, and `fastmath` each passed both relaxed and strict direct comparison with
the same-session standard archive. Maximum observable differences were
`0.000000e+00` for ETOT, total energy, force, position, and velocity in every
variant. The MPI driver identified `nvfortran` and the device remained NVIDIA
A100-PCIE-40GB with driver `595.45.04`; the compiler-version field was still
blank because `nvfortran -V` emitted a leading blank line, which the helper now
skips.

The numerical-risk check therefore does not exclude IPA or `fastmath`.
Nevertheless, neither is a clear performance finalist. The best screen result,
`fastmath`, improved only `0.1796872616` sec (`0.281093%`) over its
same-session standard run, led IPA by only `0.071769%`, and remained
`0.5313489437` sec (`0.840562%`) slower than the official Step 107 median.
This does not satisfy the documented condition for starting a separate
three-run adoption gate. Close the compiler-option screen without changing the
standard flags or official baseline.

## Step 114 NVHPC Memory-Mode Screen Plan

Keep the accepted numerical source and all non-memory compiler options fixed.
Run one same-session control with `-gpu=mem:separate:pinnedalloc`, then one run
each with `-gpu=mem:managed` and `-gpu=mem:unified`. Do not rerun unpinned
separate memory: Step 37 already established that pinned allocation improved
the Step 36 median by `4.4103%`.

The NVIDIA HPC Compilers User's Guide states that managed mode changes
dynamically allocated Fortran data to CUDA managed allocations, while unified
mode also permits global and local memory access. Unified mode on Linux x86-64
requires kernel HMM support, so a build or runtime failure is an
environment-support result rather than permission to weaken checks. Stop at
the first build, run, normal-check, or relaxed-compare failure.

Use `tools/history/tddft_steps/run_tddft_step114_memory_modes.sh`. It compiles and links every
TDDFT translation unit with exactly one memory mode, uses diagnostics off,
1 A100 / 1 MPI rank / 100 steps, unique archives, normal check, relaxed compare,
and a direct strict comparison against the same-session control. These are
one-run screening results only. The standard flags and official Step 107
baseline cannot change without a later isolated three-run gate.

## Step 114 Memory-Mode Result and Rejection

Step 114 ran all three diagnostic-off variants at revision `3fe68c1` on one
NVIDIA A100-PCIE-40GB, one MPI rank, and 100 steps:

| variant | wall_sec | delta vs control | percent vs control | percent vs official |
|---|---:|---:|---:|---:|
| `mem:separate:pinnedalloc` control | 63.9251468182 | 0.0000000000 | 0.000000% | +1.125748% |
| `mem:managed` | 130.1395111080 | +66.2143642898 | +103.581091% | +105.872900% |
| `mem:unified` | 130.4787569050 | +66.5536100868 | +104.111783% | +106.409567% |

Every variant passed normal check, relaxed compare, and direct pairwise strict
compare with the control. The alternatives are therefore correct for the
reported observables but both take slightly more than twice the control wall.
This exceeds the early-stop threshold by a wide margin, so no three-run gate is
justified. Reject managed and unified memory for this explicit-residency TDDFT
path, retain `-gpu=mem:separate:pinnedalloc`, and do not retry these whole-build
memory modes for the tutorial input without materially different ownership or
new hardware evidence.

The result is consistent with automatic page migration or host/device access
transitions overwhelming this path, but no profiler trace was collected, so
that mechanism remains an inference rather than a measured attribution.

## Step 115 Current-Source H100 cc90 Baseline Plan

Measure the latest accepted numerical path (`c46cfa9`, plus current
default-off validation/timer infrastructure) on H100 without changing the A100
baseline. Build TDDFT once with diagnostics off and the exact flags
`-O2 -acc -gpu=cc90 -mp -Msave -Mlarge_arrays -gpu=mem:separate:pinnedalloc`.
Then run the Si111-H 100-step case three times with 1 H100 and 1 MPI rank.

Use `tools/history/tddft_steps/run_tddft_step115_h100_baseline.sh`. It refuses to build on a device
whose reported name does not contain H100, records the exact model, driver,
compiler, kernel, revision, and flags, creates three unique archives, and
requires normal check plus relaxed compare for every run. Runs 02 and 03 also
receive a direct strict comparison with run 01 as a reproducibility signal.

The compact report prints the H100 median and range. It also prints the
same-source A100 Step 107 median ratio only as a cross-device observation.
Never mix H100 results into the A100 series. A correct three-run result is an
H100-only baseline candidate and still requires result review before adoption.

## Step 115 H100 cc90 Baseline Candidate Result

Step 115 ran the current accepted numerical path at revision
`e6ad059fc4ea65dda8ad19383ea32a5da37065ed` on an NVIDIA H100 PCIe:

| archive suffix | wall_sec | normal check | relaxed compare | run-01 pairwise strict |
|---|---:|---|---|---|
| `01` | 34.1089649200 | PASS | PASS | PASS |
| `02` | 34.1246850491 | PASS | PASS | PASS |
| `03` | 34.0341229439 | PASS | PASS | PASS |

- H100 median: `34.1089649200` sec
- H100 range: `0.0905621052` sec
- A100 Step 107 median: `63.2135219574` sec
- A100/H100 median ratio: `1.853282x`
- H100 wall reduction versus A100: `46.041663%`
- Compiler: `nvfortran 26.5-0`, x86-64 Linux, `-tp sapphirerapids`
- Device/driver: NVIDIA H100 PCIe, `595.45.04`
- Kernel: `6.12.0-124.8.1.el10_1.x86_64`
- Flags: `-O2 -acc -gpu=cc90 -mp -Msave -Mlarge_arrays -gpu=mem:separate:pinnedalloc`

The three-run result satisfies the H100 correctness, reproducibility, and
measurement gates. The user explicitly approved it on 2026-07-30 as the
H100-only formal baseline. The A100 Step 107 baseline remains independent and
unchanged.

## x86 Intel 16-rank CPU/FFTW Baseline Result

The independent CPU/FFTW baseline ran at revision
`5dd9962825fdb47bd09b4caafbc72c1c6782dc80` on an Intel Xeon 6980P using
ifx 2026.1.0 (20260617), Intel MPI 2021.18.0 build 20260327, Linux
`5.14.0-427.13.1.el9_4.x86_64`, 16 MPI ranks, one OpenMP thread per rank,
diagnostics off, and the Si111-H 100-step input. Existing FFTW, CG, SD, and
TDDFT build artifacts were reused.

| archive suffix | wall_sec | normal check | x86 relaxed compare | run-01 pairwise strict |
|---|---:|---|---|---|
| `01` | 29.3516199589 | PASS | PASS | SELF |
| `02` | 29.2610769272 | PASS | PASS | PASS |
| `03` | 29.4401659966 | PASS | PASS | PASS |

The x86-only cross-toolchain tolerances were energy `1e-4` Hartree, force
`2e-4` Hartree/Bohr, position `2e-6` Bohr, and velocity `1e-6`. The wider
force and position bounds do not alter the global comparator or GPU gates.
The median is `29.3516199589` sec and the corrected range is
`0.1790890694` sec. The photographed terminal report's `0.0017908907` range
was a report-only Fortran D-exponent parsing error; `e27071e` corrects future
summaries without requiring a rerun. The user explicitly approved the result
on 2026-07-30 as the x86-only formal baseline. Keep it independent of the
A100 and H100 series.

## x86 MPI x OpenMP Sweep Plan

Screen 4/8/16/32 MPI ranks against 2/4/8/16 OpenMP threads with
`tools/run_tddft_x86_mpi_omp_sweep.sh`. The host has 256 cores, so the
default `MAX_TOTAL_THREADS=256` excludes only 32 MPI x 16 OpenMP and measures
the remaining 15 configurations. The helper reuses the existing ifx/mpiifx
CPU/FFTW executables and does not compile. CG and SD stay at one OpenMP
thread; only TDDFT receives the requested thread count. Intel MPI process
domains and Intel OpenMP compact affinity are recorded with every run.

The default is one diagnostic-off run per configuration. Every run must pass
the normal result check and the x86 relaxed comparison. This first pass is a
screening experiment, not a baseline replacement. After reviewing its ranked
summary, measure only the fastest valid candidate three times and apply the
usual median, range, and run-01 pairwise strict gates before considering any
x86 baseline change.

## x86 MPI x OpenMP Sweep and Baseline Adoption

The diagnostic-off screen ran at revision
`7318e5932fdd7652d24f9e620e97a0ae3f692118` on an Intel Xeon 6980P with 256
logical and physical CPUs, ifx/mpiifx 2026.1.0, and Intel MPI 2021.18.0.
Existing FFTW, CG, SD, and TDDFT binaries were reused. The 32 MPI x 16 OpenMP
configuration was skipped because its 512 threads exceeded the 256-thread
limit. All 15 measured configurations passed normal check and the x86 relaxed
comparison.

| MPI ranks | OpenMP threads | total threads | one-run wall_sec |
|---:|---:|---:|---:|
| 32 | 8 | 256 | 16.5198910236 |
| 32 | 4 | 128 | 18.4249420166 |
| 32 | 2 | 64 | 19.9668469429 |
| 16 | 16 | 256 | 25.5983669758 |
| 16 | 4 | 64 | 27.2874531746 |
| 16 | 2 | 32 | 27.4257948399 |
| 16 | 8 | 128 | 27.4343221188 |
| 8 | 4 | 32 | 42.6165969372 |
| 8 | 8 | 64 | 44.8872098923 |
| 8 | 16 | 128 | 46.1903281212 |
| 8 | 2 | 16 | 47.2195591927 |
| 4 | 8 | 32 | 75.0795350075 |
| 4 | 4 | 16 | 78.1278450489 |
| 4 | 16 | 64 | 81.5396590233 |
| 4 | 2 | 8 | 88.7375349998 |

The fastest valid configuration, 32 MPI x 8 OpenMP, was then measured in a
fresh three-run series. All runs passed normal check and the x86 relaxed
comparison; runs 02/03 passed direct strict comparison with run 01. Its median
was `16.5392820835` sec and its range was `0.0579471588` sec. Relative to
the former 16 MPI x 1 OpenMP median of `29.3516199589` sec, this reduces wall
by `12.8123378754` sec (`43.651212%`) and gives a `1.774661x` wall ratio.
The user explicitly approved it on 2026-07-31 as the new x86-only formal
baseline. Keep the former baseline as historical scaling evidence and do not
mix either CPU result with the A100 or H100 series.

## x86 Intel MPI Affinity Screen Plan

The 256-core host exposes six NUMA nodes, each containing 42 or 43 CPUs. The
distance matrix is consistent with three NUMA nodes per 128-core socket. Since
an eight-thread MPI domain does not divide a 42/43-core NUMA node evenly,
rank-domain ordering may affect locality and communication even though all
256 cores are used.

Run `tools/run_tddft_x86_affinity_screen.sh` once. It keeps the accepted
32 MPI x 8 OpenMP configuration, binaries, input, tolerances, diagnostics-off
state, `I_MPI_PIN_DOMAIN=omp`, and compact OpenMP-thread affinity fixed. It
compares Intel MPI `I_MPI_PIN_ORDER=compact`, `scatter`, and `spread`, using
compact as the same-session control. Every variant must pass normal check and
the x86 relaxed comparison; scatter and spread must also pass direct strict
comparison with the compact control. This screen does not compile and cannot
change the formal x86 baseline. Only a clearly faster valid order may proceed
to a separate three-run adoption gate.

## x86 Intel MPI Affinity Screen Result and Rejection

The screen ran at revision
`cd36890576745ee9574f7ac366fde570de35c96e`. The compact control completed,
then the scatter variant completed 100 TDDFT steps in `78.1684319973` sec.
Its stderr contained 10 Intel MPI/Hydra IPL2
`algorithms_create_order_distribute_bitmaps` errors reporting that the domain
size was ignored. The normal check therefore failed on suspicious log lines.
The scatter relaxed comparison and compact-pairwise strict comparison were not
run, and the helper correctly stopped before spread.

Scatter is rejected for both execution-health and performance reasons. Its
wall is `61.6291499138` sec (`372.622884%`) slower than the formal compact
median, a `4.726229x` wall ratio. Do not weaken the stderr gate or rerun this
placement form. Spread remains untested rather than rejected numerically, but
is closed with this screen because it uses the same domain-ordering family on
the uneven six-NUMA topology. Keep the accepted compact x86 baseline
unchanged. The completed helper is archived under `tools/history/x86/`.

## Step 80 H100 Exploratory Run

- Archive label: `nvhpc_cufft_1rank_02_STEP80_H100_TEST`
- Reported source: Step 80
- Device class: NVIDIA H100 (exact model not yet recorded)
- Wall: `36.492636919` sec
- Correctness: check PASS; relaxed compare PASS
- Difference from the A100 Step 80 median: `-30.928125143` sec
- Relative wall reduction: `45.873295%`
- A100-median/H100-run ratio: `1.847517x`

This is a useful cross-device observation, not a formal H100 baseline. It is
one run, and the photograph does not establish the exact H100 model, Git
revision, compiler version, or whether the binary was compiled for `cc90`.
Do not mix it into the A100 three-run series or change the A100 baseline.

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
and their three nesting gaps. Run `tools/history/tddft_steps/run_tddft_step76.sh` once. Its wall is
diagnostic and cannot replace the Step 74 baseline.

## Step 116 Current-Source NSYS and NCU Plan

The user approved a fresh profiler measurement on 2026-08-04 to replace the
old Step 91 Nsight Systems evidence and the Step 39 fused-kernel launch-shape
evidence in the presentation. This is diagnostic-only and changes no numerical
source, equations, loop ordering, MPI behavior, or OpenACC ownership.

Run `tools/run_tddft_step116_current_profiles.sh` independently on A100 with
`TARGET_GPU=A100` and on H100 with `TARGET_GPU=H100`. The helper requires a
clean synchronized `tddft-openacc-residency` checkout, validates the selected
device class, and builds the TDDFT executable exactly once with the accepted
cc80 or cc90 OpenACC/cuFFT pinned configuration. Each environment then reuses
its executable for:

1. a 100-step Nsight Systems trace reporting current kernels, H2D/D2H,
   CUDA/OpenACC API, synchronization, allocation, and MPI rows; and
2. a 100-step Nsight Compute run capturing one
   `exnlp_gemm_body_fused` launch with the full metric set, including grid,
   block, register, occupancy, waves/SM, duration, and throughput data.

Both application runs must pass the normal check and relaxed comparison with
exactly 100 completed steps. Default archive labels include `STEP116_A100` or
`STEP116_H100` plus the two-digit `PROFILE_RUN`, and therefore cannot mix the
platform series or overwrite an earlier attempt. Run `PROFILE_PHASE=nsys`
under the normal user, switch to root with `su`, and run the matching
`PROFILE_PHASE=ncu`; that phase requires `BUILD_MODE=never` and reuses the
already-built executable and NSYS archive. Stop on a device
mismatch, build, profiler, correctness, archive-collision, revision, active-GPU,
or GPU-health error. Neither profiler wall is a performance baseline. Do not
choose a new optimization hypothesis or update the PowerPoint profile values
until both compact Step 116 terminal blocks have been reviewed.

## Step 116 A100 Current-Source NSYS and NCU Result

The A100 measurement completed on 2026-08-04 at revision
`9e67ad0a14d63cee2ec0ceeea5d29b98d9a15105` with accepted numerical source
`c46cfa9`. The separate cc80 archives are
`nvhpc_cufft_1rank_02_STEP116_A100_CURRENT_NSYS_03` and
`nvhpc_cufft_1rank_02_STEP116_A100_FUSED_NCU_03`. Both 100-step application
runs passed the normal check and relaxed comparison. The Nsight Systems trace
wall was `66.9540450573` sec; it includes profiler overhead and is not a
performance baseline.

The Nsight Systems kernel summary attributed `8.253502447` sec (`61.1%`,
9,440 launches) to `exnlp_gemm_body_fused_2531_gpu` and `1.565169961` sec
(`11.6%`, 2,000 launches) to `vpj_gen_acc_integral_429_gpu`. H2D traffic was
45,670 copies / `28,509.031` MB / `2.497391517` sec, and D2H traffic was
7,961 copies / `6,036.959` MB / `0.483328602` sec. The displayed CUDA API
summary contained `15.204177276` sec in 138,810 `cuStreamSynchronize` calls
and `1.691766443` sec in 14,685 `cudaEventSynchronize` calls. These API totals
are inclusive diagnostic attribution and must not be added directly to wall
time or treated as wholly removable synchronization cost.

The selected Nsight Compute fused-kernel launch used 32 blocks of 256 threads
(8,192 GPU threads), 63 registers/thread, and `0.07` waves/SM. Its duration
was `914.69` us; theoretical occupancy was `50%`, achieved occupancy was
`12.50%`, Compute (SM) Throughput was `4.28%`, Memory Throughput was `16.37%`,
and DRAM Throughput was `0.45%`. This reproduces the essential Step 39 launch
shape and occupancy on current source. The 32-block tutorial grid is smaller
than the A100's 108 SMs, so this input cannot expose enough block-level
parallelism to fill the GPU. It is current diagnostic evidence for the
presentation, not a reason to alter the official Step 107 A100 baseline or to
resume tutorial-only micro-tuning. The matching H100 Step 116 measurement
remains pending.

## Step 116 H100 Current-Source NSYS and NCU Result

The H100 measurement completed on 2026-08-04 at revision
`ac71452795e83a0c895ade1b9169e34eeb155916` with accepted numerical source
`c46cfa9`. The separate cc90 archives are
`nvhpc_cufft_1rank_02_STEP116_H100_CURRENT_NSYS_01` and
`nvhpc_cufft_1rank_02_STEP116_H100_FUSED_NCU_01`. Both 100-step application
runs passed the normal check and relaxed comparison. The Nsight Systems trace
wall was `36.1572990417` sec; it includes profiler overhead and is not a
performance baseline.

The Nsight Systems kernel summary attributed `3.184705006` sec (`57.9%`,
9,440 launches) to `exnlp_gemm_body_fused_2531_gpu` and `0.718420095` sec
(`13.1%`, 2,000 launches) to `vpj_gen_acc_integral_429_gpu`. H2D traffic was
45,670 copies / `28,509.031` MB / `0.693232871` sec, and D2H traffic was
7,961 copies / `6,036.959` MB / `0.124451121` sec. The displayed CUDA API
summary contained `5.894474225` sec in 138,810 `cuStreamSynchronize` calls and
`0.684168928` sec in 14,685 `cudaEventSynchronize` calls. As with A100, these
are inclusive diagnostic totals and not directly additive wall-time savings.

The selected Nsight Compute fused-kernel launch used 32 blocks of 256 threads
(8,192 GPU threads), 72 registers/thread, and `0.09` waves/SM. Its duration
was `355.78` us; theoretical occupancy was `37.50%`, achieved occupancy was
`12.50%`, Compute (SM) Throughput was `4.54%`, Memory Throughput was `16.45%`,
and DRAM Throughput was `0.88%`. Relative to the A100 Step 116 capture, the
fused-kernel aggregate time is about `2.59x` shorter and the selected launch is
about `2.57x` shorter, but both devices retain the same 32-block grid and
`12.50%` achieved occupancy. The current tutorial therefore remains limited
by input-scale parallel width even on H100. This completes the requested
current-source profiler refresh without changing either formal GPU baseline.

## Step 116 Non-cuFFT Launch-Shape Post-processing

`tools/report_tddft_nsys_openacc_launches.sh` and its SQLite parser report the
actual launch shape of every NVHPC OpenACC kernel already captured in a Step
116 Nsight Systems archive. The helper reads `CUPTI_ACTIVITY_KIND_KERNEL`,
groups by short kernel name, Grid, Block, and registers/thread, and calculates
threads/launch and launch counts. It includes only NVHPC `_gpu` kernels, so
cuFFT library kernels are excluded even when their names do not contain the
literal string `cufft`. If the archive's SQLite export is absent, the helper
creates it from the existing `.nsys-rep`; it never builds or executes TDDFT.
Run it once against each independent A100 and H100 NSYS archive and return the
two compact terminal blocks. These results refine the presentation's kernel
parallelism table but are diagnostic and cannot alter either formal baseline.

Both reports completed on 2026-08-04. All 24 non-cuFFT OpenACC launch
configurations used identical Grid, Block, threads/launch, and launch counts on
A100 and H100. The dominant fused kernel used 32 blocks x 256 threads (8,192
threads/launch), VPJ used 42 x 128 (5,376), and three additional S2 kernels
used 32 x 128 (4,096). Other kernels were not uniformly narrow: observed grids
included 196, 227, 7,257, and 14,513 blocks. The complete platform table is in
`docs/STEP116_OPENACC_LAUNCH_SHAPES.md`.

The result narrows the diagnosis. Low grid width is important in the kernels
that dominate current non-cuFFT GPU time, especially fused EXNLP and VPJ, but
is not a property of every OpenACC kernel. Threads/launch is a launch geometry
count, not simultaneous residency or useful-work count. This post-processing
changes no source and neither diagnostic timing changes the A100 Step 107 or
H100 Step 115 formal baseline.

## Step 117 Common CPU/GPU Timer Implementation

The timer implementation is consolidated in `mod_timer.f90`; the separate
`prof_timer.f` source is removed. Every fixed-form call site directly supplies
its region name through `start_timer('region')` and `stop_timer('region')`.
The predefined numeric-ID table and all `prof_*` timing entry points are
removed. CPU/FFTW and GPU/cuFFT retain the same logical call locations, while
the `112+L` diagnostic timer is expressed as four explicit named regions.

The timer core restores the original dynamic name registration,
`system_clock` measurement, call counts, and `[Timer Output]` table. Its
report also retains the MPI-aggregated `FPSEID_PROFILE` block required by the
standard correctness and performance helpers; the displayed row number is
only the dynamic registration order, not a timer API identifier. The cuFFT C
wrapper's separate CUDA-event `FPSEID_CUFFT_PROFILE` remains available for
GPU-only transfer and cuFFT decomposition. This changes no equation, loop
order, MPI collective in the numerical path, OpenACC ownership, or numerical
result.

Local validation on 2026-08-04 passed the full GNU MPI CPU/FFTW link with
diagnostics both off and on. A two-rank standalone MPI test verified direct
name lookup,
the original table, and the aggregated compatibility block for
`time_step_total`, `frprmn_rhoofk`, `frprmn_coef_sync`, and
`nonlocf_ylm_radius`. Static checks found matching start/stop names and
identical timer-call sequences in both PSPW variants and both LIB4 variants.
No A100, H100, or official x86 performance run has been performed for this
implementation; all three formal baselines remain unchanged and independent.

## Step 118: Dedicated 32 MPI x 8 OpenMP x86 Runner

Added `tools/run_tddft_x86_32mpi_8omp.sh` as the single-command runner for the
accepted x86 configuration. It fixes the Intel toolchain, 32 MPI ranks, 8
TDDFT OpenMP threads, one CG/SD OpenMP thread, and the accepted compact Intel
MPI/OpenMP binding. It delegates building, three-run archiving, normal check,
x86 relaxed comparison, run-to-run strict comparison, and median reporting to
the existing x86 baseline runner.

The baseline runner now accepts a positive TDDFT OpenMP thread count, records
the effective binding in each archive and terminal summary, and continues to
default to its historical 16 MPI x 1 OpenMP reference configuration. No x86,
A100, or H100 execution was performed while adding this workflow helper, so
all formal baseline timings remain unchanged.

## Step 119: Hierarchical Timer Call-Path Output

Changed only the common `mod_timer.f90` reporting/accounting layer. At each
`start_timer('name')`, the timer records the currently active parent and
accumulates a separate display node for each `(parent path, name)` pair. The
`[Timer Output]` table walks those nodes depth-first and indents child regions.
Elapsed values remain inclusive. When a shared region such as `fft_wrapper`
is called from multiple parents, it appears below each parent with the count
and elapsed time for that path instead of being assigned to whichever parent
registered the name first.

The existing name table remains authoritative for `FPSEID_PROFILE`: all paths
with the same region name are summed into one MPI-aggregated row with the same
label and total count. Existing checkers and history report scripts therefore
retain their input format. Direct `start_timer('region')` and
`stop_timer('region')` call sites are unchanged.

Local validation on 2026-08-05 passed full GNU MPI CPU/FFTW links with
diagnostics both off and on. A two-rank standalone MPI probe verified nested
depth-first output, the same region under two different parents, and one
aggregated `FPSEID_PROFILE` row for that shared name. No official x86, A100,
or H100 run has been performed, so all three formal platform baselines remain
unchanged.

The controlled x86 validation then completed at full revision
`87045133f0685b95c0943488e6953e0c8deb1936` on the Intel Xeon 6980P with ifx
2026.1.0, Intel MPI 2021.18.0, 32 MPI x 8 OpenMP, compact binding, and
diagnostics off. FFTW, CG, and SD were reused; TDDFT was rebuilt. The dedicated
runner reached its final summary, which is emitted only after all three normal
checks, x86 relaxed comparisons, and run-01 pairwise strict comparisons pass.

| archive label | wall_sec | normal | relaxed | run-01 strict |
|---|---:|---|---|---|
| `x86_fftw_32mpi_8omp_intel_20260805_133214_87045133f068_01` | 16.4435307980 | PASS | PASS | SELF |
| `x86_fftw_32mpi_8omp_intel_20260805_133214_87045133f068_02` | 16.4973180294 | PASS | PASS | PASS |
| `x86_fftw_32mpi_8omp_intel_20260805_133214_87045133f068_03` | 16.4935860634 | PASS | PASS | PASS |

The median is `16.4935860634` sec and the range is `0.0537872314` sec. This is
`0.0456960201` sec (`0.276288%`) faster than the existing official x86 median
of `16.5392820835` sec and therefore shows no timer-reporting regression. The
returned timer tree correctly nested `time_step_total`, `frprmn`, `tmevl_total`,
and S2 children. Shared `fft_wrapper` contexts summed to the previous flat
count of 13,155: startup 3, direct FRPRMN 1,748, two 78-call and two 8-call
HLOCAL FFT paths, TMEVL S2 9,360, RHOOFK 936, and RHOGET 936.

This completes x86 correctness and timer-tree validation. The small wall
difference is not treated as a new optimization result, and the official x86
baseline is unchanged pending an explicit human adoption decision. No A100 or
H100 Step 119 validation has been performed.

The complete set of timer values visible in the returned x86 timer-tree
photograph is transcribed in `docs/STEP119_X86_TIMER_TREE.md`, together with
the execution provenance and three-run wall summary. The photograph does not
show the archive label alongside the timer table, so the sample is deliberately
not assigned to run 01, 02, or 03.

For the independent GPU timer-tree validations, use
`tools/run_tddft_step119_gpu_timer_tree.sh` with an explicit `A100` or `H100`
argument on the matching host. The helper rejects the wrong device, fixes
cc80 or cc90 with pinned separate memory, rebuilds TDDFT only, executes one
diagnostic-off 100-step run at 1 GPU / 1 MPI / 1 OpenMP, archives it, requires
normal and relaxed checks, and prints the tree plus compact provenance. These
are one-run instrumentation validations and cannot replace a formal baseline.

Both GPU runs completed on 2026-08-05 at revision
`24ae7127805ce4da63078c31bbd91e3456e84b44`. The A100-PCIE-40GB cc80 archive
`nvhpc_cufft_1rank_02_STEP119_A100_TIMER_TREE_20260805_135009_24ae7127805c_01`
passed both checks at `63.9410018921` sec. The H100 PCIe cc90 archive
`nvhpc_cufft_1rank_02_STEP119_H100_TIMER_TREE_20260805_135328_24ae7127805c_01`
passed both checks at `34.0914211273` sec. Both used driver 595.45.04, pinned
separate memory, 1 GPU / 1 MPI / 1 OpenMP, and diagnostics off.

The trees had identical paths and call counts on both platforms. Each reported
140,957 inclusive region calls and 14,685 `fft_wrapper` calls. The dominant
A100/H100 inclusive ratios were `2.653x` for `s2_nonlocal_gemm`, `2.567x` for
`exnlp_gemm_dot`, and `2.382x` for `s2_nonlocal`. Full transcribed values and
provenance are in `docs/STEP119_GPU_TIMER_TREES.md`. These single-run
instrumentation walls do not alter the formal A100 or H100 baseline.

## Step 120: Dual-Socket 8468 and 8592+ MPI/OpenMP Screen Helper

Added `tools/run_tddft_x86_8468_8592_sweep.sh` for the two user-operated CPU
hosts selected for comparison with H100. It accepts only a dual-socket Xeon
Platinum 8468 with 96 physical cores or a dual-socket Xeon Platinum 8592+ with
128 physical cores. Auto-detection and topology checks stop before execution
when the model, socket count, or physical-core count does not match.

The default 8468 configurations are `32 MPI x 3 OpenMP`, `16 x 6`, `8 x 12`,
and `4 x 24`, all totaling 96 physical threads. The default 8592+
configurations are `32 x 4`, `16 x 8`, `8 x 16`, and `4 x 32`, all totaling
128 physical threads. This keeps the TDDFT MPI rank count at or below 32 while
screening four rank/thread decompositions at full physical-core occupancy.

The general sweep helper now accepts explicit paired configurations through
`CONFIGS="<MPI>x<OMP> ..."` in addition to its existing Cartesian grid. The
x86 baseline helper adds `BUILD_ONLY=1`, allowing the new wrapper to build or
safely reuse Intel/FFTW, CG, SD, and TDDFT once without consuming an extra
measurement. The screen defaults to one run per configuration; a selected set
can be repeated with `RUNS_PER_CONFIG=3`. Every run retains the normal check,
x86 relaxed comparison, archive provenance, and run-01 strict comparison for
runs 02/03.

No 8468, 8592+, 6980P, A100, or H100 execution was performed while adding the
helper. Each CPU model will have its own independent measurement series, and
no formal baseline is changed by this implementation.

### Step 120 follow-up: reject stale executable reuse

The first user-operated 8468 attempt spent abnormal time in the initial TDDFT
launch. The branch and revision were correct, but forcing an Intel/FFTW rebuild
allowed execution to progress. This exposed a build-cache integrity gap: the
previous stamp checked tracked build inputs and compiler identities but did
not verify that the executable had not subsequently been overwritten by a
different build path in the shared source tree.

The x86 baseline helper now stores a `git hash-object` fingerprint of each CG,
SD, and TDDFT executable as the second stamp line. `BUILD_MODE=auto` requires
both the existing input signature and current artifact fingerprint to match;
old one-line stamps or externally replaced binaries trigger a rebuild.
`BUILD_MODE=never` retains its explicit adoption behavior and records the
fingerprint for subsequent safe reuse. The interrupted 8468 attempt is not
archived or treated as performance evidence, and no baseline changes.

### Step 120 8468 one-run screen result

After the forced Intel/FFTW rebuild, the dual-socket Xeon Platinum 8468 screen
completed at revision `013845d3227f24cdfbe3e3d525a24ff239e754c2`. The host
reported 96 logical CPUs and 96 physical cores. All four diagnostic-off runs
passed the normal check and x86 relaxed comparison.

| MPI x OpenMP | total threads | wall_sec |
|---|---:|---:|
| 32 x 3 | 96 | 21.0896489620 |
| 16 x 6 | 96 | 29.4878950119 |
| 8 x 12 | 96 | 49.3604290485 |
| 4 x 24 | 96 | 88.6823518276 |

The screen selects 32 x 3 unambiguously. Its one-run wall is `38.1698%`
shorter than the formal H100 median but is not yet an 8468 baseline. Run the
candidate three times and require normal, relaxed, and run-01 strict checks
before using its median. Archive labels were outside the returned photograph
and are not inferred. Full recorded evidence is in
`docs/STEP120_XEON_GENERATION_SWEEPS.md`.

### Step 120 8468 controlled candidate result

The selected 32 MPI x 3 OpenMP configuration completed three diagnostic-off
runs at revision `094ebd1f421d1cb181aa404b28eb28edd350bbd9`. The final helper
summary is emitted only after every normal and x86 relaxed comparison passes
and runs 02/03 pass strict comparison against run 01.

- Median: `20.5968229771` sec
- Range: `0.0558128357` sec
- Total physical threads: 96
- H100 formal median difference: `13.5121419429` sec (`39.6146%` faster)
- 6980P formal median difference: `4.0575408936` sec (`24.5328%` slower)

The targeted `runs.tsv` return then supplied the complete individual series:

| run | wall_sec | normal | relaxed | run-01 strict | archive suffix |
|---:|---:|---|---|---|---|
| 01 | 20.5968229771 | PASS | PASS | SELF | `32mpi_3omp_01` |
| 02 | 20.6482338905 | PASS | PASS | PASS | `32mpi_3omp_02` |
| 03 | 20.5924210548 | PASS | PASS | PASS | `32mpi_3omp_03` |

The full common archive prefix is
`x86_mpi_omp_20260805_151026_094ebd1f421d_`. Sorting these walls exactly
reproduces median `20.5968229771` sec and range `0.0558128357` sec. The
controlled result was complete as an 8468 baseline candidate. The user then
explicitly approved adoption on 2026-08-05. The official independent Xeon 8468
baseline is therefore median `20.5968229771` sec and range `0.0558128357` sec
at 32 MPI x 3 OpenMP. The Xeon 6980P, A100, and H100 formal baselines remain
independent and unchanged.

### Step 120 8468 timer-tree preservation

The returned formal-series 8468 photograph contains the complete hierarchical
rank-0 timer tree. It is transcribed without assigning it to run 01, 02, or 03
because the archive label is not visible beside the table. The principal
inclusive values are `time_step_total=20.620`, `frprmn=19.869`,
`tmevl_total=13.234`, `tmevl_s2=10.270`, `s2_nonlocal=6.746`,
`s2_nonlocal_gemm=5.059`, `s2_fft_local=3.513`, and
`electf_force=0.698` sec. Total inclusive regions are 138,879 calls and
`101.678` sec. The 13,155 displayed `fft_wrapper` calls sum to `2.576` sec at
the photographed precision. Complete paths, counts, and values are in
`docs/STEP120_XEON_GENERATION_SWEEPS.md`.

### Step 120 8592+ pre-screen GLIBC failure

The first dual-socket Xeon Platinum 8592+ attempt returned to the prompt during
the initial CG phase, before any MPI/OpenMP screen configuration ran. The
returned `Si111-H.err` showed that the reused `cg_exe` required the unavailable
symbol version `GLIBC_2.34`. This is a cross-host executable compatibility
failure and supplies no 8592+ performance value.

The x86 build cache now includes the execution-host runtime identity in the
FFTW, CG, SD, and TDDFT signatures. CG, SD, and TDDFT also pass an `ldd`
dependency check before reuse and after build; missing libraries or unavailable
symbol versions force an `auto` rebuild or stop `BUILD_MODE=never`. The safe
8592+ recovery is a complete local `BUILD_MODE=always` rebuild followed by the
unchanged one-run configuration screen. No platform baseline changes.

### Step 120 8592+ one-run screen result

After the complete local Intel/FFTW rebuild, the dual-socket Xeon Platinum
8592+ screen completed at revision
`1e3762587ede0b92cc3791446cf092ef79b15ca5`. The host reported 128 logical
CPUs and 128 physical cores. All four diagnostic-off runs passed the normal
check and x86 relaxed comparison.

| MPI x OpenMP | total threads | wall_sec |
|---|---:|---:|
| 32 x 4 | 128 | 19.6031851768 |
| 16 x 8 | 128 | 28.6397459507 |
| 8 x 16 | 128 | 49.3092470169 |
| 4 x 32 | 128 | 90.9068999290 |

The screen selects 32 x 4 unambiguously. Its one-run wall is `42.5278%`
shorter than the formal H100 median, `4.8242%` shorter than the formal 8468
median, and `18.5250%` longer than the formal 6980P median. It is not an 8592+
baseline: the selected configuration still requires three equivalent runs,
normal and relaxed checks for each, strict comparison of runs 02/03 against
run 01, and explicit user adoption. Archive labels were not visible in the
returned photograph and are not inferred. No formal baseline changes.

### Step 120 8592+ additional one-run candidate sample

A targeted 32 MPI x 4 OpenMP run at the same revision subsequently completed
at `19.5182418823` sec with normal and x86 relaxed comparisons passing. The
terminal summary explicitly showed `runs_per_config=1` and range `0`, so the
requested controlled three-run measurement did not occur. This value is saved
as a separate one-run sample only. It is `0.0849432945` sec (`0.4333%`)
shorter than the initial 32 x 4 screen value, but the two independently
launched samples cannot substitute for the helper's three-run median, range,
and run-01 strict checks. No baseline changes.

### Step 120 8592+ controlled candidate result

The selected 32 MPI x 4 OpenMP configuration completed three diagnostic-off
runs in one invocation at revision
`fa6d80a21d247d4fa0360c5cb585aeac29fe861b`. The terminal reported
`runs_per_config=3`, median `19.5947289467` sec, and range `0.0526847839` sec.
The final helper summary is emitted only after all three normal and x86 relaxed
checks pass and runs 02/03 pass strict comparison against run 01.

- H100 formal median difference: `14.5142359733` sec (`42.5526%` faster)
- 8468 formal median difference: `1.0020940304` sec (`4.8653%` faster)
- 6980P formal median difference: `3.0554468632` sec (`18.4739%` slower)
- Three-run range relative to median: `0.2689%`

The targeted `runs.tsv` return supplied the individual series:

| run | wall_sec | normal | relaxed | run-01 strict |
|---:|---:|---|---|---|
| 01 | 19.5947289467 | PASS | PASS | SELF |
| 02 | 19.5884881020 | PASS | PASS | PASS |
| 03 | 19.6411728859 | PASS | PASS | PASS |

Sorting these walls exactly reproduces the reported median and range. The
visible results-directory suffix is
`x86_mpi_omp_20260805_160921_fa6d80a21d24`; full archive-label endings are
cropped from the photograph and are not inferred. The user explicitly approved
adoption on 2026-08-05. The official independent Xeon 8592+ baseline is
therefore median `19.5947289467` sec and range `0.0526847839` sec at 32 MPI x
4 OpenMP. The Xeon 8468, Xeon 6980P, A100, and H100 formal baselines remain
independent and unchanged.

### Step 120 8592+ timer-tree preservation

The returned formal-series 8592+ photograph contains the complete hierarchical
rank-0 timer tree. It is transcribed without assigning it to run 01, 02, or 03
because the archive label is not visible beside the table. The principal
inclusive values are `time_step_total=19.669`, `frprmn=18.923`,
`tmevl_total=12.527`, `tmevl_s2=9.388`, `s2_nonlocal=6.275`,
`s2_nonlocal_gemm=4.963`, `s2_fft_local=3.100`, and
`electf_force=0.699` sec. Total inclusive regions are 138,879 calls and
`95.957` sec. The 13,155 displayed `fft_wrapper` calls sum to `2.237` sec at
the photographed precision. Complete paths, counts, and values are in
`docs/STEP120_XEON_GENERATION_SWEEPS.md`.

### Step 120 PowerPoint update

Created `docs/FPSEID21_TDDFT_GPU_PROGRESS_2026-08-05_STEP120_X86.pptx` as a
new editable deck while preserving the Step 116 source deck. The formal
baseline table now contains the five independent A100, H100, Xeon 6980P,
Xeon 8468, and Xeon 8592+ series. Two slides were added: the full-core
MPI/OpenMP screens for 8468 and 8592+, and a rank-0 inclusive timer comparison
for 6980P, 8468, and 8592+. The latter shows that 8592+ improves the 8468
`time_step_total` sample by about 4.6%, while the remaining gap to 6980P is
concentrated in `tmevl_s2` and `s2_fft_local`. These timer samples remain
instrumentation observations and do not replace any formal wall-time baseline.

### Step 120 PowerPoint code mapping

Created `docs/FPSEID21_TDDFT_GPU_PROGRESS_2026-08-05_STEP120_X86_CODEMAP.pptx`
as a new copy, preserving both earlier PowerPoint files. Implementation
references were added directly to explanatory slides 4, 5, 7-10, 24, and 25.
Slide 17 now provides a page-to-source index with the concrete change in each
file, while slides 18-21 identify the source file or routine for every code
excerpt. This is a documentation-only update; no numerical source or baseline
was changed.

### Step 120 PowerPoint direct source excerpts

- Scope: documentation only; no build or execution.
- Input deck:
  `docs/FPSEID21_TDDFT_GPU_PROGRESS_2026-08-05_STEP120_X86_CODEMAP.pptx`.
- Output deck:
  `docs/FPSEID21_TDDFT_GPU_PROGRESS_2026-08-05_STEP120_X86_CODE_EXCERPTS.pptx`.
- Slides 7-10 now contain accepted-source excerpts instead of only abbreviated
  file references.
- The excerpts cover `fft_cufft.f`, `tmevl10_Avec_v4.f`,
  `frprmn_tm12_check_Vext_Avec_v4.f`, and
  `pspw_tm11_Vext_Avec_v4_alloc.f`.
- Existing diagrams, performance values, the code mapping index, the x86
  sweep, and the timer-tree comparison are preserved.
- PowerPoint overflow and template-fidelity checks passed for all 25 slides.
- Numerical source and all platform baselines are unchanged.

### Step 120 PowerPoint before/after code comparison

- Scope: documentation only; no build or execution.
- Input deck:
  `docs/FPSEID21_TDDFT_GPU_PROGRESS_2026-08-05_STEP120_X86_CODE_EXCERPTS.pptx`.
- Output deck:
  `docs/FPSEID21_TDDFT_GPU_PROGRESS_2026-08-06_STEP120_X86_BEFORE_AFTER.pptx`.
- Slides 7-10 and 18-21 now compare the Git-derived before source with the
  accepted after source.
- Orange identifies lines deleted or replaced from the before path; blue
  identifies lines added or adopted in the after path.
- The comparison is based on commits `8744981`, `bad046f`, `35835ea`,
  `1b98197`, `2b7f5ba`, and `4aaa33c`, plus the current accepted source.
- Existing performance values, charts, x86 comparisons, and timer trees are
  unchanged.
- PowerPoint overflow and template-fidelity checks passed for all 25 slides.
- Numerical source and all platform baselines are unchanged.

## Official 2026-08-08 diamond cb3x3x3 benchmark preparation

- Scope: evaluation infrastructure and documentation only; no simulation,
  numerical-source change, or baseline change.
- Official package: `benchmark-cb3x3x3.zip`, SHA-256
  `793a7754a416c83f00f563a7de3ce49d570f6830db89388d2e3b7b808c2612f9`.
- Case: diamond 3 x 3 x 3, 216 carbon atoms, 105 x 105 x 105 mesh,
  576 CG/SD bands, and 480 TDDFT bands.
- The included AOBA-S 96-MPI 40,000-step output passes the existing normal
  checker with profile requirements disabled; its recorded wall is
  `90501.2334069` sec.
- The ZIP does not include TDDFT initial density or full-grid wavefunction.
  CG and SD generation/validation remain mandatory before TDDFT.
- The official README permits a 1,000-step profiling reduction, but supplies
  no 1,000-step reference. The Si111-H reference is explicitly forbidden.
- Added preparation/preflight and case-specific archive wrappers. Generated
  data and archives are isolated under `run/benchmarks/cb3x3x3/`.
- No GPU/x86 run, rank-count change, baseline adoption, or profiler execution
  was performed.

### Unmodified-source x86 environment gate

- The user selected execution with no x86 numerical-source modification.
- Added a read-only environment checker for the independent Xeon 6980P, 8468,
  and 8592+ environments. It reports CPU topology, `MemAvailable`, Intel
  compiler/MPI identities, FFTW readiness, Git state, the former formal
  configuration gate, and a conservative MPI x OpenMP recommendation.
- The memory recommendation retains the current full 480-band RHOOFK batch
  allocation on every MPI rank. It does not claim that larger-input scaling is
  equivalent to the Si111-H tutorial configuration.
- No build, CG, SD, TDDFT, source change, or baseline change was performed.

### Staged x86 CG/SD/TDDFT runner

- Added `tools/run_cb3x3x3_x86.sh`; this is execution infrastructure only and
  does not change the x86 numerical source.
- Fixed the validated TDDFT configurations at 6980P 16 MPI x 16 OpenMP, 8468
  32 x 3, and 8592+ 32 x 4. The 6980P former 32 x 8 configuration remains
  blocked by its returned available-memory gate.
- The runner rechecks the environment and official package before every
  action, builds/reuses the diagnostic-off Intel CPU/FFTW path, serializes
  shared-source builds, and copies host-specific executables into the
  platform directory before execution.
- CG, SD, two-step TDDFT, 1,000-step TDDFT, and 40,000-step TDDFT are explicit
  separate actions. Existing state, run directories, and archives are never
  overwritten. CG and SD must share one host and revision.
- Successful SD output is installed as a common write-protected initial state
  with SHA-256 provenance. TDDFT runs are separated below
  `run/benchmarks/cb3x3x3/platforms/<sku>_<host>/runs/<label>`.
- The two-step action is startup/memory validation only. A 1,000-step action
  requires an approved same-input reference; both long actions require an
  explicit confirmation and unique label. No calculation was run locally.

### Xeon Platinum 8592+ cb3x3x3 startup result and 100-step diagnostic gate

- The user-operated CG and SD stages on host `spr10` passed for all 216 atoms
  and produced the validated, SHA-256-recorded TDDFT initial state.
- A 2-step TDDFT startup run at 32 MPI x 4 OpenMP passed the normal result
  checker. It reported `543.709180832` sec, 216 force/position/velocity rows,
  and 38 profile timers. There was no same-step reference, so the wall is not
  a correctness comparison or performance baseline.
- Added a derived 100-step input and `tddft-100` runner action for the user's
  explicitly authorized single-node 8592+ run. It fixes the existing
  validated 32 MPI x 4 OpenMP configuration, requires
  `CONFIRM_LONG_RUN=YES` and a unique label, refuses overwrite, and performs
  only the normal result check.
- The official package provides no 100-step reference. The run therefore
  remains diagnostic, is not archived by the helper, cannot use the Si111-H
  reference, and cannot enter a formal baseline series. Numerical source and
  all existing platform baselines are unchanged.

### Xeon Platinum 8592+ cb3x3x3 100-step diagnostic result

- Result returned to Main: 2026-08-28.
- Tested revision:
  `4bc30413426f029ca6c973f8e375740f0a3282bf`.
- Host/SKU: `spr10`, Intel Xeon Platinum 8592+.
- Execution: one node, 32 MPI x 4 OpenMP = 128 physical cores, diagnostics
  off; the Intel/FFTW, CG, SD, and TDDFT executables were reused.
- Input/result: diamond cb3x3x3, 216 atoms, 100 steps,
  `ETOT=-1233.257829`, and
  `Eelec+Enucl-Eext-Ework=-1232.63825227`.
- Wall: `7053.57140899` sec. The output contained 216 force, position, and
  velocity rows and 39 profile timers.
- Result: normal check PASS and `CB3X3X3_TDDFT_DIAGNOSTIC_PASS`.
  Same-input comparison was unavailable and the helper correctly reported
  `baseline=NOT_APPLICABLE`.
- A follow-up photograph confirmed the run label as
  `cb3x3x3_8592p_spr10_32mpi_4omp_100step_diag_01` below platform directory
  `run/benchmarks/cb3x3x3/platforms/8592p_spr10/runs`. No result file
  transfer, archive, second run, or baseline adoption was requested.
- This measurement remains separate from Si111-H and all existing A100,
  H100, Xeon 6980P, Xeon 8468, and Xeon 8592+ Si111-H baselines. Numerical
  source and every formal baseline are unchanged.

### NEC VE and Xeon 8592+ cb3x3x3 comparison preparation

- A returned directory listing identifies the NEC VE result directory as
  `run/cb3x3x3_ve/sample.tddft_exe/0827_100steps_8MPI_2OMP/` and confirms that
  `dia-cb3x3x3_tm.out` links to the nonempty
  `dia-cb3x3x3_tm.out_part001` file.
- Added a read-only cross-platform comparison helper. It accepts a directory
  or output path and defaults the reference to the fixed 8592+ run label
  `cb3x3x3_8592p_spr10_32mpi_4omp_100step_diag_01`.
- Extended the common result checker with an optional `--expected-atoms`
  gate. Existing calls are unchanged; the cb3x3x3 helper requires 216 force,
  position, and velocity rows in both results.
- The helper runs both normal checks without requiring the repository-specific
  profile block, applies the existing relaxed comparison at exactly 100
  steps, and prints a wall ratio only after every correctness gate passes.
- No simulation, file copy, archive mutation, numerical-source change,
  platform baseline, or claimed NEC VE hardware identity is part of this
  preparation.

### NEC VE and Xeon 8592+ cb3x3x3 comparison result

- Both normal checks passed with exactly 100 completed steps and 216 force,
  position, and velocity rows. The x86 result contained 39 profile timers;
  the NEC VE output contained none, which was allowed for this external-output
  diagnostic.
- Xeon 8592+: `ETOT=-1233.257829`,
  `Eelec+Enucl-Eext-Ework=-1232.63825227`, wall `7053.57140899` sec.
- NEC VE run-name configuration `8MPI_2OMP`: `ETOT=-1233.257801`,
  `Eelec+Enucl-Eext-Ework=-1232.63822459`, wall `3189.16684126` sec.
- Relaxed differences for ETOT `2.8e-5`, total energy `2.768e-5`, positions
  `1.314808e-9`, and velocities `6.167918e-9` passed their fixed tolerances.
- Final force failed: maximum absolute difference `2.016e-4` against tolerance
  `1.0e-4`, at atom `id=165`, component 1. The 8592+ value was
  `8.220999999999998e-4`; the NEC VE value was
  `6.204999999999996e-4`.
- The helper emitted FAIL and blocked the performance comparison before any
  wall ratio or speedup was printed. The tolerance is unchanged. Neither raw
  wall is a cross-platform baseline, and no follow-up execution is authorized
  until exact input, initial-state, source, and NEC VE platform/compiler
  provenance are reconciled.

### Staged H100 cb3x3x3 startup and memory validation preparation

- The user selected H100 as the first GPU check for the independent official
  diamond cb3x3x3 case.
- Added `tools/run_cb3x3x3_h100.sh` without changing numerical source. The
  fixed build/run path is OpenACC/cuFFT, explicit `cc90`, pinned separate
  memory, diagnostics off, one H100, one MPI rank, and one OpenMP thread.
- The read-only `preflight` action validates clean synchronized Git, official
  case/state hashes, the NVHPC/MPI toolchain, H100 identity and compute
  capability, zero active compute processes, at least 90% free GPU memory, and
  the conservative 64-GiB host-`MemAvailable` gate for one MPI rank.
- The bounded `tddft-2` action re-runs preflight, builds TDDFT only, uses the
  immutable CG/SD state, writes an isolated H100-host run directory, samples
  device-memory usage, and requires the normal checker with all 216 observable
  rows.
- The helper deliberately contains no 100-step action. A two-step pass has no
  same-input reference and remains a startup/capacity observation, not a
  correctness equivalence, cross-platform comparison, archive, or baseline.
- No H100 build or simulation was performed while preparing the helper. The
  read-only preflight result must be returned and reviewed before `tddft-2`.
  Numerical source and all formal baselines are unchanged.

### H100 cb3x3x3 preflight and first 2-step input failure

- Returned preflight revision: `92543b2c3726dafb296782dbcb281bef6fb4799f`.
- Host/device: `spr21`, NVIDIA H100 PCIe, compute capability 9.0, driver
  `595.45.04`; NVFORTRAN and MPI compiler 26.5, Open MPI 5.0.10rc2.
- Capacity preflight: 81,081/81,559 MiB GPU memory free (99.41%), 989.03 GiB
  host memory available, zero active compute processes, and every preflight
  gate PASS.
- The H100 cc90 OpenACC/cuFFT pinned-separate build passed. The process then
  exited at startup with status 127 and NVFORTRAN `FIO-F-231` at
  `tm_inputs.f:415`, before a TDDFT step or material GPU allocation. Sampled
  peak use was 515 MiB (0.63%), leaving 81,044 MiB; it is not a capacity pass.
- Root cause: the official TDDFT input has CRLF line endings, and `GCUT=64` is
  the final token on its line. The legacy fixed-width command parser retains
  the carriage return in `BSAVE` and NVFORTRAN rejects it in the internal
  `E20.0` conversion; ifx tolerated the same input in the x86 run.
- Corrected only the H100 execution helper: each new isolated run receives an
  LF-normalized 2-step input copy, with both source and normalized SHA-256
  recorded. The official/generated input, initial state, numerical source,
  failed run directory, and all baselines remain unchanged. A new 2-step run
  is required; 100 steps remain unauthorized.

### H100 cb3x3x3 second 2-step text-input failure

- The retry with the LF-normalized command input passed `tm_inputs.f`, which
  confirms the first failure diagnosis, and then stopped on record 3 of
  `fort.41` with NVFORTRAN `FIO-F-225` at
  `pspw_tm11_Vext_Avec_v4_alloc.f:3100`.
- The official carbon pseudopotential `TR.C95g_asci` also has CRLF endings.
  Its list-directed read spans records, and NVFORTRAN reports the retained
  carriage return as an unknown token. The x86 ifx path had tolerated it.
- The process exited with status 127 before computation. Sampled peak GPU use
  was 539 MiB (0.66%) with 81,020 MiB headroom; this is not a capacity pass.
- The build passed, but replacing the helper's prior write-protected platform
  executable produced an interactive `mv` confirmation prompt.
- Extended the isolated-run conversion to all Fortran-consumed text files and
  added source/normalized pseudopotential hashes. Changed executable
  installation to `mv -f`. Canonical inputs, common state, numerical source,
  both failed run directories, and all baselines remain unchanged. Another
  bounded 2-step run is required; 100 steps remain unauthorized.

### H100 cb3x3x3 batch-path 2-step correctness failure

- The LF-normalized H100 run completed two steps at one H100, one MPI rank,
  and one OpenMP thread with diagnostics off. It returned all 216 force,
  position, and velocity rows and passed the standalone normal checker.
- H100 observables were `ETOT=-637.3190723` and
  `Eelec+Enucl-Eext-Ework=-636.69918884`; wall was `1755.62075114` sec.
  Sampled device-memory peak was 55,881 MiB with 25,678 MiB headroom.
- The fixed Xeon Platinum 8592+ 32 MPI x 4 OpenMP 2-step reference reported
  `ETOT=-1233.258088`, total energy `-1232.63820424`, and wall
  `543.709180832` sec.
- The same-input relaxed comparison failed: energy differed by about
  595.939 Ha and maximum force differed by 0.2465046 Ha/Bohr. Positions and
  velocities agreed, but they do not rescue the gross energy/force failure.
- The H100 wall is not a performance result or baseline. One hundred steps,
  repeat runs, archiving, and adoption are blocked.

### H100 scalar-RHOOFK two-step diagnostic implementation and rejection

- Hypothesis: the post-TMEVL `RHOOFK_ACC_BATCH` path, originally validated on
  the 32-band Si111-H case, is the source of the gross error for the 480-band
  cb3x3x3 case. This is a hypothesis, not an accepted diagnosis.
- With compile-time macro `FPSEID_RHOOFK_SCALAR_DIAGNOSTIC`, the source first
  updates host `COEF` from its device-resident authoritative copy and calls
  the existing scalar `RHOOFK`. Without the macro, the current resident batch
  path is unchanged. Normal x86 and H100 production builds do not enable it.
- Added H100 helper action `tddft-2-rhoofk-scalar`. It creates a separately
  named executable/provenance file and isolated `rhoofk_scalar_2step` run,
  fixes one H100 / one MPI / one OpenMP with diagnostics off, and contains no
  100-step action.
- A successful process exit is insufficient: the action requires the normal
  216-atom check and then automatically runs the existing relaxed comparison
  against the fixed Xeon 8592+ 2-step result. Failure stops with 100 steps
  blocked. Even a pass is diagnostic-only and cannot become a baseline.
- Tested revision: `611c0ac`. The H100 process completed two steps and its
  standalone normal check passed with all 216 observable rows. Scalar wall was
  `1767.65834403` sec; this failed-correctness wall is not performance data.
- Scalar observables were `ETOT=-637.3190723` and total energy
  `-636.69918884`, exactly matching the earlier H100 batch-path values shown
  by the returned summaries. Against Xeon 8592+, both energy differences
  remained about 595.939 Ha.
- Maximum force difference remained `0.2465046` Ha/Bohr at atom 133,
  component 1 (`ref=-1.106e-4`, `test=0.246394`). Positions and velocities
  had zero maximum difference. The relaxed comparison emitted FAIL and
  correctly blocked performance comparison and 100 steps.
- Conclusion: replacing only post-TMEVL `RHOOFK_ACC_BATCH` with synchronized
  scalar `RHOOFK` does not change the failure. The batch density path is not
  its cause, so this hypothesis is rejected.
- The user approved disposition on 2026-09-03. The scalar source branch and
  dedicated H100 action are removed by the result/rollback commit, restoring
  those files exactly to pre-diagnostic revision `507438f`. Result files are
  preserved; no baseline or accepted numerical source changes.

### NVFORTRAN CPU/FFTW compiler-isolation diagnostic preparation

- The user selected compiler isolation before another GPU numerical-source
  experiment. The bounded question is whether the same cb3x3x3 state and
  tracked TDDFT source remain correct when compiled by NVFORTRAN but executed
  entirely through the CPU/FFTW fallback.
- Added `tools/run_cb3x3x3_nvfortran_cpu.sh` without changing numerical source.
  It is fixed to the H100 host's dual-socket Xeon Platinum 8468, 32 MPI x
  3 OpenMP = 96 physical cores, diagnostics off, and exactly two steps.
- The preflight verifies clean synchronized Git, official input/state hashes,
  Xeon 8468 topology, at least 768 GiB `MemAvailable`, an NVFORTRAN-backed
  Open MPI wrapper, the fixed ifx reference, and isolated FFTW readiness.
- The helper builds from a Git archive in a revision-specific platform build
  tree, so ignored executables or objects in the checkout are not overwritten.
  Its GCC-built POSIX-thread FFTW dependency, executable, provenance, and runs
  are isolated under `platforms/nvfortran_cpu_8468_<host>` and cannot mix with
  Intel x86 or H100 results. `libfftw3_threads` is used instead of the GCC
  OpenMP FFTW library, avoiding a second OpenMP runtime beside NVHPC libnvomp.
- Input text receives the same run-local LF normalization required by
  NVFORTRAN. The canonical official input, pseudopotential, and CG/SD state
  remain unchanged.
- The run must pass the normal 216-atom check and the existing relaxed
  comparison against the Xeon 8592+ ifx 2-step result. A pass substantially
  reduces suspicion of NVFORTRAN itself; a failure still requires separation
  of compiler, undefined behavior, Open MPI, and runtime effects.
- The helper has no long-run action. No build, simulation, result, baseline,
  accepted source change, or GPU authorization is part of this preparation.

### NVFORTRAN CPU/FFTW compiler-isolation diagnostic result

- The user authorized the two-step run after the `spr21` preflight passed at
  revision `3f83649`. The isolated GCC POSIX-thread FFTW build and NVFORTRAN
  CPU/FFTW TDDFT build both passed. The run used Xeon Platinum 8468, 32 MPI x
  3 OpenMP, diagnostics off, no `-acc`, no cuFFT, and no GPU.
- The executable link gate excluded GCC libgomp and required NVHPC libnvomp,
  removing mixed OpenMP runtimes from this test. The canonical initial-state
  hashes passed before the run and again after the process completed.
- The process completed two steps in `718.925694942` sec and printed all 216
  force, position, and velocity rows. The normal checker nevertheless failed
  because `current J(a.u.)` contained three `NaN` values. The helper stopped at
  `stage=normal_check`, so relaxed comparison was intentionally not run.
- CPU/NVFORTRAN reported `ETOT=-637.3190723` and total energy
  `-636.69918884`. These values exactly match both invalid H100 two-step paths,
  while the fixed Xeon 8592+ ifx reference reports `ETOT=-1233.258088` and
  total energy `-1232.63820424`.
- Conclusion: OpenACC, cuFFT, and GPU execution are not necessary to reproduce
  the gross error. The result narrows investigation to behavior shared by the
  NVFORTRAN builds, but does not prove an NVFORTRAN defect; source-level
  undefined behavior such as uninitialized data, out-of-bounds access, or
  aliasing may be exposed differently by the compiler.
- The failed wall time is not performance evidence. One hundred steps, repeat
  timings, cross-platform performance comparison, and baseline adoption remain
  blocked. The isolated failed run is preserved, the diagnostic helper remains
  reproducible, and no numerical source or accepted baseline is changed.

### NVFORTRAN CPU runtime-check diagnostic preparation

- The user approved a bounded source-undefined-behavior diagnostic after the
  CPU/FFTW build reproduced the two H100 paths' exact invalid energies and
  `NaN` current without OpenACC, cuFFT, or GPU execution.
- Extended `tools/run_cb3x3x3_nvfortran_cpu.sh` with the separate actions
  `preflight-runtime-checks` and `tddft-2-runtime-checks`. The numerical source,
  official state, 32 MPI x 3 OpenMP placement, POSIX-thread FFTW dependency,
  diagnostics-off application path, and two-step bound are unchanged.
- The runtime-check executable is isolated under
  `bin/runtime_checks/<revision>`, and its run label contains
  `runtime_checks_2step`, preventing reuse or mixing with the earlier `-O2`
  CPU diagnostic, Intel x86 results, or H100 results.
- The initially prepared flags were `-O0 -g -traceback -mp -Msave -Mlarge_arrays -Mbounds
  -Mchkptr -Mchkstk -Ktrap=fp -Minit-real=snan
  -Minit-integer=2147483647`. They target array bounds, NULL pointers, stack
  exhaustion, invalid/divide-by-zero/overflow exceptions, and uninitialized
  local real/integer values. Read-only preflight defers compiler flag
  validation. The build action first compiles `omp_clock.f` through the same
  NVFORTRAN-backed MPI wrapper with every runtime-check flag and
  `-Mpreprocess`; rejection stops before the full build or simulation.
- The helper disables core dumps and prints at most 40 unique diagnostic lines
  plus a 30-line stderr tail. It preserves complete stdout/stderr and result
  provenance in the isolated run. Every outcome continues to block 100 steps
  and baseline use.
- Limitations are explicit: assumed-size bounds checks are incomplete, and
  initialization sentinels do not cover every allocatable or automatic object.
  Therefore a clean checked run would narrow, but not eliminate, source-level
  undefined behavior.
- This commit is preparation only. No numerical source, build result, runtime
  result, accepted source, or baseline is changed; execution requires a fresh
  returned preflight and separate human approval.

### First NVFORTRAN runtime-check build rejected its integer sentinel

- Returned revision: `53499eb`.
- The helper completed the environment preflight and began the isolated
  runtime-check build, but NVFORTRAN emitted
  `NVFORTRAN-S-0011-Unrecognized command line switch: -2147483647` for every
  TDDFT source. The negative integer sentinel in
  `-Minit-integer=-2147483647` was parsed as a separate switch.
- The earlier `-dryrun` flag gate was a false PASS because it did not exercise
  the compiler phase that rejected the nested option. No executable was
  produced and no simulation was started, so there is no correctness or
  performance result.
- The helper now uses the positive sentinel `2147483647` and replaces the
  `-dryrun` gate with a real isolated compile probe at the start of the build
  action. A flag or later build failure prints an explicit compact result
  block with `simulation_started=NO`.
- The numerical source, official cb3x3x3 state, prior failed NVFORTRAN results,
  accepted source `c46cfa9`, and all formal platform baselines are unchanged.
  A new preflight return and separate approval remain required before retrying
  the two-step diagnostic; 100 steps remain blocked.

### Runtime-check floating-point trap stopped inside MPI initialization

- Returned revision: `de50e5a` on the Xeon Platinum 8468 host `spr21`, using
  32 MPI x 3 OpenMP and the separate runtime-check executable.
- The compile probe and full build passed. The run then stopped with exit
  status 136. Multiple ranks reported signal 8 and
  `Invalid floating point operation`; Open MPI reported a rank exiting on
  `Floating point exception`.
- The returned stack trace passes through Open MPI/UCX and `MPI_Init`. FPSEID21
  calls `MPI_Init` before its application initialization, so global
  `-Ktrap=fp` trapped inside the communication runtime before the remaining
  source checks could diagnose TDDFT. This is not evidence of a TDDFT formula
  error or an NVFORTRAN code-generation defect.
- No TDDFT observables or valid wall time were produced. The initial-state
  post-run SHA-256 gate passed. The result is diagnostic only and the helper
  correctly kept 100 steps blocked.
- The user approved one bounded follow-up change: remove only `-Ktrap=fp`.
  `-Mbounds`, `-Mchkptr`, `-Mchkstk`, `-g`, `-traceback`,
  `-Minit-real=snan`, and `-Minit-integer=2147483647` remain enabled. The
  numerical source, input/state, MPI/OpenMP placement, prior results, accepted
  source, and all baselines are unchanged. A fresh preflight and separate
  approval are required before the two-step retry.

### Runtime check found an uninitialized ELECTF k-point subscript

- Returned revision: `ee1a949` on the Xeon Platinum 8468 host `spr21`, using
  32 MPI x 3 OpenMP and the runtime-check flags without `-Ktrap=fp`.
- The compile and build gates passed. TDDFT then stopped with exit status 127.
  NVFORTRAN bounds checking reported `electf4_Vext_Avec.f:1047`, where
  dimension 2 of `OCC` was accessed at subscript 0 although its bounds were
  1:1. The initial-state post-run SHA-256 gate passed.
- ELECTF's enclosing loop is `IK=1,NUMK`, but the PXTOT, PYTOT, and PZTOT
  occupation factors used `OCC(IB,K)`. `K` is an implicit integer and is never
  assigned in this subroutine. Neighboring kinetic, nonlocal-energy, and force
  sums use `OCC(IB,IK)`, establishing a local index-contract violation.
- Git history shows the three `K` indices in the initial imported source and
  accepted source `c46cfa9`. The runtime result therefore identifies
  pre-existing source undefined behavior, not an NVFORTRAN-only compiler
  defect. It plausibly explains the NaN macroscopic current but does not by
  itself establish the cause of the gross energy or force mismatch.
- The user approved changing only those three references from `K` to `IK`.
  The change preserves loop order, array shapes, MPI, OpenACC boundaries, and
  CPU/FFTW fallback. It is a pending correctness candidate; accepted source,
  all platform baselines, and prior results remain unchanged. Runtime-check
  preflight and a separately approved two-step retry are required before any
  acceptance decision. One hundred steps remain blocked.

### Corrected ELECTF index removes NaN but not the gross mismatch

- Returned revision: `bb5cb58` on Xeon Platinum 8468 host `spr21`, using the
  same isolated NVFORTRAN runtime-check CPU/FFTW path, 32 MPI x 3 OpenMP, and
  the canonical ifx CG/SD initial state.
- The corrected run completed two steps without another trapped bounds,
  pointer, stack, or initialized-local violation. The normal 216-atom check
  passed and the three macroscopic-current components were finite; therefore
  changing the uninitialized `OCC(IB,K)` references to `OCC(IB,IK)` fixed a
  genuine current-calculation defect.
- The relaxed same-input comparison still failed. NVFORTRAN reported
  `ETOT=-637.3190723` and total energy `-636.69918884`, while the fixed ifx
  reference reports `ETOT=-1233.258088` and total energy `-1232.63820424`.
  The energy difference remains about `595.9390` Ha and the maximum force
  difference remains `2.465046e-01` Ha/Bohr. Positions and velocities passed.
- The diagnostic wall time was `4027.4240129` sec and is not performance
  evidence. The post-run canonical-state SHA-256 gate passed. Revision
  `bb5cb58` remains a pending correctness candidate rather than the accepted
  numerical source; accepted source `c46cfa9`, baselines, and 100-step
  authorization remain unchanged.
- Conclusion: the `K` to `IK` correction explains the NaN current but does
  not explain the energy/force failure. A different controlled variable is
  required before another long or GPU performance run.

### Isolated NVFORTRAN SD lineage diagnostic preparation

- Historical Si111-H validation did not use an all-NVFORTRAN CG/SD chain.
  Its practical lineage was Intel CG output -> NVFORTRAN SD built with
  `-O1 -mp -Msave -Mlarge_arrays -Kieee` -> NVFORTRAN TDDFT. The current
  cb3x3x3 failure instead used ifx CG -> ifx SD -> NVFORTRAN TDDFT, so the SD
  state producer is an unresolved lineage difference.
- Added `tools/run_cb3x3x3_nvfortran_sd_chain.sh` with separate `preflight`,
  `sd`, and `tddft-2` actions. It verifies the existing ifx CG state and ifx
  SD reference through their hashes, executable provenance, and ifx platform
  build provenance before using them.
- The `sd` action builds from an isolated Git archive with the historically
  validated NVFORTRAN flags and one OpenMP thread, copies the ifx CG state
  into a revision-specific private directory, checks 216 forces, and requires
  the established relaxed SD comparison. It creates a private, hashed TDDFT
  state only after both checks pass.
- The `tddft-2` action passes that private state to the existing NVFORTRAN
  CPU/FFTW helper through explicit state/platform-root overrides. The TDDFT
  compiler flags, previously built isolated FFTW dependency, 32 MPI x 3
  OpenMP placement, ifx 2-step reference, and normal/relaxed TDDFT checks
  otherwise remain unchanged, isolating the SD state lineage as the principal
  variable.
- The common NVFORTRAN CPU helper now accepts explicit `STATE_DIR` and
  `NVFORTRAN_PLATFORM_ROOT`/`NVFORTRAN_FFTW_ROOT` overrides while preserving
  its canonical defaults and recording the effective paths in provenance.
- Every build, run, and candidate state is isolated below
  `platforms/nvfortran_cpu_8468_<host>/chains/ifx_cg_nvfortran_sd/<revision>`.
  Existing ifx CG/SD data, canonical state, and all platform results are never
  overwritten. Disk headroom for private input/output copies is checked.
- This is preparation only. No SD or TDDFT process has run. Review the new
  preflight before authorizing SD; review SD before authorizing TDDFT. The
  helper exposes no 100-step or baseline-adoption action.

### Isolated NVFORTRAN SD lineage result

- The reviewed chain at revision `5917b115d765` used the existing ifx CG
  output, rebuilt only SD with NVFORTRAN using
  `-O1 -mp -Msave -Mlarge_arrays -Kieee`, and ran SD with one OpenMP thread.
  Its normal 216-force check passed, and the relaxed comparison with the ifx
  SD result reported zero difference for ETOT, convergence, forces, and band
  energies.
- The resulting private TDDFT state is preserved below
  `platforms/nvfortran_cpu_8468_spr21/chains/ifx_cg_nvfortran_sd/5917b115d765/state`.
  Its recorded density and wavefunction SHA-256 values both differ from the
  canonical ifx-SD state. This establishes different state content, but the
  hashes alone do not distinguish numerical phase/content differences from a
  compiler-dependent representation issue.
- NVFORTRAN CPU/FFTW TDDFT then consumed that private state with the same
  32 MPI x 3 OpenMP diagnostic configuration. Two steps completed in
  `642.453624964` sec, passed the normal check, and matched the fixed Xeon
  8592+ ifx result exactly: zero difference in ETOT, total energy, forces,
  positions, and velocities under the relaxed comparator.
- The successful CPU result substantially reduces suspicion of NVFORTRAN
  TDDFT arithmetic itself. The failed CPU and H100 tests had instead paired
  NVFORTRAN TDDFT with the canonical ifx-SD state, so that mixed producer /
  consumer lineage is now the implicated controlled variable. This does not
  by itself prove a generic file-format incompatibility or validate GPU
  execution.
- The `642.453624964`-sec wall is diagnostic only. Accepted numerical source
  remains `c46cfa9`; the `K` to `IK` correction remains pending; no baseline
  or 100-step authorization changes.

### H100 diagnostic using the reviewed NVFORTRAN-SD state

- Added `tools/run_cb3x3x3_h100_nvfortran_sd.sh` to fix the H100 input lineage
  to the reviewed revision `5917b115d765` private state. It verifies the SD
  provenance and requires both density and wavefunction manifest hashes to
  differ from the canonical ifx-SD state before entering the common H100
  preflight.
- Its output is isolated below an H100 platform chain containing both the
  state-producer revision and current source revision. Existing canonical-
  state H100 builds and runs cannot be reused or overwritten.
- The common H100 two-step gate now accepts explicit state and platform roots,
  validates the fixed Xeon 8592+ ifx reference during preflight, verifies the
  selected state SHA-256 before and after execution, and requires both the
  normal check and relaxed platform comparison.
- The wrapper exposes only `preflight` and `tddft-2`. No H100 process has run
  under this lineage yet. Return and review `preflight` before separately
  authorizing two steps; 100 steps and performance interpretation remain
  blocked.

### H100 reviewed NVFORTRAN-SD-state 2-step result and 100-step preflight gate

- The user-operated H100 two-step run at revision `c442b1a` used the private
  `IFX_CG_TO_NVFORTRAN_SD` state produced at revision `5917b115d765`, one
  NVIDIA H100 PCIe, one MPI rank, one OpenMP thread, explicit `cc90`, pinned
  separate memory, and diagnostics off.
- The normal 216-atom check and the relaxed comparison with the fixed Xeon
  Platinum 8592+ ifx two-step result both passed. The initial-state SHA-256
  gate also passed after execution, proving that the shared private state was
  not changed by the run.
- The sampled GPU peak was 55,881 MiB (`68.52%`) with 25,678 MiB minimum
  headroom. The reported wall was approximately `1469.507` sec. It is a
  diagnostic startup/capacity value, not a performance result or baseline.
- This is the first correct H100 result for the reviewed NVFORTRAN-SD lineage.
  It supports the conclusion that the earlier approximately 595.939-Ha
  failure was principally associated with the mixed ifx-SD-state to
  NVFORTRAN-TDDFT lineage rather than being established as an H100,
  OpenACC, or cuFFT defect.
- Added a read-only `preflight-100` action to
  `tools/run_cb3x3x3_h100_nvfortran_sd.sh`. It verifies the same private state
  lineage and hashes, the fixed 100-step input, the Xeon 8592+ ifx 100-step
  reference and its normal/relaxed self-check, synchronized clean Git, H100
  identity and availability, and a run-01-only isolated destination below a
  `100step_validation` subtree.
- The preflight records that a future run 01 must repeat state SHA-256 checks
  before and after execution and must pass the 100-step/216-atom normal check
  plus the relaxed Xeon comparison. No 100-step execution action exists in
  this preparation commit. Run 01 requires separate user approval, and runs
  02/03 remain blocked until run 01 passes every gate.
- Accepted numerical source remains `c46cfa9`; `bb5cb58` remains the pending
  correctness candidate. No baseline, numerical-source adoption, or
  performance conclusion changes.

### Paired x86/H100 two-step cost-distribution remeasurement preparation

- The 100-step cb3x3x3 validation is deferred because its turnaround is too
  long for the next diagnosis. The replacement experiment measures exactly
  two steps on the paired `spr21` paths: Xeon Platinum 8468 NVFORTRAN
  CPU/FFTW at 32 MPI x 3 OpenMP and H100 NVFORTRAN OpenACC/cuFFT at one GPU,
  one MPI rank, and one OpenMP thread.
- Both paths use the same reviewed private `IFX_CG_TO_NVFORTRAN_SD` state
  produced at revision `5917b115d765`, the same current TDDFT source, and
  diagnostics off. Both retain the pre/post state SHA-256 gate, normal
  two-step/216-atom check, and relaxed comparison with the fixed Xeon 8592+
  ifx two-step result.
- Added `tools/run_cb3x3x3_2step_cost_remeasure.sh` with separate read-only
  preflights and separately authorized x86/GPU execution actions. Results are
  isolated by state revision, source revision, and platform below a dedicated
  `comparisons/2step_cost_distribution` subtree.
- Added `tools/report_cb3x3x3_2step_costs.sh`. It prints the same selected
  timer rows and top 12 inclusive timers for both platforms, normalized to
  each path's max-rank `time_step_total`. Inclusive percentages overlap and
  are explicitly not summed to 100%; the output is a cost-distribution
  diagnostic rather than a performance baseline.
- This preparation changes no Fortran source, timer boundary, compiler flag,
  MPI/OpenMP configuration, accepted numerical source, pending-candidate
  status, or formal baseline. The earlier 100-step preflight remains available
  but is not the next requested action.

### Xeon 8468 NVFORTRAN CPU/FFTW two-step cost-distribution result

- The user-operated x86 run at revision `f5d3d1097dc2` used the reviewed
  `IFX_CG_TO_NVFORTRAN_SD` state produced at revision `5917b115d765`,
  NVFORTRAN CPU/FFTW, 32 MPI ranks, three OpenMP threads per rank, and
  diagnostics off. The run completed two steps in `642.8832999112` sec.
- The normal 216-atom check, relaxed comparison with the fixed Xeon 8592+
  ifx two-step result, post-run initial-state SHA-256 gate, and compiler
  isolation gate all passed. The generic platform comparator continued to
  label its output-only provenance scope `INCOMPLETE`; this is its explicit
  diagnostic contract and is not an additional failed execution gate.
- Max-rank `time_step_total` was `662.595020` sec. The largest inclusive
  timer was `frprmn` at `633.502221` sec (`95.61%`). Its major visible
  subtrees were `electf_force` at `216.824312` sec (`32.72%`) and
  `tmevl_total` at `149.010050` sec (`22.49%`).
- Within the time-evolution work, `tmevl_s2` took `146.553825` sec
  (`22.12%`). `s2_nonlocal` took `120.043901` sec (`18.12%`), of which
  `s2_nonlocal_gemm` / `exnlp_gemm_dot` accounted for about `116.792` sec
  (`17.63%`). `s2_fft_local` took `27.163256` sec (`4.10%`), while the
  broader `fft_wrapper` accumulated `46.644479` sec (`7.04%`).
- These are overlapping inclusive timers and must not be summed. On this x86
  path, the measured nonlocal GEMM/dot subtree is about 4.3 times the
  `s2_fft_local` time, so the two-step distribution does not support treating
  FFT as the sole or dominant time-evolution cost.
- This is a two-step cost-distribution diagnostic, not a performance baseline.
  The H100 half of the paired measurement has not run because the user chose
  to proceed with x86 only. Accepted source `c46cfa9`, pending candidate
  `bb5cb58`, 100-step authorization, and all formal baselines remain unchanged.

### x86-only cb3x3x3 cost-detail timer preparation

- The reviewed NVFORTRAN-SD state may exercise force/nonlocal paths that were
  not material in the earlier Si111-H measurements. The next bounded x86 run
  therefore subdivides the two dominant inclusive regions without changing
  any numerical operation, loop order, array shape, MPI/OpenMP placement, or
  FFT backend.
- Added an opt-in `FPSEID_COST_DETAIL_TIMERS` build switch. On the x86
  cost-distribution path it creates a separate `cost_detail` executable and
  enables the existing ELECTF/NONLOCF/SEPPOTF timers while leaving runtime
  checks and the broad `FPSEID_FRPRMN_DIAGNOSTIC` mode off.
- ELECTF will be split into local and nonlocal force work. NONLOCF will be
  split into setup, kinetic/MPI preparation and communication, YLM, SEPPOTF,
  and finalization. The SEPPOTF s/p branch timers report `NOT_CALLED` when a
  path is absent, making the input-dependent traversal explicit.
- Added `s2_nonlocal_forward` and `s2_nonlocal_reverse` around the two S2
  traversals. The report also prints the existing `exnlp_gemm_data`, dot, and
  update timers, plus average-rank unclassified gaps for ELECTF, NONLOCF, and
  its kinetic/MPI subtree. Max-rank percentages remain inclusive and must not
  be summed.
- The compact detail report is bounded by
  `FPSEID21_CB3X3X3_X86_COST_DETAIL_BEGIN/END` and requires all structural
  parent timers before printing `detail_timer_gate=PASS`. Result storage
  remains isolated by state revision, source revision, and platform.
- Shell syntax, preprocessing with the detail macro, a synthetic report test,
  and an isolated GNU CPU/FFTW full build passed. No x86 calculation, H100
  calculation, or 100-step calculation has run for this preparation.
  Accepted source `c46cfa9`, pending candidate `bb5cb58`, authorizations, and
  formal baselines remain unchanged.
