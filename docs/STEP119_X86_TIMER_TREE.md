# Step 119 x86 Timer Tree Values

Recorded from the terminal photographs returned on 2026-08-05 for the
controlled Step 119 x86 validation series. The timer photograph and the final
three-run summary came from the same execution, but the timer photograph does
not show its archive label. Therefore the timer sample is not assigned to a
specific run number by inference.

## Execution provenance

- Revision: `87045133f0685b95c0943488e6953e0c8deb1936`
- CPU: Intel Xeon 6980P
- Kernel: Linux `5.14.0-427.13.1.el9_4.x86_64`
- Compiler: ifx 2026.1.0 (20260617)
- MPI: Intel MPI 2021.18.0, build 20260327
- Execution: 32 MPI ranks x 8 OpenMP threads
- Binding: `I_MPI_PIN=1`, `I_MPI_PIN_DOMAIN=omp`,
  `I_MPI_PIN_ORDER=compact`,
  `KMP_AFFINITY=granularity=fine,compact,1,0`
- Diagnostics: off
- Build: FFTW, CG, and SD reused; TDDFT rebuilt
- Case: Si111-H, 100 TDDFT time steps

## Three-run wall result

| archive label | wall_sec | normal | relaxed | run-01 strict |
|---|---:|---|---|---|
| `x86_fftw_32mpi_8omp_intel_20260805_133214_87045133f068_01` | 16.4435307980 | PASS | PASS | SELF |
| `x86_fftw_32mpi_8omp_intel_20260805_133214_87045133f068_02` | 16.4973180294 | PASS | PASS | PASS |
| `x86_fftw_32mpi_8omp_intel_20260805_133214_87045133f068_03` | 16.4935860634 | PASS | PASS | PASS |

- Median: `16.4935860634` sec
- Range: `0.0537872314` sec

## Returned timer-tree sample

All elapsed values below are inclusive. Paths preserve the nesting displayed
by `[Timer Output]` and all rows are rank 0 values.

| call path | called | elapsed_sec |
|---|---:|---:|
| `startup_before_steps` | 1 | 0.481 |
| `startup_before_steps > fft_plan_init` | 1 | 0.139 |
| `startup_before_steps > fft_wrapper` | 3 | 0.000 |
| `startup_before_steps > prenon` | 1 | 0.007 |
| `time_step_total` | 101 | 16.478 |
| `time_step_total > g_vector_update` | 101 | 0.032 |
| `time_step_total > ion_md` | 101 | 0.002 |
| `time_step_total > frprmn` | 101 | 15.864 |
| `time_step_total > frprmn > fft_wrapper` | 1,748 | 0.132 |
| `time_step_total > frprmn > hlocal_zero` | 78 | 0.001 |
| `time_step_total > frprmn > hlocal_scatter` | 78 | 0.003 |
| `time_step_total > frprmn > hlocal_inverse_fft` | 78 | 0.006 |
| `time_step_total > frprmn > hlocal_inverse_fft > fft_wrapper` | 78 | 0.006 |
| `time_step_total > frprmn > hlocal_vg_multiply` | 78 | 0.004 |
| `time_step_total > frprmn > hlocal_forward_fft` | 78 | 0.006 |
| `time_step_total > frprmn > hlocal_forward_fft > fft_wrapper` | 78 | 0.006 |
| `time_step_total > frprmn > hlocal_gather` | 78 | 0.003 |
| `time_step_total > frprmn > tmevl_total` | 936 | 10.386 |
| `time_step_total > frprmn > tmevl_total > tmevl_p_enter` | 936 | 0.000 |
| `time_step_total > frprmn > tmevl_total > tmevl_exkin` | 9,360 | 1.171 |
| `time_step_total > frprmn > tmevl_total > tmevl_exkin > exkin_acc_kernel` | 9,360 | 1.165 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2` | 4,680 | 7.616 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal` | 9,360 | 5.510 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_make` | 9,360 | 1.057 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm` | 9,360 | 4.439 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_work1_enter` | 4,680 | 0.000 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_meta_enter` | 4,680 | 0.000 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_gemm_data` | 9,360 | 4.425 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_nonlocal > s2_nonlocal_gemm > exnlp_gemm_data > exnlp_gemm_dot` | 9,360 | 4.416 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local` | 4,680 | 2.096 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel` | 14,040 | 1.367 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_zero_rho2` | 4,680 | 0.094 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_scatter_p` | 4,680 | 0.325 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_vg_build` | 4,680 | 0.541 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_local_multiply` | 4,680 | 0.202 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > s2_acc_kernel > s2_gather_p` | 4,680 | 0.184 |
| `time_step_total > frprmn > tmevl_total > tmevl_s2 > s2_fft_local > fft_wrapper` | 9,360 | 0.689 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation` | 8 | 0.010 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_zero` | 8 | 0.000 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_scatter` | 8 | 0.000 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_inverse_fft` | 8 | 0.001 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_inverse_fft > fft_wrapper` | 8 | 0.001 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_vg_multiply` | 8 | 0.000 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_forward_fft` | 8 | 0.001 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_forward_fft > fft_wrapper` | 8 | 0.001 |
| `time_step_total > frprmn > tmevl_total > tmevl_expectation > hlocal_gather` | 8 | 0.000 |
| `time_step_total > frprmn > frprmn_rhoofk` | 468 | 0.533 |
| `time_step_total > frprmn > frprmn_rhoofk > fft_wrapper` | 936 | 0.068 |
| `time_step_total > frprmn > frprmn_rhoget` | 468 | 0.140 |
| `time_step_total > frprmn > frprmn_rhoget > fft_wrapper` | 936 | 0.070 |
| `time_step_total > frprmn > frprmn_coef_sync` | 103 | 0.000 |
| `time_step_total > electf_force` | 101 | 0.572 |
| `time_step_total > force_energy_update` | 101 | 0.000 |
| `TOTAL (inclusive regions)` | 138,879 | 80.250 |

The nine displayed `fft_wrapper` paths sum to 13,155 calls and `0.973` sec.
The call count exactly matches the earlier flat timer output. The elapsed sum
is specific to this returned timer sample. The `FPSEID_PROFILE` value rows were
not visible in the returned photograph and are therefore not reconstructed.
