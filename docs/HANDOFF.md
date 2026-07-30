# TDDFT OpenACC GPU Handoff

Last updated: 2026-07-30

## Current State

- Branch: `tddft-openacc-residency`
- Accepted source baseline: `c46cfa9` (bounded FRPRMN-to-ELECTF COEF residency;
  the proposed SEPPOTF batch path was inactive for the tutorial input)
- Accepted GPU build mode: `9cbb6bc` with `ENABLE_PINNED_ALLOC=1`
- Required current A100 NVHPC TDDFT flags: `-O2 -acc -gpu=cc80 -gpu=mem:separate:pinnedalloc -mp -Msave -Mlarge_arrays`
- Required current H100 NVHPC TDDFT flags: `-O2 -acc -gpu=cc90 -gpu=mem:separate:pinnedalloc -mp -Msave -Mlarge_arrays`
- Accepted result record: `347718f`
- Current configuration: accepted Step 107 numerical path with Step 37 pinned
  allocation mode
- Current source implementation: Step 107 commit `c46cfa9`
- Rejected Step 45 implementation: `da24adf`
- Step 45 rollback: `c406a4a`
- Validated diagnostic implementation: Step 46 `edfafed` plus enforcement
  commit `3e2c630`
- Rejected Step 47 implementation: `0252da9`
- Step 47 and Step 46 source rollback: `35f8542`
- H100 baseline-adoption record: `7fc0c6d`
- Current HEAD source status: the numerical path matches accepted Step 107
  source `c46cfa9`; Step 110 and Step 112 are rejected and restored
- Rejected Step 31 implementation: `f8b6188`
- Step 31 rollback: `8ef55bb`
- Official A100 baseline: Step 107 median `63.2135219574` sec
- Official H100 baseline: Step 115 median `34.1089649200` sec, range
  `0.0905621052` sec, explicitly approved by the user on 2026-07-30
- Pending human-operated GPU action: none
- PowerPoint-ready GPU implementation summary:
  `docs/POWERPOINT_GPU_IMPLEMENTATION_SUMMARY_JA.md`

Step 31 reused `GDUMP1..5` mappings across the five TMEVL kinetic stages. All
three runs passed correctness, but the median was `129.250354052` sec, about
`0.1355%` slower than Step 28. It was rejected and rolled back.

Step 32 commit `13f9e98` added measurement-only timers around the density
rebuild after TMEVL. Run 01 passed both correctness checks. `RHOOFK` took
`14.509684` sec over 472 calls, `RHOGET` took `0.440581` sec, and the preceding
944 `tmevl_p_exit` operations took `2.819788` sec. `SUMCHR` was inactive because
`NPFL=0`.

Step 33 commit `b2a43c9` replaced only the post-TMEVL `RHOOFK` path with a
device scatter, batched cuFFT, and device density accumulation. All three runs
passed both correctness checks. The median was `116.124675989` sec, which is
`10.0335%` faster than Step 28. Run 01 reduced `frprmn_rhoofk` from the Step 32
value of `14.509684` sec to `0.729800` sec and reduced `fft_wrapper` calls from
43,949 to 14,685. The per-TMEVL full coefficient D2H remains intentionally.

Step 34 commit `83a030c` removed the per-TMEVL coefficient D2H and synchronizes
only before verified host consumers or at FRPRMN exit. All three runs passed
both correctness checks. The median was `113.561361074` sec, `2.2074%` faster
than Step 33. Run 01 replaced 944 `tmevl_p_exit` operations with 103
`frprmn_coef_sync` operations taking `0.638588` sec.

Step 35 traced the accepted Step 34 source revision `7567ae8` with Nsight
Systems. The diagnostic archive is
`nvhpc_cufft_1rank_02_STEP35_NSYS_01`; its `116.000924826` sec trace wall is
not a performance baseline. Both correctness checks passed. H2D was 44,166
copies and `32,307.014` MB; D2H was 5,348 copies and `5,592.769` MB. Compared
with Step 30, this confirms reductions of 28,320 H2D copies / `13,918.755` MB
and 30,105 D2H copies / `24,461.806` MB.

Step 36 commit `24e1cc3` reduced the `work2_` leading dimension from `NGcont`
to the maximum `NGNL` among active atom types. It does not change the number
of updates, equations, or sequential `ia` order. All three runs passed both
correctness checks. The median was `113.083628893` sec, `0.4207%` faster than
Step 34. In run 01, `exnlp_work1_enter` fell from the Step 34 run-01 value of
`4.040431` sec to `3.759735` sec, and `s2_nonlocal` fell from `14.055285` sec
to `13.758056` sec.

Step 37 commit `9cbb6bc` added an optional, default-off NVHPC pinned-allocation
build mode. The accepted GPU build uses `ENABLE_PINNED_ALLOC=1`, which adds
`-gpu=mem:separate:pinnedalloc` while retaining separate host/device memory.
All three runs passed both correctness checks. The median was `108.096301079`
sec, `4.4103%` faster than Step 36. Run 01 reduced `exnlp_work1_enter` from
`3.759735` to `1.542147` sec and `tmevl_total` from `55.183834` to
`51.654634` sec.

Step 38 traced the accepted pinned build at revision `643e639`. Both
correctness checks passed; its `110.78916502` sec wall is diagnostic only.
H2D was 44,166 copies / `31,234.025` MB / `1.272192545` sec, and D2H was 5,348
copies / `5,592.769` MB / `0.440373299` sec. Relative to Step 35, pinned
allocation reduced H2D time by `74.6861%` and D2H time by `46.9758%` without
changing copy counts. The `work2_` update fell from `3.728488477` to
`1.617571795` sec. The fused kernel remained effectively unchanged at
`8.311268224` sec versus the corrected Step 35 value of `8.302662687` sec.

Step 39 profiled one `exnlp_gemm_body_fused_2399_gpu` launch with Nsight
Compute 2026.1.0. The two-step diagnostic archive is
`nvhpc_cufft_1rank_02_STEP39_FUSED_NCU_01`; its `11.1839032173` sec wall is not
a performance baseline. The normal check passed; relaxed compare was not run.
The launch used a 32-block grid, 256 threads/block, and 63 registers/thread,
with `12.5%` achieved occupancy and `0.07` waves/SM on the 108-SM A100.

Step 40 implementation `ea81633` split the fused nonlocal kernel into explicit
forward and reverse routines while preserving each phase's sequential `ia`
order. The CPU/FFTW full link passed, and all three diagnostic-off A100 runs
passed normal check and relaxed compare. Their wall median was
`107.751713037` sec, but the targeted `exnlp_gemm_dot` median regressed to
`8.545724` sec (`+1.2310%` versus Step 37 run 01) and `s2_nonlocal` regressed
to `11.571148` sec (`+0.7134%`). The sub-1% wall difference is not supported
by the target timer, so Step 40 is rejected and does not replace Step 37.
Implementation `ea81633` was reverted by `0726e26`; the CPU/FFTW fallback full
link passed after rollback.

Step 41 implementation `4aaa33c` keeps the read-only `J2G` and `OCC` metadata
resident across the time-step loop. It replaces repeated `copyin` clauses in
S2 and batched RHOOFK with `present` lookups without changing equations,
kernel structure, or sequential `ia` order. The CPU/FFTW fallback full link
passed. After an explicit diagnostic-off rebuild, three A100 runs (`_02` to
`_04`) all passed normal check and relaxed compare. Their median was
`107.754213095` sec, `0.342087984` sec (`0.3165%`) faster than Step 37, with a
`0.065072060` sec range. The earlier `_01` run at `115.517135143` sec remains
recorded as a pre-rebuild provenance anomaly and is not part of the controlled
three-run series.

Step 48 re-profiled the restored Step 41 source at revision `adf4d5b`. The
diagnostic archive `nvhpc_cufft_1rank_02_STEP48_STEP41_NSYS_01` passed normal
check and relaxed compare; its `110.223116875` sec wall is not a baseline. H2D
fell from Step 38's 44,166 calls / `31,234.025` MB to 37,560 calls /
`30,576.426` MB, while D2H remained 5,348 calls / `5,592.769` MB. CUDA API
time was dominated by synchronization, but the summaries do not isolate the
FRPRMN residual from TMEVL. In-run MPI collectives totaled only `0.260338098`
sec, about `0.55%` of the `47.476614` sec residual; allocation/free activity
was negligible. The next bounded diagnostic times COEF setup, GDUMP
preparation, `Part1to5`, and EXTAU preparation. It is compile-time off by
default and is measurement only.

Step 49 measured the FRPRMN host preparation at tested revision `fe7cbd1`.
Archive `nvhpc_cufft_1rank_02_STEP49_FRPRMN_TIMERS_01` passed normal check and
relaxed compare; its `107.879790783` sec wall is diagnostic only. The FRPRMN
residual outside TMEVL was `47.519384` sec, of which `frprmn_part1to5` consumed
`36.452430` sec (`76.71%`). The measured components account for `83.34%` of
the residual. Step 48 limits all in-run MPI collectives to `0.260338098` sec,
so the dominant `Part1to5` time is host computation with corresponding GPU
idle. The next diagnostic splits its 1,000 `GETYLM` and 1,000 `VPJ_GEN` calls
into GETYLM, CPU radial integration, MPI all-reduction, and host post-reduction
processing. No optimization has been selected.

