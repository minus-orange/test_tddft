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

## Step 27: Nsight Systems Diagnosis of the Accepted Step 25 Code

The accepted vector-length-256 code was profiled without a source change for
100 steps with one GPU and one MPI rank, using Nsight Systems 2026.2.1. The
archive label is `nvhpc_cufft_1rank_02_STEP27_NSYS_03`, and the source revision
is `deefc3e`. The traced wall time was `134.876740932` sec, but it includes
profiler overhead and is not a performance baseline. The normal check and
relaxed comparison both passed when applied to the TDDFT application log. The
first automatic check failed only because a standalone Nsight CLI error line
was mixed into the same stderr and flagged as suspicious. Commit `1cfde9a`
separates the Nsight CLI and TDDFT logs for subsequent traces.

The principal data movement was:

| operation | count | total size | device time |
|---|---:|---:|---:|
| H2D | 73,230 | 54,124.284 MB | 78.231 sec |
| D2H | 35,453 | 30,054.575 MB | 39.284 sec |

In the OpenACC summary, the TMEVL entry for `P` at line 532 occurred 944 times
and took about 2.977 sec, with about 2.899 sec in the corresponding uploads.
The TMEVL exit and download at line 714 also occurred 944 times and took about
2.807 sec and 2.794 sec, respectively. The nonlocal `work2_` update at line
1913 occurred 4,720 times and took about 4.146 sec, with about 3.734 sec in the
corresponding uploads. These nested event times must not be added together.

The kernel summary reported 9,440 `exnlp_gemm_body_fused` launches totaling
about 8.206 sec, approximately 63% of GPU kernel time. CUDA reported 222,996
`cuLaunchKernel` calls, but their API time was only about 1.16 sec. Actual
allocation was limited to 16 `cuMemAlloc_v2` calls, 14 `cuMemFree_v2` calls,
and one call each to `cudaMalloc` and `cudaFree`; repeated time-step allocation
is therefore not a primary bottleneck.

The scratch-allocation persistence and further launch-reduction candidates are
deprioritized. The next candidate is to raise `P/COEF` mapping ownership above
TMEVL, initially retaining D2H synchronization for host consumers while
removing repeated H2D. The second candidate is direct device generation of
`work2_`, removing the bulk H2D at line 1913.

## Step 28: COEF Residency Across the Predictor-Corrector Sequence

To remove the repeated TMEVL-entry H2D identified in Step 27, the device
mapping of `COEF` and its correction restart value `COEF0` was moved to the
FRPRMN predictor-corrector scope. Each correction now restores `COEF` from
`COEF0` on the device. The D2H at the end of TMEVL remains because the
immediately following host-side `RHOOFK` and `SUMCHR` routines read `COEF`.
The CPU/FFTW fallback retains the original host `coefcp` path, and its full
link passed.

The implementation commit is `c3552af` (`Keep TDDFT coefficients resident
across corrections`). Three diagnostic-off, one-GPU / one-MPI-rank, 100-step
runs were made.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_01` | 129.075486183 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_02` | 127.753921986 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_03` | 129.260547161 | PASS | PASS |

The three-run median is `129.075486183` sec, about 1.173% faster than the Step
25 median of `130.607889175` sec and about 20.202% faster than the refreshed
Step 18 median of `161.753436089` sec. The run-to-run range is about 1.507 sec,
and every run passed both the normal check and relaxed comparison.

In run 01, `tmevl_p_enter` was nearly eliminated, falling from `2.925959` sec
in Step 25 run 01 to `0.001273` sec. `tmevl_total` fell by about 4.745%, from
`61.235540` sec to `58.329469` sec. `tmevl_p_exit` remained at `2.825121` sec,
as intended for the host consumers. Step 28 is accepted because it removes the
repeated H2D while preserving the numerical result. The next candidate is
direct device generation of the nonlocal `work2_` buffer identified in Step 27.

## Step 29: Device Initialization of Resident COEF0 (Rejected)

Step 28 copied both `COEF` and `COEF0` to the device at the start of each
FRPRMN call. Step 29 created `COEF0` on the device and initialized it with a GPU
kernel from the already transferred `COEF`, replacing one H2D per FRPRMN with
a device-local copy. The correction restore, post-TMEVL D2H, equations, and
loop order were unchanged. The implementation commit is `94e0e0e`
(`Initialize resident coefficient backup on device`).

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP29_COEF0_D2D_01` | 130.160923958 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP29_COEF0_D2D_02` | 129.451672077 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP29_COEF0_D2D_03` | 130.183923006 | PASS | PASS |

