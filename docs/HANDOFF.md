# TDDFT OpenACC GPU Handoff

Last updated: 2026-07-23

## Current State

- Branch: `tddft-openacc-residency`
- Accepted source baseline: `3687243` (`Reuse NONLOC YLM preparation by k-point`)
- Accepted GPU build mode: `9cbb6bc` with `ENABLE_PINNED_ALLOC=1`
- Required current NVHPC TDDFT flags: `-O2 -acc -gpu=cc80 -gpu=mem:separate:pinnedalloc -mp -Msave -Mlarge_arrays`
- Accepted result record: this documentation update
- Current configuration: accepted Step 74 with Step 37 pinned allocation mode
- Current source implementation: Step 74 commit `3687243`
- Rejected Step 45 implementation: `da24adf`
- Step 45 rollback: `c406a4a`
- Validated diagnostic implementation: Step 46 `edfafed` plus enforcement
  commit `3e2c630`
- Rejected Step 47 implementation: `0252da9`
- Step 47 and Step 46 source rollback: `35f8542`
- Current HEAD status: Step 74 accepted
- Rejected Step 31 implementation: `f8b6188`
- Step 31 rollback: `8ef55bb`
- Performance baseline: Step 74 median `68.0681188811` sec
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
6. Compare the three-run median with `68.0681188811` sec.
7. Record and revert a change that has no performance advantage.

The A100 environment is operated by the user. Provide exact commands and wait
for the returned logs or screenshots before making an adoption decision.