Step 50 archive `nvhpc_cufft_1rank_02_STEP50_PART1TO5_TIMERS_01` passed normal
check and relaxed compare at revision `6bc6770`; its `107.682908058` sec wall
is diagnostic only. `Part1to5` was `36.310625` sec and its 1,000 `GETYLM`
calls totaled only `0.057162` sec. The internal `VPJ_GEN` timers accidentally
included calls from TMEVL as well as `Part1to5`, producing an impossible
`70.229142` sec child value against the `36.310625` sec intended parent. Those
VPJ_GEN CPU/post values are excluded from attribution. Their combined MPI
value was only `0.075660` sec and remains a valid upper bound. Step 51 changes
only diagnostic scoping so TMEVL calls do not enter the internal timers; normal
builds retain the original argument list after preprocessing.

Step 51 archive `nvhpc_cufft_1rank_02_STEP51_PART1TO5_SCOPED_01` passed normal
check and relaxed compare at revision `c880d0c`. Its `108.201426983` sec wall
is diagnostic only. The corrected `Part1to5` scope measured `36.132464` sec in
the VPJ_GEN CPU radial integral, `0.037303` sec in MPI all-reduction, and
`0.060445` sec in host post-reduction. The children account for `36.284148` of
the `36.306091` sec parent. CPU computation therefore explains `99.52%` of
`Part1to5` and `75.99%` of the `47.546135` sec FRPRMN residual, with matching
GPU idle; MPI is negligible.

Step 52 is one bounded optimization hypothesis: only `Part1to5` VPJ_GEN radial
integration is parallelized across G vectors on the GPU. Each G vector retains
the original sequential radial accumulation order, the host MPI boundary is
unchanged, and TMEVL retains the original CPU path. Static pseudopotential
tables remain resident across the time-step loop; five phase G arrays share a
single data region per `Part1to5` call; the contiguous VPJWORK result returns
to the host immediately before MPI. Diagnostics are off for performance runs.
Run 01 is the correctness gate; runs 02 and 03 are allowed only after it passes.

Step 52 runs 01 through 03 all passed normal check and relaxed compare at
revision `22aad92`. Their walls were `72.9733359814`, `73.4374880791`, and
`73.4901540279` sec. The median is `73.4374880791` sec with a
`0.5168180465` sec range, `31.8472%` faster than Step 41. In the median run,
`frprmn` was `64.618912` sec and `tmevl_total` was `51.468926` sec, leaving a
`13.149986` sec residual. Step 52 is the official baseline.

The 32-band tutorial is the smallest operational case expected. A dedicated
smaller-band multi-gang path is out of scope. The current one-gang-per-band path
expands naturally with local band count, so shared bottlenecks should be
validated on medium or production-sized inputs rather than inferred only from
the tutorial occupancy.

## Performance Direction and Next Task Boundary

The governing performance objective is no longer to offload isolated routines
one by one. It is to keep the GPU busy for longer intervals by extending bulk
device ownership across FRPRMN, TMEVL, and only where justified ELECTF. Large
arrays should cross the host/device boundary at the time-step-loop entrance,
at verified MPI or host-consumer boundaries, and at required output points.
Small convergence scalars may remain on the host. CPU/FFTW fallback code stays
intact.

Two different utilization estimates must not be conflated:

- Step 41 run 02 places `51.442021` of `108.026444` sec (`47.620%`) in the
  GPU-dominant TMEVL region. Including known accelerated density work gives a
  conservative algorithmic GPU coverage of about `48%`; unseparated mixed
  work makes a practical range of roughly `48-55%` reasonable.
- Step 48 Nsight Systems measured the fused kernel at `8.312052815` sec and
  `66.6%` of CUDA kernel time, implying about `12.48` sec of aggregate CUDA
  kernel execution, or about `11.3%` of its `110.223116875` sec trace wall.
  H2D and D2H took `2.637303759` and `0.440437627` sec, respectively. These
  durations may overlap and are diagnostic, not an additive performance
  baseline.

The gap between approximately 48% GPU-dominant algorithm coverage and only
about 11% aggregate kernel duration points to host preparation, fine-grained
launches, synchronization, runtime calls, low-parallelism launches, and GPU
idle intervals as the primary class of bottleneck. Direct copy duration alone
is not the dominant wall-time cost, although Step 48 still recorded 37,560 H2D
and 5,348 D2H operations. Reducing their count can remove runtime and
synchronization boundaries in addition to bytes.

Steps 49 through 51 completed the FRPRMN decomposition and Step 52 removed its
dominant CPU integral from the host critical path. The immediate task is a
diagnostic-only Nsight Systems trace of the accepted Step 52 source. Recompute
kernel, transfer, runtime/API, synchronization, MPI, and GPU-idle shares before
selecting another optimization. Do not use trace wall as a baseline.
Use the committed one-command helper `tools/run_tddft_step53_nsys.sh`; it emits
the bounded terminal evidence required for photograph-only return.

Step 53 archive `nvhpc_cufft_1rank_02_STEP53_STEP52_NSYS_01` passed both
correctness checks at revision `84a7af8`; its `76.0769960680` sec wall is
diagnostic only. The trace measured the new VPJ kernel at `1.793293070` sec
over 2,000 launches and aggregate CUDA kernels at about `14.26` sec. H2D was
38,564 calls / `30,745.626` MB / `2.565299787` sec; D2H was 7,348 calls /
`5,846.065` MB / `0.466224230` sec. The exact +1,004 H2D and +2,000 D2H call
increments from Step 48 match the Step 52 mappings and VPJ result downloads.

The trace FRPRMN residual was `13.608745` sec. Subtracting the VPJ kernel leaves
an `11.815452` sec envelope containing CPU/host orchestration and unresolved
waits. MPI remains negligible by the Step 48 whole-run `0.260338098` sec bound
and Step 51 scoped `0.037303` sec value; Step 53's MPI report was empty. CUDA
API synchronization is large but overlaps the complete trace: stream and event
synchronization total `17.613188385` sec, and VPJ OpenACC wait is
`1.816791731` sec. Aggregate kernel share is only about `18.7%` of trace wall.

The immediate next task is the single Step 54 diagnostic run, not optimization.
Use `tools/run_tddft_step54.sh`; it builds only TDDFT, runs the 100-step case,
archives it, checks correctness, and prints the complete photograph-sized
timer summary. The added timers are compile-time off unless explicitly enabled
by this helper. They split Vloc preparation, density/potential mixing,
energy/expectation work, initial density, iteration initialization, pre/post
TMEVL work, density initialization, and exit-data cleanup. Predictor/corrector
control is the remaining unaccounted residual.

Step 54 archive `nvhpc_cufft_1rank_02_STEP54_FRPRMN_HOST_TIMERS_01` passed
normal check and relaxed compare at revision `e44a602`; its `74.2483499050`
sec wall is diagnostic only. The FRPRMN residual outside TMEVL was
`13.094395` sec. Its components total `13.084581` sec (`99.9251%`), leaving
only `0.009814` sec unaccounted. The leading envelopes are
`frprmn_vrho_mix` `3.923983` sec, `frprmn_vloc_prepare` `2.940147` sec,
`frprmn_part1to5` `2.135653` sec, `frprmn_extau_prepare` `1.452314` sec,
and `frprmn_energy_diag` `0.902628` sec.

The next bounded task is Step 55 diagnostic timing, not optimization. Split
only `frprmn_vrho_mix` into VOFRHO, smoothing/FFT, and
interpolation/convergence. VRHO contains host loops and a cuFFT-backed
transform, so its full Step 54 wall is not a pure CPU measurement.

Step 55 diagnostic code and `tools/run_tddft_step55.sh` are ready. The helper
prints only `time_step_total`, `frprmn`, `tmevl_total`, the VRHO parent, and
the three exclusive child rows so the complete evidence fits in one photo.

Step 55 archive `nvhpc_cufft_1rank_02_STEP55_VRHO_TIMERS_01` passed both
correctness checks at revision `5d6d71b`; its `74.3233120441` sec wall is
diagnostic only. The VRHO parent was `3.943543` sec. Its exclusive children
were VOFRHO `0.937779` sec, smoothing/FFT `0.161545` sec, and host
interpolation/convergence/control `2.841719` sec. The children cover
`99.9366%` of the parent. Host control therefore accounts for `72.0600%` of
VRHO, while smoothing/FFT is only `4.0964%`; VRHO is host-dominated.

The next bounded task is Step 56 diagnostic timing, not optimization. Split
the Step 54 `frprmn_vloc_prepare=2.940147` sec envelope into LOCPOT,
smoothing/FFT, and remaining interpolation/Vloc-generation work.

