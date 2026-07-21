# TDDFT GPU Residency Plan

> [Japanese version](tddft_gpu_residency_plan_ja.md)

Date: 2026-07-09

This note records the next GPU optimization direction for the FPSEID21 TDDFT
`Si111-H` validation case. The scope is the current one-GPU, one-MPI-rank path.
The first implementation choice is OpenACC. CUDA libraries such as cuFFT may be
used, but custom CUDA kernels are not the first target.

Implementation progress and measured step results are summarized in
`docs/tddft_gpu_progress_summary.md`.

## Goal

The goal of this branch is to move the TDDFT time-step body to GPU execution
where practical and to minimize host-device memory transfers across the
time-step loop.

The initial target was `s2_fft_local`, but that was only the first high-impact
transfer bottleneck. The optimization boundary should now expand toward the
entire propagation path, while preserving the validated CPU/FFTW path and the
current one-GPU, one-MPI-rank validation policy.

## Current Finding

The cuFFT version is numerically acceptable in relaxed comparison against the
committed GNU reference.

Current 100-step profile snapshot:

| backend | time_step_total | tmevl_s2 | s2_fft_local | fft_wrapper |
| --- | ---: | ---: | ---: | ---: |
| FFTW | 501.068871 s | 357.088483 s | 234.100450 s | 163.592244 s |
| cuFFT | 443.502158 s | 306.979328 s | 183.825464 s | 100.969549 s |
| cuFFT + detailed timer | 450.275156 s | 312.923191 s | 190.457058 s | 109.613606 s |

The detailed cuFFT profile showed:

| item | value |
| --- | ---: |
| cuFFT calls | 336589 |
| host-to-device copy | 47.947526631 s |
| cuFFT execution | 15.640776237 s |
| device-to-host copy | 41.666117352 s |
| total wrapper time | 105.254420208 s |

The dominant cost is data transfer, not the FFT kernel itself.

## Source Data Flow

The hot region is `S2_` in
`FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`.

The measured regions map as follows:

| profile label | source role |
| --- | --- |
| `tmevl_s2` | whole `S2_` operation |
| `s2_nonlocal` | nonlocal pseudopotential application via `exnlp_only_make` and `exnlp_gemm` |
| `s2_fft_local` | local-potential FFT section |
| `fft_wrapper` | individual FFT wrapper calls |

Inside `s2_fft_local`, the data path is:

1. `P(IG,iib)` is scattered into `RHO1_(JG,iib)` using `J2G`.
2. `FFT3BX_fftwASL(..., RHO1_(1,iib), RHO2_(1,iib), ...)` is called for each band.
3. `VG(i)=VGG(i)+Vloc(i)` is prepared on the CPU.
4. The local potential is applied as
   `RHO2_(I,iib)=exp(-i*dt*VG(I))*RHO1_(I,iib)`.
5. `FFT3FX_fftwASL(..., RHO2_(1,iib), RHO1_(1,iib), ...)` is called for each band.
6. `RHO2_(JG,iib)` is gathered back into `P(IG,iib)`.

`RHO1_(NXYZ,mxbnd)` and `RHO2_(NXYZ,mxbnd)` are the first practical GPU
residency targets because each band slice is contiguous in Fortran memory.

## Implementation Policy

Use OpenACC for GPU-resident arrays and element-wise work in the TDDFT Fortran
code. Use cuFFT only as a library backend for FFT operations.

The practical meaning is:

- Prefer `!$acc data`, `!$acc parallel loop`, `!$acc kernels`, and
  `!$acc host_data use_device(...)` in new TDDFT GPU work.
- Do not introduce new hand-written CUDA kernels as the primary implementation
  path.
- Keep the existing CPU/FFTW path and GNU/Intel-oriented source variants usable.
- Treat cuFFT calls as library calls that can operate on OpenACC-managed device
  buffers.
- Keep the existing host-copy cuFFT wrapper for compatibility, and add a
  separate device-pointer cuFFT wrapper for OpenACC-managed arrays.

## cuFFT Wrapper API Boundary

The current cuFFT wrapper copies host arrays to a private CUDA buffer, executes
cuFFT, and copies the result back. That path should remain as the compatibility
backend because it has already passed validation.

For OpenACC residency, add a second wrapper interface that receives a device
pointer and does not perform host-device copies:

```text
existing compatibility API:
  host array -> wrapper H2D -> cuFFT -> wrapper D2H -> host array

new OpenACC API:
  OpenACC device array -> host_data use_device -> cuFFT only
```