The three-run median is `130.160923958` sec, about 0.841% slower than the Step
28 median of `129.075486183` sec. Every run passed both the normal check and
relaxed comparison, but the removed initial H2D did not offset the additional
device-copy kernel in wall time. Step 29 is therefore rejected, and commit
`bd53a88` (`Restore accepted Step28 coefficient mapping`) restores the Step 28
method. The CPU/FFTW fallback full link passed after the rollback.

## Step 30: Nsight Systems Recheck of the Accepted Step 28 Code

The accepted Step 28 code was traced again with Nsight Systems 2026.2.1. The
archive label is `nvhpc_cufft_1rank_02_STEP30_NSYS_01`, and the source revision
is `1f5d474`. The traced wall time of `133.093063116` sec is not a baseline.
Both the normal check and relaxed comparison passed on `tddft.out` after
excluding the standalone Nsight stderr artifact. Commit `21c084a` preserves
the raw-stderr validation while preventing this known artifact from causing a
false failure in subsequent diagnostic runs.

| operation | count | total size | device time |
|---|---:|---:|---:|
| H2D | 72,486 | 46,225.769 MB | 62.951 sec |
| D2H | 35,453 | 30,054.575 MB | 39.972 sec |

Relative to Step 27, H2D fell by 744 operations, 7,898.515 MB, and about 15.280
sec of device time. The D2H count and total size were unchanged. The old TMEVL
`P` entry disappeared from the leading OpenACC rows. The replacement
caller-owned mapping at FRPRMN line 1382 occurred 100 times and took about
1.247 sec, with 200 corresponding uploads totaling about 1.235 sec. This
confirms the Step 28 P/COEF H2D reduction in the trace.

The largest remaining repeated upload is the line-1914 `work2_` update: 4,720
events taking about 4.184 sec, with about 3.745 sec in the enqueue-upload
events. The TMEVL-exit D2H also remains at 944 events and about 2.892 sec, with
about 2.882 sec in the corresponding downloads. Direct generation of `work2_`
is the next implementation candidate, but only if it does not increase the
input traffic for YLM, VPJ, and EXTAU.

## Step 31: Reuse GDUMP Mappings Across TMEVL Kinetic Stages (Rejected)

Step 31 moved the per-`exkin_` `GDUMP` `copyin` operations to the surrounding
fourth-order `TMEVL` interval. `GDUMP1..5` were mapped once and referenced as
`present` by the five kinetic stages. This was expected to reduce the mapping
count from 9,440 to 4,720 without changing equations, operation order, array
shapes, or the sequential `ia` update order. The implementation commit was
`f8b6188` (`Reuse GDUMP mappings across TMEVL kinetic stages`).