Step 56 diagnostic code and `tools/run_tddft_step56.sh` are ready. It directly
times aggregate LOCPOT and smoothing/cuFFT work and prints the remaining Vloc
work as the parent minus those two children.

Step 56 archive `nvhpc_cufft_1rank_02_STEP56_VLOC_TIMERS_01` passed both
correctness checks at revision `ea13406`; its `73.4618239403` sec wall is
diagnostic only. Vloc preparation was `2.947276` sec: LOCPOT `2.764985` sec
(`93.8149%`), smoothing/cuFFT `0.152869` sec (`5.1868%`), and all remaining
Vloc work `0.029422` sec (`0.9983%`). LOCPOT contains no GPU work. The Step 48
whole-run MPI bound leaves at least about `2.504647` sec attributable to host
computation/orchestration, with corresponding GPU idle.

The next bounded hypothesis is allowed to be an optimization: parallelize only
LOCPOT across G vectors while preserving the original ITY/K/IA accumulation
order within each G vector and the host MPI boundary. This is distinct from
the rejected Step 42 Vloc-residency form. Require diagnostic-off check and
compare PASS followed by a three-run median before adoption.

Step 57 implements that bounded hypothesis. The OpenACC path assigns one GPU
thread to each nonzero G vector, retains its serial ITY/K/IA accumulation, and
copies the local result back before the original host MPI Allreduce. G=0 stays
on the host; the CPU/FFTW loop nest is unchanged; no Vloc residency is added.
All three Step 57 runs passed both correctness checks. Their walls were
`71.2373509407`, `71.2909028530`, and `71.3753330708` sec. The median is
`71.2909028530` sec with a `0.1379821301` sec range, `2.9230%` faster than
Step 52. Median `frprmn` fell by `2.117284` sec and its residual outside TMEVL
fell by `2.660213` sec, while `exnlp_gemm_dot` remained stable. Step 57 is the
official baseline.

The immediate next task is diagnostic only: use the committed one-command
helper `tools/run_tddft_step58_nsys.sh` to collect one Nsight Systems trace
of the accepted Step 57 source and compare its LOCPOT kernel, kernel total,
H2D/D2H, runtime/API, synchronization, MPI, and GPU-idle structure with Step
53. Do not select another optimization before that classification, and do not
use trace wall as a performance baseline.

Step 58 archive `nvhpc_cufft_1rank_02_STEP58_STEP57_NSYS_01` passed both
correctness checks at revision `797ba4f`; its `74.2175440788` sec wall is
diagnostic only. Aggregate CUDA kernels were about `14.29` sec, with the fused
kernel at `8.304842909` sec and VPJ at `1.793326009` sec. Relative to Step 53,
H2D increased by 6,756 calls / `844.619` MB / `0.183726804` sec and D2H by
606 calls / `281.417` MB / `0.024563386` sec. The D2H count exactly matches
six LOCPOT result downloads over 101 FRPRMN calls. MPI again had no rows.

The LOCPOT kernel was not separately identifiable in the returned top summary.
The immediate next task is one Step 59 diagnostic using
`tools/run_tddft_step59.sh`. It enables the existing timers to measure the
current accepted-source LOCPOT envelope directly. Do not change algorithms or
data ownership and do not use its wall as a baseline.

Step 59 archive `nvhpc_cufft_1rank_02_STEP59_LOCPOT_TIMERS_01` passed both
correctness checks at revision `03ec9bd`; its `71.1150200367` sec wall is
diagnostic only. Current-source LOCPOT was `0.305052` sec, down `2.459933` sec
(`88.9673%`) from Step 56. Vloc preparation fell from `2.947276` to
`0.484717` sec. LOCPOT is now only `2.8533%` of the current FRPRMN residual,
directly confirming the Step 57 hypothesis.

The next bounded task is diagnostic Step 60. The existing VRHO host-control
parent is split into exclusive seed/coefficient-copy, predictor/extrapolation,
and corrector/interpolation/convergence timers. Use
`tools/run_tddft_step60.sh`; do not implement an optimization before its result.

Step 60 archive `nvhpc_cufft_1rank_02_STEP60_VRHO_CONTROL_01` passed both
correctness checks at revision `fad4d11`; its `70.9675290585` sec wall is
diagnostic only. Of `2.787119` sec in VRHO host control, corrector work used
`2.215861` sec (`79.5036%`), seed/coefficient copy used `0.552540` sec, and
predictor work used only `0.016408` sec. The three children cover `99.9171%`.

The next bounded task is diagnostic Step 61. Split only corrector work into
interpolation arithmetic, convergence calculation, and failed-correction
COEF/VGOLD restoration. Use `tools/run_tddft_step61.sh` and do not implement
an optimization before its result.

Step 61 archive `nvhpc_cufft_1rank_02_STEP61_VRHO_CORRECTOR_01` passed both
correctness checks at revision `817b955`; its `71.7462480068` sec wall is
diagnostic only. Of the `2.240276` sec corrector parent, COEF/VGOLD restoration
used `2.158536` sec (`96.3513%`), interpolation used `0.057358` sec, and
VGCONV used `0.014480` sec. The children cover `99.5580%`.

Source ownership shows that the large host COEF0-to-COEF copy is dead on the
OpenACC failed-correction path: device `COEF0` remains authoritative and the
next correction already restores device `COEF` locally. Step 62 omits only
that host copy under `_OPENACC`; CPU/FFTW, VGOLD, device restart, MPI, and
arithmetic order remain unchanged. Use `tools/run_tddft_step62.sh 01` first.

Step 62 run 01 archive `nvhpc_cufft_1rank_02_STEP62_SKIP_HOST_COEFCP_01`
passed both correctness checks at revision `7475ccb`. Its wall was
`68.66669352055` sec, `2.62420933245` sec (`3.6810%`) below the accepted
Step 57 median. This is promising but not yet accepted; collect runs 02 and 03
with `tools/run_tddft_step62.sh 02-03` and decide from the three-run median.

Runs 02 and 03 also passed both correctness checks at `68.4877460003` and
`68.5734798908` sec. The three-run median is `68.5734798908` sec with a
`0.17894752025` sec range. This is `2.7174229622` sec (`3.811739%`) faster than
Step 57, so Step 62 is accepted as the official source and performance
baseline. The median-wall run's FRPRMN residual is `8.386479` sec, down
`2.103294` sec from Step 57 and consistent with the removed restore envelope.

Step 63 archive `nvhpc_cufft_1rank_02_STEP63_CURRENT_FRPRMN_01` passed both
checks at revision `16cea8a`; its `68.9920969009` sec wall is diagnostic only.
The FRPRMN residual was `8.547452` sec and the broad exclusive envelopes covered
`99.5381%`. The largest were `part1to5=2.137278` sec (`25.0049%`),
VRHO mix `1.801928` sec, EXTAU preparation `1.468457` sec, and energy diagnostic
`0.933094` sec. The next bounded task is measurement-only: re-run the existing
`part1to5` child timers on accepted Step 62 source before choosing an
optimization.

Use `tools/run_tddft_step64.sh` once for that measurement. It is a thin wrapper
over the already validated default-off diagnostic and prints the parent plus
GETYLM, VPJ integral, MPI all-reduce, and post-reduction rows. Do not implement
an optimization before this result is classified.

Step 64 archive `nvhpc_cufft_1rank_02_STEP64_CURRENT_PART1TO5_01` passed both
checks at revision `f69aeac`; its `68.8858208656` sec wall is diagnostic only.
The `2.140208` sec parent was `97.8140%` covered: GETYLM `0.054554` sec, the
legacy-named VPJ integral scope `1.910793` sec, MPI `0.039413` sec, and
post-reduction `0.088664` sec. The `1.910793` sec scope includes host zeroing,
VPP2 setup, GPU integral, and D2H synchronization. Split those components with
measurement-only Step 65 before selecting an optimization.

Step 65 adds only compile-time default-off timers for host VPJWORK/VPJ zeroing,
VPP2 zeroing, and OpenACC integral-kernel-plus-D2H time. Use
`tools/run_tddft_step65.sh` once, require both checks, and do not use its wall
as a performance baseline.

Step 65 archive `nvhpc_cufft_1rank_02_STEP65_VPJ_INTEGRAL_SPLIT_01` passed both
checks at revision `2c6227f`; its `70.3901228905` sec wall is diagnostic only.
Of the `1.920204` sec parent, host zeroing used `0.037640` sec, VPP2 zeroing
`0.001753` sec, and OpenACC kernel plus D2H `1.872989` sec (`97.5411%`). Host
initialization is not a useful optimization target. Step 66 should split kernel
completion from D2H at the existing synchronous update boundary, with no
diagnostic-off change.

Step 66 adds two default-off children inside the existing kernel-plus-D2H
parent. Its explicit wait exists only in the diagnostic build and is placed at
the already synchronous host update boundary. Use `tools/run_tddft_step66.sh`
once and require both checks before choosing a kernel or transfer hypothesis.

