# Official diamond cb3x3x3 benchmark evaluation plan

## Source and identity

- Official update date: 2026-08-08
- Official package:
  `https://staff.aist.go.jp/yoshi-miyamoto/ja/download/benchmark-cb3x3x3.zip`
- Package SHA-256:
  `793a7754a416c83f00f563a7de3ce49d570f6830db89388d2e3b7b808c2612f9`
- Carbon pseudopotential:
  `https://staff.aist.go.jp/yoshi-miyamoto/en/TR/TR.C95g_asci`
- Pseudopotential SHA-256:
  `bc743cb0f8829a2b07c68e1a33ce9a4c44c8cf75cc6503da3707fc9db90a5244`

The package is announced by the official site as available only within Japan.
Do not mirror it into Git or require result-file transfer from a closed
execution environment.

## Case definition

- Model: diamond 3 x 3 x 3 supercell
- Atoms: 216 carbon atoms
- FFT mesh: 105 x 105 x 105
- `NG`: 745,411
- `NG2`: 93,176
- k-points: 1
- CG/SD bands: 432 occupied + 144 empty = 576
- TDDFT bands: 432 occupied + 48 empty = 480
- Official TDDFT input: 40,000 steps, `dt=0.03`, `TMOD=100`, `SUZUKI=4`
- Official comparison output: AOBA-S, 96 MPI ranks, 40,000 steps
- Official AOBA-S wall recorded in the output: `90501.2334069` sec

The official reference passes the repository's normal output checker with
`--expected-steps 40000 --no-require-profile`. It contains no current
`FPSEID_PROFILE` block because it predates the repository timer format.

## Independent directory and baseline series

Run data is ignored by Git and is kept below:

```text
run/benchmarks/cb3x3x3/
  downloads/                 original ZIP and carbon pseudopotential
  official/                  immutable extracted package and AOBA-S reference
  work/
    cg/                      CG initial-state generation
    sd/                      SD full-grid state generation
    tddft_600K/              600 K TDDFT inputs and future state
  archives/                  cb3x3x3-only result archives
```

Never place a cb3x3x3 archive under the historical
`run/tddft_archives` Si111-H series. A100, H100, and each x86 host will receive
an independent cb3x3x3 platform baseline after its own approved three-run
series.

Prepare and verify without running a simulation:

```sh
./tools/prepare_cb3x3x3_benchmark.sh
./tools/check_cb3x3x3_benchmark.sh
```

Before any x86 build or run, execute the read-only environment gate on each
independent SKU. It checks CPU identity, topology, available memory, Intel
compiler/MPI commands, FFTW readiness, Git state, and recommends a safe MPI x
OpenMP configuration for the current unmodified numerical source:

```sh
EXPECTED_SKU=6980P ./tools/check_cb3x3x3_x86_environment.sh
EXPECTED_SKU=8468  ./tools/check_cb3x3x3_x86_environment.sh
EXPECTED_SKU=8592+ ./tools/check_cb3x3x3_x86_environment.sh
```

Do not start CG, SD, or TDDFT when `environment_gate=BLOCK`. Preserve each
terminal summary as the platform-specific preflight record. The script is
read-only and does not build, stage data, or start a simulation.

The three returned environment gates select these fixed configurations for
the unmodified x86 numerical source:

| platform | TDDFT configuration | environment result |
| --- | --- | --- |
| Xeon 6980P x 2 | 16 MPI x 16 OpenMP | PASS; 32 x 8 is memory-blocked |
| Xeon Platinum 8468 x 2 | 32 MPI x 3 OpenMP | PASS |
| Xeon Platinum 8592+ x 2 | 32 MPI x 4 OpenMP | PASS |

Use the case-specific x86 runner for all builds and calculations. It always
re-runs both read-only preflights, builds the CPU/FFTW path with diagnostics
off, copies host-specific executables below `platforms/<sku>_<host>/bin`, and
refuses to overwrite any existing state, run, or archive:

```sh
EXPECTED_SKU=<SKU> ./tools/run_cb3x3x3_x86.sh build
EXPECTED_SKU=<SKU> ./tools/run_cb3x3x3_x86.sh cg
EXPECTED_SKU=<SKU> ./tools/run_cb3x3x3_x86.sh sd
EXPECTED_SKU=<SKU> ./tools/run_cb3x3x3_x86.sh tddft-2
```