Three runs used diagnostics off, NVHPC with OpenACC and cuFFT, one GPU / one MPI
rank, an A100-PCIE-40GB, and the 100-step Si111-H case.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_01` | 129.635676146 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_02` | 128.958827972 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_03` | 129.250354052 | PASS | PASS |

The three-run median was `129.250354052` sec, which is `0.174867869` sec, or
about `0.1355%`, slower than the official Step 28 median of `129.075486183`
sec. The run-to-run range was `0.676848174` sec. Every run passed both the
normal check and relaxed comparison, but no performance advantage over the
official baseline was demonstrated, so Step 31 is rejected.

In run 01, `tmevl_gdump_enter` occurred 944 times and took `0.294118` sec,
`tmevl_gdump_exit` occurred 944 times and took `0.002970` sec,
`exkin_acc_kernel` occurred 9,440 times and took `0.348747` sec, and
`tmevl_total` was `57.794941` sec. The changed GDUMP ownership boundary was
functionally valid, but its approximately `0.297088` sec of TMEVL-level
enter/exit time did not improve the wall-time median.

Commit `8ef55bb` (`Revert "Reuse GDUMP mappings across TMEVL kinetic stages"`)
rolls back only the Step 31 source change and restores the accepted Step 28
method. The Step 28 median of `129.075486183` sec remains the performance
baseline for subsequent experiments.

## Step 32: Post-TMEVL Density-Rebuild Timers

Step 32 is a measurement step that separates the host work immediately after
the TMEVL-exit coefficient D2H identified in Step 30. It adds
`frprmn_rhoofk`, `frprmn_sumchr`, and `frprmn_rhoget` around `RHOOFK`, the
conditional `SUMCHR`, and `RHOGET`, respectively. It does not change equations,
OpenACC data clauses, or FFT paths. The implementation commit is `13f9e98`
(`Measure post-TMEVL density rebuild costs`).

The diagnostic-off NVHPC + OpenACC + cuFFT run used one A100-PCIE-40GB, one MPI
rank, and the 100-step Si111-H case.

```text
archive: nvhpc_cufft_1rank_02_STEP32_DENSITY_TIMERS_01
wall_sec: 129.658223152
check: PASS
relaxed compare: PASS
frprmn_rhoofk: count 472, 14.509684 sec
frprmn_rhoget: count 472, 0.440581 sec
tmevl_p_exit: count 944, 2.819788 sec
```

`frprmn_sumchr` did not appear because `NPFL=0` in this case. The measured
density-rebuild total is about `14.950265` sec, dominated by `RHOOFK`. The next
implementation candidate is therefore a device charge-density path that
consumes resident `COEF` and avoids each TMEVL `tmevl_p_exit`. Step 32 is a
measurement run and does not replace the official Step 28 median baseline of
`129.075486183` sec.

## Step 33: Batch Post-TMEVL Charge-Density FFTs

Step 33 leaves the initial-density `RHOOFK` path unchanged and replaces only
the post-TMEVL density rebuild with `RHOOFK_ACC_BATCH`. It scatters the
predictor-corrector-resident `COEF` on the device, transforms all local bands
with one batched cuFFT, and accumulates the occupation-weighted density on the
device in the original band order. Only the local density required by the MPI
reduction returns to the host. The full coefficient D2H was intentionally kept
to isolate this hypothesis. The CPU/FFTW fallback batch entry executes scalar
FFTW transforms in the original band order, and the full fallback link passed.

The implementation commit is `b2a43c9` (`Batch post-TMEVL charge-density
FFTs`). Three diagnostic-off runs used NVHPC with OpenACC and cuFFT, one GPU,
one MPI rank, an A100-PCIE-40GB, and the 100-step Si111-H case.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_01` | 116.124675989 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_02` | 117.093669176 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_03` | 115.763577938 | PASS | PASS |

The three-run median is `116.124675989` sec. This is `12.950810194` sec, or
about `10.0335%`, faster than the Step 28 median of `129.075486183` sec. The
run-to-run range is `1.330091238` sec. Every run passed both correctness
checks, so Step 33 is accepted as the new official performance baseline.

In run 01, `frprmn_rhoofk` fell by about 94.97%, from the Step 32 value of
`14.509684` sec to `0.729800` sec. `fft_wrapper` fell from 43,949 calls and
`13.369605` sec to 14,685 calls and `3.402723` sec. `tmevl_total` was nearly
unchanged at `58.338570` sec, while the intentionally retained `tmevl_p_exit`
occurred 944 times and took `2.880805` sec. The next separate hypothesis is to
defer that full coefficient D2H until the predictor-corrector sequence ends,
after verifying all intervening host consumers.

## Step 34: Defer Coefficient D2H Across Corrections

