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

## Correctness and performance gates

- The official 40,000-step output is the only supplied external reference.
- The derived 2-step input is for bounded startup/memory validation only.
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
