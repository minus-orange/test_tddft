# TDDFT OpenACC GPU Handoff

Last updated: 2026-07-21

## Current State

- Branch: `tddft-openacc-residency`
- Accepted source baseline: `4aaa33c` (`Keep static TDDFT metadata resident`)
- Accepted GPU build mode: `9cbb6bc` with `ENABLE_PINNED_ALLOC=1`
- Required current NVHPC TDDFT flags: `-O2 -acc -gpu=cc80 -gpu=mem:separate:pinnedalloc -mp -Msave -Mlarge_arrays`
- Accepted result record: this documentation update
- Current configuration: Step 41 source with Step 37 pinned allocation mode
- Current source implementation: Step 41 commit `4aaa33c`
- Rejected Step 45 implementation: `da24adf`
- Step 45 rollback: `c406a4a`
- Validated diagnostic implementation: Step 46 `edfafed` plus enforcement
  commit `3e2c630`
- Rejected Step 47 implementation: `0252da9`
- Step 47 and Step 46 source rollback: `35f8542`
- Current HEAD status: accepted Step 41 source restored; CPU/FFTW fallback
  full link passed after rollback; Step 48 trace classified and one bounded
  default-off FRPRMN timer diagnostic is being prepared
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

Step 48 completed the current-source trace. The next task remains diagnostic
only: run one default-off-by-design timer build that divides the FRPRMN host
preparation into COEF setup, GDUMP preparation, `Part1to5`, and EXTAU
preparation. Use the result with Step 48 to narrow the remaining CPU,
runtime/API, synchronization, and GPU-idle components. Do not use the
timer-enabled wall as a baseline and do not begin an optimization.

Do not begin another offload implementation until the diagnostic identifies one
evidence-backed bottleneck and Main presents one bounded hypothesis. Step 47
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
6. Compare the three-run median with `107.754213095` sec.
7. Record and revert a change that has no performance advantage.

The A100 environment is operated by the user. Provide exact commands and wait
for the returned logs or screenshots before making an adoption decision.