Step 34 removes the per-TMEVL host synchronization of `COEF` and keeps the
device copy authoritative. It synchronizes only at the first boundary that
requires host coefficients: final-time-step expectation evaluation, `SUMCHR`
when `NPFL!=0`, or FRPRMN exit. It does not change the device correction
restart, equations, FFT path, or sequential `ia` update order. The new
`frprmn_coef_sync` timer measures these synchronization points. The
implementation commit is `83a030c` (`Defer coefficient downloads across
corrections`), and the full CPU/FFTW fallback link passed.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_01` | 113.896168210 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_02` | 113.491595984 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_03` | 113.561361074 | PASS | PASS |

The three-run median is `113.561361074` sec. This is `2.563314915` sec, or
about `2.2074%`, faster than the Step 33 median of `116.124675989` sec. The
run-to-run range is `0.404572226` sec. Every run passed both correctness
checks, so Step 34 is accepted as the new official baseline. It is about
`12.0194%` faster than Step 28.

In run 01, `frprmn_coef_sync` occurred 103 times and took `0.638588` sec,
while the former 944-call `tmevl_p_exit` timer disappeared. `tmevl_total` fell
from `58.338570` sec in Step 33 run 01 to `55.375345` sec. The next task is a
fresh Nsight Systems diagnosis of the accepted Step 34 path to quantify the
D2H reduction and re-rank the remaining repeated H2D operations.

## Step 35: Nsight Systems Recheck of the Accepted Step 34 Code

The accepted Step 34 source revision
`7567ae83e520a79e480ee6eaaa83842526938465` was traced with Nsight Systems
2026.2.1. The archive label is `nvhpc_cufft_1rank_02_STEP35_NSYS_01`. Its
`116.000924826` sec trace wall includes diagnostic overhead and is not a
performance baseline. Both the normal check and relaxed comparison passed.

The trace reported 44,166 H2D copies, `32,307.014` MB, and about `5.026` sec;
D2H was 5,348 copies, `5,592.769` MB, and about `0.831` sec. Relative to Step
30, H2D fell by 28,320 copies and `13,918.755` MB, while D2H fell by 30,105
copies and `24,461.806` MB. This confirms the transfer reduction from the
Steps 33–34 density FFT batching and deferred coefficient synchronization.

The largest GPU kernel was `exnlp_gemm_body_fused_2387_gpu`, with 9,440
launches, about `8.303` sec, and 66.5% of reported CUDA-kernel time. The largest
repeated upload remains the line-1913 `work2_` update: 4,720 calls and about
`3.728` sec in the OpenACC summary, including about `1.264` sec of enqueue
upload time. Direct device construction of `work2_` requires YLM, VPJ, and
EXTAU mappings. Because the B1 ownership experiment regressed severely and
Step 20's fine-grained copies failed, this remains a high-risk candidate until
an ownership boundary can avoid increasing producer-input transfers. The
official baseline remains the Step 34 median of `113.561361074` sec.

## Step 36: Right-Size the Nonlocal Staging Columns

Step 36 reduces the `work2_` leading dimension from the fixed `NGcont` upper
bound to the maximum `NGNL` among active atom types. Each projector column is
still generated by the same host loop with identical values. The update count,
equations, reverse-phase reuse, and sequential `ia` update order are unchanged.
The implementation commit is `24e1cc3` (`Right-size nonlocal staging columns`),
and the full CPU/FFTW fallback link passed.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_01` | 113.023494005 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_02` | 113.083628893 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_03` | 113.681638956 | PASS | PASS |

The three-run median is `113.083628893` sec, `0.477732181` sec or about
`0.4207%` faster than Step 34. The run-to-run range is `0.658144951` sec, and
every run passed both correctness checks. In run 01, `exnlp_work1_enter` fell
about `6.947%`, from `4.040431` sec in Step 34 run 01 to `3.759735` sec, while
`s2_nonlocal` fell about `2.115%`, from `14.055285` sec to `13.758056` sec.
Step 36 is accepted and the official performance baseline becomes
`113.083628893` sec.

## Step 37: Use Pinned Memory for Dynamic Host Allocations

