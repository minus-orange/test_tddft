# TDDFT OpenACC GPU Handoff

Last updated: 2026-07-16

## Current State

- Branch: `tddft-openacc-residency`
- Accepted implementation baseline: `83a030c` (`Defer coefficient downloads across corrections`)
- Accepted result record: this documentation update
- Current source behavior: Step 34
- Rejected Step 31 implementation: `f8b6188`
- Step 31 rollback: `8ef55bb`
- Performance baseline: Step 34 median `113.561361074` sec

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

## Next Task Boundary

Before another source optimization, collect a fresh Nsight Systems trace on
the accepted Step 34 path. Confirm the new D2H count and size, re-rank repeated
H2D operations, and verify whether `work2_` remains the largest actionable
transfer after Steps 33 and 34.
Step 30 Nsight data identifies the largest repeated remaining upload as
`work2_`: 4,720 events, with its updates taking about 4.184 sec. The full trace
reported 46,225.769 MB of aggregate H2D traffic. Direct GPU generation remains
high risk because it may increase YLM, VPJ, or EXTAU traffic.

Before changing that path, design an ownership boundary that does not repeat
fine-grained lookup copies and does not alter the sequential projector update
order. CPU/FFTW fallback behavior must remain unchanged.

## Validation Gate

For every performance implementation:

1. Build CPU/FFTW fallback successfully.
2. Build NVHPC OpenACC + cuFFT with diagnostics off.
3. Run one 100-step correctness measurement.
4. Require normal check and relaxed compare to pass.
5. If run 01 is healthy, run 02 and 03.
6. Compare the three-run median with `113.561361074` sec.
7. Record and revert a change that has no performance advantage.

The A100 environment is operated by the user. Provide exact commands and wait
for the returned logs or screenshots before making an adoption decision.
