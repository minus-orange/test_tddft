# Historical x86 Measurement Helpers

This directory contains completed x86 CPU measurement helpers retained for
provenance. Do not rerun them automatically against a newer source or use
their results to replace the formal x86 baseline.

`run_tddft_x86_affinity_screen.sh` tested Intel MPI `compact`, `scatter`, and
`spread` ordering at 32 MPI ranks x 8 OpenMP threads. At revision `cd36890`,
the compact control completed, but scatter emitted Intel MPI/Hydra IPL2
domain-size errors and regressed to `78.1684319973` sec. The normal check
failed on the suspicious stderr, so the helper stopped before relaxed,
control-strict, or spread execution. Scatter is rejected and the accepted
compact baseline remains unchanged.