Step 37 adds the NVHPC 26.5 option `-gpu=mem:separate:pinnedalloc` to the TDDFT
OpenACC + cuFFT build. It retains separate host/device memory and the existing
data clauses while placing dynamically allocated host arrays in CUDA pinned
memory. `tools/build_nvhpc.sh` enables this with `ENABLE_PINNED_ALLOC=1`; the
default remains off. The build-mode commit is `9cbb6bc` (`Add optional pinned
allocation build mode`).

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_01` | 108.676812287 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_02` | 107.854416847 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_03` | 108.096301079 | PASS | PASS |

The three-run median is `108.096301079` sec, `4.987327814` sec or about
`4.4103%` faster than Step 36. The run-to-run range is `0.822395440` sec, and
every run passed both correctness checks. In run 01, `exnlp_work1_enter` fell
from `3.759735` to `1.542147` sec, `s2_nonlocal` fell from `13.758056` to
`11.489188` sec, and `tmevl_total` fell from `55.183834` to `51.654634` sec.
Step 37 is accepted with the new official median of `108.096301079` sec. The
next task is a fresh Nsight Systems trace using this build configuration.

## Step 38: Nsight Systems Recheck of the Pinned-Allocation Build

The accepted Step 37 build was traced at revision
`643e639d45a163499a71355ecee33d7dba8466a3` with Nsight Systems 2026.2.1. The
archive is `nvhpc_cufft_1rank_02_STEP38_PINNED_NSYS_01`; its `110.78916502` sec
wall includes diagnostic overhead and is not a baseline. Both correctness
checks passed.

H2D was 44,166 copies, `31,234.025` MB, and `1.272192545` sec. D2H was 5,348
copies, `5,592.769` MB, and `0.440373299` sec. Relative to Step 35, pinned
allocation reduced H2D time by `74.6861%` and D2H time by `46.9758%`. Copy
counts were unchanged; the `3.3212%` H2D-byte reduction primarily reflects
Step 36 right-sizing. The 4,720 `work2_` OpenACC updates fell `56.6159%`, from
`3.728488477` sec to `1.617571795` sec.

The largest kernel, `exnlp_gemm_body_fused_2399_gpu`, took `8.311268224` sec
over 9,440 launches, or 66.6% of reported CUDA-kernel time. This is effectively
unchanged (`+0.1036%`) from the corrected Step 35 value of `8.302662687` sec.
The former Step 35 value of `5.830` sec in these documents was a screenshot
transcription error and is corrected above to `8.303` sec. Initializing the
pinned host pool added one `cuMemHostAlloc` call of `0.273495492` sec. The next
investigation should measure fused-kernel resource use or occupancy before a
separate mapping hypothesis is implemented.

## Step 39: Nsight Compute Diagnosis of the Fused Nonlocal Kernel

Nsight Compute 2026.1.0 profiled one launch of
`exnlp_gemm_body_fused_2399_gpu` from the accepted Step 37 build. The archive
is `nvhpc_cufft_1rank_02_STEP39_FUSED_NCU_01`, using the two-step input. The
diagnostic wall time was `11.1839032173` sec and the normal check passed. This
two-step diagnostic did not run the relaxed comparison, so neither its wall
time nor its limited correctness result replaces the official baseline. The
manifest's `git_revision` is blank because root execution triggered Git's
safe-directory protection; the profiled executable still used the accepted
Step 37 implementation and did not change equations or execution order.

The selected kernel used a block size of 256, a grid size of 32, and 63
registers per thread. On the A100's 108 SMs, it reported only `0.07` waves/SM.
Theoretical occupancy was `50.0%`, but achieved occupancy was `12.5%` with
`8.0` achieved active warps per SM. Compute (SM) throughput was `4.27%`, memory
throughput was `16.35%`, DRAM throughput was `0.45%`, and the selected launch
took `915.52 us`. The L1/TEX hit rate was `84.31%`.

Nsight Compute identified the 32-block grid, which cannot fill 108 SMs, as the
primary launch-shape limit. It also reported about `15.5 / 32` useful bytes per
global-load/store sector, roughly 51% excess sectors, and about 7.1 scoreboard
stall cycles out of an average 14.3 cycles. A simple block-size increase is not
the next experiment because Step 26 already rejected `vector_length(512)` by a
three-run median. Reducing register pressure alone also cannot remove the
32-block grid limit. However, 32 bands are the smallest operational problem
size expected, so no small-band-specific multi-gang path will be added. The
current one-gang-per-band path expands its grid naturally as the band count
increases. Step 39's low occupancy is therefore treated as a tutorial-size
lower-bound characteristic. The next step is to measure the same kernel on
medium and production-sized inputs, then optimize only bottlenecks shared
across those sizes. The official baseline remains the Step 37 median of
`108.096301079` sec.

## Step 40: Direction-Specialize the Fused Nonlocal Kernel (Rejected)

Implementation commit `ea81633` split the fused nonlocal kernel into explicit
forward and reverse routines, removing the per-projector direction branch while
preserving each phase's sequential `ia` update order. The CPU/FFTW fallback
full link passed before A100 validation.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_01` | 107.751713037 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_02` | 107.828091860 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_03` | 107.690500021 | PASS | PASS |

