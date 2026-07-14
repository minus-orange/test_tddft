# TDDFT GPU Progress Summary

> [Japanese version](tddft_gpu_progress_summary_ja.md)

Date: 2026-07-10

This note summarizes the TDDFT GPU work performed on the
`tddft-openacc-residency` branch for the FPSEID21 `Si111-H` 100-step validation
case. The current policy is one GPU with one MPI rank, using OpenACC for data
residency and element-wise kernels, and cuFFT as a CUDA library backend.

## Scope

- Target program: `FPSEID21/tddft_2022October`
- Hot routine: `S2_` in `tmevl10_Avec_v4.f`
- Main target region: local-potential FFT section, `s2_fft_local`
- Validation input: `Si111-H_tm.in_100steps`
- Validation command: `tools/check_tddft_result.py compare ...`
- Reference: `docs/runtime_logs/gnu_si111_h_tddft_100steps.out`
- Comparison policy: relaxed tolerance

## Implemented Changes

### Baseline: cuFFT host-copy backend

The first cuFFT implementation added `fft_cufft.f` and `fpseid_cufft_wrap.c`.
It preserved the original Fortran FFT entry names and copied each FFT input
from host to GPU, executed cuFFT, then copied the result back.

### Step 1: OpenACC local FFT data region

An OpenACC data region was added around the S2 local FFT section. The work arrays
`RHO1_`, `RHO2_`, and `VG` are created on the device, while `P`, `VGG`, `Vloc`,
and `J2G` are copied in for the local FFT block.

At this stage the FFT path still used the host-copy cuFFT wrapper, so explicit
`update self` and `update device` calls remained around the FFT calls.

### Step 2: OpenACC kernels for local-potential work

The scatter, local-potential construction, local-potential multiply, and gather
loops were moved into OpenACC kernels. Additional timers were added:

- `s2_acc_update`
- `s2_acc_kernel`
- `startup_before_steps`
- `fft_plan_init`

### Step 3: Device-resident cuFFT path

A second cuFFT wrapper API was added:

```text
fpseid_cufft_exec_device
```

This API receives an OpenACC-managed device pointer and executes cuFFT in place
without wrapper-managed host-to-device or device-to-host copies.

New Fortran entry points were added:

```text
FFT3BX_fftwASL_ACC
FFT3FX_fftwASL_ACC
```

For the cuFFT backend, these use `!$acc host_data use_device(...)` to pass the
OpenACC device pointer to the C wrapper. The forward FFT normalization is done
with an OpenACC loop on the device.

For FFTW compatibility, the same `_ACC` entry names were added to `fft_fftw.f`
and simply delegate to the original host FFT wrappers.

## Performance Snapshot

All values below are 100-step `Si111-H` TDDFT runs on the tested NVHPC/A100
environment. Exact times can vary by run, but the trend is stable.

| stage | check | compare | wall_sec | time_step_total | s2_fft_local | fft_wrapper | s2_acc_update | s2_acc_kernel |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cuFFT host-copy baseline | PASS | PASS | 443.2 s | 443.5 s | 183.8 s | 101.0 s | n/a | n/a |
| Step 1 | PASS | PASS | 540.2 s | 540.5 s | 282.0 s | 106.1 s | n/a | n/a |
| Step 2 | PASS | PASS | 524.9 s | 525.1 s | 267.6 s | 106.5 s | 93.3 s | 58.3 s |
| Step 3 | PASS | PASS | 360.3 s | 360.6 s | 104.6 s | 30.4 s | 11.1 s | 57.9 s |

Step 3 produced the largest improvement because the dominant transfer overhead
around the S2 FFT pair was removed.

## cuFFT Transfer Profile

The detailed cuFFT wrapper profile changed as follows:

| stage | count | h2d_sec | fft_sec | d2h_sec | total_sec |
| --- | ---: | ---: | ---: | ---: | ---: |
| Step 2 | 336589 | 50.247 | 15.054 | 36.860 | 102.162 |
| Step 3 | 336589 | 6.125 | 13.636 | 6.285 | 26.045 |

The remaining H2D/D2H time indicates that some FFT calls still use the
compatibility host-copy wrapper. The major S2 local FFT path is now using the
device-resident cuFFT entry points.

## Current Interpretation

- Correctness is acceptable for the current validation case:
  `check_tddft_result.py check` and `compare` both pass.
- Step 3 validates the OpenACC + cuFFT device-pointer direction.
- `s2_acc_update` dropped from about 93 s to about 11 s.
- `fft_wrapper` dropped from about 106 s to about 30 s.
- `s2_acc_kernel` stayed around 58 s, so the next optimization target is now
  kernel work and remaining data movement, not the cuFFT kernel itself.

## Remaining Issues

1. Identify remaining host-copy FFT calls.

   `FPSEID_CUFFT_PROFILE` still reports non-zero `h2d_sec` and `d2h_sec`.
   Locate call sites that still use `FFT3BX_fftwASL` / `FFT3FX_fftwASL` instead
   of the `_ACC` entry points, then decide whether they should also move to the
   device-resident path.

2. Break down `s2_acc_kernel`.

   `s2_acc_kernel` remains about 58 s. Split this into scatter, local potential
   build, local-potential multiply, forward-normalization, and gather timers.

3. Reduce residual synchronization and update overhead.

   `s2_acc_update` is much smaller but still about 11 s. Confirm whether this is
   mostly the final `P` update back to host or other implicit synchronization.

4. Decide the boundary for keeping `P` resident.

   The current implementation copies `P` back before returning to CPU-side code.
   Keeping `P` resident across a larger TDDFT section may reduce transfers, but
   it also expands the GPU/CPU ownership boundary.

5. Leave multi-rank GPU execution out of scope for now.

   The current validated GPU direction is one GPU with one MPI rank. Multi-rank
   NVHPC TDDFT already showed rank-count issues in the CPU FFTW path, so it
   should be handled separately from the first GPU residency work.

## Recommended Next Step

The next coding step should instrument and reduce the remaining costs in this
order:

1. Add finer timers inside `s2_acc_kernel`.
2. Identify remaining non-`_ACC` FFT wrapper calls.
3. Confirm whether final `P` copyout dominates `s2_acc_update`.
4. Only after the above, consider extending the OpenACC data lifetime beyond
   the current local FFT block.