The new device-pointer path should:

- assume the input pointer is already a valid device pointer;
- execute cuFFT in place;
- optionally apply cuFFT normalization through OpenACC on the Fortran side;
- report errors without silently falling back to host copies.

This separation is important: if the OpenACC path accidentally calls the
host-copy wrapper, transfer time will remain dominant and the experiment will
not test GPU residency.

## Recommended Implementation Order

### Step 1: OpenACC data region for the local FFT work arrays

Add an OpenACC data region around the `S2_` local FFT section so `RHO1_`,
`RHO2_`, and the local-potential vector can remain on the GPU while the local
FFT pair is evaluated.

Expected benefit:

- Makes data movement explicit and measurable in Fortran.
- Gives a stable base for cuFFT/OpenACC interoperability.
- Avoids introducing custom CUDA kernels before the data lifetime is clear.

The first data-region boundary should be deliberately narrow:

```text
CPU-side nonlocal section completes
copyin P, VGG, Vloc, J2G as needed for the local FFT section
create/copy RHO1_, RHO2_, VG on device
run local FFT section on device
copyout P before returning to CPU-side/nonlocal code
```

This keeps the CPU/GPU ownership clear while the nonlocal sections remain on the
CPU.

Initial implementation note:

- Step 1 may still call the existing host-copy FFT wrapper.
- In that transitional state, use explicit `!$acc update self(...)` before FFT
  calls and `!$acc update device(...)` after FFT calls.
- This does not remove FFT transfer overhead yet. It verifies the OpenACC data
  lifetime and synchronization boundary before adding the device-pointer cuFFT
  API in Step 2.

### Step 2: Use cuFFT through OpenACC device pointers

Process the active band block using cuFFT on OpenACC-managed device memory.
The Fortran side should enter `!$acc host_data use_device(...)` around the cuFFT
library call instead of copying each band to a private CUDA buffer inside the C
wrapper.

### Step 3: Move the local-potential multiply with OpenACC

Move the middle local-potential operation to the GPU:

```fortran
RHO2_(I,iib)=dcmplx(dcos(fac),-dsin(fac))*RHO1_(I,iib)
```

The GPU path should perform:

```text
OpenACC data region for RHO1_/RHO2_/VG
cuFFT inverse/bx using OpenACC device pointer
OpenACC local-potential multiply using VG
cuFFT forward/fx using OpenACC device pointer
OpenACC scaling
copy out only the data required by the following CPU-side section
```

This changes the transfer granularity from one transfer pair per FFT call to
one transfer pair per local FFT block.

Build `VG` on the GPU from `VGG` and `Vloc` unless a validation issue requires a
temporary CPU-generated `VG`:

```fortran
VG(I)=VGG(I)+Vloc(I)
```

```fortran
VG(I)=VGG(I)+Vloc(I)
```

### Step 4: Leave nonlocal sections on CPU initially

The two `s2_nonlocal` regions use `exnlp_only_make` and `exnlp_gemm`. These
should remain CPU-side until the local FFT path is validated.

### Step 5: Reconsider larger residency only after validation

If Step 3 passes and transfer is still the dominant cost, then consider moving
the scatter/gather around `P`, `J2G`, and possibly the nonlocal GEMM path.

## Validation Policy

Use the existing TDDFT archive and comparison flow:

```sh
LABEL=<label> ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/

python3 ./tools/check_tddft_result.py check \
  ./run/tddft_archives/<label>/tddft.out \
  --err ./run/tddft_archives/<label>/tddft.err

python3 ./tools/check_tddft_result.py compare \
  ./run/tddft_archives/<label>/tddft.err
```

For performance, compare at least:

- `time_step_total`
- `tmevl_s2`
- `s2_fft_local`
- `fft_wrapper`
- `[Timer Output]` entries for `cufft_fft3bx` and `cufft_fft3fx`
- `FPSEID_CUFFT_PROFILE` transfer and FFT timings

Correctness acceptance remains the relaxed TDDFT comparison policy unless a
specific strict test is being run.

For the first OpenACC residency changes, also run a short strict-oriented check
before relying on the 100-step relaxed comparison:

```text
1. 2-step or smallest practical TDDFT run.
2. check_tddft_result.py check must pass.
3. compare against the current validated output with tighter tolerances where
   practical.
4. then run the 100-step relaxed comparison.
```

The goal is to catch synchronization mistakes, stale device data, or accidental
use of the host-copy cuFFT wrapper early.

