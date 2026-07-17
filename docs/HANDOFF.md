# TDDFT OpenACC GPU Handoff

Last updated: 2026-07-17

## Current State

- Branch: `tddft-openacc-residency`
- Accepted source baseline: `4aaa33c` (`Keep static TDDFT metadata resident`)
- Accepted GPU build mode: `9cbb6bc` with `ENABLE_PINNED_ALLOC=1`
- Accepted result record: this documentation update
- Current configuration: Step 41 source with Step 37 pinned allocation mode
- Current source implementation: Step 41 commit `4aaa33c`
- Rejected Step 45 implementation: `da24adf`
- Step 45 rollback: `c406a4a`
- Current experimental implementation: Step 46 diagnostic `edfafed`
- Current HEAD status: Step 46 establishes the FRPRMN-to-ELECTF COEF lifetime
  and NONLOCF parent mappings; CPU/FFTW full link and review passed
- Rejected Step 31 implementation: `f8b6188`
- Step 31 rollback: `8ef55bb`
- Performance baseline: Step 41 median `107.754213095` sec

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

The 32-band tutorial is the smallest operational case expected. A dedicated
smaller-band multi-gang path is out of scope. The current one-gang-per-band path
expands naturally with local band count, so shared bottlenecks should be
validated on medium or production-sized inputs rather than inferred only from
the tutorial occupancy.

## Next Task Boundary

Step 44 measured `ELECTF` at `8.913402` sec and the projector section at
`4.092541` sec. Within that section, GETYLM used only `0.009894` sec while
SEPPOTF used `4.068364` sec (`99.4092%`). The archive
`nvhpc_cufft_1rank_02_STEP44_NONLOCF_TIMERS_01` passed normal check and relaxed
compare. Its `108.715013981` sec wall is diagnostic-only and must not replace
the Step 41 baseline. Step 45 extends COEF device allocation across the whole
time-step loop while retaining the existing D2H before ELECTF host readers.
It was intended to remove the next-step COEF H2D copyin without changing
SEPPOTF, MPI, equations, or arithmetic order. All three runs passed both
correctness checks, but the median was `108.782176018` sec, `0.9540%` slower
than Step 41, with a `2.832067967` sec range. No Nsight Systems trace was
collected. Step 45 was reverted by `c406a4a`, and the CPU/FFTW fallback full
link passed. Step 46 is a diagnostic-only ownership scaffold for the tutorial
non-partitioned s/p SEPPOTF band reduction. It adds a no-op device `present`
probe for the COEF, G2, YLM, VPJ, WORK2-column, DCOEF, and EXTAU dummy sections.
Its wall time is not a performance baseline. A short A100 run must first show
no present/partial-present error before any SEPPOTF arithmetic is ported.

Step 42 kept `Vloc(:,1:5)` resident across each FRPRMN predictor-corrector
sequence. All three runs passed both correctness checks, but the median was
`107.809727907` sec, `0.0515%` slower than Step 41. The implementation is
rejected and was reverted by `afa1678`. The CPU/FFTW fallback full link passed
after rollback.

After Step 42 is accepted or rejected, the next direction is to decompose the
roughly 9-second host-side `ELECTF` region into `LOCPOTF`, `NONLOCF`, and
their major reductions. This first stage is diagnostic only. The expected
implementation direction is then to port bounded `NONLOCF` coefficient
consumers to the GPU and extend `COEF` device authority through `ELECTF`.
Do not remove the current COEF download before every downstream host consumer,
force reduction, MPI boundary, and output requirement has been accounted for.

No core TDDFT equation is inherently unsuitable for a GPU. The practical
host/device boundaries are scalar convergence decisions, non-device-aware MPI
or host density consumers, ionic/control updates, and output/checkpoint I/O.
The goal is therefore to leave only small scalars and required output data on
these boundaries while keeping large arrays resident. Repeated fine-grained
copyin, ownership-free `work2_` device generation, and previously rejected
GDUMP/YLM mapping experiments remain prohibited.

## Validation Gate

The authoritative procedure is `docs/VALIDATION_WORKFLOW.md`. In summary, for
every performance implementation:

1. Build CPU/FFTW fallback successfully.
2. Build NVHPC OpenACC + cuFFT with diagnostics off.
3. Run one 100-step correctness measurement.
4. Require normal check and relaxed compare to pass.
5. If run 01 is healthy, run 02 and 03.
6. Compare the three-run median with `107.754213095` sec.
7. Record and revert a change that has no performance advantage.

The A100 environment is operated by the user. Provide exact commands and wait
for the returned logs or screenshots before making an adoption decision.