This keeps the next experiment measurable and avoids expanding the GPU-resident
region before the remaining Step 3 costs are understood.

## Added Fine-Grained Timers

After the Step 3 run, additional timers were added to split the remaining
`s2_acc_kernel` and `s2_acc_update` costs. These timers are nested inside the
existing aggregate timers, so the aggregate labels remain comparable with the
previous Step 1-3 measurements.

| id | label | measured work |
| ---: | --- | --- |
| 19 | `s2_zero_rho2` | zero initialization of `RHO2_` |
| 20 | `s2_scatter_p` | scatter from `P` to `RHO1_` through `J2G` |
| 21 | `s2_vg_build` | build `VG = VGG + Vloc` |
| 22 | `s2_local_multiply` | apply the local-potential phase factor |
| 23 | `s2_gather_p` | gather from `RHO2_` back to `P` through `J2G` |
| 24 | `s2_copyout_p` | final `P` copyout from device to host |

These labels should appear in both `FPSEID_PROFILE` and `[Timer Output]`.

## Remaining Host-Copy FFT Calls

The S2 local FFT block now calls `FFT3BX_fftwASL_ACC` and `FFT3FX_fftwASL_ACC`.
However, the codebase still has other compatibility FFT calls that use the
host-copy wrapper path. They are outside the current S2 local FFT residency
experiment and explain why `FPSEID_CUFFT_PROFILE` can still show non-zero
`h2d_sec` and `d2h_sec`.

Main remaining call areas:

- `gga_lib_3_PBE.f`: PBE/GGA derivative FFTs
- `lib4_ASL_2_check_Vext_SXACE.f`: startup/external-potential related FFTs
- `frprmn_tm12_check_Vext_Avec_v4.f`: force/minimization related FFTs
- `pspw_tm11_Vext_Avec_v4_alloc.f`: PSPW setup and related transforms
- other `tmevl10_Avec_v4.f` regions outside the current S2 local FFT block

These should not be moved blindly to `_ACC` because each area has a different
data lifetime and CPU/GPU ownership boundary. The next decision should be based
on the new fine-grained timer output.

## Scatter Parallelization Experiment

The Step 4 timer output showed that `s2_scatter_p` dominated the remaining
OpenACC kernel time. The first follow-up change flattens the `P -> RHO1_`
scatter loop from a band-outer nested loop into a single
`NXYZ * nbndloc` OpenACC loop. This gives the compiler a much larger iteration
space for the scatter kernel while preserving the same `J2G` mapping.

The Step 5 run passed both `check` and relaxed `compare`. In that run,
`s2_scatter_p` dropped from about 56 s to about 0.46 s, and total wall time
dropped to about 303 s. This confirms that the scatter loop flattening is a
useful optimization for the current one-rank A100 case.

## Step 6: Nonlocal Split Timers

After Step 5, the largest remaining S2 cost is `s2_nonlocal`. Step 6 adds nested
timers that split this aggregate region without changing the computation:

| id | label | measured work |
| ---: | --- | --- |
| 25 | `s2_nonlocal_make` | repeated `exnlp_only_make` calls that build `work2_`, `cfac_`, and `ngnl_` input data |
| 26 | `s2_nonlocal_gemm` | `exnlp_gemm` accumulation into `P` |

These timers are nested inside `s2_nonlocal`, so:

```text
s2_nonlocal ≈ s2_nonlocal_make + s2_nonlocal_gemm + loop/control overhead
```

Use the next run to decide whether the next GPU work should target
`exnlp_only_make` construction, `exnlp_gemm`, or both.

The Step 6 result showed that `s2_nonlocal_gemm` dominates this region:

```text
s2_nonlocal       about 119.0 sec
s2_nonlocal_make  about   3.3 sec
s2_nonlocal_gemm  about 115.7 sec
```

## Step 7: Experimental OpenACC exnlp_gemm

Step 7 moves the inner work of `exnlp_gemm` to OpenACC while preserving the
outer `ia` order. The `ia` loop updates `coef` sequentially and therefore is
kept on the host side for correctness. Within each `ia`, the implementation
parallelizes over local bands and uses real/imaginary reductions for the dot
product.

This is intentionally conservative:

- It does not reorder the `ia` updates.
- It avoids complex reduction syntax and uses two real reductions.
- It is expected to validate correctness first; performance may still be
  limited by per-call data movement and kernel launch overhead.

Recommended archive label:

```text
nvhpc_cufft_1rank_02_STEP7_01
```

## Step 8: exnlp_gemm Split Timers

Step 7 made `exnlp_gemm` correct and useful, but it remains the largest
nonlocal contribution. Step 8 adds nested timers to split the region without
changing the numerical algorithm.

| id | label | measured work |
| ---: | --- | --- |
| 27 | `exnlp_gemm_data` | whole OpenACC data region in `exnlp_gemm`, including transfer and kernels |
| 28 | `exnlp_gemm_dot` | dot-product/reduction kernel that builds `ct1` |
| 29 | `exnlp_gemm_update` | coefficient update kernel using `ct1` and `work1` |

`exnlp_gemm_data` is intentionally broad. It is not a pure copy timer; it
contains the OpenACC data-region lifetime plus the inner GPU kernels. If this
region is still expensive after the next run, the next step should separate
explicit `enter data` / `exit data` transfer timing from kernel timing.

Recommended archive label:

```text
nvhpc_cufft_1rank_02_STEP8_01
```

## Step 9: exnlp_gemm Transfer Split

The Step 8 result showed that `exnlp_gemm_data` is much larger than
`exnlp_gemm_dot + exnlp_gemm_update`, so the remaining cost is likely dominated
by OpenACC data-region overhead, data transfer, or untimed setup kernels.

Step 9 replaces the implicit structured data region in `exnlp_gemm` with
explicit `enter data` / `exit data` directives so that the cost can be split
without changing the computation.

| id | label | measured work |
| ---: | --- | --- |
| 30 | `exnlp_gemm_enter` | device allocation and copy-in before the `ia` loop |
| 31 | `exnlp_gemm_zero` | `ct1` initialization kernel inside the `ia` loop |
| 32 | `exnlp_gemm_exit` | copy-out of `coef` and device deallocation after the `ia` loop |

