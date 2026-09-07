# FPSEID21 TDDFT OpenACC GPU Work

## Scope

- Branch: `tddft-openacc-residency`
- Target: `FPSEID21/tddft_2022October`
- Validated GPU path: NVHPC OpenACC + cuFFT, 1 GPU / 1 MPI rank
- Required fallback: CPU/FFTW must remain buildable
- Performance case: Si111-H, 100 TDDFT time steps, NVIDIA A100-PCIE-40GB

## Start Every Task

Run these commands before modifying anything:

```sh
git fetch origin
git checkout tddft-openacc-residency
git status -sb
git log --oneline --decorate -n 30
git rev-list --left-right --count origin/tddft-openacc-residency...HEAD
git diff
git diff --cached
```

Read `docs/HANDOFF.md`, `docs/PERFORMANCE_BASELINE.md`,
`docs/EXPERIMENT_LOG.md`, both `docs/tddft_gpu_progress_summary_*.md` files,
`docs/tddft_gpu_residency_plan_ja.md`, and
`docs/VALIDATION_WORKFLOW.md` before starting a new experiment.

Follow `docs/VALIDATION_WORKFLOW.md` for Main, Investigation, Implementation,
and Review responsibilities, A100 execution gates, early-stop conditions,
human approval boundaries, adoption, and rollback.

## Permanent Rules

- One commit represents one performance hypothesis.
- The user granted standing approval on 2026-07-21 to push each new commit on
  `tddft-openacc-residency` to `origin` immediately after it is created. This
  does not authorize force-pushes, pushing a different branch, or including
  unrelated user changes.
- Keep human-operated A100 commands short and directly copyable. Prefer one
  existing wrapper command. If the required procedure cannot be expressed
  concisely, add a bounded helper script to Git instead of sending a long
  sequence of shell commands.
- Always include the exact execution command and the result-check/return
  instructions in the chat response, even when the workflow is implemented by
  a committed helper or documented elsewhere.
- Assume that results can be returned from the closed A100 environment only as
  photographs or manually typed text. Never require transfer of raw traces,
  archives, reports, or other files. Make profiler helpers print a compact
  terminal summary that can be captured in a small number of photographs, and
  request only targeted follow-up output when necessary.
- Never treat the newest HEAD as the performance baseline automatically.
- Measure performance with diagnostics off.
- When adding cost timers, place equivalent timers at the corresponding CPU
  and GPU source boundaries wherever both paths exist, use the same labels,
  and include them in the compact cross-platform report so later x86/GPU
  distributions remain comparable.
- Require both the normal result check and relaxed comparison.
- Accept performance only after three runs and a median comparison.
- Record rejected experiments, then revert their source changes.
- Preserve the CPU/FFTW fallback and the 1 GPU / 1 MPI rank validation path.
- Preserve fixed-form Fortran columns and continuation syntax.
- Confirm array shapes, dummy arguments, and OpenACC section boundaries.
- Do not reorder sequential `ia` updates without a separate mathematical and
  correctness justification.
- Do not introduce repeated fine-grained section `copyin` operations.
- Do not modify, delete, stage, or commit user-owned untracked files.

## Correctness Commands

```sh
python3 ./tools/check_tddft_result.py check \
  ./run/tddft_archives/<LABEL>/tddft.out \
  --err ./run/tddft_archives/<LABEL>/tddft.err \
  --expected-steps 100

python3 ./tools/check_tddft_result.py compare \
  ./run/tddft_archives/<LABEL>/tddft.out \
  --test-err ./run/tddft_archives/<LABEL>/tddft.err \
  --expected-steps 100
```

Archive with:

```sh
LABEL=<LABEL> ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
```
