# TDDFT GPU Validation Workflow

This document defines the standard investigation, implementation, review,
measurement, and adoption loop for FPSEID21 TDDFT GPU performance work.

## Roles

### Main

Main owns the experiment scope and the adoption decision. Main must:

- reconstruct HEAD, remote synchronization, worktree state, and the official
  baseline before selecting work;
- keep HEAD, implementation commits, diagnostic runs, and the performance
  baseline distinct;
- select exactly one hypothesis;
- send bounded tasks to Investigation, Implementation, and Review;
- provide exact A100 commands to the user;
- combine correctness, timing, and review evidence into an adoption proposal;
- wait for human approval before implementation, A100 execution, push,
  rollback, or baseline changes.

Main must not start a second hypothesis until the current implementation has
been accepted or recorded and rolled back.

### Investigation

Investigation is read-only. It identifies one evidence-backed hypothesis and
reports the target source, expected wall-time and timer signals, correctness
risk, CPU/FFTW impact, OpenACC ownership impact, stop conditions, and rollback
point. It does not edit files or start experiments.

### Implementation

Implementation changes only the approved hypothesis. One implementation commit
must represent one hypothesis. It preserves CPU/FFTW fallback, fixed-form
Fortran columns, array shapes, OpenACC section boundaries, and sequential `ia`
semantics. It performs available local checks and reports the exact commit and
rollback target. It does not add unrelated cleanup or decide adoption.

### Review

Review is independent and read-only. It checks hypothesis/diff correspondence,
mathematical and `ia` ordering equivalence, forward/reverse paths, array bounds,
dummy shapes, leading dimensions, OpenACC ownership and `present` sections,
fixed-form syntax, CPU/FFTW fallback, measurement conditions, and rollback
safety. Its result is `PASS`, `PASS WITH NOTES`, `CHANGES REQUIRED`, or `BLOCK`.
A100 validation starts only after an acceptable review result.

## Permanent Experiment Rules

- One commit represents one hypothesis.
- Performance runs use diagnostics off.
- Every performance run must pass both normal `check` and relaxed `compare`.
- Adoption requires three equivalent runs and a median comparison.
- Nsight wall time is diagnostic and never replaces a performance baseline.
- A newer HEAD is not automatically the performance baseline.
- Different input sizes require separate baselines.
- Record rejected experiments before reverting their implementation.
- Preserve the CPU/FFTW fallback and 1 GPU / 1 MPI rank validation path.
- Do not reorder sequential `ia` updates without separate mathematical and
  correctness justification.
- Do not introduce repeated fine-grained section `copyin` operations.
- Do not modify, delete, stage, or commit user-owned untracked files.
- Never overwrite or delete an existing result archive to reuse its label.

## One-Hypothesis Cycle

1. Main reconstructs Git state, current HEAD position, and official baseline.
2. Investigation proposes one hypothesis with expected and stop signals.
3. Main presents the hypothesis and risks to the human.
4. The human approves or rejects implementation.
5. Implementation creates one bounded implementation commit and verifies the
   CPU/FFTW fallback build/link.
6. Review independently evaluates the commit.
7. After Review passes and the human approves execution, Main provides exact
   A100 build and run commands.
8. Run 01 is archived and checked with both correctness commands.
9. If run 01 is correct and healthy, repeat as independent runs 02 and 03.
10. Compare the three-run median with the official baseline for the same input
    and build conditions.
11. Main proposes acceptance, rejection, or additional investigation.
12. The human approves the disposition.
13. Accepted results are recorded in the bilingual progress summaries,
    `PERFORMANCE_BASELINE.md`, and `EXPERIMENT_LOG.md` as appropriate.
14. Rejected results are recorded, then the source implementation is reverted
    and the CPU/FFTW fallback is rechecked.
15. Only after synchronization and disposition are complete may Main select a
    new hypothesis.

## A100 Preflight

The A100 environment is operated by the user. Commands must remain short and
directly copyable. Prefer one existing wrapper command. If build, profiling,
archiving, checking, and summarizing would otherwise require a long sequence,
add a bounded helper script to Git and ask the user to run that script instead.

The closed A100 environment returns evidence only through photographs or
manually typed text. Do not require transfer of `.nsys-rep` files, archives,
CSV files, logs, or other artifacts. Profiling workflows must emit a compact
terminal report containing the revision, configuration, correctness, and top
diagnostic rows. Design it to fit in a small number of photographs and request
additional targeted terminal output only when that report is insufficient.

Before building, Main requests:

```sh
cd /usr/uhome/aurora/4gi/k-hanagata/work/FY2026/FPSEID21/test_tddft
git fetch origin
git checkout tddft-openacc-residency
git status -sb
git log --oneline --decorate -n 12
git rev-list --left-right --count \
  origin/tddft-openacc-residency...HEAD
git diff
git diff --cached
```

The tracked worktree and index must be clean, the expected implementation must
exist on the branch, and user-owned untracked files must remain untouched. Then:

```sh
git pull --ff-only origin tddft-openacc-residency
git rev-parse HEAD
git status -sb
nvidia-smi
```

Stop if the revision differs from Main's requested revision, the branch has
diverged, or the GPU is occupied by an unrelated workload.

## Build Gate

The accepted GPU configuration uses NVHPC, OpenACC, cuFFT, separate memory, and
pinned dynamic host allocation. The standard build entry is:

```sh
ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 ./tools/build_nvhpc.sh
```

The current A100 TDDFT compile flags are `-O2 -acc -gpu=cc80 -gpu=mem:separate:pinnedalloc -mp -Msave -Mlarge_arrays`. When CG and SD are
not part of the selected hypothesis, add `TDDFT_ONLY=1` so only TDDFT is
built.

Confirm diagnostics are off and the TDDFT executable links successfully. Do
not run the GPU measurement after a failed CPU/FFTW or GPU build.

For the standard 100-step tutorial measurement, run from the repository root:

```sh
cd run/Si111-H_nvhpc
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M
export CUDA_VISIBLE_DEVICES=0
mpirun -np 1 ../../FPSEID21/tddft_2022October/tddft_exe \
  < Si111-H_tm.in_100steps \
  > Si111-H_tm.out_100steps \
  2> Si111-H_tm.err
cd ../..
```

Do not change the input, GPU count, MPI rank count, OpenMP settings, or output
names during a three-run series. Confirm that all 100 steps completed before
archiving the result.

## Archive and Correctness Gate

Use a unique monotonic label for every run:

```text
nvhpc_cufft_1rank_02_STEP<NN>_<HYPOTHESIS>_01
nvhpc_cufft_1rank_02_STEP<NN>_<HYPOTHESIS>_02
nvhpc_cufft_1rank_02_STEP<NN>_<HYPOTHESIS>_03
```

Archive from the repository root:

```sh
LABEL=<LABEL> ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
```

Run both checks on the archived result:

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

Stop immediately on a failed check or compare, NaN/Inf, CUDA, cuFFT, OpenACC,
or MPI error, incomplete steps, archive collision, unknown revision, or
unexpected stderr. Do not run 02 or 03 after a correctness failure.

## Performance Gate

For the 100-step tutorial case, collect `wall_sec` plus the hypothesis-specific
timers and at least:

- `time_step_total`
- `frprmn`
- `electf_force`
- `tmevl_total`
- `tmevl_s2`
- `s2_nonlocal`
- `s2_fft_local`
- `fft_wrapper`
- `exnlp_gemm_dot`
- `exnlp_work1_enter`
- `exkin_acc_kernel`
- `frprmn_rhoofk`
- `frprmn_rhoget`
- `frprmn_coef_sync`

Run 02 and 03 only when run 01 passes both correctness checks and has no clear
regression. A run-01 wall regression of about 5% or more, a many-fold slowdown,
exploding repeated transfers or allocations, or a clear regression in the
target timer is an early-stop candidate. Main reports the evidence and waits
for human direction instead of spending two more runs automatically.

For smaller differences, complete all three runs. Use the median, not the mean,
and also report the run-to-run range:

```text
improvement_sec = baseline_median - candidate_median
improvement_pct = improvement_sec / baseline_median * 100
run_range = max(run_01, run_02, run_03) - min(run_01, run_02, run_03)
```

The current tutorial baseline is defined only in
`PERFORMANCE_BASELINE.md`. Production inputs need their own reference,
correctness tolerance, and same-input performance baseline.

## Adoption and Rejection

An implementation is an acceptance candidate only when all three runs pass both
correctness checks, the diagnostic-off median has an advantage over the
same-case baseline, the expected timer signal is observed, fallback remains
valid, and no material portability or ownership risk is introduced.

If the median has no advantage, the change is rejected even if it is correct.
Record its commit, three archives, correctness, median, range, timer evidence,
and reason. After human approval, revert the implementation and recheck the
CPU/FFTW fallback. Do not leave a rejected source experiment as the assumed
baseline or continue directly to another optimization.

## Human Approval Boundaries

Explicit human approval is required before:

- authorizing implementation of a selected hypothesis;
- starting source or document edits for an experiment;
- pushing an implementation or result commit, unless the standing approval
  below applies;
- starting A100 performance or profiler execution;
- changing GPU count, MPI ranks, compiler flags, inputs, references, or
  tolerances;
- accepting an implementation or updating the official baseline;
- reverting an implementation;
- deleting archives or changing branches destructively.

Read-only investigation and result analysis may proceed without changing
external state. When approval is required, Main presents the exact action,
evidence, risks, and rollback before stopping for the human decision.

As of 2026-07-21, the user has granted standing approval to push each newly
created commit on `tddft-openacc-residency` to the same branch on `origin`
immediately after committing. This standing approval is limited to normal
fast-forward pushes of the intended project commit. Force-pushes, another
branch, and commits containing unrelated user changes still require explicit
approval.

For every human-operated A100 action, Main must also place the exact execution
command and the result-check/return instructions directly in the chat. A
helper script or repository document may shorten the procedure but does not
replace the chat instructions.

## Main Result Report

Main reports each completed validation using:

```text
Logical step:
Hypothesis:
Implementation commit:
Tested revision:
Review result:
CPU/FFTW fallback:
GPU build:
Input / steps / hardware:
Diagnostic status:

Run 01: archive, wall_sec, check, compare, key timers
Run 02: archive, wall_sec, check, compare, key timers
Run 03: archive, wall_sec, check, compare, key timers

Median:
Range:
Official same-case baseline:
Difference seconds / percent:
Expected signal:
Observed signal:
Correctness conclusion:
Performance conclusion:
Risks:
Recommendation:
Human approval required:
```

Main stops after this report until the human approves the disposition.