Recommended archive label:

```text
nvhpc_cufft_1rank_02_STEP9_01
```

## Step 10: Keep P Resident Across S2

The Step 9-style run showed that `exnlp_gemm_enter` and `exnlp_gemm_exit`
remain large. This means that copying `P` into and out of each `exnlp_gemm`
call is a major part of the remaining cost.

Step 10 keeps `P` resident across the whole `S2_` routine:

- `P(1:NG2Q,1:nbndloc)` is copied to the device once before the first
  nonlocal operation.
- Both `exnlp_gemm` calls use `P` through `present`.
- The local FFT/potential section also uses the same device-resident `P`.
- `P` is copied back once at the end of `S2_`.

Additional timers:

| id | label | measured work |
| ---: | --- | --- |
| 33 | `s2_p_enter` | one-time `P` copy-in at the beginning of `S2_` |
| 34 | `s2_p_exit` | one-time `P` copy-out at the end of `S2_` |

Recommended archive label:

```text
nvhpc_cufft_1rank_02_STEP10_01
```

Observed Step 10-equivalent result:

```text
archive label: nvhpc_cufft_1rank_02_STEP9_01
check: PASS
compare: PASS
wall_sec: 232.159
time_step_total: about 232.46 sec
s2_p_enter: about 14.05 sec
s2_p_exit: about 11.18 sec
```

This confirms that keeping `P` resident within each `S2_` call is correct and
substantially faster than the previous finer-grained `exnlp_gemm` transfer
split. The remaining `s2_p_enter + s2_p_exit` cost is still about 25 sec, so the
next step is to move the `P` residency boundary from `S2_` to `TMEVL`.

## Step 11: Keep P Resident Across TMEVL

Step 11 moves ownership of `P(1:NG2Q,1:nbndloc)` from `S2_` to the surrounding
`TMEVL` fourth-order propagation path (`ioption.eq.4`).

Implemented changes:

- `TMEVL` copies `P` to the device once before the first `exkin_` call.
- `TMEVL` copies `P` back to the host once after the final `exkin_` call.
- `S2_` no longer performs its own `P` enter/exit.
- `exkin_` now updates resident `P` with an OpenACC `parallel loop`.

Additional timers:

| id | label | measured work |
| ---: | --- | --- |
| 35 | `tmevl_p_enter` | one-time `P` copy-in before the `ioption.eq.4` propagation sequence |
| 36 | `tmevl_p_exit` | one-time `P` copy-out after the `ioption.eq.4` propagation sequence |
| 37 | `exkin_acc_kernel` | OpenACC kinetic-energy phase update in `exkin_` |

Expected validation:

```text
LABEL=nvhpc_cufft_1rank_02_STEP10_01 ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
python3 ./tools/check_tddft_result.py check ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP10_01/tddft.err
python3 ./tools/check_tddft_result.py compare ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP10_01/tddft.err
```

The main expected performance signal is that `s2_p_enter` and `s2_p_exit`
should disappear from the active timer list, replaced by one `tmevl_p_enter`
and one `tmevl_p_exit` per time step. `exkin_acc_kernel` should also appear and
should be checked against the existing `tmevl_exkin` aggregate.

Observed Step 11 result:

```text
archive label: nvhpc_cufft_1rank_02_STEP10_01
check: PASS
compare: PASS
wall_sec: 179.769
time_step_total: about 180.06 sec
tmevl_total: about 108.94 sec
tmevl_s2: about 66.22 sec
s2_nonlocal: about 43.74 sec
s2_fft_local: about 22.46 sec
fft_wrapper: about 28.77 sec
tmevl_p_enter: about 2.99 sec
tmevl_p_exit: about 2.73 sec
exkin_acc_kernel: about 1.08 sec
```

Compared with the Step 10-equivalent run, the `P` transfer cost dropped from
about `s2_p_enter + s2_p_exit = 25.2 sec` to about
`tmevl_p_enter + tmevl_p_exit = 5.7 sec`. The 100-step wall time improved from
about 232 sec to about 180 sec.

The remaining dominant regions are now:

- `s2_nonlocal_gemm`: about 40.8 sec
- `s2_fft_local`: about 22.5 sec
- `exnlp_gemm_dot + exnlp_gemm_update`: about 25.8 sec
- `exnlp_gemm_enter + exnlp_gemm_zero`: about 13.9 sec

This suggests that the next useful experiment should target `exnlp_gemm`
itself, especially reducing per-call data setup and improving the dot/update
kernel structure, rather than further extending `P` copy boundaries first.

## Step 12: Remove Redundant exnlp_gemm Zero Kernel

Step 12 removes the `ct1` zero-initialization OpenACC kernel from the
`exnlp_gemm` inner `ia` loop.

Rationale:

- The following `exnlp_gemm_dot` kernel writes `ct1(iib)` for every
  `iib = 1, nbndloc` before `ct1` is used by the update kernel.
- Therefore the previous `ct1(iib) = (0.d0,0.d0)` kernel was redundant.
- In the Step 11 measurement, `exnlp_gemm_zero` cost about 5.8 sec, so removing
  it should reduce kernel launch work and eliminate that timer region.

Expected validation:

```text
LABEL=nvhpc_cufft_1rank_02_STEP11_01 ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
python3 ./tools/check_tddft_result.py check ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP11_01/tddft.err
python3 ./tools/check_tddft_result.py compare ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP11_01/tddft.err
```

The expected performance signal is that `exnlp_gemm_zero` should disappear
from the timer output, while `check` and relaxed `compare` should remain `PASS`.
If this passes, the next larger experiment is to restructure `exnlp_gemm` so
that the dot and update work can avoid unnecessary temporary setup or launch
overhead.

Observed result with the Step 12 code, archived as `STEP11_01`:

```text
archive label: nvhpc_cufft_1rank_02_STEP11_01
check: PASS
compare: PASS
wall_sec: 172.646986008
time_step_total: about 172.94 sec
tmevl_total: about 101.42 sec
tmevl_s2: about 58.80 sec
s2_nonlocal: about 37.05 sec
s2_fft_local: about 21.74 sec
fft_wrapper: about 28.05 sec
s2_nonlocal_make: about 2.90 sec
s2_nonlocal_gemm: about 34.13 sec
exnlp_gemm_data: about 34.11 sec
exnlp_gemm_dot: about 13.37 sec
exnlp_gemm_update: about 11.88 sec
exnlp_gemm_enter: about 8.16 sec
exnlp_gemm_exit: about 0.03 sec
tmevl_p_enter: about 3.00 sec
tmevl_p_exit: about 2.71 sec
exkin_acc_kernel: about 1.07 sec
```

The expected signal was confirmed: `exnlp_gemm_zero` no longer appears in the
timer output, while both `check` and relaxed `compare` still pass. The measured
wall time improved from about 179.77 sec to about 172.65 sec.

## Current Goal

The project goal for this branch is now:

```text
Move the whole TDDFT time-step body to GPU execution where practical, and
minimize host-device memory transfers across the time-step loop.
```

This means the optimization boundary is no longer only `s2_fft_local`.
`s2_fft_local` was the first target because it exposed the largest avoidable
FFT transfer cost, but the remaining work should expand toward all major
regions inside the propagation step.

## Current Status

Accomplished:

- The validated path is still one GPU with one MPI rank.
- cuFFT is used as the FFT library backend.
- OpenACC manages device-resident arrays and element-wise kernels.
- `P` is resident across the `TMEVL` propagation block instead of being copied
  in/out for every `S2_` call.
- The S2 local FFT path uses device-pointer cuFFT entry points.
- Scatter, gather, local-potential multiply, kinetic phase update, and parts of
  the nonlocal GEMM path are OpenACC kernels.
- The Step 12 code passes `check` and relaxed `compare` against the committed
  GNU reference.

Remaining issues:

1. `exnlp_gemm_enter` is still about 8 sec.

   `work1`, `cfac`, and `ngnl` are still copied or created per `exnlp_gemm`
   call. The next target is to reduce this setup cost or extend the residency
   of these nonlocal inputs safely.

2. `exnlp_gemm_dot + exnlp_gemm_update` remains about 25 sec.

   The dot/update structure is correct but still expensive. Any change here
   must preserve the sequential `ia` update dependency.

3. `fft_wrapper` still reports about 28 sec.

   Major S2 local FFT calls are device-resident, but compatibility host-copy
   FFT calls remain elsewhere. These should be moved only after confirming
   their data ownership boundaries.

4. `tmevl_p_enter + tmevl_p_exit` remains about 5.7 sec.

   This is much smaller than the previous S2-level copies, but full time-step
   GPU residency will require reducing or eliminating these remaining
   time-step boundary transfers.

5. CPU-side routines still exist inside the time-step body.

   The current GPU work has focused on the measured hot regions. A later pass
   should audit the full time-step body and classify each CPU-side section as:
   keep on CPU, move to OpenACC, or isolate behind a transfer boundary.

Recommended next step:

1. Split `exnlp_gemm_enter` into copy/setup components, or move one candidate
   nonlocal input buffer to a longer-lived OpenACC data region.
2. Keep using `check_tddft_result.py check` and relaxed `compare` after every
   step.
3. Archive each successful run with a monotonic label such as
   `nvhpc_cufft_1rank_02_STEP12_01`.

## Step 13: Split exnlp_gemm Enter Cost

Step 13 is a measurement-only change. It keeps the aggregate
`exnlp_gemm_enter` timer, but splits the OpenACC `enter data` work inside it:

| id | label | measured work |
| ---: | --- | --- |
| 38 | `exnlp_work1_enter` | copy-in of `work1(1:NGcont,1:loopcnt)` |
| 39 | `exnlp_meta_enter` | copy-in of `cfac(1:loopcnt)` and `ngnl(1:loopcnt)` |
| 40 | `exnlp_ct1_create` | device allocation of `ct1(1:nbndloc)` |

This should not change numerical results. The purpose is to decide whether the
next real optimization should target the large `work1` transfer, metadata
transfer, or temporary allocation.

Recommended archive label:

```text
nvhpc_cufft_1rank_02_STEP12_01
```

## Step 14: Probe exnlp Cache Invariance

Step 14 is also a measurement-only change. The Step 13 result showed that
`exnlp_work1_enter` dominates `exnlp_gemm_enter`, so the next optimization
candidate is to avoid rebuilding or recopying the nonlocal projector input
buffer passed as `work1` to `exnlp_gemm`.

Before doing that, the code now probes whether the generated inputs are stable
for each atom-type index and phase:

- `phase=1`: the first nonlocal block in `S2_`
- `phase=2`: the second nonlocal block in `S2_`
- probed data: `work2_`, `cfac_`, and `ngnl_`

The probe records a lightweight numeric signature the first time each
`NP/phase` pair is seen and prints:

```text
FPSEID_EXNLP_CACHE_REF np phase sig= ...
```

If the signature later changes beyond the diagnostic tolerance, it prints:

```text
FPSEID_EXNLP_CACHE_DIFF np phase ref sig= ...
```

This is not an exhaustive bitwise comparison. It is a low-cost guard for the
current validation run. If no `FPSEID_EXNLP_CACHE_DIFF` lines appear in the
100-step run, the next coding step is to cache `work2_` per `NP/phase` and make
`exnlp_gemm` consume the cached, device-resident buffer.

Recommended archive label:

```text
nvhpc_cufft_1rank_02_STEP13_01
```

Suggested check:

```sh
grep FPSEID_EXNLP_CACHE run/tddft_archives/nvhpc_cufft_1rank_02_STEP13_01/tddft.out
```

Expected result for the cache experiment:

- `FPSEID_EXNLP_CACHE_REF` appears for the observed `NP/phase` pairs.
- `FPSEID_EXNLP_CACHE_DIFF` does not appear.

## Step 15: Component Probe for exnlp Cache

The Step 14 run showed `FPSEID_EXNLP_CACHE_DIFF` for all observed `NP/phase`
pairs. This means the combined `work2_ + cfac_ + ngnl_` signature changes during
the TDDFT time evolution, so a simple cache keyed only by `NP/phase` is not safe.