Step 66 archive `nvhpc_cufft_1rank_02_STEP66_VPJ_KERNEL_D2H_01` passed both
checks at revision `25ede22`; its `68.8903579712` sec wall is diagnostic only.
Of the `1.886449` sec parent, GPU kernel completion used `1.831545` sec
(`97.0896%`) and D2H only `0.047825` sec. The next bounded performance
hypothesis changes only the VPJ kernel vector length from 256 to 128, preserving
radial accumulation order, equations, ownership, D2H, and MPI. Use the normal
diagnostic-off three-run adoption gate against Step 62.

Step 67 implements exactly that one-parameter hypothesis. Run
`tools/run_tddft_step67.sh 01` first. If both checks pass, use
`tools/run_tddft_step67.sh 02-03` for the remaining two runs. Compare the
three-run median with `68.5734798908` sec and revert if no advantage is
supported.

Step 67 run 01 archive `nvhpc_cufft_1rank_02_STEP67_VPJ_VL128_01` passed both
checks at revision `39a181e` and took `68.4441161156` sec. It is
`0.1293637752` sec (`0.188650%`) below the Step 62 median, but that difference
is smaller than the Step 62 run range. The result is inconclusive; collect runs
02/03 without changing the tested revision and decide from the median.

Runs 02 and 03 also passed both checks at `68.2400159836` and
`68.3616518974` sec. The three-run median is `68.3616518974` sec with a
`0.2041001320` sec range, `0.308907%` faster than Step 62. The slowest Step 67
run is faster than the fastest Step 62 run, so Step 67 is accepted as the new
official source and performance baseline.

Step 68 continues the same bounded one-parameter search by changing only VPJ
vector length 128 to 64. Run `tools/run_tddft_step68.sh 01` first, then
`tools/run_tddft_step68.sh 02-03` only after both checks pass. Compare against
the Step 67 median `68.3616518974` sec and revert if unsupported.

Step 68 run 01 archive `nvhpc_cufft_1rank_02_STEP68_VPJ_VL64_01` passed both
checks but took `68.7983009815` sec, `0.4366490841` sec (`0.638734%`) slower
than Step 67 and `2.1394x` the accepted run range. Runs 02/03 were intentionally
skipped. Step 68 is rejected and VPJ vector length is restored to 128; Step 67
remains the official baseline.

Step 69 is a bounded EXTAU preparation hypothesis selected from the current
Step 63 residual classification. Under OpenACC only, it computes the five
independent phase tables on the GPU inside one grouped data region. G21..G25
and TAU1..TAU5 are copied in once per preparation and EXTAU is copied out once
for the unchanged host TMEVL consumer. It does not extend device ownership to
`work2_`, alter MPI, or change the CPU/FFTW loops. Run
`tools/run_tddft_step69.sh 01` first and stop after a clear regression;
otherwise collect 02/03 with the combined helper command.

Step 69 run 01 passed both checks at revision `d5e76b7` but took
`69.0177049637` sec. This is `0.6560530663` sec (`0.959680%`) slower than the
Step 67 median and `3.2144x` its run range. Although the FRPRMN residual was
`0.546599` sec lower, the complete wall regressed, so runs 02/03 were skipped
and the accepted host EXTAU source was restored. Step 67 remains the baseline.
Next, re-profile the restored current source with Nsight Systems before another
optimization.

Step 70 is that measurement-only current-source trace. Run
`tools/run_tddft_step70_nsys.sh` once. It builds only TDDFT with source timers
off, profiles CUDA/OpenACC/NVTX/OSRT/MPI, archives and checks the result, and
prints the first ten rows of each summary for photograph-only return. Its wall
is diagnostic and must not replace the Step 67 baseline.

Step 70 passed both checks at revision `d596361`. Its `71.0379288197` sec trace
wall is diagnostic only. Aggregate CUDA kernels were about `13.96` sec
(`19.65%`), led by the unchanged fused nonlocal kernel at `8.247974033` sec
(`59.1%`) and the VPJ kernel at `1.574436754` sec (`11.3%`). H2D plus D2H
device time was `3.230806864` sec; stream plus event synchronization was
`17.372092065` sec and overlaps other work. MPI had no rows. Because Step 39
already identified the fused kernel's 32-block tutorial occupancy constraint,
do not repeat that NCU form. Split current `frprmn_energy_diag` next.

Step 71 adds only default-off child timers for VG assembly, E-field work, and
initial/final expectation plus off-diagonal work. Use
`tools/run_tddft_step71.sh` once. It builds TDDFT only, runs and archives the
100-step case, requires both checks, and prints the parent, children, and gap
in one photograph-sized summary. Do not use its wall as a baseline.

Step 71 passed both checks at revision `b379f69`. Of the `0.871809` sec
`frprmn_energy_diag` envelope, expectation plus off-diagonal work consumed
`0.809350` sec (`92.84%`), VG assembly `0.054056` sec, E-field `0.004286` sec,
and the gap `0.004117` sec. Do not optimize the two small children. Step 72
adds default-off timers only to split the dominant expectation envelope into
diagonal HLOCAL, diagonal NONLOC, dot products, EE communication, and the
complete off-diagonal path. Run `tools/run_tddft_step72.sh` once.

Step 72 passed both checks at revision `10a1d50`. The `0.816429` sec
expectation envelope split into diagonal HLOCAL `0.239888` sec, diagonal
NONLOC `0.299706` sec, dot products `0.012768` sec, EE communication
`0.000014` sec, off-diagonal work `0.258875` sec, and a `0.005178` sec gap.
Do not optimize the dot or communication children. Step 73 adds default-off
timers only inside off-diagonal work for HLOCAL, NONLOC, matrix dots,
communication/copy, and gather/output. Run `tools/run_tddft_step73.sh` once.

Step 73 passed both checks at revision `6fdbecb`. Its `0.264491` sec
off-diagonal parent split into HLOCAL `0.080938` sec, NONLOC `0.099967` sec,
matrix dots `0.079395` sec, communication/copy `0.000005` sec,
gather/output `0.002409` sec, and a `0.001777` sec gap. Do not optimize
communication or output. Diagonal plus off-diagonal NONLOC is about
`0.399673` sec and repeats band-independent YLM preparation for every band.
The next bounded implementation should prepare YLM once per k-point while
preserving all coefficient-dependent NONLOC work.

Step 74 implements only that reuse hypothesis. NONLOC accepts an explicit
reuse flag; the first band at each k-point/event computes YLM and later bands
reuse it. All coefficient-dependent kinetic and SEPPOT work remains
unchanged. Use `tools/run_tddft_step74.sh 01` first, then `02-03` only after a
healthy first run. Require both checks and compare the three-run median with
the official Step 67 median `68.3616518974` sec.

All three Step 74 runs passed both checks at `68.1138920784`,
`68.0681188811`, and `68.0592751503` sec. The median is
`68.0681188811` sec with a `0.0546169281` sec range, improving on Step 67 by
`0.2935330163` sec (`0.429383%`). Every candidate run is faster than the
fastest Step 67 run, so Step 74 is the accepted source and official baseline.

Step 75 performs no optimization. It re-runs the broad FRPRMN timers on the
accepted Step 74 source and reports both residual and unclassified time in one
summary. Use `tools/run_tddft_step75.sh` once; its wall is diagnostic.

Step 75 passed both checks at revision `30c8623`. The current FRPRMN residual
was `8.203100` sec with only `0.039580` sec unclassified. The largest children
were Part1to5 `1.939650` sec, VRHO `1.799974` sec, and EXTAU preparation
`1.438920` sec. Part1to5 and EXTAU have rejected alternatives already. Re-run
the existing VRHO child timers on current accepted source before selecting
another implementation; Step 60/61 predate the Step 62 restore removal.

Step 76 performs that diagnostic-only current-source VRHO split. It reports
the existing timer rows 54, 62-64, and 67-72 plus parent, control, and
corrector nesting gaps. Use `tools/run_tddft_step76.sh` once; its wall is not a
performance baseline.

Step 76 passed both checks at revision `5a4b9c7`. Current VRHO was `1.762396`
sec: VOFRHO `0.956957`, smoothing/FFT `0.156599`, and control `0.646548` sec.
Control was dominated by seed `0.549649` sec; corrector was only `0.078602`
sec and coefficient restore only `0.002889` sec. Re-split VOFRHO before
selecting another implementation.

Step 77 adds default-off VOFRHO child timers for exchange-correlation, FFT,
Hartree zeroing, Hartree construction, and Hartree addition. Use
`tools/run_tddft_step77.sh` once; its wall is not a performance baseline.

Before running Step 77, Step 78 temporarily combined the remaining
data-parallel host-loop candidates to obtain a quick upper-bound result. It
offloaded EXTAU generation, VRHO array/control loops, energy expectation and
off-diagonal dot products, and convergence reduction while retaining host MPI
and scalar branch control. Archive
`nvhpc_cufft_1rank_02_STEP78_MAX_OFFLOAD_01` passed both checks at revision
`cc65c3c` but took `68.3785300255` sec. That is `0.3104111444` sec
(`0.456030%`) slower than the Step 74 median and `5.6834x` the accepted run
range. Runs 02/03 were skipped, and the complete temporary implementation and
helper were reverted in the result-record commit. Step 74 remains the official
baseline; the next bounded action remains the Step 77 diagnostic.

