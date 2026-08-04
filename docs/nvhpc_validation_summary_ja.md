# NVHPC検証まとめ

> [English version](nvhpc_validation_summary_en.md)

> この日本語版は、英語版と同じ検証結果を読みやすく整理したものです。
> コマンド、ファイル名、PASS/FAILラベルは再現性のため原表記を維持します。

## 用語メモ

- **NVHPC**: NVIDIA HPC SDKに含まれるFortran/Cコンパイラ群です。
- **FFTW / cuFFT**: それぞれCPU向け、NVIDIA GPU向けの高速フーリエ変換ライブラリです。
- **relaxed比較**: コンパイラや並列リダクション順序による低位桁差を許容する比較です。
- **baseline（基準結果）**: 他環境の結果を判定するときの参照データです。

日付: 2026-07-08

このメモは、FPSEID21 `Si111-H` の CG -> SD -> TDDFT フローについて、
NVIDIA HPC SDK環境で確認した内容をまとめたものです。実用上のビルド
オプション、PASS/FAILの境界、比較基準、今後GPU/FFT化へ進む際の推奨条件を
記録します。

## 環境

- compiler: NVIDIA HPC SDK `nvfortran` / `nvc`、MPI wrapper `mpifort` / `mpicc`
- CPU FFT backend: NVHPC実行環境向けにbuildしたFFTW 3.3.11
- runtime依存: 検証環境では`gcc/14.3.0` moduleのloadにより
  `libatomic.so.1` errorを解消
- GPU: NVIDIA A100-PCIE-40GB

## ソース互換性修正

NVHPCでは、従来コンパイラでは通っていた固定形式Fortranの一部`FORMAT`
文がエラーになりました。対応は区切りカンマの追加だけで、数値アルゴリズム
は変更していません。

対象箇所:

- CG: `cg_main_gga_df_omp_YY_allct.f`, `rarr4.f`
- SD: `sd_main_df_SXACE_allct.f`, `rarr3.f`, `rarr4.f`, `rarr5.f`
- TDDFT: `lib4_ASL_2_check_Vext_SXACE.f`, `rarr3.f`

## 比較基準

比較ツールは、コミット済みGNUログをデフォルトの参照値として使います。

- CG: `docs/runtime_logs/gnu_si111_h_cg.out`
- SD: `docs/runtime_logs/gnu_si111_h_sd.out`
- TDDFT: `docs/runtime_logs/gnu_si111_h_tddft_100steps.out`

コンパイラ、MPIプロセス数、リダクション順序の違いで低位桁は変わるため、
通常の比較はrelaxed基準をデフォルトにしています。厳密比較は`--strict`で
実行できます。

コマンド:

```sh
python3 ./tools/compare_cg_result.py compare ./run/Si111-H_nvhpc/Si111-H.out
python3 ./tools/compare_sd_result.py compare ./run/Si111-H_nvhpc/Si111-H_sd.out
python3 ./tools/check_tddft_result.py compare ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI
```

## CG結果

NVHPC版CGはコンパイラ検証としては有用でしたが、現時点では後段SD/TDDFTの
入力基準にはしていません。実用上はIntel版CG結果をSD入力に使います。

確認結果:

- `-O0 -Kieee`: GNU/Intelにかなり近づくが、後段入力の基準にはしない
- `-O1 -Kieee`: 調査用途としては改善
- `-O2`: 初回反復から分岐するため非推奨

## SD結果

SDはIntel版CG出力を入力として実行しました。

推奨ビルド:

```sh
cd FPSEID21/sd_GGA_f_compact_code
FC=nvfortran FFLAGS="-O1 -mp -Msave -Mlarge_arrays -Kieee" ./mk_ifort.sh
```

確認結果:

- `-O0 -Kieee`: relaxed比較でPASS
- `-O1 -Kieee`: relaxed比較でPASS
- `-O2`: ETOT、force、band、最終収束値が大きく外れるためFAIL

SDのrelaxed比較では、SCF反復回数が違っても、両方の最終収束値がSDの収束条件を
満たしていればOKとします。

## TDDFT CPU FFTW結果

TDDFTは、Intel CG出力とNVHPC SD出力を使って確認しました。

推奨ビルド:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort \
CC=mpicc \
FFLAGS="-O1 -mp -Msave -Mlarge_arrays -Kieee" \
FFTW_ROOT=../../fftw-3.3.11-nvhpc/install \
./mk_ifort.sh
```

検証用の推奨入力:

```text
Si111-H_tm.in_100steps
```

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

現時点の推奨:

```text
NVHPC CPU FFTW版TDDFTの基準実行は -np 5 とする。
```

実行例:

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

```sh
cd ../..
python3 ./tools/check_tddft_result.py check \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI \
  --err ./run/Si111-H_nvhpc/Si111-H_tm_5MPI.err

python3 ./tools/check_tddft_result.py compare \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI \
  --test-err ./run/Si111-H_nvhpc/Si111-H_tm_5MPI.err
