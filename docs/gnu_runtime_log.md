# GNU Runtime Log: Si111-H Sample

Date: 2026-06-27

This records the GNU build/runtime check for the AIST FPSEID21 `Si111-H`
sample. Raw stdout/stderr logs are kept under `docs/runtime_logs/`.

## Environment

- Host OS: Darwin `25.5.0` arm64, `MacMiniM1.local`
- Fortran compiler: GNU Fortran, Homebrew GCC `16.1.0`
- MPI Fortran wrapper: `mpifort`, GNU Fortran, Homebrew GCC `16.1.0`
- FFTW prefix for TDDFT: `/opt/homebrew/opt/fftw`
- Threads/processes used for runtime checks:
  - CG: `OMP_NUM_THREADS=1`
  - SD: `OMP_NUM_THREADS=1`
  - TDDFT: `OMP_NUM_THREADS=1 mpirun -np 1`

## Build Commands

```sh
cd FPSEID21/cg_GGA_f_code
FC=gfortran ./mk_ifort.sh

cd ../sd_GGA_f_compact_code
FC=gfortran ./mk_ifort.sh

cd ../tddft_2022October
FFTW_ROOT=/opt/homebrew/opt/fftw FC=mpifort CC=mpicc ./mk_ifort.sh
```

The GNU builds use `_gnu.f` source variants where GNU Fortran requires
compatibility fixes. The Intel/default builds keep using the original `.f`
source files.

## Input And File Mapping

Sample: AIST `Si111-H`

- CG input: `Si111-H.in`
- SD input: `Si111-H_sd.in`
- TDDFT input: `Si111-H_tm.in_1000steps`, shortened locally to
  `Si111-H_tm.in_2steps` by changing `tstep=1000` to `tstep=2` and `TMOD=50`
  to `TMOD=1`.

Important unit mapping for TDDFT:

- `fort.18 -> Eext`
- `fort.20 -> rh.Si111-H`
- `fort.22 -> wf_fft.Si111-H`
- `fort.28 -> Etot`
- `fort.32 -> wf_fft.Si111-H`
- `fort.41 -> TR.Si93g_asci`
- `fort.42 -> TR.H99g_asc`
- `fort.46 -> TR.Si93e_asci`
- `fort.53 -> laser.dat`
- `fort.54 -> size.dat`
- `fort.55 -> sym.C1`
- `fort.60 -> Avec`
- `fort.62 -> Ework`

For CG and SD, `fort.54` and `fort.55` are read at startup. SD also reads
`fort.20`, `fort.22`, and `fort.88` after the CG stage has generated and
promoted the state files. Use `tools/check_si111_h_unit_files.sh` to validate
the stage-specific files before running manually.

## Raw Logs

- CG stdout: `docs/runtime_logs/gnu_si111_h_cg.out`
- CG stderr: `docs/runtime_logs/gnu_si111_h_cg.err`
- SD stdout: `docs/runtime_logs/gnu_si111_h_sd.out`
- SD stderr: `docs/runtime_logs/gnu_si111_h_sd.err`
- TDDFT stdout: `docs/runtime_logs/gnu_si111_h_tddft_2steps.out`
- TDDFT stderr: `docs/runtime_logs/gnu_si111_h_tddft_2steps.err`
- TDDFT 50-step stdout: `docs/runtime_logs/gnu_si111_h_tddft_50steps.out`
- TDDFT 50-step stderr: `docs/runtime_logs/gnu_si111_h_tddft_50steps.err`
- TDDFT 100-step stdout: `docs/runtime_logs/gnu_si111_h_tddft_100steps.out`
- TDDFT 100-step stderr: `docs/runtime_logs/gnu_si111_h_tddft_100steps.err`

## CG Result

- Exit status: success
- Final SCF iteration: `ITR #24`
- Final convergence value: `0.6871249D-07`
- `CPU TIME END OF PSPW`: `10.1874870 SEC`
- Final total energy: `ETOT = -0.4867975116D+02 HR`
- stderr note: `IEEE_UNDERFLOW_FLAG`

Selected timing:

```text
CPU TIME BFR CRYST:       0.0002530 SEC
CPU TIME AFTR CRYST:      0.0029370 SEC
CPU TIME AFT INITPW:      0.0110610 SEC
CPU TIME AFT PRENON:      0.2939900 SEC
CPU TIME AFT FRPRMN:     10.1459570 SEC
CPU TIME END OF PSPW:    10.1874870 SEC
```

## SD Result

- Exit status: success
- Final SCF iteration: `ITR #9`
- Final convergence value: `0.2668622D-08`
- `CPU TIME END OF PSPW`: `10.0600860 SEC`
- Final total energy: `ETOT = -0.4877484889D+02 HR`
- stderr note: `IEEE_UNDERFLOW_FLAG`

Selected timing:

```text
CPU TIME BFR CRYST:       0.0005870 SEC
CPU TIME AFTR CRYST:      0.0065400 SEC
CPU TIME AFT INITPW:      0.0839880 SEC
CPU TIME AFT PRENON:      0.6347490 SEC
CPU TIME AFT FRPRMN:      9.9699400 SEC
CPU TIME END OF PSPW:    10.0600860 SEC
```

## TDDFT Result

- Exit status: success
- Run length: 2 steps
- Reported runtime: `0.121374209998D+02 sec`
- Final reported time: `0.0193600000000000 fsec`
- Final total energy: `ETOT = -0.4877395620D+02 HR`
- stderr: empty