The diagnostic-off three-run median was `107.751713037` sec, with a
`0.137591839` sec range. The apparent improvement over Step 37 was only
`0.344588042` sec (`0.3188%`). In contrast, the targeted `exnlp_gemm_dot`
timer median was `8.545724` sec, `1.2310%` worse than Step 37 run 01, and the
`s2_nonlocal` median was `11.571148` sec, `0.7134%` worse. The
`tmevl_total` median was effectively unchanged at `51.656927` sec.

All correctness checks passed, but the targeted timer consistently regressed
and does not support the sub-1% wall-time difference. The duplicated
forward/reverse implementation is not justified by the measured effect, so
Step 40 is rejected. Implementation `ea81633` was reverted by `0726e26`, and
the CPU/FFTW fallback full link passed after rollback. The official baseline
remains Step 37 at `108.096301079` sec.

## Step 41: Keep Static Metadata Resident Across the Time-Step Loop

Implementation commit `4aaa33c` copies the read-only `J2G` and `OCC`
metadata to the device outside the time-step loop and changes their repeated
S2 and batched-RHOOFK `copyin` clauses to `present`. It does not change the
equations, kernel loops, array shapes, or sequential `ia` update order. The
CPU/FFTW fallback full link and independent review passed.

The first archive, `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_01`, passed
normal check and relaxed compare but took `115.517135143` sec. Its standard
manifest lacked the revision and build flags. It is retained as a pre-rebuild
provenance anomaly and is not included in the official series. After an
explicit diagnostic-off NVHPC OpenACC + cuFFT rebuild with
`-gpu=mem:separate:pinnedalloc`, the results were:

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_02` | 107.783477068 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_03` | 107.718405008 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_04` | 107.754213095 | PASS | PASS |

The three-run median is `107.754213095` sec with a `0.065072060` sec range.
It is `0.342087984` sec (`0.3165%`) faster than the Step 37 median. In run
02, `frprmn_rhoofk` was `0.528846` sec, about `5.19%` below Step 37 run 01,
while `s2_nonlocal` at `11.489951` sec and `exnlp_gemm_dot` at
`8.441246` sec were effectively unchanged.

At source level, 4,720 S2 `J2G` copyins plus 472 RHOOFK `J2G` and 472
RHOOFK `OCC` copyins are replaced by two outer-loop copyins, a net reduction
of up to 5,662 repeated H2D operations. The actual runtime copy count can be
remeasured later with Nsight Systems. All official runs passed both
correctness checks, the median improved, and the change directly advances the
goal of reducing transfers inside the time-step loop. Step 41 is accepted and
the official baseline becomes `107.754213095` sec.

## Step 42: Keep Vloc Resident Across FRPRMN Corrections (Rejected)

Implementation commit `d56815e` copied `Vloc(:,1:5)` to the device at the
start of each FRPRMN predictor-corrector sequence and changed the repeated S2
local-potential `copyin` to `present`. It did not change equations, array
shapes, kernel loops, or sequential `ia` order. The CPU/FFTW fallback full
link and independent review passed before A100 validation.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_01` | 107.732875109 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_02` | 107.809727907 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_03` | 107.831543922 | PASS | PASS |