## NVHPC OpenACC Build Notes

The OpenACC path should be built explicitly with NVHPC OpenACC flags. The exact
GPU architecture flag can be environment-specific, but the build must make the
OpenACC mode visible in the command line.

Typical direction:

```sh
BUILD_REPORT=1
FFLAGS="-O2 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays -Kieee"
FFT_BACKEND=cufft
```

`BUILD_REPORT=1` appends compiler-report flags and prints the final build
settings. For NVHPC the default report flags are:

```sh
REPORT_FLAGS="-Minfo=accel -Minfo=mp"
```

Use the report to confirm whether OpenACC regions in `S2_` are recognized and
whether CPU OpenMP regions are still being compiled as expected.

For cuFFT linkage, keep using the existing cuFFT library settings. If the
OpenACC device-pointer wrapper needs CUDA runtime types or cuFFT declarations,
include/library paths should remain explicit as in the validated cuFFT build.

## Current Decision

The current validated direction is:

- Use OpenACC for Fortran-side GPU residency and kernels.
- Use cuFFT as a library backend through OpenACC device pointers.
- Avoid custom CUDA kernels for now.
- Keep one GPU with one MPI rank as the validation target.
- Expand residency from local `S2_` sections toward the whole TDDFT time-step
  body.

The next coding target should be chosen by measured cost, not by replacing all
physics routines at once. After the latest validated run, the likely next
targets are:

1. Reduce `exnlp_gemm_enter` setup/copy cost.
2. Improve the `exnlp_gemm_dot` and `exnlp_gemm_update` kernel structure
   without changing the sequential `ia` dependency.
3. Identify compatibility FFT calls that still use host-copy cuFFT wrappers.
4. Reduce remaining `TMEVL` boundary copies for `P`.

## Post-Step-41 Strategy for Completing Time-Step GPU Residency

No major TDDFT equation is inherently unsuitable for GPU execution. Complete
device-only execution is nevertheless difficult with the current interfaces:

- SCF convergence reads small scalars on the host to control the loop.
- Density and force MPI aggregation and their downstream consumers currently
  use host authority.
- Ionic/external-field updates feed host-side potential producers.
- Output, checkpoints, and reference validation require selected host data.
- The CPU/FFTW fallback must retain its host computation statements.

The goal is therefore not unconditional device-only execution. Large arrays
should remain resident across the widest verified ownership interval, while
host transfers are restricted to convergence scalars, required MPI/force
boundaries, and output data.

The main blockers and planned responses are:

1. `ELECTF/NONLOCF` reads host `COEF`, so the download at FRPRMN exit cannot
   yet be removed. First split `ELECTF` timing into `LOCPOTF`, `NONLOCF`,
   and major reductions. Then port bounded `NONLOCF` consumers incrementally.
2. Direct device generation of `work2_` requires stable ownership for `YLM`,
   `VPJ`, and `EXTAU`. The B1 and Step 20 regressions prohibit retrying this
   path without a bulk-resident producer-input design.
3. Density D2H remains necessary while MPI, convergence, and host potential
   consumers immediately read it. Producer and consumers must move together.
4. Reduction-order changes can alter rounding. Normal check and relaxed
   compare remain mandatory, and nontrivial numerical changes require separate
   approval.

The planned order is:

1. Complete disposition of the unvalidated Step 42 FRPRMN residency for
   `Vloc(:,1:5)`.
2. Add diagnostic timers inside `ELECTF` to resolve its roughly 9-second cost.
3. Port one bounded COEF-dependent `NONLOCF` reduction at a time.
4. Extend COEF device authority from FRPRMN through ELECTF and remove only
   synchronizations whose host consumers have been eliminated.
5. Re-audit density, MPI, ionic, and output boundaries, leaving only unavoidable
   minimal D2H transfers.

Do not retry fine-grained section copies, Step-31-style GDUMP reuse,
ownership-free YLM/`work2_` paths, or small-band-only kernels. Different
hardware and input sizes retain independent performance baselines.

## Post-Step-52 Update

Steps 48-51 completed the FRPRMN diagnosis described above and identified the
`36.132464` sec VPJ_GEN CPU radial integral inside `Part1to5` as the dominant
component. Step 52 implementation `22aad92` offloaded only that integral and
achieved a three-run median of `73.4374880791` sec, `31.8472%` faster than
Step 41. Step 52 is now the official baseline.