Step 15 refines the probe by splitting the signature into three components:

- `ng`: integer `ngnl_` projector lengths
- `cf`: complex `cfac_` coefficients
- `wk`: sampled `work2_` projector values

The reference line now prints all three component signatures:

```text
FPSEID_EXNLP_CACHE_REF np phase ng cf wk= ...
```

If a component changes later, the diff line identifies the component:

```text
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... ngnl ...
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... cfac ...
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... work ...
```

Interpretation:

- If only `work` changes, keep `ngnl_` and `cfac_` resident/cached and move
  projector value generation closer to GPU.
- If `cfac` also changes, keep only `ngnl_` resident and generate/copy
  coefficient data per step.
- If `ngnl` changes, do not cache the projector metadata for this path.

Recommended archive label:

```text
nvhpc_cufft_1rank_02_STEP14_01
```

Observed Step 15 result:

The component probe showed differences in all checked nonlocal input
components:

- `ngnl`
- `cfac`
- `work`

Therefore a cache keyed by only `NP/phase` is rejected. Caching only metadata is
also not safe for this validation path because `ngnl` changes. The probe was
removed from the active code after recording this result so that later timing
runs are not polluted by diagnostic output or extra host-side work.

## Step 16: Nonlocal Input Residency Direction

Step 16 resets the nonlocal optimization direction after the cache experiment.
The next target is not reuse of old projector input data. Instead, the target
is to move projector input generation closer to its GPU consumer:

```text
exnlp_only_make -> exnlp_gemm
```

The current cost model is:

- `exnlp_only_make` builds `work2_`, `cfac_`, and `ngnl_` on the host.
- `exnlp_gemm` copies those inputs to the device, then updates resident `P`.
- `exnlp_work1_enter` remains a measurable transfer/setup cost.

The preferred next implementation path is:

1. Keep the existing host-generated path as the correctness fallback.
2. Add an experimental OpenACC path that generates the nonlocal projector input
   and consumes it without a host round trip.
3. Validate each step with `check_tddft_result.py check` and relaxed `compare`.
4. Keep the `ia` update order in `exnlp_gemm` unchanged unless a separate
   correctness experiment proves the reorder acceptable.

Recommended archive label for the next successful run:

```text
nvhpc_cufft_1rank_02_STEP16_01
```

Implemented Step 16 change:

- Split `exnlp_gemm` into a transfer-owning wrapper and a shared GPU kernel
  body.
- Added `exnlp_gemm_present_inputs`, which assumes `work1`, `cfac`, `ngnl`,
  and `coef` are already present on the device and only creates/deletes the
  temporary `ct1` buffer.
- The current call sites still use the original `exnlp_gemm` wrapper, so this
  step is intended to preserve numerical behavior while preparing the next
  step where `work2_`, `cfac_`, and `ngnl_` can be generated and consumed on
  the device.

Expected validation:

```text
python3 ./tools/check_tddft_result.py check \
  ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP16_01/tddft.err

python3 ./tools/check_tddft_result.py compare \
  ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP16_01/tddft.err
```

## Step 17: Use Present-Input exnlp GEMM Call Path

Step 17 connects the new `exnlp_gemm_present_inputs` routine to the two
nonlocal call sites in `S2_`.

Implemented change:

- `work2_`, `cfac_`, and `ngnl_` are explicitly copied to the device at the
  `S2_` call site before `exnlp_gemm_present_inputs`.
- `exnlp_gemm_present_inputs` consumes those already-present inputs and updates
  the resident `P`.
- The call site explicitly deletes `work2_`, `cfac_`, and `ngnl_` after the
  GEMM path returns.
- The original transfer-owning `exnlp_gemm` wrapper is kept as the fallback
  implementation.

This step does not yet remove the host generation of `work2_`, `cfac_`, and
`ngnl_`. It makes the data ownership boundary explicit so that the next step can
move selected input generation onto the GPU and feed the present-input GEMM
path without a host round trip.

Timer interpretation:

- `exnlp_work1_enter` and `exnlp_meta_enter` now measure the caller-side
  explicit input copy-in.
- `exnlp_ct1_create` and `exnlp_gemm_dot/update` remain inside
  `exnlp_gemm_present_inputs`.
- `exnlp_gemm_exit` now also includes caller-side deletion of the explicit
  nonlocal input buffers.

Expected validation label:

```text
nvhpc_cufft_1rank_02_STEP17_01
```

Observed Step 17 result:

```text
archive label: nvhpc_cufft_1rank_02_STEP17_01
check: PASS
compare: PASS
wall_sec: 170.24688876
time_step_total: about 170.53 sec
tmevl_total: about 100.45 sec
tmevl_s2: about 58.46 sec
s2_nonlocal: about 36.39 sec
s2_fft_local: about 22.06 sec
fft_wrapper: about 28.39 sec
s2_nonlocal_make: about 2.68 sec
s2_nonlocal_gemm: about 33.69 sec
exnlp_gemm_data: about 25.39 sec
exnlp_gemm_dot: about 13.35 sec
exnlp_gemm_update: about 11.25 sec
exnlp_work1_enter: about 8.08 sec
exnlp_meta_enter: about 0.16 sec
exnlp_ct1_create: about 0.02 sec
tmevl_p_enter: about 2.97 sec
tmevl_p_exit: about 2.72 sec
```

The correctness result is unchanged from Step 16. The wall time is also nearly
unchanged, which is expected because Step 17 only moves the explicit ownership
of `work2_`, `cfac_`, and `ngnl_` to the caller. The data is still generated on
the host and copied to the device. The important outcome is that the
present-input path is now validated at the real call sites, so the next step can
start moving `exnlp_only_make` output generation toward the GPU without changing
the GEMM consumer again.

## Step 18: Fuse Present-Input exnlp GEMM Dot/Update

Step 18 changes only the already validated `exnlp_gemm_present_inputs` path.
The older transfer-owning `exnlp_gemm` wrapper is kept as the fallback path.

Implementation change:

- Added `exnlp_gemm_body_fused`.
- `exnlp_gemm_present_inputs` now calls the fused body directly.
- The fused body computes the dot product and immediately applies the
  coefficient update inside the same OpenACC `parallel loop` over local bands.