Run CG and SD exactly once, sequentially, on the same selected state-generation
host. Their default one-thread OpenMP setting is deliberate and is recorded in
the provenance. After SD passes, the runner installs the density and full-grid
wavefunction under `work/tddft_600K`, makes them write-protected, and records a
`STATE_MANIFEST.sha256`. Each TDDFT host then uses that identical state while
writing to its own label directory below `platforms/<sku>_<host>/runs`.

## Initial-state gate

The official ZIP does not contain `rh.dia-cb3x3x3` or
`wf_fft.dia-cb3x3x3`. The supplied instructions require:

1. run CG with 576 bands;
2. pass CG validation and preserve its density/wavefunction provenance;
3. run SD with the CG state;
4. pass SD validation;
5. copy the SD density and full-grid wavefunction as write-protected TDDFT
   initial conditions;
6. record their SHA-256 values in `STATE_MANIFEST.sha256`.

No TDDFT execution is authorized until these inputs exist and the platform
memory/rank configuration is reviewed. The former 1 GPU / 1 MPI validation
path may not fit this 480-band case and must not be assumed without a memory
preflight.

The two-step runner action is only a bounded startup and memory check. It
performs the normal result check but has no same-input external reference and
cannot become a performance baseline. Stop and review its summary before any
long run.

## Staged H100 startup and memory gate

The user selected H100 as the first GPU for this independent cb3x3x3 case.
Use `tools/run_cb3x3x3_h100.sh`; it does not modify numerical source and it
deliberately exposes only `preflight` and `tddft-2` actions. The fixed path is
one H100, one MPI rank, one OpenMP thread, diagnostic off, OpenACC/cuFFT,
explicit `cc90`, and `-gpu=mem:separate:pinnedalloc`. It reuses the immutable
CG/SD state but writes the executable, run, and provenance under the separate
`run/benchmarks/cb3x3x3/platforms/h100_<hostname>/` tree.

Run the read-only gate first:

```sh
CUDA_VISIBLE_DEVICES=0 ./tools/run_cb3x3x3_h100.sh preflight
```

It requires clean synchronized Git, the expected official input and
SHA-256-validated initial state, an H100 with compute capability 9.0, no active
compute process, at least 90% free device memory, at least 64 GiB host
`MemAvailable` for the conservative one-rank gate, and the NVHPC/MPI
toolchain. It does not build or execute TDDFT. Return and review its compact
terminal summary before the next action.

Only after that review, run the bounded startup/memory check:

```sh
CUDA_VISIBLE_DEVICES=0 ./tools/run_cb3x3x3_h100.sh tddft-2
```

This action rebuilds TDDFT for H100, runs exactly two steps, requires the
normal checker with 216 force/position/velocity rows, and reports sampled peak
GPU memory and minimum headroom. Two steps have no same-input reference and
cannot establish correctness equivalence or a performance baseline. The
helper contains no 100-step action; a separate review and explicit user
authorization are required before adding or issuing any long-run command.

The first user-operated H100 attempt built successfully but stopped during
input parsing at `tm_inputs.f:415` with NVFORTRAN `FIO-F-231`. The official
input uses CRLF, and the `GCUT=64` token is last on its line; the legacy
72-character parser retained the carriage return in that token before its
internal formatted read. The x86 ifx run had accepted the same byte sequence.
The H100 helper now removes only carriage-return bytes while copying the
2-step input into each new isolated run directory. It preserves the canonical
official and generated inputs, records both source and normalized input
SHA-256 values, and does not change any keyword, numeric value, numerical
source, initial state, or prior run directory. The failed run reported only
515 MiB peak device use and therefore supplied no capacity evidence.

The user authorized one 100-step diagnostic on the Xeon Platinum 8592+ host
using its fixed single-node `32 MPI x 4 OpenMP = 128 physical cores`
configuration. The derived 100-step input changes only `tstep` from the
official input. Because the official package supplies no 100-step reference,
this action performs the normal result check only, remains in its isolated
platform run directory, and is not archived or treated as a baseline.

That diagnostic completed on host `spr10` at revision
`4bc30413426f029ca6c973f8e375740f0a3282bf`. It ran all 100 steps in
`7053.57140899` sec with diagnostics off and passed the normal checker. The
returned summary contained 216 force, position, and velocity rows and 39
profile timers. Same-input comparison remains unavailable and the result is
not a baseline. A follow-up photograph confirmed the run label as
`cb3x3x3_8592p_spr10_32mpi_4omp_100step_diag_01`.

