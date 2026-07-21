# TDDFT GPU Performance Baseline

Last updated: 2026-07-21

## Official Baseline

- Logical step: Step 62
- Source implementation commit: `7475ccb`
- Pinned-allocation build-mode commit: `9cbb6bc`
- Result record commit: this documentation update
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Memory mode: `-gpu=mem:separate:pinnedalloc`
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP62_SKIP_HOST_COEFCP_01` | 68.66669352055 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP62_SKIP_HOST_COEFCP_02` | 68.4877460003 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP62_SKIP_HOST_COEFCP_03` | 68.5734798908 | PASS | PASS |

Official three-run median: `68.5734798908` sec.
Run-to-run range: `0.17894752025` sec.

## Step 62 Run 03 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 68.789653 |
| `frprmn` | 59.785449 |
| `tmevl_total` | 51.398970 |
| `s2_nonlocal` | 11.477712 |
| `s2_nonlocal_make` | 1.336635 |
| `s2_nonlocal_gemm` | 10.118493 |
| `exnlp_gemm_dot` | 8.449516 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

Step 57 is `36.4633102420` sec (`33.8393%`) faster than the Step 41 median and
`2.1465852261` sec (`2.9230%`) faster than the Step 52 median. It retains the
accepted Step 52 VPJ radial-integration offload and additionally parallelizes
only LOCPOT across G vectors. Each G vector preserves its ITY/K/IA accumulation
order, G=0 remains on the host, and the original host MPI boundary is retained.
The median run's FRPRMN residual outside TMEVL is `10.489773` sec, down by
`2.660213` sec from the Step 52 median run.
Step 41 remains the historical comparison baseline, and Step 37 remains the
underlying pinned-allocation build mode.

Step 52 is the immediate predecessor baseline. Its three-run median was
`73.4374880791` sec with a `0.5168180465` sec range. It remains accepted
history, but Step 57 supersedes it as the official performance baseline.

Step 53 re-profiled the accepted Step 52 source with Nsight Systems. Archive
`nvhpc_cufft_1rank_02_STEP53_STEP52_NSYS_01` passed both correctness checks;
its `76.0769960680` sec wall is diagnostic only and did not replace the
then-official Step 52 median of `73.4374880791` sec. The trace measured the VPJ kernel at
`1.793293070` sec and aggregate CUDA kernel time at about `14.26` sec.

Step 58 re-profiled the accepted Step 57 source. Archive
`nvhpc_cufft_1rank_02_STEP58_STEP57_NSYS_01` passed both correctness checks;
its `74.2175440788` sec wall is diagnostic only. Aggregate CUDA kernels remained
about `14.29` sec. Relative to Step 53, H2D increased by 6,756 calls and D2H by
606 calls, while combined transfer duration increased by `0.208290190` sec.
The official Step 57 median remains `71.2909028530` sec.

Step 59 measured the accepted-source LOCPOT envelope at `0.305052` sec, an
`88.9673%` reduction from its Step 56 pre-offload value. Its
`71.1150200367` sec diagnostic wall passed both correctness checks but does not
replace the official three-run median.

Step 60 partitioned the current VRHO host-control envelope. Corrector work was
`2.215861` sec (`79.5036%` of the parent), while seed and predictor work were
`0.552540` and `0.016408` sec. Its `70.9675290585` sec diagnostic wall passed
both correctness checks and does not replace the official baseline.

Step 61 isolated `2.158536` sec in failed-correction COEF/VGOLD restoration,
`96.3513%` of its corrector parent. Its `71.7462480068` sec diagnostic wall
passed both correctness checks and does not replace the official baseline.

Step 62 omitted only the redundant OpenACC-path host COEF0-to-COEF restore.
All three runs passed both correctness checks. Its `68.5734798908` sec median
is `2.7174229622` sec (`3.811739%`) faster than Step 57, so Step 62 supersedes
Step 57 as the official baseline. The median-wall run's FRPRMN residual outside
TMEVL is `8.386479` sec, `2.103294` sec below Step 57's median-wall run, which
is consistent with the Step 61 restore measurement of `2.158536` sec.

Step 63 re-measured the broad FRPRMN envelopes on accepted Step 62 source. Its
`68.9920969009` sec diagnostic wall passed both checks and does not replace the
official median. The measured FRPRMN residual was `8.547452` sec, with
`99.5381%` coverage by the broad exclusive timers.

Step 64 measured the current `part1to5` parent at `2.140208` sec. Its
`68.8858208656` sec diagnostic wall passed both checks and is not a baseline.
MPI used only `0.039413` sec; the legacy-named VPJ integral scope dominated at
`1.910793` sec but still includes host preparation and GPU/D2H work.

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