- The temporary `ct1` device allocation is no longer used by the
  present-input path.
- The original `exnlp_gemm_body` remains in place for the fallback
  `exnlp_gemm` wrapper.

Expected performance signal:

- `exnlp_ct1_create` should disappear from the present-input path.
- `exnlp_gemm_update` should disappear from the present-input path because the
  update is included in `exnlp_gemm_dot`.
- `exnlp_gemm_dot` should increase relative to Step 17, but the combined
  `exnlp_gemm_dot + exnlp_gemm_update + exnlp_ct1_create` cost should decrease
  if the fused kernel is effective.
- Correctness should continue to pass with the relaxed TDDFT comparator.

Expected validation label:

```text
nvhpc_cufft_1rank_02_STEP18_01
```

Observed Step 18 result:

```text
archive label: nvhpc_cufft_1rank_02_STEP18_01
check: PASS
compare: PASS
wall_sec: 163.310745001
time_step_total: about 163.60 sec
tmevl_total: about 92.92 sec
tmevl_s2: about 50.91 sec
s2_nonlocal: about 28.41 sec
s2_fft_local: about 22.48 sec
fft_wrapper: about 28.80 sec
s2_nonlocal_make: about 2.88 sec
s2_nonlocal_gemm: about 25.51 sec
exnlp_gemm_data: about 17.20 sec
exnlp_gemm_dot: about 16.84 sec
exnlp_gemm_update: removed from the present-input path
exnlp_ct1_create: removed from the present-input path
exnlp_work1_enter: about 8.10 sec
exnlp_meta_enter: about 0.15 sec
```

The expected signal was confirmed. The fused present-input path removes the
`ct1` allocation and the separate update kernel from this path while preserving
the relaxed TDDFT comparison result. The measured wall time improved from the
Step 17 result of about 170.25 sec to about 163.31 sec. The remaining major
costs are now `tmevl_total`, `s2_nonlocal`, and `s2_fft_local`; inside
`s2_nonlocal`, the next target is the remaining nonlocal GEMM/input-generation
cost rather than the removed `ct1`/update split.

## Step 19: Move exnlp Input Lifetime Toward the Caller

Step 19 continued the attempt to reduce data motion in the nonlocal path by
moving more of the `exnlp_gemm` input ownership toward the `S2_` call site.

Observed Step 19 result:

```text
archive label: nvhpc_cufft_1rank_02_STEP19_01
check: PASS
compare: PASS
wall_sec: 178.063332081
time_step_total: about 178.36 sec
tmevl_total: about 108.53 sec
tmevl_s2: about 66.17 sec
s2_nonlocal: about 45.51 sec
s2_fft_local: about 20.64 sec
fft_wrapper: about 27.01 sec
s2_nonlocal_make: about 30.44 sec
s2_nonlocal_gemm: about 15.04 sec
exnlp_gemm_data: about 14.86 sec
exnlp_gemm_dot: about 14.52 sec
exnlp_work1_enter: about 0.03 sec
exnlp_meta_enter: about 0.13 sec
```

The result stayed numerically valid, but performance regressed relative to
Step 18. The explicit input transfer cost moved out of `exnlp_gemm_data`, but
the cost reappeared in `s2_nonlocal_make`. In other words, the GEMM consumer was
cleaner, but the producer side became the bottleneck.

## Step 20: exnlp Make Lookup Copy Experiment

Step 20 tested a correctness-first variant for the `exnlp_only_make_acc` input
lookup arrays. It avoided the OpenACC present-table mismatch that occurred when
trying to keep larger parent arrays resident, but it introduced heavy repeated
copy cost.

Observed Step 20 result:

```text
archive label: nvhpc_cufft_1rank_02_STEP20_01
check: PASS
compare: PASS
wall_sec: 819.404727936
time_step_total: about 819.69 sec
tmevl_total: about 749.54 sec
tmevl_s2: about 707.44 sec
s2_nonlocal: about 691.47 sec
s2_fft_local: about 15.95 sec
fft_wrapper: about 22.61 sec
s2_nonlocal_make: about 679.87 sec
s2_nonlocal_gemm: about 11.57 sec
exnlp_gemm_dot: about 11.39 sec
exnlp_work1_enter: about 1.00 sec
exnlp_meta_enter: about 0.03 sec
```

This confirms that the current `exnlp_only_make_acc` lookup-transfer approach
is correct but not a viable performance direction. The dominant regression is
`s2_nonlocal_make`, not cuFFT or the fused GEMM body.

## Current Status

The working goal remains:

```text
Keep the full TDDFT time-step loop on the GPU and minimize host/device memory
transfers inside the step loop.
```

Validated positive results so far:

- cuFFT replacement is numerically valid with the relaxed TDDFT comparator.
- The one-rank, one-GPU route is the current baseline policy.
- `S2_` local/FFT-side residency and cuFFT device-resident execution are valid.
- The fused present-input nonlocal GEMM path is valid and improved performance
  through Step 18.
- Step 18 is the latest clearly useful performance point in this sequence:
  about 163 sec for the 100-step Si111-H TDDFT sample.

Current code state:

- The latest code is past Step 20 experiments and includes a correctness-first
  lookup-input copy approach for `exnlp_only_make_acc`.
- It should be treated as an experimental state, not as the performance
  baseline.
- If the current head is used for timing, compare it with Step 18 and confirm
  whether `s2_nonlocal_make` dominates before accepting it.

## Remaining Work

1. Fix `exnlp_only_make_acc` input residency.

   `ylm`, `vpj`, and `extau` need a stable OpenACC ownership strategy. The
   present-table failures show that parent-array lifetime and dummy-argument
   sections are not yet aligned. Repeated fine-grained copyin is correct but too
   slow.

2. Recover or exceed the Step 18 performance point.

   Any next step should first recover the Step 18 level of about 163 sec before
   being considered a real improvement. Step 20 is useful as a correctness
   checkpoint, not as a performance checkpoint.

3. Continue reducing host/device transfers inside the time-step loop.

   The remaining high-cost areas are `s2_nonlocal`, `tmevl_s2`, and the FFT path.
   The priority is still to avoid moving large or frequently used arrays across
   the host/device boundary inside the repeated loops.

