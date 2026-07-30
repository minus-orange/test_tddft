# Completed TDDFT Step Helpers

This directory contains shell helpers for completed TDDFT GPU experiments and
diagnostics (Steps 52 through 115). They are retained for provenance and
bounded reproduction of the recorded experiments.

These scripts are not the entry points for a new performance experiment.
Current reusable build, profiling, archive, correctness, sample, and x86
baseline tools remain directly under `tools/`.

Historical scripts continue to resolve the repository root and reusable tools
from this location. The authoritative result and adoption status for each step
is recorded in:

- `docs/EXPERIMENT_LOG.md`
- `docs/PERFORMANCE_BASELINE.md`
- `docs/HANDOFF.md`
- `docs/tddft_gpu_progress_summary_ja.md`
- `docs/tddft_gpu_progress_summary_en.md`

Do not rerun a completed or rejected step merely because its helper is
available here. Follow `docs/VALIDATION_WORKFLOW.md` and obtain the required
approval before any new GPU execution.