Step 77 subsequently passed both checks at revision `a371d4d`. Archive
`nvhpc_cufft_1rank_02_STEP77_VOFRHO_SPLIT_01` took
`69.1326959133` sec with diagnostics enabled, so its wall is not a baseline.
VOFRHO was `0.962422` sec: exchange-correlation `0.653802`, final FFT
`0.111733`, Hartree zeroing `0.013661`, Hartree construction `0.161106`,
Hartree addition `0.017956`, and gap `0.004164` sec. Exchange-correlation is
the dominant child at `67.9329%`.

Step 79 is a diagnostic-only split of G2VXC2 into derivative setup, nine
derivative FFTs, exchange, correlation, and final assembly. It changes no
equations, loops, FFT calls, MPI, ownership, or diagnostic-off execution. Run
`tools/run_tddft_step79.sh` once and use its child times to choose one bounded
ownership or compute hypothesis.

Step 79 archive `nvhpc_cufft_1rank_02_STEP79_XC_SPLIT_01` passed both checks
at revision `0f3b066`; its `69.1785750389` sec wall is diagnostic only.
VOFRHO was `0.960509` sec and XC was `0.655301` sec, but every G2VXC2 child
was inactive and the derived gap equaled the complete XC parent. The Si111-H
input therefore uses the LDA S2VXC2 branch, not G2VXC2. S2VXC2 is one
independent grid-point loop.

Step 80 tests only OpenACC offload of that active S2VXC2 loop, copying RHO in
and VCSR out while preserving formulas, branches, caller FFT/Hartree work,
MPI, and CPU/FFTW behavior. Run `tools/run_tddft_step80.sh 01` first. Run
`02-03` only after a healthy first result and decide from the diagnostic-off
three-run median against Step 74.

Step 80 runs 01/02/03 at revision `59686f0` all passed both checks and took
`67.4321370125`, `67.2197408676`, and `67.4207620621` sec. The median is
`67.4207620621` sec with a `0.2123961449` sec range, improving on Step 74 by
`0.6473568190` sec (`0.951043%`). The user approved adoption, so Step 80 is
the official baseline.

Step 81 makes no source optimization. It re-runs the existing broad exclusive
FRPRMN timers on the accepted Step 80 source to classify the current residual
before another hypothesis is selected. Run `tools/run_tddft_step81.sh` once;
its diagnostic wall is not a baseline.

Step 81 passed both checks at revision `ace5097`. Its diagnostic wall was
`68.5029249191` sec. The FRPRMN residual was `7.878776` sec, with
`7.833973` sec (`99.4313%`) classified and only `0.044803` sec unclassified.
The largest children were Part1to5 `1.947618`, EXTAU preparation `1.448376`,
VRHO `1.173977`, and energy diagnostic `1.118869` sec. VRHO was
`0.625997` sec (`34.7781%`) below the Step 75 value, directly supporting the
accepted S2VXC2 offload. Use `tools/show_tddft_step81_detail.sh` to print the
already-recorded VRHO and energy child rows before selecting another
implementation; it performs no build or rerun.

That detail showed VOFRHO `0.359571` sec, with XC reduced to `0.063268` sec
and the remaining FFT plus Hartree work accounting for nearly all of the
rest. XC fell by `0.590534` sec (`90.3231%`) from Step 77 and is no longer
the target. VRHO control is now larger at `0.657103` sec. Energy was
`1.118869` sec, including E-field `0.248282` and expectation `0.778436` sec.
E-field was only `0.004286` sec in Step 71 and includes host output work, so
first run `tools/show_tddft_step81_detail.sh control` to print the current
call counts and VRHO control split from the same archive. Do not rebuild or
rerun yet.

The control detail shows seed initialization at `0.562341` sec
(`85.5773%` of VRHO control), while predictor and corrector control are only
`0.016313` and `0.076263` sec. Step 82 tests only device-local
COEF-to-COEF0 initialization at the existing predictor-corrector data entry,
removing the OpenACC host seed copy and COEF0 H2D. It preserves per-sequence
lifetime and the CPU/FFTW copy, so it is distinct from rejected Step 45.
Run `tools/run_tddft_step82.sh 01` first.

Step 82 run 01 passed both checks at `66.8839480877` sec. This is
`0.5368139744` sec (`0.796215%`) faster than the official Step 80 median and
is close to the measured `0.562341` sec seed cost. It is promising but remains
one run. Next run `tools/run_tddft_step82.sh 02-03` and decide from the
three-run median.

Step 82 runs 02/03 also passed both checks at `66.6139972210` and
`66.6539101601` sec. The three-run median is `66.6539101601` sec with a
`0.2699508667` sec range, improving on Step 80 by `0.7668519020` sec
(`1.137412%`). Step 82 is the new official baseline. Next run the
diagnostic-only `tools/run_tddft_step83.sh` once to confirm the current VRHO
seed/control split; do not use its diagnostic wall as a baseline.

Step 83 passed both checks. Seed control fell from the Step 81 value
`0.562341` to `0.000497` sec (`99.9116%`), VRHO control fell from `0.657103`
to `0.103696` sec, and the VRHO parent fell from `1.173977` to `0.622439`
sec. This confirms the Step 82 mechanism. Next run only
`tools/show_tddft_step83_next.sh`; it reads the existing archive and performs
no build or rerun.

The Step 83 archive ranks Part1to5 at `1.941613` sec, EXTAU preparation at
`1.440404` sec, and energy at `0.847562` sec. The first two already regressed
in direct-offload forms because their immediate consumers remain on the host.
Step 84 instead removes one redundant host pass inside NONLOC kinetic-factor
setup without changing ownership or communication. Its three runs were
`66.7368218899`, `66.7220189571`, and `66.8331620693` sec; all passed both
checks, but the `66.7368218899` sec median is `0.124391%` slower than Step 82.
Step 84 is rejected and its source change is reverted.

Step 85 passed both checks. Across all 768 HLOCAL calls, zero was `0.013984`,
scatter `0.067270`, inverse FFT `0.128601`, local-potential multiply `0.040314`,
forward FFT `0.141528`, and gather `0.090866` sec. The `0.482563` sec total
includes 384 diagonal, 128 off-diagonal, and 256 TMEVL HLOCAL calls. The
original negative gap was only a helper attribution error and is corrected.

Step 86 keeps HLOCAL zero, scatter, both cuFFTs, local-potential multiply, and
gather inside one temporary device data region while keeping the CPU/FFTW path
unchanged. All three runs passed both checks at `66.5019950867`,
`66.6454100609`, and `66.3501911163` sec. The median is
`66.5019950867` sec with a `0.2952189446` sec range, improving on Step 82 by
`0.1519150734` sec (`0.22791%`). Step 86 is the accepted baseline.

Step 87 adds one diagnostic-only parent timer around the accepted device
HLOCAL path. Run `./tools/run_tddft_step87.sh` once on A100. Use its compact
summary to compare all 768 HLOCAL calls with the Step 85 host-staged total of
`0.482563` sec and derive the diagonal, off-diagonal, and TMEVL contributions.
Its wall time is diagnostic and must not replace the Step 86 median.

Step 87 passed both checks. The accepted device HLOCAL path took `0.247780`
sec over 768 calls: diagonal `0.128030`, off-diagonal `0.040771`, and derived
TMEVL `0.078979` sec. Relative to the Step 85 host-staged total of `0.482563`
sec, HLOCAL fell by `0.234783` sec (`48.653%`). Next, use
`./tools/show_tddft_step87_next.sh` without rebuilding or rerunning to display
the remaining energy hierarchy before selecting another implementation.

The Step 87 existing-archive detail shows `0.634219` sec in energy expectation.
NONLOC is the largest component at `0.364838` sec: diagonal `0.274122` plus
off-diagonal `0.090716`. Step 88 adds default-off timers for NONLOC kinetic,
YLM, and SEPPOT stages. Run `./tools/run_tddft_step88.sh` once; do not add an
optimization until that split is available.

Step 88 passed both checks. Across 768 NONLOC calls, kinetic took `0.056220`
sec (`10.325%`), YLM `0.003207` sec (`0.589%`), and SEPPOT `0.485064` sec
(`89.086%`). Step 89 adds default-off timers for SEPPOT EXTAU and the s/p/d/f
orbital channels. Run `./tools/run_tddft_step89.sh` once before selecting a
single channel implementation.

Step 89 passed both checks. SEPPOT used `0.547832` sec. Its classified
children were EXTAU `0.188158` sec (`36.414%`), s `0.103150` sec
(`19.963%`), and p `0.225405` sec (`43.623%`); d/f were inactive. Because
Step 47 already rejected a tutorial-specific whole s/p offload, Step 90 adds
diagnostic-only timers around the p projector, reduction, and DCOEF loops.
Run `./tools/run_tddft_step90.sh` once and do not use its wall as a baseline.

