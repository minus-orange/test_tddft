# NVHPC Validation Summary / NVHPC検証まとめ

Date: 2026-07-08

This note summarizes the NVIDIA HPC SDK validation work for the FPSEID21
`Si111-H` CG -> SD -> TDDFT workflow. It records the practical build flags,
known pass/fail points, comparison policy, and the current recommendation for
continuing GPU/FFT work.

このメモは、FPSEID21 `Si111-H` の CG -> SD -> TDDFT フローについて、
NVIDIA HPC SDK環境で確認した内容をまとめたものです。実用上のビルド
オプション、PASS/FAILの境界、比較基準、今後GPU/FFT化へ進む際の推奨条件を
記録します。

## Environment / 環境

- Compiler: NVIDIA HPC SDK `nvfortran`, `nvc`, MPI wrapper `mpifort`/`mpicc`
- CPU FFT backend: FFTW 3.3.11 built for the NVHPC run environment
- Runtime dependency note: loading `gcc/14.3.0` resolved `libatomic.so.1`
  runtime errors on the tested system
- GPU test system used earlier: NVIDIA A100-PCIE-40GB

## Source Compatibility Fixes / ソース互換性修正

NVHPC rejects several legacy fixed-form `FORMAT` statements that other
compilers accepted. The required source changes are separator-only fixes, for
example `FORMAT(8X` -> `FORMAT(8X,` and `I4/8X` -> `I4/8X,`.

NVHPCでは、従来コンパイラでは通っていた固定形式Fortranの一部`FORMAT`
文がエラーになりました。対応は区切りカンマの追加だけで、数値アルゴリズム
は変更していません。

Affected areas:

- CG: `cg_main_gga_df_omp_YY_allct.f`, `rarr4.f`
- SD: `sd_main_df_SXACE_allct.f`, `rarr3.f`, `rarr4.f`, `rarr5.f`
- TDDFT: `lib4_ASL_2_check_Vext_SXACE.f`, `rarr3.f`

## Comparison Policy / 比較基準

The comparison tools use committed GNU logs as the default references:

比較ツールは、コミット済みGNUログをデフォルトの参照値として使います。

- CG: `docs/runtime_logs/gnu_si111_h_cg.out`
- SD: `docs/runtime_logs/gnu_si111_h_sd.out`
- TDDFT: `docs/runtime_logs/gnu_si111_h_tddft_100steps.out`

Relaxed tolerances are the default because compiler, MPI rank count, and
reduction order change low-order numerical results. Strict mode remains
available with `--strict`.

コンパイラ、MPIプロセス数、リダクション順序の違いで低位桁は変わるため、
通常の比較はrelaxed基準をデフォルトにしています。厳密比較は`--strict`で
実行できます。

Commands:

```sh
python3 ./tools/compare_cg_result.py compare ./run/Si111-H_nvhpc/Si111-H.out
python3 ./tools/compare_sd_result.py compare ./run/Si111-H_nvhpc/Si111-H_sd.out
python3 ./tools/check_tddft_result.py compare ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI
```

## CG Results / CG結果

NVHPC CG was useful for compiler investigation but is not the current baseline
for downstream SD/TDDFT. The Intel CG result is used as the practical input for
SD.

NVHPC版CGはコンパイラ検証としては有用でしたが、現時点では後段SD/TDDFTの
入力基準にはしていません。実用上はIntel版CG結果をSD入力に使います。

Observed behavior:

- `-O0 -Kieee`: much closer to GNU/Intel, but still not the preferred baseline
- `-O1 -Kieee`: improved/usable for investigation
- `-O2`: diverges from the first CG/SCF iteration and is not recommended

確認結果:

- `-O0 -Kieee`: GNU/Intelにかなり近づくが、後段入力の基準にはしない
- `-O1 -Kieee`: 調査用途としては改善
- `-O2`: 初回反復から分岐するため非推奨

## SD Results / SD結果

SD was run using the Intel CG output as input.

SDはIntel版CG出力を入力として実行しました。

Recommended build:

```sh
cd FPSEID21/sd_GGA_f_compact_code
FC=nvfortran FFLAGS="-O1 -mp -Msave -Mlarge_arrays -Kieee" ./mk_ifort.sh
```

Observed behavior:

- `-O0 -Kieee`: PASS with relaxed comparison
- `-O1 -Kieee`: PASS with relaxed comparison
- `-O2`: FAIL; ETOT, force, band energies, and final convergence differ too much

確認結果:

