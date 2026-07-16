# TDDFT OpenACC GPU Handoff

Last updated: 2026-07-16

## Current State

- Branch: `tddft-openacc-residency`
- Accepted source baseline: `24e1cc3` (`Right-size nonlocal staging columns`)
- Accepted GPU build mode: `9cbb6bc` with `ENABLE_PINNED_ALLOC=1`
- Accepted result record: this documentation update
- Current configuration: Step 36 source with Step 37 pinned allocation
- Rejected Step 31 implementation: `f8b6188`
- Step 31 rollback: `8ef55bb`
- Performance baseline: Step 37 median `108.096301079` sec

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

## Next Task Boundary

Step 38 shows that direct GPU generation of `work2_` can save at most a portion
of the now `1.272` sec total H2D time and still risks increasing YLM, VPJ, or
EXTAU traffic. The next investigation should therefore target the fused
nonlocal kernel, which remains about `8.31` sec and 66.6% of reported CUDA
kernel time. Obtain compiler resource information or a focused Nsight Compute
measurement before changing its mapping. Any change must preserve the
sequential `ia` order and CPU/FFTW fallback.

## Validation Gate

For every performance implementation:

1. Build CPU/FFTW fallback successfully.
2. Build NVHPC OpenACC + cuFFT with diagnostics off.
3. Run one 100-step correctness measurement.
4. Require normal check and relaxed compare to pass.
5. If run 01 is healthy, run 02 and 03.
6. Compare the three-run median with `108.096301079` sec.
7. Record and revert a change that has no performance advantage.

The A100 environment is operated by the user. Provide exact commands and wait
for the returned logs or screenshots before making an adoption decision.
