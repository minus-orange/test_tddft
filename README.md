# test_tddft

FPSEID21 TDDFT profiling patch.

This workspace contains a lightly instrumented copy of the FPSEID21 TDDFT
source. The profiling additions use `MPI_Wtime` and print a summary block to
standard output at the end of `tddft_exe` runs.

Look for:

```text
FPSEID_PROFILE_BEGIN
...
FPSEID_PROFILE_END
```

Instrumented files:

- `FPSEID21/tddft_2022October/prof_timer.f`
- `FPSEID21/tddft_2022October/mk.sh`
- `FPSEID21/tddft_2022October/pspw_tm11_Vext_Avec_v4_alloc.f`
- `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- `FPSEID21/tddft_2022October/fft_fftw.f`

The original FPSEID21 source is distributed by AIST:
https://staff.aist.go.jp/yoshi-miyamoto/