Step 90 passed both checks. The p channel split into projector `0.095651` sec
(`39.103%`), coefficient reduction `0.069291` sec (`28.327%`), and DCOEF
update `0.079670` sec (`32.570%`) over 9,216 calls. No child dominates and
each has a sub-`0.1` sec ceiling, so do not add separate fine-grained kernels.
The current SEPPOT path is closed. Run `./tools/run_tddft_step91_nsys.sh`
once to re-profile the accepted Step 86 source after Steps 74/80/82/86.

Step 91 passed both checks. Its `69.98909358414` sec trace wall is diagnostic,
not a baseline. Aggregate CUDA kernels were about `13.90` sec (`19.86%`),
led by fused nonlocal at `8.200543838` sec and VPJ at `1.559553328` sec.
H2D was 45,663 copies, `28,361.039` MB, and `2.479428511` sec; D2H was
7,759 copies, `6,036.924` MB, and `0.482051802` sec. Stream plus event
synchronization totaled `17.235587864` sec, MPI had no rows, and allocation
was negligible apart from one `0.273660713` sec pinned-pool initialization.

Compared with Step 70, direct transfer time fell `0.269326551` sec and H2D
volume fell `3,229.206` MB, while synchronization and the two leading kernels
were nearly flat. Do not interpret the approximately `56.09` sec outside CUDA
kernels as pure GPU idle because CPU work, waits, runtime, and trace overhead
overlap. Before a new implementation, run
`./tools/show_tddft_step91_detail.sh` once. It reads the existing Step 91
archive only and prints source-attributed TMEVL update/wait rows and selected
CUDA API rows.

The existing-archive detail attributes line 1930 to 4,720 `work2_` updates:
`1.609217948` sec inclusive, with `1.530650988` sec in the nested Wait row.
Line 1933 metadata updates used `0.148298132` sec inclusive, with
`0.137812074` sec in nested Wait. Line 2405 fused-kernel completion Wait was
`8.360886829` sec, consistent with the `8.200543838` sec fused CUDA kernel.
Do not add inclusive Update, nested Wait, and CUDA API rows together.

Run `./tools/show_tddft_step91_next.sh` next. It performs no build or rerun;
it combines the existing Step 88 current-source timers with these Step 91
source-attributed rows. Select no direct `work2_` generation implementation
until its host-generation, upload, and fused-GEMM ceilings are shown together.

The combined view shows `s2_nonlocal=11.548827`, host make `1.348333`,
owner-side `work2_` setup `1.550889`, metadata setup `0.088045`, and fused
dot/update `8.400202` seconds. Host make plus owner-side setup is `2.987267`
seconds, but direct GPU generation would require the already rejected YLM
ownership or fine-grained lookup-copy forms.

Step 92 is diagnostic-only. It compares the complete active
`work2_`/`cfac_`/`ngnl_` values with the preceding call of the same
Suzuki-Trotter phase and prints exact equal/changed counts. Run
`./tools/run_tddft_step92.sh` once. Its wall is diagnostic; use the counts to
decide whether a host-produced phase cache is safe before implementing reuse.

Step 92 passed both checks. For each of the five phases, all 943 comparisons
changed and none matched exactly. Complete host-produced `work2_` caching is
therefore rejected. Step 93 is diagnostic-only and separates equality for
`ngnl_`, `cfac_`, and `work2_`; run `./tools/run_tddft_step93.sh` once and
use only its compact component table. Its wall is not a baseline.

Step 93 passed both checks at revision `0c63c84`. Its diagnostic wall was
`72.5525600910` sec and is not a baseline. Every phase reported 943 component
comparisons, and `ngnl_`, `cfac_`, `work2_`, and the complete tuple each had
`0.000%` exact equality. The metadata changes together with the projector
values, so do not replace the repeated metadata update with one-time device
initialization. Steps 92/93 close this complete-value reuse path; do not retry
full `work2_` caching or metadata caching for the same phase-keyed scheme.
The official Step 86 median remains `66.5019950867` sec.

The next bounded action is diagnostic-only Step 94. The old Step 43
`electf_locpotf=4.071556` sec value covers EWALD, local G-vector and force
construction, MPI, energy, XC, and Hartree work, so it is not evidence for a
direct offload. Step 94 adds default-off parent and local-build/MPI timers only.
Run `./tools/run_tddft_step94.sh` once and use the child share to decide whether
the current local construction merits a narrower split. Do not implement a
LOCPOTF offload before this current-source measurement, and do not use its
diagnostic wall as a baseline.

Step 94 passed both checks at revision `f7cf9d7`. Its diagnostic wall was
`72.0893621445` sec and is not a baseline. `electf_locpotf_total` was
`4.345268` sec; local G construction, force accumulation, and MPI used
`1.193364` sec (`27.464%`), leaving `3.151904` sec (`72.536%`) outside that
child. The local/MPI section is not dominant, so do not offload it yet. Step 95
must first split the remainder into EWALD, local-energy, XC, Hartree, and gap.

Step 95 adds default-off timers only for those four remainder components and
extends the diagnostic timer table from 120 to 124 entries. It changes no
equation, loop, MPI call, OpenACC ownership, or diagnostic-off path. Run
`./tools/run_tddft_step95.sh` once and select no implementation before the
remainder percentages and gap are known. Its wall is diagnostic only.

The first Step 95 A100 run at `6952f54` completed, archived its output, and
passed both checks. Its diagnostic wall was `72.0551159382` sec and is not a
baseline. Only the final `awk` summary failed because the target implementation
reserves `split` as a function name and rejected it as a variable. Do not rerun
the calculation: pull the summary fix and run
`./tools/report_tddft_step95.sh` against the existing archive.

The recovered Step 95 summary shows a `3.159508` sec LOCPOTF remainder:
EWALD `3.024790` sec (`95.736%`), local energy `0.008415` sec (`0.266%`),
XC `0.105457` sec (`3.338%`), Hartree `0.018546` sec (`0.587%`), and gap
`0.002300` sec (`0.073%`). Step 96 adds diagnostic-only exact comparisons of
EWALDY `EWA` and active-atom `FORCE` outputs across its 101 fixed-nuclei calls.
Run `./tools/run_tddft_step96.sh` once. Only if all 100 comparisons are equal
should the next step implement first-call reuse of those two outputs.

Step 96 at `4902b4f` passed both checks, but all 100 comparisons changed:
`ewa_pct=0.000`, `force_pct=0.000`, and `all_pct=0.000`. Its
`71.6179108620` sec diagnostic wall is not a baseline. Close output caching.
Step 97 retains the high-value EWALD target and splits its `3.024790` sec into
G-space, R-space, MPI, and setup/AGEN gap before directly accelerating the
dominant compute child. Run `./tools/run_tddft_step97.sh` once.

Step 97 at `02fa239` passed both checks. G-space dominated EWALDY at
`2.795064` sec (`92.404%`); R-space was `0.205414` sec, MPI `0.019249` sec,
and setup/AGEN gap `0.005089` sec. Its diagnostic wall is not a baseline.
Step 98 directly parallelizes atom pairs in G-space inside one data region per
EWALDY call, retains pair-local G accumulation order and MPI pair assignment,
and atomically accumulates shared force elements. Run
`./tools/run_tddft_step98.sh 01` first.

All Step 98 runs passed both checks. The walls were `66.1477772789`,
`66.14293359913`, and `66.4177260399` sec; median `66.1477772789`, range
`0.27479244077`. This is `0.532642%` faster than Step 86, so Step 98 is the
accepted baseline. Step 99 retains its ownership and arithmetic but maps each
pair to a gang and the inner G loop to a vector reduction. Run
`./tools/run_tddft_step99.sh 01` first.

All Step 99 runs passed both checks. The walls were `64.5138220787`,
`64.2798080444`, and `64.3024969101` sec; median `64.3024969101`, range
`0.2340140343`. This is `2.789633%` faster than Step 98 and `3.307417%`
faster than Step 86, so Step 99 is the accepted baseline. Step 100 performs
one diagnostic-only current-source timer run to rank the largest remaining
intervals before choosing another implementation.

Step 100 passed both checks at revision `f1e22c2`; its diagnostic wall
`70.6082198620` sec is not a baseline. `tmevl_s2` used `20.759666` sec,
including `s2_nonlocal=16.100488`, `s2_nonlocal_make=1.432096`, and
`s2_nonlocal_gemm=10.169891` sec. Their `4.498501` sec gap is caused by the
diagnostic-only Steps 92/93 full-array reuse observer and is absent from
performance builds. Do not optimize that artifact. Step 101 reads the existing
archive only and prints nonlocal transfer plus S2-local child timers; it does
not build or rerun TDDFT.