- `-O0 -Kieee`: relaxed比較でPASS
- `-O1 -Kieee`: relaxed比較でPASS
- `-O2`: ETOT、force、band、最終収束値が大きく外れるためFAIL

The relaxed SD comparison accepts different SCF iteration counts when both
final potential convergence values satisfy the SD convergence threshold.

SDのrelaxed比較では、SCF反復回数が違っても、両方の最終収束値がSDの収束条件を
満たしていればOKとします。

## TDDFT CPU FFTW Results / TDDFT CPU FFTW結果

TDDFT was tested using Intel CG output and NVHPC SD output.

TDDFTは、Intel CG出力とNVHPC SD出力を使って確認しました。

Recommended build:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort \
CC=mpicc \
FFLAGS="-O1 -mp -Msave -Mlarge_arrays -Kieee" \
FFTW_ROOT=../../fftw-3.3.11-nvhpc/install \
./mk_ifort.sh
```

Recommended input for validation:

```text
Si111-H_tm.in_100steps
```

TDDFT status by MPI process count:

| MPI ranks | status | approximate wall time for 100 steps |
| ---: | --- | ---: |
| 1 | PASS | 1457 s |
| 2 | PASS | 797 s |
| 4 | PASS | 456 s |
| 5 | PASS | 392 s |
| 6 | FAIL | incomplete output / MPI termination |
| 8 | FAIL | incomplete output / MPI termination |
| 16 | FAIL | incomplete output / MPI termination |

MPIプロセス数ごとの状態:

| MPIプロセス数 | 状態 | 100 stepのおおよその時間 |
| ---: | --- | ---: |
| 1 | PASS | 1457秒 |
| 2 | PASS | 797秒 |
| 4 | PASS | 456秒 |
| 5 | PASS | 392秒 |
| 6 | FAIL | 出力不完全 / MPI終了メッセージ |
| 8 | FAIL | 出力不完全 / MPI終了メッセージ |
| 16 | FAIL | 出力不完全 / MPI終了メッセージ |

Current recommendation:

```text
Use -np 5 for the NVHPC CPU FFTW TDDFT baseline.
```

現時点の推奨:

```text
NVHPC CPU FFTW版TDDFTの基準実行は -np 5 とする。
```

Example run:

```sh
cd run/Si111-H_nvhpc
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M

mpirun --quiet -np 5 ../../FPSEID21/tddft_2022October/tddft_exe \
  < Si111-H_tm.in_100steps \
  > Si111-H_tm.out_100steps_5MPI \
  2> Si111-H_tm_5MPI.err
```

Check and compare:

```sh
cd ../..
python3 ./tools/check_tddft_result.py check \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI \
  --err ./run/Si111-H_nvhpc/Si111-H_tm_5MPI.err

python3 ./tools/check_tddft_result.py compare \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI \
  --test-err ./run/Si111-H_nvhpc/Si111-H_tm_5MPI.err
```

## Current Interpretation / 現時点の解釈

NVHPC CPU execution is validated for SD and for TDDFT up to 5 MPI ranks. The
TDDFT failure at 6 or more ranks is not an input-file issue because `np=1..5`
complete and compare successfully. It is likely related to MPI decomposition,
rank-dependent communication, or an array partitioning assumption.

NVHPC CPU実行は、SDおよびTDDFTの5 MPIプロセスまで確認済みです。TDDFTが
6プロセス以上で落ちる問題は、`np=1..5`が完走して比較PASSしているため、
入力ファイル起因ではありません。MPI分割、ランク依存通信、または配列分割の
前提に関係している可能性が高いです。

## Next Step / 次の作業

Use the `-np 5` NVHPC CPU FFTW TDDFT run as the CPU-side performance baseline.
For the first GPU/cuFFT validation, use a simpler `1 GPU + 1 MPI rank` policy.
This separates GPU FFT correctness and transfer overhead from the known
rank-count issue seen at `-np 6` and above.

`-np 5` のNVHPC CPU FFTW版TDDFTはCPU側の性能基準として使います。一方、
最初のGPU/cuFFT検証は `1 GPU + 1 MPIプロセス` 方針で行います。これにより、
`-np 6` 以上で見えているMPIプロセス数依存の問題と、GPU FFTの正当性・転送
オーバーヘッドを切り分けます。

GPU validation run:

```sh
cd run/Si111-H_nvhpc
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M
export CUDA_VISIBLE_DEVICES=0

mpirun --quiet -np 1 ../../FPSEID21/tddft_2022October/tddft_exe \
  < Si111-H_tm.in_100steps \
  > Si111-H_tm.out_100steps_gpu_1rank \
  2> Si111-H_tm_gpu_1rank.err
