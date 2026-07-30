# TDDFT GPU Performance Baseline

Last updated: 2026-07-30

## Official Baseline

- Logical step: Step 107
- Source implementation commit: `c46cfa9`
- Pinned-allocation build-mode commit: `9cbb6bc`
- Result record commit: `347718f`
- Diagnostics: off
- Compiler/backend: NVHPC + OpenACC + cuFFT
- Memory mode: `-gpu=mem:separate:pinnedalloc`
- Execution: 1 NVIDIA A100-PCIE-40GB, 1 MPI rank
- Case: Si111-H, 100 TDDFT time steps

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP107_SEPPOTF_BATCH_01` | 63.1300778389 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP107_SEPPOTF_BATCH_02` | 63.2335109711 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP107_SEPPOTF_BATCH_03` | 63.2135219574 | PASS | PASS |

Official three-run median: `63.2135219574` sec.
Run-to-run range: `0.1034331322` sec.

Step 107 is `0.6252970695` sec (`0.979493%`) faster than the former Step 102
median. All three runs passed both correctness gates.
Step 109 later proved that signed `NUMTY=12,-2` kept the proposed batched
SEPPOTF path inactive in these runs. The accepted gain is therefore attributed
to Step 107's bounded FRPRMN-to-ELECTF COEF residency change. Step 110 enabled
the batch path, was slower, and was rejected and restored in `d8ae16e`.

Step 113 screened `-O3`, `-Mipa=fast,inline`, and GPU `fastmath` against a
same-session standard build. All option archives matched that standard archive
under both relaxed and strict comparisons, with zero differences in the
reported observables. The best one-run result, `fastmath`, was only `0.281093%`
faster than its same-session control and remained `0.840562%` slower than this
official median. It therefore does not enter a three-run adoption gate, and
the standard flags and official baseline remain unchanged.

Step 114 compared the accepted `mem:separate:pinnedalloc` mode with whole-build
`mem:managed` and `mem:unified` variants. All three passed normal, relaxed, and
same-session pairwise strict correctness checks. Managed and unified took
`130.1395111080` and `130.4787569050` sec, respectively, versus the
`63.9251468182` sec same-session control. Their `103.581091%` and `104.111783%`
regressions reject both alternatives after one run. The accepted memory mode
and official Step 107 median remain unchanged.

## Step 86 Median-Wall Run 01 Profile

| timer | total_sec |
|---|---:|
| `time_step_total` | 66.691550 |
| `frprmn` | 57.683623 |
| `tmevl_total` | 51.100760 |
| `s2_nonlocal` | 11.416854 |
| `s2_nonlocal_make` | 1.327232 |
| `s2_nonlocal_gemm` | 10.065262 |
| `exnlp_gemm_dot` | 8.390635 |

## Comparison Policy

- Use `steps took ... sec` as the wall-time value.
- Performance decisions require three diagnostic-off runs and their median.
- A newer commit or a diagnostic/Nsight run is not a baseline automatically.
- Correctness requires both `check` and relaxed `compare` to pass for every run.
- An implementation without a median advantage is recorded and rolled back.

## Source-Level GPU Coverage History

For a reproducible source-based trend, define the OpenACC compute-site coverage
index as:

```text
NVHPC-selected TDDFT source OpenACC parallel/kernels construct starts
--------------------------------------------------------------------- * 100
Step 86 accepted-source construct starts (24)
```

This is a relative source-coverage index, not GPU utilization and not an
absolute percentage of every theoretically parallelizable loop. It does not
count cuFFT library internals, and it intentionally stays unchanged for
residency, allocation, vector-length, reuse, and transfer-boundary
optimizations that add no compute construct.

For a bounded time-step-loop estimate, the denominator is 39 currently
identified parallelizable compute sites: the 24 accepted Step 86 sites plus
the 15 still-unaccepted sites identified by the Step 78 temporary experiment.
This is a provisional absolute candidate-site coverage, not proof that all
theoretically parallelizable loops have been identified. It weights a small
control loop and a dominant array kernel equally.

| accepted step | compute sites | relative index | identified time-step candidate coverage |
|---:|---:|---:|---:|
| 21 | 11 | 45.8% | 28.2% |
| 22 | 11 | 45.8% | 28.2% |
| 23 | 11 | 45.8% | 28.2% |
| 24 | 11 | 45.8% | 28.2% |
| 25 | 11 | 45.8% | 28.2% |
| 28 | 12 | 50.0% | 30.8% |
| 33 | 16 | 66.7% | 41.0% |
| 34 | 16 | 66.7% | 41.0% |
| 36 | 16 | 66.7% | 41.0% |
| 37 | 16 | 66.7% | 41.0% |
| 41 | 16 | 66.7% | 41.0% |
| 52 | 17 | 70.8% | 43.6% |
| 57 | 18 | 75.0% | 46.2% |
| 62 | 18 | 75.0% | 46.2% |
| 67 | 18 | 75.0% | 46.2% |
| 74 | 18 | 75.0% | 46.2% |
| 80 | 19 | 79.2% | 48.7% |
| 82 | 20 | 83.3% | 51.3% |
| 86 | 24 | 100.0% | 61.5% |
| 98 | 26 | 108.3% | 66.7% |
| 99 | 26 | 108.3% | 66.7% |
| 102 | 26 | 108.3% | 66.7% |

Regenerate this table with `tools/report_tddft_source_gpu_index.sh`.

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

Step 65 split that legacy scope. Its `70.3901228905` sec diagnostic wall passed
both checks and is not a baseline. OpenACC kernel plus D2H used `1.872989` sec
(`97.5411%`), while host and VPP2 zeroing together used only `0.039393` sec.

Step 66 separated GPU completion from D2H. Its `68.8903579712` sec diagnostic
wall passed both checks and is not a baseline. The VPJ kernel used `1.831545`
sec (`97.0896%` of its parent), while D2H used only `0.047825` sec.

Step 67 run 01 with VPJ vector length 128 passed both checks at
`68.4441161156` sec. It is only `0.188650%` below the official median and the
difference is smaller than the official run range, so Step 62 remains the
baseline until all three Step 67 runs are classified.

All three Step 67 runs passed both checks. The `68.3616518974` sec median is
`0.2118279934` sec (`0.308907%`) faster than Step 62 with a
`0.2041001320` sec range. The slowest Step 67 run is still `0.0436298847` sec
faster than the fastest Step 62 run, so the observed distributions do not
overlap. Step 67 supersedes Step 62 as the official baseline.

Step 68 tested VPJ vector length 64. Run 01 passed both checks but took
`68.7983009815` sec, a `0.638734%` regression from Step 67 and more than twice
the accepted run range. The remaining runs were skipped, the change was
rejected, and vector length 128 was restored.

Step 69 tested grouped OpenACC EXTAU preparation. Run 01 passed both checks but
took `69.0177049637` sec, `0.959680%` slower than Step 67 and `3.2144x` the
accepted run range. Runs 02/03 were skipped and the host EXTAU source was
restored. Step 67 remains the official baseline.

Step 70 re-profiled the restored current source. Its `71.0379288197` sec trace
wall passed both checks but is not a baseline. Aggregate CUDA kernels were
about `13.96` sec (`19.65%`), H2D plus D2H device time was `3.230806864` sec,
CUDA stream plus event synchronization was `17.372092065` sec, and MPI had no
rows. Step 67 remains the official baseline.

Step 74 reuses band-independent YLM preparation within each k-point while
preserving the first preparation and all coefficient-dependent NONLOC work.
All three runs passed both checks. Its `68.0681188811` sec median is
`0.2935330163` sec (`0.429383%`) faster than Step 67, with a
`0.0546169281` sec range. Every Step 74 run is faster than the fastest Step 67
run, so Step 74 supersedes Step 67 as the official baseline.

Step 78 temporarily offloaded several remaining data-parallel host-loop
candidates together. Its single diagnostic-off run passed both checks but took
`68.3785300255` sec, `0.3104111444` sec (`0.456030%`) slower than the Step 74
median and `5.6834x` the Step 74 run range. Runs 02/03 were skipped and the
temporary implementation was reverted. Step 74 remains the official baseline.

Step 80 offloads only the active LDA S2VXC2 independent grid-point loop,
copying RHO in and VCSR out while preserving its formulas, branches, caller
FFT/Hartree work, MPI, and CPU/FFTW path. All three runs passed both checks.
Its `67.4207620621` sec median is `0.6473568190` sec (`0.951043%`) faster than
Step 74, with a `0.2123961449` sec range. Step 80 supersedes Step 74 as the
official baseline.

Step 81 re-ran the broad FRPRMN timers on accepted Step 80 source. It passed
both checks; its `68.5029249191` sec wall is diagnostic only. The FRPRMN
residual was `7.878776` sec, of which `7.833973` sec (`99.4313%`) was
classified and `0.044803` sec remained unclassified. VRHO fell from the
Step 75 value of `1.799974` to `1.173977` sec, a `0.625997` sec
(`34.7781%`) reduction consistent with the formal Step 80 wall improvement.

Step 82 replaces the OpenACC host COEF-to-COEF0 seed copy and COEF0 H2D with
a device-local copy at the existing predictor-corrector data entry. All three
runs passed both checks. Its `66.6539101601` sec median is
`0.7668519020` sec (`1.137412%`) faster than Step 80, with a
`0.2699508667` sec range. Step 82 supersedes Step 80 as the official baseline.

Step 86 keeps HLOCAL zero, scatter, both cuFFTs, local-potential multiply, and
gather in one temporary device data region while preserving the CPU/FFTW path.
All three runs passed both checks. Its `66.5019950867` sec median is
`0.1519150734` sec (`0.22791%`) faster than Step 82, with a
`0.2952189446` sec range. Step 86 supersedes Step 82 as the official baseline.

## H100 Cross-Device Observation

One user-operated Step 80 run on an NVIDIA H100 reported
`36.492636919` sec and passed both correctness checks. This is `1.847517x`
the throughput of the A100 Step 80 median, or a `45.873295%` wall reduction.
It is not a formal H100 baseline because only one run is available and the
exact H100 model, Git revision, compiler version, and GPU architecture target
were not captured. The official baseline above remains A100-only.

Step 115 will replace this incomplete observation with a controlled H100
baseline candidate using the latest accepted numerical path, an explicit
`cc90` build, `mem:separate:pinnedalloc`, diagnostics off, and three Si111-H
100-step runs. It records exact provenance and a device-specific median and
range. Even if accepted, that result remains an H100-only baseline and does not
replace or mix with the A100 Step 107 series.

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