Step 101 reports `exnlp_gemm_data=8.455729`, fused kernel
`exnlp_gemm_dot=8.402617`, `work2_` upload `1.551925`, and metadata upload
`0.088854` sec. The `s2_fft_local` parent is `4.612063` sec; its five
elementwise children total about `2.334380` sec and leave `2.277363` sec.
The local phase multiply is the largest elementwise child at `0.917904` sec.
Step 102 computes the band-independent complex local phase once per grid point
and reuses it across bands instead of repeating `COS/SIN` for every band. The
GNU MPI + FFTW fallback full build/link passes.

All Step 102 runs passed both checks. Their walls were `63.8388190269`,
`63.71222411728`, and `63.9600141048` sec; median `63.8388190269`, range
`0.24778998752`. This is `0.721088%` faster than Step 99 and `4.004656%`
faster than Step 86, so Step 102 is accepted. Step 103 reads only the existing
Step 100 archive to measure the unchanged kinetic-phase ceiling before any
similar implementation is attempted.

Step 103 reports `tmevl_exkin=0.671559` sec and its GPU kernel at
`0.635902` sec over 9,440 calls; the wrapper gap is only `0.035657` sec.
Step 104 maps G vectors across the GPU, computes one band-independent kinetic
phase per G vector, and applies it sequentially across the 32 local bands.
The element updates are independent, and equations, MPI, ownership, and call
count are unchanged. The GNU MPI + FFTW fallback full build/link passes.

Step 104 run 01 passed both checks but took `64.0659618378` sec, which is
`0.2271428109` sec (`0.355807%`) slower than the Step 102 median. Runs 02/03
are skipped. The reduced phase count did not offset the lost band-direction
parallelism, so the implementation and helper are removed and Step 102 is
restored.
The restored GNU MPI + FFTW fallback full build/link passes.

The next bounded action is diagnostic-only Step 105. The Step 100 current
timers imply `6.249443 - 1.373461 = 4.875982` sec inside ELECTF but outside
LOCPOTF, or `7.638%` of the official Step 102 wall. Old Steps 43/44 attributed
almost the same interval to NONLOCF and mainly SEPPOTF, but Step 47 already
rejected the tutorial-specific whole s/p SEPPOTF offload. Re-measure the
current source before selecting any new implementation.

Step 105 adds default-off timers for the complete ELECTF NONLOCF call, setup,
coefficient kinetic/current plus MPI, GETYLM, SEPPOTF, and final force/energy
assembly. Equations, loop order, MPI boundaries, OpenACC ownership, and the
diagnostic-off path are unchanged. Run `./tools/run_tddft_step105.sh` once.
Require both correctness checks and use the diagnostic wall only for
classification. If SEPPOTF still dominates, do not repeat the Step 47 form;
select a new structurally different hypothesis only if one current child has a
material ceiling.

Step 105 at `91f27a0` passed both checks. Its diagnostic wall was
`70.5463471413` sec and is not a baseline. ELECTF NONLOCF used `4.975987`
sec: setup `0.000899`, coefficient kinetic/current plus MPI `0.898982`, GETYLM
`0.011795`, SEPPOTF `4.061892`, finalization `0.000562`, and an unclassified
gap of `0.001857` sec. SEPPOTF is `81.630%` of NONLOCF and `6.362730%` of the
official Step 102 median, so it is the largest actionable child.

Do not repeat Step 47's tutorial-specific fused s/p GPU path. Source review
shows that it moved projector generation inside each band reduction, whereas
the current host path generates WORK/DCOEF once and reuses them across local
bands. Step 106 is diagnostic only and separates current SEPPOTF phase
generation, nonpartitioned s/p projector generation, nonpartitioned s/p band
reductions, MPI, and an unclassified gap. Run
`./tools/run_tddft_step106.sh` once, require both checks, and do not use the
diagnostic wall as a baseline. A structurally different two-stage GPU path is
considered only if the band-reduction children have a material ceiling.

Step 106 at `9ef703b` passed both checks. Its diagnostic wall was
`70.2937791348` sec and is not a baseline. SEPPOTF used `4.101524` sec:
phase `0.091686`, s-projector generation `0.047953`, s-band reduction
`1.270594`, p-projector generation `0.122658`, p-band reduction `2.537915`,
MPI `0.000391`, and unclassified gap `0.030327` sec. The two band reductions
total `3.808509` sec (`92.856%` of SEPPOTF and `5.965820%` of the official
Step 102 wall), establishing a material ceiling for a different GPU shape.

Step 107 is one bounded performance hypothesis. It generates each atom's
nonpartitioned s/p projector values once, then launches reductions over atom x
local-band gangs and performs final type/atom/s-then-p accumulation in the
original order. It reuses the existing `EXTAU(NGcont,5,NTAUQ)` allocation and
adds only `SEPRED(16,NTAUQ,MXBND2)`. `COEF` remains resident only from FRPRMN
through the immediately following ELECTF call in the same time step; it is
deleted before the next time step, so this is not the rejected Step 45
whole-time-step ownership. Partitioned or d/f projector shapes retain the
host path. The GNU MPI + FFTW fallback full build/link passes.

Run `./tools/run_tddft_step107.sh 01` first with diagnostics off. Require both
checks and compare its wall with the official Step 102 median
`63.8388190269` sec. Stop after run 01 if correctness fails or the result is
not promising; only then use `02-03` for the adoption median. Rollback target
for the experiment is `9ef703b`.

All three Step 107 runs passed normal check and relaxed compare. Their walls
were `63.1300778389`, `63.2335109711`, and `63.2135219574` sec. The median is
`63.2135219574` sec and the range is `0.1034331322` sec. This is
`0.6252970695` sec (`0.979493%`) faster than Step 102, so Step 107 is the
accepted source and performance baseline.

The next bounded action is diagnostic-only Step 108. It reuses the current
default-off timers on accepted Step 107 and prints the major TMEVL/S2,
FRPRMN, ELECTF/NONLOCF, HLOCAL, and EWALD intervals. Run
`./tools/run_tddft_step108.sh` once. Its diagnostic wall is not a baseline;
use the timer ranking only to choose one next high-impact hypothesis.

Step 108 at `4ccf7dc` passed both checks. Its `70.2021420002` sec diagnostic
wall is not a baseline. S2 NONLOCAL remains `16.045700` sec, with
`10.201628` sec in its GEMM wrapper and `8.412670` sec in the fused kernel,
but the safe mapping/cache variants for that kernel are already classified.
The next actionable parent is ELECTF NONLOCF at `5.076909` sec, including
`4.262210` sec in the SEPPOTF parent. Step 109 later proved that the proposed
Step 107 batch path was inactive for this signed-`NUMTY` tutorial input.

Step 109 adds default-off timers only. It attempts to split the proposed
batched SEPPOTF path into projector generation, s/p batch reductions, final GPU
assembly, result download, MPI, and a gap. Run `./tools/run_tddft_step109.sh`
once and do not use its diagnostic wall as a baseline.

Step 109 at `f3d6082` passed both checks, but timer IDs 140--144 did not appear
and the wrapper stopped with its intended count error. Do not rerun yet.
First run `./tools/report_tddft_step109.sh`; it reads the existing archive
only and reports whether legacy IDs 134--138 were active.

The report confirms the legacy path. Startup output shows `NTYPE=2`,
`NUMTY=12,-2`, and no partition message. Existing SEPPOTF uses
`ABS(NUMTY)`; the Step 107 guard alone rejected the negative signed count.
Consequently the accepted Step 107 gain is attributed to its bounded COEF
residency change, while the batched path was inactive.

Step 110 changes only this signed-count handling: zero remains unsupported and
the batched projector/final loops use `ABS(NUMTY)` like the legacy path. Run
`./tools/run_tddft_step110.sh 01` with diagnostics off. Require both checks and
stop on failure or an unpromising wall; only then run `02-03`.

Step 110 run 01 passed both checks with diagnostics off but took
`63.7820260525` sec, `0.5685040951` sec (`0.899339%`) slower than the official
Step 107 median. The difference is `5.496344x` the Step 107 run range, so runs
02/03 were stopped. The signed-count batch path is rejected; its source changes
and helper are removed. The accepted negative-`NUMTY` guard is restored, and
the Step 107 baseline remains valid because its measured gain came from bounded
COEF residency. Do not retry this SEPPOTF batch shape for the tutorial input.

Step 111 is diagnostic only. It splits the current `nonlocf_kinetic_mpi`
interval into two G-vector setup loops, two host band reductions, their two MPI
exchanges, and YLM-radius setup. Run `./tools/run_tddft_step111.sh` once,
require both checks, and return the compact split block. Its diagnostic wall is
not a performance baseline. Proceed to an implementation only if one compute
child dominates the `0.799754` sec Step 108 parent.

Step 111 at `2415d30` passed both checks. Its `69.0858860016` sec diagnostic
wall is not a baseline. Of the `0.814936` sec parent, the kinetic/current and
A-vector band reductions used `0.470508` and `0.287670` sec, together
`93.037%`; both MPI intervals together used only `0.000745` sec.