The earlier planned-order sections are completed history. The current next
theme is diagnostic only: re-profile the accepted Step 52 source with Nsight
Systems, including its remaining `13.149986` sec FRPRMN residual, and reclassify
CUDA kernels, H2D/D2H, runtime/API, synchronization, MPI, and GPU idle before
selecting one new bounded hypothesis. Trace wall is not a performance baseline.

Step 53 completed that trace. CUDA kernels occupied about `18.7%` of trace
wall, and the new VPJ kernel used `1.793293070` sec. The next diagnostic target
is the `11.815452` sec host/wait envelope remaining after subtracting that
kernel from the `13.608745` sec FRPRMN residual. Step 54 should add default-off
timers around uncovered predictor/corrector control, energy/reduction, density,
and update blocks. Do not select another optimization before its result.

## Post-Step-57 Update

Steps 54-56 isolated LOCPOT as a leading CPU-dominated region. Step 57
implementation `8646707` offloaded only its independent G vectors. All three
diagnostic-off runs passed check and relaxed compare, with a median of
`71.2909028530` sec and a `0.1379821301` sec range. The median is `2.9230%`
faster than Step 52, and median FRPRMN fell by `2.117284` sec. Step 57 is the
new official baseline.

The next theme is diagnostic, not optimization: re-profile the accepted Step
57 source with Nsight Systems and compare its LOCPOT kernel, aggregate CUDA
kernels, H2D/D2H, runtime/API, synchronization, MPI, and GPU-idle structure
with Step 53. Trace wall is not a performance baseline.

The Step 58 trace of the accepted Step 57 source passed both correctness
checks. Aggregate CUDA kernels remained about `14.29` sec. H2D increased by
6,756 calls and D2H by 606 calls, but combined transfer duration increased by
only `0.208290190` sec; the MPI report was empty. Because the LOCPOT kernel
duration was not independently identifiable in the photographed summary rows,
Step 59 will enable only existing timers to measure the current LOCPOT envelope
directly. No additional optimization is selected yet.

Step 59 measured the accepted-source LOCPOT envelope at `0.305052` sec,
`88.9673%` below its Step 56 pre-offload value. The full Vloc envelope fell by
`83.5537%`, and LOCPOT is now only `2.8533%` of the current FRPRMN residual.
Step 60 will diagnose the largest known remaining host region by partitioning
VRHO control into exclusive seed, predictor, and corrector intervals. No
additional optimization is selected before that result.

Step 60 measured `2.787119` sec in VRHO control: `2.215861` sec (`79.5036%`)
in corrector work, `0.552540` sec in seed work, and only `0.016408` sec in
predictor work. Step 61 will split corrector work into interpolation,
convergence, and COEF/VGOLD restoration. No optimization is selected before
that diagnostic result.

Step 61 found `2.158536` sec (`96.3513%` of the corrector parent) in failed-
correction COEF/VGOLD restoration. OpenACC keeps COEF/COEF0 resident and
already restores COEF from device COEF0 at the next correction, so the host
COEF0-to-COEF copy does not update device authority. Step 62 removes only that
host copy under `_OPENACC`, retaining VGOLD, device restoration, MPI, and the
CPU fallback.

Step 62 run 01 passed both correctness checks at `68.66669352055` sec,
`3.6810%` below the accepted Step 57 median. Keep Step 57 as the official
baseline until runs 02 and 03 confirm the result and the three-run median is
classified.

Runs 02 and 03 passed both checks. The final median is `68.5734798908` sec,
`3.811739%` faster than Step 57, with a `0.17894752025` sec range. Step 62 is
accepted and becomes the new official baseline; future hypotheses must compare
against it.

Step 63 will make no source optimization. It will re-run the existing broad
FRPRMN timers on accepted Step 62 source so the next hypothesis is selected
from the current residual rather than stale pre-Step-57/62 timings.

Step 63 classified `99.5381%` of the current `8.547452` sec residual.
`part1to5` is now the largest exclusive envelope at `2.137278` sec. Re-run its
existing child timers before selecting any new implementation.

Step 64 will reuse those default-off child timers through a one-command helper.
No source optimization is included in this diagnostic.

Step 64 found `1.910793` sec in the legacy VPJ integral scope and only
`0.039413` sec in MPI. Step 65 will split the legacy scope into host zeroing,
VPP2 setup, and GPU-kernel-plus-D2H synchronization before choosing a bounded
hypothesis.

Step 65 is a timer-only split of those three regions. The diagnostic-off path
and all computation remain unchanged.
