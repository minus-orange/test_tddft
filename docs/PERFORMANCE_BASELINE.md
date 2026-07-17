# TDDFT GPU Performance Baseline

Last updated: 2026-07-17

## Official Baseline

- Logical step: Step 41
- Source implementation commit: `4aaa33c`
- Pinned-allocation build-mode commit: `9cbb6bc`
- Result record commit: this documentation update
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Memory mode: `-gpu=mem:separate:pinnedalloc`
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_02` | 107.783477068 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_03` | 107.718405008 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_04` | 107.754213095 | PASS | PASS |

Official three-run median: `107.754213095` sec.
Run-to-run range: `0.065072060` sec.

## Step 41 Run 02 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 108.026444 |
| `frprmn` | 98.918635 |
| `electf_force` | 9.055956 |
| `tmevl_total` | 51.442021 |
| `tmevl_s2` | 16.027619 |
| `s2_nonlocal` | 11.489951 |
| `s2_fft_local` | 4.521393 |
| `fft_wrapper` | 2.648518 |
| `exnlp_gemm_dot` | 8.441246 |
| `tmevl_p_enter` | 0.001200 |
| `exkin_acc_kernel` | 0.634409 |
| `exnlp_work1_enter` | 1.543497 |
| `frprmn_rhoofk` | 0.528846 |
| `frprmn_rhoget` | 0.242984 |
| `frprmn_coef_sync` | 0.242068 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

Step 41 is `0.342087984` sec (`0.3165%`) faster than the Step 37 median. Its
source-level residency boundary replaces 5,664 repeated `J2G`/`OCC` copyins
with two outer-loop copyins, a net reduction of up to 5,662 repeated H2D
operations. This transfer-count effect has not yet been remeasured with Nsight
Systems. Step 37 remains the underlying pinned-allocation build mode and the
historical comparison baseline.

The earlier archive `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_01` passed
both correctness checks but took `115.517135143` sec. It preceded the explicit
controlled rebuild and lacked revision/build provenance in the standard
archive manifest, so it is retained as an anomalous run and is not mixed into
the `_02` through `_04` three-run series.

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

Step 40 tested direction-specialized forward and reverse fused nonlocal
kernels at implementation revision `ea81633`. All three diagnostic-off runs
passed normal check and relaxed compare. Their wall-time median was
`107.751713037` sec, an apparent `0.3188%` improvement, but the targeted
`exnlp_gemm_dot` timer median regressed to `8.545724` sec (`+1.2310%` versus
Step 37 run 01) and `s2_nonlocal` regressed to `11.571148` sec (`+0.7134%`).
The small wall difference is not supported by the target timer, so Step 40 is
rejected and does not replace the Step 37 baseline. Implementation `ea81633`
was reverted by `0726e26`; the CPU/FFTW fallback full link passed afterward.

Step 42 tested keeping `Vloc(:,1:5)` resident across each FRPRMN
predictor-corrector sequence at implementation revision `d56815e`. All three
diagnostic-off runs passed normal check and relaxed compare. Their wall times
were `107.732875109`, `107.809727907`, and `107.831543922` sec, giving a
median of `107.809727907` sec and a range of `0.098668813` sec. The median is
`0.055514812` sec (`0.0515%`) slower than Step 41. The source-level transfer
boundary changed as intended, but it produced no measured performance
advantage, so Step 42 is rejected and does not replace this baseline.
Implementation `d56815e` was reverted by `afa1678`; the CPU/FFTW fallback
full link passed afterward.

Step 43 was a single diagnostic run that decomposed the host-side ELECTF
region. Archive `nvhpc_cufft_1rank_02_STEP43_ELECTF_TIMERS_01` passed normal
check and relaxed compare and took `107.821303844` sec. Its diagnostic wall is
not a baseline. Of the `9.012769` sec ELECTF timer, LOCPOTF used `4.071556`
sec and NONLOCF used `4.939849` sec. Within NONLOCF, the coefficient
kinetic/current section used `0.846204` sec and the combined GETYLM plus
SEPPOTF/projector section used `4.091718` sec.

Step 44 was a single diagnostic run that separated GETYLM from SEPPOTF.
Archive `nvhpc_cufft_1rank_02_STEP44_NONLOCF_TIMERS_01` passed normal check
and relaxed compare and took `108.715013981` sec. Its diagnostic wall is not a
baseline. Of the `4.092541` sec projector timer, GETYLM used `0.009894` sec
and SEPPOTF used `4.068364` sec. SEPPOTF therefore accounts for `99.4092%` of
that section and `45.6432%` of ELECTF. The official Step 41 baseline remains
`107.754213095` sec.

Step 45 tested retaining COEF device allocation across the full time-step
loop at implementation revision `da24adf`. All three diagnostic-off runs
passed normal check and relaxed compare. Their wall times were
`108.508744955`, `108.782176018`, and `111.340812922` sec, giving a median of
`108.782176018` sec and a range of `2.832067967` sec. The median is
`1.027962923` sec (`0.9540%`) slower than Step 41. No Nsight Systems trace was
collected to verify the expected H2D reduction. Step 45 is rejected and the
official baseline remains Step 41 at `107.754213095` sec. Implementation
`da24adf` was reverted by `c406a4a`; the CPU/FFTW fallback full link passed.

Step 46 was an ownership diagnostic at implementation `edfafed`, completed by
enforcement commit `3e2c630`. Archive
`nvhpc_cufft_1rank_02_STEP46_OWNERSHIP_01` ran 100 steps in
`107.869318008` sec and passed normal check and relaxed compare. It produced
no OpenACC present/partial-present error and did not trigger the SEPPOTF
ownership-probe failure. Because the diagnostic adds parent-object transfers
and a serial probe kernel, its wall time is not a performance result and does
not replace the Step 41 median of `107.754213095` sec.

Step 47 implementation `0252da9` offloaded the tutorial non-partitioned s/p
SEPPOTF reductions. Its three diagnostic-off runs passed normal check and
relaxed compare at `107.598769903`, `107.722885132`, and `107.848846912` sec.
The median `107.722885132` sec is only `0.031327963` sec (`0.0291%`) faster
than Step 41, while the run range is `0.250077009` sec. This noise-level result
does not justify the specialized implementation, so Step 47 is rejected and
the official baseline remains Step 41 at `107.754213095` sec.

Rollback `35f8542` restored the accepted Step 41 source and the CPU/FFTW
fallback full link passed afterward.