The diagnostic-off three-run median is `107.809727907` sec with a
`0.098668813` sec range. It is `0.055514812` sec (`0.0515%`) slower than the
Step 41 median. All normal checks and relaxed comparisons passed, and the
source-level transfer boundary changed as intended, but there is no measured
performance advantage. No transfer profile was collected to demonstrate an
additional runtime benefit. Step 42 is therefore rejected, and the official
baseline remains Step 41 at `107.754213095` sec.
Implementation `d56815e` was reverted by `afa1678`, and the CPU/FFTW fallback
full link passed after the rollback.

## Step 43: Decompose the Host-Side ELECTF Region

Diagnostic commit `e90c80a` separated ELECTF into LOCPOTF and NONLOCF, then
split NONLOCF into the host-COEF kinetic/current section and the combined
GETYLM plus SEPPOTF/projector section. It did not change equations, loops,
MPI behavior, or OpenACC synchronization.

Archive `nvhpc_cufft_1rank_02_STEP43_ELECTF_TIMERS_01` passed normal check and
relaxed compare. Its diagnostic wall was `107.821303844` sec and is not a
performance baseline.

| timer | count | sec | share of ELECTF |
|---|---:|---:|---:|
| `electf_force` | 101 | 9.012769 | 100% |
| `electf_locpotf` | 101 | 4.071556 | 45.1754% |
| `electf_nonlocf` | 101 | 4.939849 | 54.8094% |
| `nonlocf_coef_kin_mpi` | 202 | 0.846204 | 9.3896% |
| `nonlocf_projector_mpi` | 202 | 4.091718 | 45.3991% |

The combined GETYLM and SEPPOTF section accounts for `82.8308%` of NONLOCF.
The 202 inner calls reflect two k points per ELECTF call. The next diagnostic
separates GETYLM from SEPPOTF before one GPU-port hypothesis is selected.

## Step 44: Decompose the NONLOCF Projector Region

Archive `nvhpc_cufft_1rank_02_STEP44_NONLOCF_TIMERS_01` passed normal check
and relaxed compare. Its diagnostic wall was `108.715013981` sec and is not a
performance baseline.

| timer | count | sec | share of projector section |
|---|---:|---:|---:|
| `nonlocf_projector_mpi` | 202 | 4.092541 | 100% |
| `nonlocf_getylm` | 202 | 0.009894 | 0.2418% |
| `nonlocf_seppotf` | 202 | 4.068364 | 99.4092% |

SEPPOTF accounts for `84.0486%` of NONLOCF and `45.6432%` of ELECTF. The next
single theme is a bounded SEPPOTF GPU port and COEF/data-ownership review that
preserves arithmetic order, MPI boundaries, and the CPU fallback. The official
baseline remains the Step 41 median of `107.754213095` sec.

## Step 45: Retain COEF Device Allocation Across Time Steps (Rejected)

Implementation `da24adf` extended the COEF device allocation across the full
time-step loop to remove the next-step FRPRMN COEF H2D copyin. It retained the
D2H before ELECTF, per-sequence COEF0 ownership, SEPPOTF, MPI, and arithmetic
order.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_01` | 108.508744955 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_02` | 108.782176018 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_03` | 111.340812922 | PASS | PASS |

The median is `108.782176018` sec with a `2.832067967` sec range. It is
`1.027962923` sec (`0.9540%`) slower than Step 41 and has no performance
advantage. The expected H2D reduction was not verified with Nsight Systems.
Step 45 is rejected, and the official baseline remains the Step 41 median of
`107.754213095` sec. Implementation `da24adf` was reverted by `c406a4a`, and
the CPU/FFTW fallback full link passed after rollback.

## Step 46: Validate SEPPOTF Data Ownership

Diagnostic implementation `edfafed` and enforcement commit `3e2c630`
extended the COEF device lifetime from FRPRMN through ELECTF and mapped the
NONLOCF parent arrays outside the k-point loop. A no-op serial kernel in
SEPPOTF validated the `present` dummy sections required by the tutorial s/p
projectors without changing projector arithmetic.

Archive `nvhpc_cufft_1rank_02_STEP46_OWNERSHIP_01` completed 100 steps in
`107.869318008` sec and passed normal check and relaxed compare. There was no
present/partial-present error and no ownership-probe failure. The wall time
includes diagnostic transfers and a serial probe, so it is not a performance
baseline. The official Step 41 median remains `107.754213095` sec. The next
single hypothesis is a one-gang-per-band GPU path restricted to the tutorial
non-partitioned s/p case, with the complete original host path retained for
all unsupported projector shapes.

## Step 47: Offload Tutorial Non-Partitioned s/p SEPPOTF (Rejected)

Implementation `0252da9` moved the phase and band reductions for the tutorial
non-partitioned s/p projectors to one-gang-per-band OpenACC kernels. It kept
the ITY, atom, s, then p order, the MPI boundary, and complete host fallback
for FFTW and unsupported shapes.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_01` | 107.598769903 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_02` | 107.722885132 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_03` | 107.848846912 | PASS | PASS |