```

## 現時点の解釈

NVHPC CPU実行は、SDおよびTDDFTの5 MPIプロセスまで確認済みです。TDDFTが
6プロセス以上で落ちる問題は、`np=1..5`が完走して比較PASSしているため、
入力ファイル起因ではありません。MPI分割、ランク依存通信、または配列分割の
前提に関係している可能性が高いです。

## 次の作業

`-np 5` のNVHPC CPU FFTW版TDDFTはCPU側の性能基準として使います。一方、
最初のGPU/cuFFT検証は `1 GPU + 1 MPIプロセス` 方針で行います。これにより、
`-np 6` 以上で見えているMPIプロセス数依存の問題と、GPU FFTの正当性・転送
オーバーヘッドを切り分けます。

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

現在のcuFFT結果では、FFT wrapper時間の大半がHost <-> Device転送です。そのため
次の実装対象は、単発FFT置換の追加ではなく、`S2_` のlocal FFT部における
OpenACCベースのGPU常駐化です。独自CUDAカーネルは最初の対象にせず、cuFFTは
OpenACC device pointer連携によるライブラリbackendとして使用します。詳細は
`docs/tddft_gpu_residency_plan.md` に記録しています。

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

### 初期cuFFT結果

最初の `1 GPU + 1 MPIプロセス` cuFFT実行は100 TDDFT stepを完走し、
コミット済みGNU TDDFT参照ログとのrelaxed比較でPASSしました。退避ラベルは
以下です。

- FFTW baseline: `run/tddft_archives/nvhpc_fftw_1rank_o2`
- cuFFT test: `run/tddft_archives/nvhpc_cufft_1rank_o2`

正当性確認:

- `check_tddft_result.py check`: PASS
- `check_tddft_result.py compare`: PASS
- `ETOT`、`Eelec+Enucl-Eext-Ework`、force、positions、velocitiesは
  relaxed tolerance内

100 stepの性能比較:

| profile領域 | FFTW秒 | cuFFT秒 | speedup |
|---|---:|---:|---:|
| `time_step_total` | 501.068871 | 443.502158 | 1.13x |
| `frprmn` | 492.014268 | 434.422398 | 1.13x |
| `tmevl_total` | 427.833639 | 373.854727 | 1.14x |
| `tmevl_s2` | 357.088483 | 306.979328 | 1.16x |
| `s2_nonlocal` | 122.986159 | 123.152011 | 1.00x |
| `s2_fft_local` | 234.100450 | 183.825464 | 1.27x |
| `fft_wrapper` | 163.592244 | 100.969549 | 1.62x |

解釈:

- cuFFT backendは有効に動作しており、狙い通りFFT関連領域が改善しました。
- 初期版は各FFTで host -> GPU -> host 転送を行いますが、それでも
  `fft_wrapper` は約1.62倍改善しました。
- 全体の `time_step_total` は約1.13倍改善しました。
- `s2_nonlocal` は改善していないため、FFTとは別のGPU化候補として残ります。
- 追加高速化には、転送時間とcuFFT実行時間の分離計測、およびOpenACC data
  regionによる `tmevl_s2` 作業配列のGPU常駐化が必要になる見込みです。

cuFFTラッパは、終了時に追加で以下のブロックを出力します。

```text
FPSEID_CUFFT_PROFILE_BEGIN
  count h2d_sec fft_sec d2h_sec total_sec
  ...
FPSEID_CUFFT_PROFILE_END
```

このブロックにより、`fft_wrapper` の時間を host-to-device 転送、cuFFT実行、
device-to-host 転送、CUDA eventで測った合計時間に分解できます。次の最適化で
転送削減を優先すべきか、FFT実行そのものを優先すべきかを判断する材料にします。

TDDFTのCPU/FFTWビルドとGPU/cuFFTビルドは、どちらも`mod_timer.f90`の
`start_timer('region')` / `stop_timer('region')`をリージョン名で直接呼びます。
共通する論理区間は、元の`[Timer Output]`表とMPI集約済み
`FPSEID_PROFILE`形式で出力されます。GPU固有のCUDA event転送・cuFFT内訳には、
引き続き`FPSEID_CUFFT_PROFILE`を使用します。

正当性比較と同時に、以下のプロファイル領域を比較します。

- `time_step_total`
- `frprmn`
- `tmevl_total`
- `tmevl_s2`
- `s2_fft_local`
- `s2_nonlocal`
- `fft_wrapper`

初期cuFFT実装の主な対象は`fft_wrapper`と`s2_fft_local`です。さらに大きな
高速化には、OpenACCで`tmevl_s2`の作業配列をGPU上に保持し、FFTが必要な箇所で
そのdevice pointerをcuFFTに渡す実装が必要になる見込みです。

重要な設計上の制約:

- 現行のhost-copy型cuFFT wrapperは、検証済み互換経路として残します。
- OpenACC管理配列用には、device pointerを受け取るcuFFT wrapperを別に追加します。
- 最初のOpenACC data regionは狭くし、CPU側非局所項の後で入り、local FFTペアの間
  `RHO1_`/`RHO2_`/`VG` をdevice側に保持し、CPU側処理へ戻る前に `P` をhostへ
  戻します。
- OpenACC local FFT経路の検証では、`VG=VGG+Vloc` はGPU上で作ります。
- まず短時間のstrict寄り確認を行い、その後に既存の100 step relaxed比較を使います。
