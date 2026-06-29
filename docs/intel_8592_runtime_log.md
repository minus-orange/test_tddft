# Intel 8592+ Runtime Log: Si111-H TDDFT

Date: 2026-06-29

This records TDDFT profiling results reported from an Intel Xeon Platinum
8592+ environment for the AIST FPSEID21 `Si111-H` sample.

The run used the repository sample setup/run flow:

```sh
./tools/prepare_si111_h_sample.sh

ulimit -s unlimited
export OMP_STACKSIZE=512M

TDDFT_INPUT=Si111-H_tm.in_2steps ./tools/run_si111_h_sample.sh
TDDFT_INPUT=Si111-H_tm.in_50steps ./tools/run_si111_h_sample.sh
TDDFT_INPUT=Si111-H_tm.in_100steps ./tools/run_si111_h_sample.sh
```

The measurements below are transcribed from terminal screenshots of the
`FPSEID_PROFILE_BEGIN` / `FPSEID_PROFILE_END` blocks.

## TDDFT 2 Steps

```text
FPSEID_PROFILE_BEGIN
 id label                    count      max_rank_sec       avg_rank_sec
 1 time_step_total                   3           9.438272           9.438272
 2 g_vector_update                   3           0.000601           0.000601
 3 ion_md                            3           0.000002           0.000002
 4 frprmn                            3           9.205910           9.205910
 5 electf_force                      3           0.222213           0.222213
 6 force_energy_update               3           0.000001           0.000001
 7 prenon                            1           0.077705           0.077705
 8 tmevl_total                      18           7.022106           7.022106
 9 tmevl_exkin                     180           0.700823           0.700823
10 tmevl_s2                         90           4.710671           4.710671
11 s2_nonlocal                     180           2.075491           2.075491
12 s2_fft_local                     90           2.635136           2.635136
13 tmevl_expectation                18           0.962010           0.962010
14 fft_wrapper                    8769           3.004556           3.004556
FPSEID_PROFILE_END
```

## TDDFT 50 Steps

```text
FPSEID_PROFILE_BEGIN
 id label                    count      max_rank_sec       avg_rank_sec
 1 time_step_total                  51         196.886668         196.886668
 2 g_vector_update                  51           0.010207           0.010207
 3 ion_md                           51           0.000030           0.000030
 4 frprmn                           51         193.160398         193.160398
 5 electf_force                     51           3.703574           3.703574
 6 force_energy_update              51           0.000024           0.000024
 7 prenon                            1           0.077716           0.077716
 8 tmevl_total                     490         164.796785         164.796785
 9 tmevl_exkin                    4900          18.986148          18.986148
10 tmevl_s2                       2450         127.765929         127.765929
11 s2_nonlocal                    4900          56.447593          56.447593
12 s2_fft_local                   2450          71.317852          71.317852
13 tmevl_expectation                 8           0.422561           0.422561
14 fft_wrapper                  175473          59.589456          59.589456
FPSEID_PROFILE_END
```

## TDDFT 100 Steps

```text
FPSEID_PROFILE_BEGIN
 id label                    count      max_rank_sec       avg_rank_sec
 1 time_step_total                 101         378.317744         378.317744
 2 g_vector_update                 101           0.019793           0.019793
 3 ion_md                          101           0.000051           0.000051
 4 frprmn                          101         370.960171         370.960171
 5 electf_force                    101           7.327799           7.327799
 6 force_energy_update             101           0.000042           0.000042
 7 prenon                            1           0.077723           0.077723
 8 tmevl_total                     940         315.939448         315.939448
 9 tmevl_exkin                    9400          36.415513          36.415513
10 tmevl_s2                       4700         245.301083         245.301083
11 s2_nonlocal                    9400         108.233087         108.233087
12 s2_fft_local                   4700         137.067198         137.067198
13 tmevl_expectation                 8           0.423259           0.423259
14 fft_wrapper                  335173         113.922130         113.922130
FPSEID_PROFILE_END
```

## Trend Comparison

Percentages below are each timer's `max_rank_sec` divided by
`time_step_total`. Timers are nested, so percentages identify hotspots and
should not be summed as exclusive time.

| label | 2 steps | 50 steps | 100 steps |
| --- | ---: | ---: | ---: |
| frprmn | 97.54% | 98.11% | 98.06% |
| electf_force | 2.35% | 1.88% | 1.94% |
| prenon | 0.82% | 0.04% | 0.02% |
| tmevl_total | 74.40% | 83.70% | 83.51% |
| tmevl_exkin | 7.43% | 9.64% | 9.63% |
| tmevl_s2 | 49.91% | 64.89% | 64.84% |
| s2_nonlocal | 21.99% | 28.67% | 28.61% |
| s2_fft_local | 27.92% | 36.22% | 36.23% |
| fft_wrapper | 31.83% | 30.27% | 30.11% |

The 50-step and 100-step profiles are consistent. Compared with the 2-step
smoke test, `prenon` becomes negligible while `tmevl_total` and especially
`tmevl_s2` become more dominant.

GPU porting priority from this Intel 8592+ measurement:

1. `tmevl_s2`, especially `s2_fft_local`.
2. `s2_nonlocal`, including nonlocal projector/GEMM-style work.
3. `fft_wrapper`, noting that it overlaps with the FFT-heavy local path.
4. `tmevl_exkin`.

## Notes

- `fort.23` must be promoted to `wf_fft.Si111-H` for TDDFT. `fort.88` is a
  real-space intermediate used by SD and is not the TDDFT reciprocal-space
  wavefunction.
- The 50-step and 100-step counts differ slightly from the earlier GNU/Mac
  run, but the hotspot ordering is stable.