## Correctness and performance gates

- The official 40,000-step output is the only supplied external reference.
- The derived 2-step input is for bounded startup/memory validation only.
- The derived 100-step input is for the explicitly authorized 8592+
  diagnostic only. It has no supplied same-step reference and cannot enter a
  formal correctness or performance series.
- The derived 1,000-step input follows the official README's profiling
  suggestion, but it has no supplied 1,000-step reference.
- A 1,000-step performance run therefore requires a separately approved,
  same-input reference. The Si111-H GNU reference is invalid for this case.
- Every measured run must pass the normal checker and a same-input relaxed
  comparison.
- A platform baseline requires diagnostics off, three equivalent runs, the
  median, range, exact revision/build/device/rank configuration, and explicit
  adoption.
- Profiler walls remain diagnostic and never become a baseline.

Archive only through the case-specific wrapper, which uses the independent
archive root and refuses a non-40,000-step result without an explicit
reference:

```sh
EXPECTED_STEPS=40000 \
LABEL=<UNIQUE_CB3X3X3_LABEL> \
./tools/archive_cb3x3x3_result.sh
```

For a future approved 1,000-step reference:

```sh
EXPECTED_STEPS=1000 \
REFERENCE_OUTPUT=<APPROVED_1000_STEP_REFERENCE> \
LABEL=<UNIQUE_CB3X3X3_LABEL> \
./tools/archive_cb3x3x3_result.sh
```

The x86 runner exposes the same long-run gates, but requires explicit
confirmation so they cannot start accidentally:

```sh
EXPECTED_SKU=8592+ CONFIRM_LONG_RUN=YES LABEL=<UNIQUE_100_STEP_LABEL> \
  ./tools/run_cb3x3x3_x86.sh tddft-100

EXPECTED_SKU=<SKU> CONFIRM_LONG_RUN=YES LABEL=<UNIQUE_LABEL> \
  ./tools/run_cb3x3x3_x86.sh tddft-40000

EXPECTED_SKU=<SKU> CONFIRM_LONG_RUN=YES LABEL=<UNIQUE_LABEL> \
REFERENCE_OUTPUT=<APPROVED_1000_STEP_REFERENCE> \
  ./tools/run_cb3x3x3_x86.sh tddft-1000
```

Execute one long run at a time. Runs 02 and 03 remain gated on run 01 passing
both the normal check and same-input relaxed comparison.

## NEC VE diagnostic comparison

A user-supplied NEC VE result is present outside the x86 platform tree at:

```text
run/cb3x3x3_ve/sample.tddft_exe/0827_100steps_8MPI_2OMP/
```

Its `dia-cb3x3x3_tm.out` name is a symlink to the nonempty
`dia-cb3x3x3_tm.out_part001` result. Keep this NEC VE directory independent;
do not move or copy it into the 8592+ run or archive tree. Compare it read-only
with the fixed 8592+ 100-step diagnostic using:

```sh
TEST_PLATFORM=NEC_VE_8MPI_2OMP \
./tools/compare_cb3x3x3_platform_results.sh \
  ./run/cb3x3x3_ve/sample.tddft_exe/0827_100steps_8MPI_2OMP/
```

The helper requires normal checks for both outputs, exactly 100 completed
steps, exactly 216 force/position/velocity rows, and a relaxed numerical
comparison before printing a wall-time ratio. A failure blocks the performance
comparison. This output-only check does not by itself establish the exact NEC
VE model, VE count, compiler, input provenance, or a formal platform baseline.

The returned comparison passed both normal checks at 100 steps and 216 atoms.
The 8592+ and NEC VE walls were `7053.57140899` and `3189.16684126` sec,
respectively, but the relaxed numerical comparison failed: final-force
`id=165`, component 1 differed by `2.016e-4`, above the fixed `1.0e-4`
tolerance. ETOT (`2.8e-5`), total energy (`2.768e-5`), positions
(`1.314808e-9`), and velocities (`6.167918e-9`) were within tolerance. The
helper correctly blocked the wall ratio. Do not weaken the force tolerance or
claim a performance comparison until input, initial-state, numerical-source,
and NEC VE provenance are reconciled.