```

GPU検証実行:

```sh
cd run/Si111-H_nvhpc
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M
export CUDA_VISIBLE_DEVICES=0

mpirun --quiet -np 1 ../../FPSEID21/tddft_2022October/tddft_exe \
  < Si111-H_tm.in_100steps \
  > Si111-H_tm.out_100steps_gpu_1rank \
  2> Si111-H_tm_gpu_1rank.err
```

Check the GPU run against the committed GNU reference with the existing relaxed
TDDFT comparison:

GPU実行結果は、既存のrelaxed TDDFT比較でコミット済みGNU参照ログと比較します。

```sh
cd ../..
python3 ./tools/check_tddft_result.py check \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_gpu_1rank \
  --err ./run/Si111-H_nvhpc/Si111-H_tm_gpu_1rank.err

python3 ./tools/check_tddft_result.py compare \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_gpu_1rank \
  --test-err ./run/Si111-H_nvhpc/Si111-H_tm_gpu_1rank.err
```

### Initial cuFFT Result / 初期cuFFT結果

The first `1 GPU + 1 MPI rank` cuFFT run completed 100 TDDFT steps and passed
the relaxed comparison against the committed GNU TDDFT reference. The archived
run labels are:

最初の `1 GPU + 1 MPIプロセス` cuFFT実行は100 TDDFT stepを完走し、
コミット済みGNU TDDFT参照ログとのrelaxed比較でPASSしました。退避ラベルは
以下です。

- FFTW baseline: `run/tddft_archives/nvhpc_fftw_1rank_o2`
- cuFFT test: `run/tddft_archives/nvhpc_cufft_1rank_o2`

Correctness status:

正当性確認:

- `check_tddft_result.py check`: PASS
- `check_tddft_result.py compare`: PASS
- `ETOT`, `Eelec+Enucl-Eext-Ework`, force, positions, and velocities were all
  within relaxed tolerances.

Performance summary for 100 steps:

100 stepの性能比較:

| profile region | FFTW sec | cuFFT sec | speedup |
| --- | ---: | ---: | ---: |
| `time_step_total` | 501.068871 | 443.502158 | 1.13x |
| `frprmn` | 492.014268 | 434.422398 | 1.13x |
| `tmevl_total` | 427.833639 | 373.854727 | 1.14x |
| `tmevl_s2` | 357.088483 | 306.979328 | 1.16x |
| `s2_nonlocal` | 122.986159 | 123.152011 | 1.00x |
| `s2_fft_local` | 234.100450 | 183.825464 | 1.27x |
| `fft_wrapper` | 163.592244 | 100.969549 | 1.62x |

Interpretation:

解釈:

- The cuFFT backend is active and improves the targeted FFT regions.
- `fft_wrapper` improved by about 1.62x even though this initial version still
  copies data host -> GPU -> host for every FFT call.
- End-to-end `time_step_total` improved by about 1.13x.
- `s2_nonlocal` did not improve, so it remains a separate non-FFT GPU
  acceleration candidate.
- Further speedup likely requires splitting transfer time from cuFFT execution
  time and keeping the relevant `tmevl_s2` working arrays resident on the GPU.

- cuFFT backendは有効に動作しており、狙い通りFFT関連領域が改善しました。
- 初期版は各FFTで host -> GPU -> host 転送を行いますが、それでも
  `fft_wrapper` は約1.62倍改善しました。
- 全体の `time_step_total` は約1.13倍改善しました。
- `s2_nonlocal` は改善していないため、FFTとは別のGPU化候補として残ります。
- 追加高速化には、転送時間とcuFFT実行時間の分離計測、および `tmevl_s2`
  作業配列のGPU常駐化が必要になる見込みです。

Compare both correctness and profile regions:

正当性比較と同時に、以下のプロファイル領域を比較します。

- `time_step_total`
- `frprmn`
- `tmevl_total`
- `tmevl_s2`
- `s2_fft_local`
- `s2_nonlocal`
- `fft_wrapper`

The initial cuFFT implementation mainly targets `fft_wrapper` and
`s2_fft_local`. Larger speedups will likely require keeping the relevant
`tmevl_s2` working arrays resident on the GPU.

初期cuFFT実装の主な対象は`fft_wrapper`と`s2_fft_local`です。さらに大きな
高速化には、`tmevl_s2`の作業配列をGPU上に保持する実装が必要になる見込みです。
