# TDDFT OpenACC GPU Handoff

Last updated: 2026-07-16

## Current State

- Branch: `tddft-openacc-residency`
- Accepted implementation baseline: `c3552af` (`Keep TDDFT coefficients resident across corrections`)
- Accepted result record: `ccdd4a2`
- Current source behavior after rollback: Step 28
- Rejected Step 31 implementation: `f8b6188`
- Step 31 rollback: `8ef55bb`
- Performance baseline: Step 28 median `129.075486183` sec

Step 31 reused `GDUMP1..5` mappings across the five TMEVL kinetic stages. All
three runs passed correctness, but the median was `129.250354052` sec, about
`0.1355%` slower than Step 28. It was rejected and rolled back.

## Next Task Boundary

Do not continue from the rejected GDUMP hypothesis. Start from the restored
Step 28 source and choose one new, independently measurable hypothesis.
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
6. Compare the three-run median with `129.075486183` sec.
7. Record and revert a change that has no performance advantage.

The A100 environment is operated by the user. Provide exact commands and wait
for the returned logs or screenshots before making an adoption decision.