Step 112 reuses the `WFAC=|COEF|^2` already computed in the first band/G loop
to accumulate A-vector energy in the same G order, removing the later second
COEF traversal. Keep both MPI exchanges and downstream order unchanged. The
measured removable ceiling is about `0.287670` sec (`0.455%` of the official
Step 107 wall). Run `./tools/run_tddft_step112.sh 01` with diagnostics off and
require both checks before considering `02-03`. Rollback target: `4f4a276`.

Step 112 run 01 passed both checks but took `63.6258358955` sec,
`0.4123139381` sec (`0.652256%`) slower than the official Step 107 median and
`3.986285x` its run range. Runs 02/03 were stopped. The source and helper are
restored/removed in `330bd1c`, closing this COEF-pass fusion strategy together
with the earlier Step 84 rejection. Step 110 was likewise restored in
`d8ae16e`. No untried safe tutorial hypothesis now has a comparable measured
ceiling; require new production input or new profiler evidence before more
low-ceiling source experiments.

Step 113 is a compiler-option screen, not a source optimization or baseline
change. In one user-operated command it rebuilds and runs the same current
source once with the standard `-O2` flags, isolated `-O3`,
`-Mipa=fast,inline`, and GPU `fastmath` variants, in that order. Every run uses
diagnostics off, 1 A100 / 1 MPI rank / 100 steps, a unique archive, normal
check, relaxed compare, and an additional strict comparison. The compact
summary reports exact flags, compiler/device identity, wall time, difference
from the same-session standard build, and difference from the official Step
107 median. Run `./tools/run_tddft_step113_flags.sh` once. These single runs
cannot replace the official baseline; only a correct, clearly faster isolated
variant may proceed to a separate three-run adoption gate.

Step 113 at `05fd3c4` completed all four runs with normal check and relaxed
compare PASS. Same-session walls were standard `63.9245581627`, O3
`64.3075950146`, IPA `63.7906529903`, and `fastmath` `63.7448709011` sec.
Relative to the same-session standard build, O3 regressed `0.599201%`, IPA
improved `0.209474%`, and `fastmath` improved `0.281093%`. All four remain
slower than the official Step 107 median, and none changes the baseline.
`fastmath` is only `0.0457820892` sec (`0.071769%`) faster than IPA.

All rows reported strict FAIL against the default GNU reference, including the
unchanged standard build, so that column cannot attribute a numerical change
to one option. Run `./tools/report_tddft_step113_flags.sh` once. It reads only
the existing archives, directly compares each option with the same-session
standard archive, prints maximum observable differences plus compiler/MPI
provenance, and performs no build or simulation. Use that result to choose at
most one three-run finalist; O3 is already excluded.

The Step 113 existing-archive report then showed relaxed and strict PASS for
O3, IPA, and `fastmath` against the same-session standard archive. ETOT, total
energy, force, position, and velocity differences were all
`0.000000e+00`. This clears the pairwise numerical-risk question but does not
create a performance finalist: `fastmath` improved only `0.281093%` over the
same-session standard run, led IPA by only `0.071769%`, and was still
`0.840562%` slower than the official Step 107 median. Do not spend three more
runs on this noise-level candidate. Step 113 is closed; retain the standard
flags and Step 107 baseline.

The report's compiler field remained blank because `nvfortran -V` begins with
an empty line in this environment. The helpers now select its first nonblank
line. The MPI driver output still established that the wrapper invokes
`nvfortran`; no rerun is required for the closed Step 113 decision.

Step 114 is an explicit memory-mode screen requested by the user. Keep all
accepted source and non-memory flags fixed. Run a same-session
`-gpu=mem:separate:pinnedalloc` control, then `-gpu=mem:managed`, then
`-gpu=mem:unified`, using `./tools/run_tddft_step114_memory_modes.sh`.
Unpinned separate memory is not repeated because Step 37 already measured the
pinned mode as `4.4103%` faster than Step 36.

Each variant is diagnostics off, 1 A100 / 1 MPI rank / 100 steps, with a unique
archive, normal check, relaxed compare, and direct pairwise strict comparison
against the control. Linux x86-64 unified mode requires HMM support; if build
or execution fails, return the compact failure block and do not continue or
weaken validation. This screen cannot change the standard flags or official
Step 107 baseline.

Step 114 at `3fe68c1` completed all three variants with normal check, relaxed
compare, and control-pairwise strict compare PASS. Walls were
`63.9251468182` sec for `mem:separate:pinnedalloc`, `130.1395111080` sec for
`mem:managed`, and `130.4787569050` sec for `mem:unified`. Managed and unified
regressed `103.581091%` and `104.111783%` against the same-session control and
were also more than twice the official Step 107 median.

Reject both alternative modes without runs 02/03. Keep
`-gpu=mem:separate:pinnedalloc` as the required build mode. Do not repeat
whole-build managed or unified memory on this tutorial path without materially
different ownership or hardware evidence. The large regression is consistent
with migration/access-transition overhead, but it was not profiled and should
not be attributed more narrowly.

Step 115 establishes a separate H100 baseline candidate from the latest
accepted numerical source. Run
`./tools/run_tddft_step115_h100_baseline.sh` on exactly one H100. The helper
requires an H100 device name, builds once for `cc90` with the accepted
`mem:separate:pinnedalloc` mode and diagnostics off, then collects three
Si111-H 100-step runs with 1 MPI rank.

Every run must pass normal check and relaxed compare; runs 02/03 are also
strictly compared directly with run 01. The report captures exact device,
driver, compiler, kernel, revision, flags, median, and range. Treat the result
as an H100-only baseline candidate. The A100 Step 107 baseline remains
independent and cannot be replaced or mixed with this series.

Step 115 at full revision `e6ad059fc4ea65dda8ad19383ea32a5da37065ed`
completed on an NVIDIA H100 PCIe with driver `595.45.04`, `nvfortran 26.5-0`,
kernel `6.12.0-124.8.1.el10_1.x86_64`, and explicit `cc90`. All three runs
passed normal check, relaxed compare, and run-01 pairwise strict comparison.
Walls were `34.1089649200`, `34.1246850491`, and `34.0341229439` sec.

The H100 median is `34.1089649200` sec with a `0.0905621052` sec range. It is
`1.853282x` faster by A100/H100 wall ratio and reduces wall by `46.041663%`
relative to the A100 Step 107 median. The user explicitly approved this as the
H100-only formal baseline on 2026-07-30. Keep the A100 baseline unchanged and
do not mix the two device series.

After Step 115, NVIDIA MPS was considered only as a read-only investigation.
The code distributes bands across MPI ranks, so multiple ranks on one GPU
could in principle provide separate CUDA clients for MPS concurrency.
However, the Si111-H tutorial has only 32 bands: two ranks would have about
16 bands each and four ranks about 8 each, without reducing total GPU work.
Additional MPI reduction/broadcast, CUDA-context, and duplicated host-work
costs make a large single-job wall-time improvement unlikely. The user
explicitly decided not to run an MPS or multi-rank experiment. Do not create
an MPS wrapper, change MPI rank count, or request MPS execution unless the
user later reopens that scope.

There is no pending A100 or H100 command and no selected Step 116 performance
hypothesis. A new task must first reconstruct Git and the two device-specific
baselines. If further optimization is requested, perform read-only
investigation and present one bounded hypothesis for explicit approval before
editing source or requesting GPU execution. Do not infer that H100 results
replace the A100 series, and do not resume low-upside tutorial micro-tuning
without new profiler evidence or a production input.

A user-operated exploratory Step 80 run on an NVIDIA H100 took
`36.492636919` sec and passed both checks. It is `1.847517x` faster than the
A100 Step 80 median by ratio, but it is not a formal H100 baseline: there is
only one run, and the exact H100 model, revision, compiler, and `cc90` build
target were not captured. Keep the official A100 baseline and Step 81 plan
unchanged.

Do not broaden Step 62 beyond the measured dead host copy
is classified. The accepted LOCPOT hypothesis must remain bounded.
Step 47
proved that a correct approximately 250-line SEPPOTF special path can produce
only a noise-level `0.0291%` median advantage; the same form must not be
retried. Likewise, do not retry Step 45 whole-loop COEF allocation, Step 42
Vloc residency, fine-grained section copyin, ownership-free `work2_` device
generation, GDUMP reuse, YLM ownership, vector length 512, or a small-band-only
kernel path in their rejected forms.

Production-size scaling remains blocked because no production input or matching
correctness reference is available. The tutorial's 32-band grid is the minimum
operational case and must not be used to infer production occupancy.

## Validation Gate

The authoritative procedure is `docs/VALIDATION_WORKFLOW.md`. In summary, for
every performance implementation:

1. Build CPU/FFTW fallback successfully.
2. Build NVHPC OpenACC + cuFFT with diagnostics off.
3. Run one 100-step correctness measurement.
4. Require normal check and relaxed compare to pass.
5. If run 01 is healthy, run 02 and 03.
6. Compare the three-run median with `63.2135219574` sec.
7. Record and revert a change that has no performance advantage.

The A100 environment is operated by the user. Provide exact commands and wait
for the returned logs or screenshots before making an adoption decision.