4. Keep fallback paths and validation scripts.

   The CPU/FFTW fallback and the relaxed TDDFT comparator remain important
   because the OpenACC work is now experimental. Every performance step should
   continue to archive output and pass both `check` and `compare`.

## B1 YLM ownership experiment and rollback

B1 made TMEVL the device-lifetime owner of `YLM1..5` and replaced the callee
YLM-section `copyin` with `present`. Diagnostics reported present parent and
section mappings in all five phases, with observed address offsets matching the
expected offsets. Both the result `check` and relaxed `compare` passed.

The three performance runs were:

```text
wall_sec: 174.30, 174.05, 174.32 sec
median:   174.30 sec
Step 18:  163.31 sec
increase: about 6.7 percent
```

The median was about 6.7% slower than Step 18 and failed the within-3% adoption
gate. B1 was therefore rejected, and commit `a40ddd6` rolled back only the YLM
ownership change. The rollback has been pushed to
`origin/tddft-openacc-residency`. VPJ/EXTAU ownership must not proceed until
three diagnostic-OFF Step-18-equivalent runs confirm baseline recovery.

### Post-rollback Step 18 baseline recovery

After restoring the code to the state recorded by Step 18 commit `732793d`,
the 100-step case was rerun three times with diagnostics off and one GPU / one
MPI rank.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_B1_ROLLBACK_01` | 162.262726068 | PASS | PASS |
| `nvhpc_cufft_1rank_02_B1_ROLLBACK_02` | 161.753436089 | PASS | PASS |
| `nvhpc_cufft_1rank_02_B1_ROLLBACK_03` | 161.717231989 | PASS | PASS |

The three-run median is `161.753436089` sec, about 0.954% faster than the
official Step 18 value of `163.310745001` sec. The run-to-run range is about
0.545 sec. The median is within the +3% limit of `168.210067351` sec, and all
runs passed both the normal check and relaxed comparison. The post-rollback
baseline recovery gate is therefore complete.

The common maximum absolute differences in the relaxed comparisons were ETOT
`9.287000e-05`, Eelec+Enucl-Eext-Ework `9.497180e-05`, force `9.050000e-05`,
positions `8.117602e-07`, and velocities `2.087788e-07`; all were within their
configured tolerances.

## Step 21: Device-Resident Batched cuFFT for the S2 Local FFT Path

Step 21 replaces the separate forward and backward cuFFT calls for every local
band in `S2_` with one batched cuFFT call over all `nbndloc` bands. The cuFFT
wrapper lazily creates and reuses `cufftPlanMany` batch plans and destroys them
through the existing finalizer. OpenACC device pointers are passed directly, so
the change adds no large H2D or D2H transfer. The CPU/FFTW fallback is preserved
by batch entries that invoke the original functions in band order.

The implementation commit is `bad046f` (`Batch device-resident S2 cuFFT
calls`). Three diagnostic-off, one-GPU / one-MPI-rank, 100-step runs were made.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP21_BATCHFFT_01` | 146.439893007 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP21_BATCHFFT_02` | 147.131322861 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP21_BATCHFFT_03` | 146.540076017 | PASS | PASS |

The three-run median is `146.540076017` sec. It is about 9.405% faster than the
refreshed post-rollback Step 18 median of `161.753436089` sec and about 10.269%
faster than the official Step 18 value of `163.310745001` sec. The run-to-run
range is about 0.691 sec. The median is about 20.066 sec below the +3% adoption
limit of `166.606039172` sec, so it passes the performance gate.

In the run 01 profile, `s2_fft_local` was `5.026740` sec, `fft_wrapper` was
`13.494185` sec, and `tmevl_s2` was `34.768706` sec. Relative to the approximate
Step 18 profile values, these are reductions of about 77.6%, 53.1%, and 31.7%,
respectively, confirming that the batch optimization affected the intended FFT
path. The main remaining cost has shifted to `s2_nonlocal` at `29.728696` sec.

All runs passed both the normal check and relaxed comparison. Their common
maximum absolute differences are unchanged from the recovered Step 18 runs and
remain within the configured tolerances. Step 21 is therefore accepted. Its
implementation commit remains the rollback target and comparison point for the
next performance hypothesis.

## Step 22: Persistent Device Allocation for Nonlocal Staging Buffers

Step 22 removes the repeated OpenACC `enter data copyin` and `exit data delete`
operations for `work2_`, `cfac_`, and `ngnl_` in each `S2_` nonlocal phase.
These arrays already have saved host allocations, so their device storage is
now created once. Each phase only updates the host-generated values on the
device. The large H2D data volume, nonlocal calculation, `ia` update order, and
YLM/VPJ/EXTAU ownership are unchanged. The CPU/FFTW fallback full link passed.

The implementation commit is `1b98197` (`Persist nonlocal staging buffers on
device`). Three diagnostic-off, one-GPU / one-MPI-rank, 100-step runs were made.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP22_PERSIST_NLBUF_01` | 146.283041954 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP22_PERSIST_NLBUF_02` | 146.165471077 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP22_PERSIST_NLBUF_03` | 146.268707991 | PASS | PASS |

The three-run median is `146.268707991` sec, about 0.185% faster than the Step
21 median of `146.540076017` sec. The run-to-run range is about 0.118 sec, and
the median is within the Step 21 +3% limit of `150.936278298` sec. Every run
passed both the normal check and relaxed comparison with the same maximum
absolute differences as the preceding runs.

In the run 01 profile, `s2_nonlocal` was `29.425824` sec, `tmevl_s2` was
`34.474580` sec, `exnlp_work1_enter` was `8.071267` sec, and
`exnlp_meta_enter` was `0.150348` sec. `exnlp_gemm_exit`, which measured the
repeated delete path, disappeared from the profile and the timer count dropped
from 32 to 31. Although the wall-time improvement is small, Step 22 is accepted
because it removes repeated device allocation without regressing performance.

## Step 23: Reuse Staging Buffers in the Reverse Nonlocal Phase

Each `S2_` applies nonlocal projectors before and after the local potential.
The first phase traverses every `ity/it/il/ip/l` index in descending order, and
the second traverses the same index set in ascending order. The second projector
column sequence is therefore the exact reverse of the first. Step 23 reuses the
device-resident `work2_`, `cfac_`, and `ngnl_` values generated by the first
phase and maps only the consumer column index to `loopcnt-ia+1`. This preserves
the original sequential `ia` application order while removing the second host
generation and large H2D transfer.

The implementation commit is `f911621` (`Reuse nonlocal staging buffers in
reverse phase`). After confirming the CPU/FFTW fallback full link, three
diagnostic-off, one-GPU / one-MPI-rank, 100-step runs were made.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP23_REVERSE_REUSE_01` | 140.934056997 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP23_REVERSE_REUSE_02` | 140.840327024 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP23_REVERSE_REUSE_03` | 140.451899052 | PASS | PASS |