TDDFT profile:

```text
FPSEID_PROFILE_BEGIN
 id label                    count      max_rank_sec       avg_rank_sec
 1 time_step_total                   3          12.427678          12.427678
 2 g_vector_update                   3           0.000546           0.000546
 3 ion_md                            3           0.000002           0.000002
 4 frprmn                            3          12.149675          12.149675
 5 electf_force                      3           0.276112           0.276112
 6 force_energy_update               3           0.000003           0.000003
 7 prenon                            1           0.167556           0.167556
 8 tmevl_total                      18           8.886564           8.886564
 9 tmevl_exkin                     180           1.497501           1.497501
10 tmevl_s2                         90           4.883973           4.883973
11 s2_nonlocal                     180           2.105035           2.105035
12 s2_fft_local                     90           2.778910           2.778910
13 tmevl_expectation                18           1.177167           1.177167
14 fft_wrapper                    8769           2.691144           2.691144
FPSEID_PROFILE_END
```

## TDDFT Longer-Step Checks

The 2-step run was intended as a smoke test. Longer 50-step and 100-step runs
were added to check whether the profile trend changes once startup effects are
less dominant.

### 50 Steps

- Exit status: success
- Reported runtime: `0.270753938000D+03 sec`
- Final reported time: `0.4840000000000000 fsec`
- Final total energy: `ETOT = -0.487251559675D+02 HR`
- stderr: empty

```text
FPSEID_PROFILE_BEGIN
 id label                    count      max_rank_sec       avg_rank_sec
 1 time_step_total                  51         271.042540         271.042540
 2 g_vector_update                  51           0.005653           0.005653
 3 ion_md                           51           0.000057           0.000057
 4 frprmn                           51         266.301909         266.301909
 5 electf_force                     51           4.733873           4.733873
 6 force_energy_update              51           0.000047           0.000047
 7 prenon                            1           0.168707           0.168707
 8 tmevl_total                     492         214.945228         214.945228
 9 tmevl_exkin                    4920          41.547327          41.547327
10 tmevl_s2                       2460         135.700722         135.700722
11 s2_nonlocal                    4920          58.562251          58.562251
12 s2_fft_local                   2460          77.137261          77.137261
13 tmevl_expectation                 8           0.530998           0.530998
14 fft_wrapper                  176181          54.835651          54.835651
FPSEID_PROFILE_END
```

### 100 Steps

- Exit status: success
- Reported runtime: `0.527506942000D+03 sec`
- Final reported time: `0.9680000000000001 fsec`
- Final total energy: `ETOT = -0.487124920508D+02 HR`
- stderr: empty

```text
FPSEID_PROFILE_BEGIN
 id label                    count      max_rank_sec       avg_rank_sec
 1 time_step_total                 101         527.884465         527.884465
 2 g_vector_update                 101           0.012296           0.012296
 3 ion_md                          101           0.000117           0.000117
 4 frprmn                          101         518.327174         518.327174
 5 electf_force                    101           9.543496           9.543496
 6 force_energy_update             101           0.000103           0.000103
 7 prenon                            1           0.169014           0.169014
 8 tmevl_total                     942         415.875456         415.875456
 9 tmevl_exkin                    9420          80.354704          80.354704
10 tmevl_s2                       4710         262.497933         262.497933
11 s2_nonlocal                    9420         113.499976         113.499976
12 s2_fft_local                   4710         148.996303         148.996303
13 tmevl_expectation                 8           0.536824           0.536824
14 fft_wrapper                  335881         105.316609         105.316609
FPSEID_PROFILE_END
```

### Trend Comparison

Percentages below are each timer's `max_rank_sec` divided by
`time_step_total`. Some timers are nested, so percentages should be used to
identify hotspots rather than summed as exclusive time.

| label | 2 steps | 50 steps | 100 steps |
| --- | ---: | ---: | ---: |
| frprmn | 97.76% | 98.25% | 98.19% |
| electf_force | 2.22% | 1.75% | 1.81% |
| prenon | 1.35% | 0.06% | 0.03% |
| tmevl_total | 71.51% | 79.30% | 78.78% |
| tmevl_exkin | 12.05% | 15.33% | 15.22% |
| tmevl_s2 | 39.30% | 50.07% | 49.73% |
| s2_nonlocal | 16.94% | 21.60% | 21.50% |
| s2_fft_local | 22.36% | 28.46% | 28.22% |
| fft_wrapper | 21.65% | 20.23% | 19.95% |

The 50-step and 100-step profiles are consistent. Compared with the 2-step
smoke test, startup-only work such as `prenon` becomes negligible, while
`frprmn`, `tmevl_total`, and especially `tmevl_s2` become more dominant.

GPU porting priority remains:

1. `tmevl_s2`, especially `s2_fft_local` and the FFT wrapper.
2. `s2_nonlocal`, including `exnlp_gemm` and projector work.
3. `tmevl_exkin` pointwise complex phase multiplication.

## Notes

- CG and SD were run first to generate the density and wavefunction files used
  by TDDFT.
- TDDFT uses `fort.22` for the wavefunction input in this sample path, even
  though the input command line contains `WF=32`; the runtime log reports
  `READ PREVIOUS WAVEFUNCTION FROM FILE22`.
- The CPU time values printed by TDDFT's legacy `CPU TIME` lines include a
  large offset on this platform. The profile block and `2 steps took ... sec`
  line are the useful timing records for TDDFT.