The median is `107.722885132` sec with a `0.250077009` sec range. It is only
`0.031327963` sec (`0.0291%`) faster than Step 41, which is smaller than the
run range and does not justify the approximately 250-line specialized path.
Step 47 is rejected, and the official baseline remains the Step 41 median of
`107.754213095` sec.

Rollback `35f8542` removed Step 47 and the completed Step 46 diagnostic source,
restored the affected source files to the accepted Step 41 state, and passed
the CPU/FFTW fallback full link.

## Steps 48-51: Re-profile Step 41 and Decompose FRPRMN

The Step 48 Nsight Systems trace bounded all MPI collectives at
`0.260338098` sec and found negligible allocation activity. Default-off timer
decomposition in Steps 49-51 measured `Part1to5` at `36.306091` sec, including
`36.132464` sec in the VPJ_GEN CPU radial integral and only `0.037303` sec in
MPI. Host computation with corresponding GPU idle was the dominant class.

## Step 52: Offload Part1to5 VPJ Radial Integration (Accepted)

Implementation `22aad92` parallelizes only the VPJ_GEN radial integration
called by `Part1to5` across G vectors. It preserves radial accumulation order
within each G vector, the host MPI boundary, and the original TMEVL CPU path,
while keeping static pseudopotential tables resident across the time-step loop.

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_01` | 72.9733359814 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_02` | 73.4374880791 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_03` | 73.4901540279 | PASS | PASS |

The median is `73.4374880791` sec with a `0.5168180465` sec range. It is
`34.3167250159` sec (`31.8472%`) faster than the Step 41 median, consistent
with the large reduction in the targeted FRPRMN residual. Step 52 is accepted
as the official baseline. The next task is diagnostic only: re-profile the
accepted Step 52 source with Nsight Systems and reclassify remaining kernel,
transfer, runtime/API, synchronization, MPI, and GPU-idle time. Trace wall is
not a performance baseline.

## Step 53: Re-profile the Accepted Step 52 Source

Archive `nvhpc_cufft_1rank_02_STEP53_STEP52_NSYS_01` passed normal check and
relaxed compare. Its `76.0769960680` sec trace wall is diagnostic only. The
2,000 VPJ kernels totaled `1.793293070` sec; aggregate CUDA kernels were about
`14.26` sec, or `18.7%` of trace wall. H2D was 38,564 calls /
`30,745.626` MB / `2.565299787` sec, and D2H was 7,348 calls /
`5,846.065` MB / `0.466224230` sec.

The FRPRMN residual was `13.608745` sec, leaving an approximately `11.815452`
sec CPU/host-orchestration and unresolved-wait envelope after subtracting the
VPJ kernel. The MPI report was empty, but the Step 48 `0.260338098` sec
whole-run bound and Step 51 `0.037303` sec scoped value rule out MPI as the
principal cause. Whole-trace stream/event synchronization totaled
`17.613188385` sec, while VPJ-specific OpenACC wait was `1.816791731` sec.
The next task is not optimization: Step 54 should use default-off timers to
divide the remaining FRPRMN host envelope into uncovered control,
energy/reduction, density, and update blocks.