The three-run median is `140.840327024` sec. It is about 3.711% faster than the
Step 22 median of `146.268707991` sec and about 12.929% faster than the refreshed
Step 18 median of `161.753436089` sec. The run-to-run range is about 0.482 sec,
and every run passed both the normal check and relaxed comparison.

In run 01, the `exnlp_work1_enter` and `exnlp_meta_enter` counts dropped from
9440 to 4720, and their times nearly halved to `4.046410` sec and `0.074782` sec.
The `exnlp_gemm_dot` count remained unchanged at `453120`.
`s2_nonlocal_make` was `1.517394` sec, `s2_nonlocal` was `24.380108` sec, and
`tmevl_s2` was `29.408207` sec. Step 23 is accepted because it removes the
second-phase H2D transfer while preserving the numerical result and projector
application count.

## Step 24: Fuse Nonlocal Projector Kernels Across ia

At Step 23, `exnlp_gemm_body_fused` kept the sequentially dependent `ia` order
on the host and launched one OpenACC kernel over all local bands for every
`ia`. This produced 453120 `exnlp_gemm_dot` calls in 100 steps and left a large
kernel-launch overhead.

Step 24 assigns independent bands to OpenACC gangs and executes
`ia=1..loopcnt` sequentially inside each band. The projector order within each
band, the `ig` reduction within each `ia`, and the reverse-phase
`loopcnt-ia+1` mapping are unchanged. Each nonlocal phase now uses one kernel,
reducing the `exnlp_gemm_dot` count to 9440.

The implementation commit is `b3559f1` (`Fuse nonlocal projector kernels
across ia`). After confirming the CPU/FFTW fallback full link, three
diagnostic-off, one-GPU / one-MPI-rank, 100-step runs were made.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP24_IA_FUSION_01` | 133.278103113 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP24_IA_FUSION_02` | 133.268284082 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP24_IA_FUSION_03` | 133.029439926 | PASS | PASS |

The three-run median is `133.268284082` sec. It is about 5.376% faster than the
Step 23 median of `140.840327024` sec and about 17.610% faster than the refreshed
Step 18 median of `161.753436089` sec. The run-to-run range is about 0.249 sec,
and every run passed both the normal check and relaxed comparison.

In run 01, the `exnlp_gemm_dot` count dropped from 453120 to 9440 and its time
fell by about 39.87%, from `18.374716` sec to `11.048592` sec. `s2_nonlocal`
was `16.746555` sec and `tmevl_s2` was `21.786372` sec, reductions of about
31.31% and 25.92% from Step 23 run 01. Step 24 is accepted because it removes
kernel launches while preserving projector order and the numerical result.

## Step 25: Vector Length 256 for the Fused Nonlocal Kernel

The Step 24 NVHPC compiler report showed that the fused nonlocal kernel mapped
bands to `gang`, `ia` to `seq`, and both `ig` loops to `vector(128)`. Step 25
sets `vector_length(256)` only on this kernel. The equations, per-band `ia`
order, `ig` reduction, and reverse-phase mapping are unchanged. The CPU/FFTW
fallback full link also passed.

The implementation commit is `825697a` (`Tune fused nonlocal vector length to
256`). Three diagnostic-off, one-GPU / one-MPI-rank, 100-step runs were made.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP25_VEC256_01` | 130.607889175 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP25_VEC256_02` | 130.404011011 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP25_VEC256_03` | 130.849056005 | PASS | PASS |

The three-run median is `130.607889175` sec. It is about 1.996% faster than the
Step 24 median of `133.268284082` sec and about 19.255% faster than the refreshed
Step 18 median of `161.753436089` sec. The run-to-run range is about 0.445 sec,
and every run passed both the normal check and relaxed comparison.

In run 01, the `exnlp_gemm_dot` count remained 9440 while its time fell by about
23.57%, from `11.048592` sec in Step 24 run 01 to `8.444633` sec.
`s2_nonlocal` was `14.127723` sec and `tmevl_s2` was `19.169946` sec, reductions
of about 15.64% and 12.01%. Vector length 256 is therefore accepted.

## Step 26: Vector Length 512 for the Fused Nonlocal Kernel (Rejected)

Step 26 changed only the fused nonlocal kernel from `vector_length(256)` to
`vector_length(512)` to test the upper tuning point. The equations, loop order,
and data mapping were unchanged. The implementation commit is `a8b4db0` (`Tune
fused nonlocal vector length to 512`). Three diagnostic-off, one-GPU /
one-MPI-rank, 100-step runs were made.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP26_VEC512_01` | 130.546390057 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP26_VEC512_02` | 130.834260225 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP26_VEC512_03` | 133.752757072 | PASS | PASS |

The three-run median is `130.834260225` sec. Every run passed both the normal
check and relaxed comparison. This is about 19.115% faster than the refreshed
Step 18 median of `161.753436089` sec, but about 0.173% slower than the accepted
Step 25 median of `130.607889175` sec. The run-to-run range also increased to
about 3.206 sec from about 0.445 sec for Step 25.

The run 01 profile showed a local reduction of about 1.14% in
`exnlp_gemm_dot`, from `8.444633` sec in Step 25 run 01 to `8.348217` sec, but
this did not improve the wall-time median. Because 512 showed no performance
advantage over the lighter 256 setting, Step 26 is rejected. Commit `336422e`
(`Restore accepted nonlocal vector length 256`) restores 256. The CPU/FFTW
fallback full link passed after the rollback, with only the existing legacy
warnings.
