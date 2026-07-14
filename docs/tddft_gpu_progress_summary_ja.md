# TDDFT GPU化進捗まとめ

> [English version](tddft_gpu_progress_summary_en.md)

> この日本語版はGPU化の実験履歴を段階ごとに追えるよう整理しています。
> routine名、timer label、archive label、OpenACC directiveはソースとの対応を保つため英語のまま記載します。

## 用語メモ

- **Step**: 1つの性能仮説を検証する実装単位です。結果が悪ければそのStepだけを戻します。
- **residency（常駐）**: 配列をGPUメモリに保持し、反復するHost-Device転送を避けることです。
- **inclusive timer**: 子routineの時間も含む計測値です。親と子を単純加算できません。
- **host-copy backend**: ライブラリ呼び出しのたびにCPUメモリとGPUメモリ間をコピーする経路です。
- **present-input path**: 必要な配列がすでにGPU上にあることを前提にする経路です。

日付: 2026-07-10

このメモは、`tddft-openacc-residency` ブランチで実施した FPSEID21
`Si111-H` 100 step 検証ケースの TDDFT GPU 化内容をまとめたものです。現時点の
方針は 1 GPU / 1 MPI rank とし、データ常駐と要素演算は OpenACC、FFT は CUDA
ライブラリ backend として cuFFT を使用します。

## 対象範囲

対象は TDDFT の `S2_` 内にある局所ポテンシャル FFT 部です。比較基準は
コミット済み GNU 100 step ログで、通常確認は relaxed tolerance を使用します。

## 実装済み内容

最初の cuFFT 実装では `fft_cufft.f` と `fpseid_cufft_wrap.c` を追加しました。
Fortran 側の FFT entry 名は既存のまま維持し、各 FFT 呼び出しごとに host から
GPU へコピー、cuFFT 実行、GPU から host へコピーする方式です。

Step 1 では S2 の local FFT 部に OpenACC data region を追加しました。
`RHO1_`, `RHO2_`, `VG` を device 上に作成し、`P`, `VGG`, `Vloc`, `J2G` を
local FFT block 用に転送します。

この段階では FFT 呼び出し自体は host-copy 型 cuFFT wrapper のままだったため、
FFT 前後に `update self` / `update device` が残っていました。

Step 2 では scatter、local potential 作成、local potential multiply、gather の
ループを OpenACC kernel 化しました。併せて `s2_acc_update`,
`s2_acc_kernel`, `startup_before_steps`, `fft_plan_init` のタイマーを追加しました。

```text
fpseid_cufft_exec_device
```

Step 3 では OpenACC 管理下の device pointer を受け取る cuFFT API
`fpseid_cufft_exec_device` を追加しました。この経路では wrapper 内部の
host-to-device / device-to-host コピーを行わず、device pointer 上で cuFFT を
in-place 実行します。

```text
FFT3BX_fftwASL_ACC
FFT3FX_fftwASL_ACC
```

cuFFT backend では、これらの entry point が `!$acc host_data use_device(...)`
で OpenACC device pointer を C wrapper に渡します。forward FFT 後の正規化は
OpenACC loop で device 上実行します。

FFTW 互換性維持のため、`fft_fftw.f` にも同名の `_ACC` entry を追加し、従来の
host FFT wrapper へ委譲する形にしています。

## 性能スナップショット

以下は検証環境での `Si111-H` TDDFT 100 step 実行結果です。実行ごとに多少の
揺らぎはありますが、傾向確認用の値です。

| stage | check | compare | wall_sec | `time_step_total` | `s2_fft_local` | `fft_wrapper` | `s2_acc_update` | `s2_acc_kernel` |
|---|---|---|---:|---:|---:|---:|---:|---:|
| cuFFT host-copy baseline | PASS | PASS | 443.2秒 | 443.5秒 | 183.8秒 | 101.0秒 | n/a | n/a |
| Step 1 | PASS | PASS | 540.2秒 | 540.5秒 | 282.0秒 | 106.1秒 | n/a | n/a |
| Step 2 | PASS | PASS | 524.9秒 | 525.1秒 | 267.6秒 | 106.5秒 | 93.3秒 | 58.3秒 |
| Step 3 | PASS | PASS | 360.3秒 | 360.6秒 | 104.6秒 | 30.4秒 | 11.1秒 | 57.9秒 |

Step 3 では S2 の FFT ペア周辺で支配的だった転送オーバーヘッドを削減できたため、
最も大きな改善が出ています。

## cuFFT転送プロファイル

詳細 cuFFT wrapper profile は以下のように変化しました。

| stage | count | H2D秒 | FFT秒 | D2H秒 | 合計秒 |
|---|---:|---:|---:|---:|---:|
| Step 2 | 336589 | 50.247 | 15.054 | 36.860 | 102.162 |
| Step 3 | 336589 | 6.125 | 13.636 | 6.285 | 26.045 |

まだ H2D/D2H が 0 ではないため、一部の FFT 呼び出しは互換用 host-copy wrapper
を通っています。ただし、主要な S2 local FFT 経路は device-resident cuFFT entry
を使用する状態になっています。

## 現時点の解釈

- 現在の検証ケースでは計算結果は許容範囲内です。
- Step 3 により OpenACC + cuFFT device-pointer 方針が有効であることを確認しました。
- `s2_acc_update` は約 93 秒から約 11 秒へ減少しました。
- `fft_wrapper` は約 106 秒から約 30 秒へ減少しました。
- `s2_acc_kernel` は約 58 秒で大きく変わっていないため、次の対象は cuFFT
  カーネルそのものではなく、kernel 部分と残るデータ移動です。

## 残課題

   `FPSEID_CUFFT_PROFILE` ではまだ `h2d_sec` と `d2h_sec` が 0 ではありません。
   `_ACC` 版ではなく従来の `FFT3BX_fftwASL` / `FFT3FX_fftwASL` を呼んでいる箇所を
   特定し、device-resident 経路へ移すべきか判断します。

   `s2_acc_kernel` は約 58 秒残っています。scatter、local potential 作成、
   local-potential multiply、forward 正規化、gather に分けて測定します。

   `s2_acc_update` は大きく減りましたが、まだ約 11 秒あります。これが主に最後の
   `P` host 戻しなのか、他の暗黙同期なのかを確認します。

   現在は CPU 側処理へ戻る前に `P` を host へ戻します。より広い TDDFT 区間で
   `P` を常駐させれば転送は減る可能性がありますが、GPU/CPU の所有境界が広がります。

   現時点の GPU 方針は 1 GPU / 1 MPI rank です。NVHPC TDDFT は CPU FFTW 経路でも
   rank 数依存の問題が確認されているため、multi-rank GPU 化は最初の GPU 常駐化
   とは分けて扱います。

## 推奨される次ステップ

次の実装は、以下の順に測定と削減を進めるのが妥当です。

1. `s2_acc_kernel`内部へ細粒度timerを追加する。
2. 残る非`_ACC` FFT wrapper callを特定する。
3. 最後の`P` copyoutが`s2_acc_update`を支配するか確認する。
4. 以上を確認してからOpenACC data lifetimeの拡張を検討する。

これにより、次の実験を測定可能な範囲に保ち、Step 3 後に残ったコストの内訳を
理解する前に GPU 常駐範囲を広げすぎることを避けられます。

## 追加した細粒度タイマー

Step 3 実行後、残っている `s2_acc_kernel` と `s2_acc_update` の内訳を見るために
細粒度タイマーを追加しました。これらは既存の集計タイマーの内側で計測するため、
従来の Step 1-3 の集計ラベルとの比較は維持されます。

| id | label | 計測対象 |
|---:|---|---|
| 19 | `s2_zero_rho2` | `RHO2_`のゼロ初期化 |
| 20 | `s2_scatter_p` | `J2G`を使った`P`から`RHO1_`へのscatter |
| 21 | `s2_vg_build` | `VG = VGG + Vloc` |
| 22 | `s2_local_multiply` | 局所ポテンシャルphase factorの適用 |
| 23 | `s2_gather_p` | `RHO2_`から`P`へのgather |
| 24 | `s2_copyout_p` | DeviceからHostへの最後の`P` copyout |

これらのラベルは `FPSEID_PROFILE` と `[Timer Output]` の両方に出力されます。

## 残るhost-copy FFT呼び出し

S2 local FFT block は現在 `FFT3BX_fftwASL_ACC` / `FFT3FX_fftwASL_ACC` を呼びます。
一方で、コード全体にはまだ host-copy wrapper 経路を使う互換 FFT 呼び出しが
残っています。これらは現在の S2 local FFT 常駐化実験の外側にあるため、
`FPSEID_CUFFT_PROFILE` の `h2d_sec` / `d2h_sec` がまだ 0 にならない理由になります。

主な残存箇所:

- `gga_lib_3_PBE.f`: PBE/GGA derivative FFT
- `lib4_ASL_2_check_Vext_SXACE.f`: startup/external-potential関連FFT
- `frprmn_tm12_check_Vext_Avec_v4.f`: force/minimization関連FFT
- `pspw_tm11_Vext_Avec_v4_alloc.f`: PSPW setupと関連transform
- `tmevl10_Avec_v4.f`内の、現在のS2 local FFT block以外の領域

これらはデータ寿命と CPU/GPU 所有境界がそれぞれ異なるため、機械的に `_ACC` 化
しない方が安全です。次の判断は、今回追加した細粒度タイマーの出力に基づいて
行います。

## scatter並列化実験

Step 4 の timer 出力では、残っている OpenACC kernel 時間の大半が
`s2_scatter_p` でした。最初の追試として、`P -> RHO1_` の scatter loop を
band 外側の二重 loop から `NXYZ * nbndloc` の一次元 OpenACC loop に変更しました。
これにより `J2G` mapping は維持したまま、scatter kernel の並列化粒度を大きく
します。

Step 5 実行では `check` と relaxed `compare` の両方が PASS しました。
`s2_scatter_p` は約 56 秒から約 0.46 秒へ減少し、wall time は約 303 秒まで
短縮しました。現在の 1 rank / A100 ケースでは、scatter loop 平坦化は有効な
最適化と判断できます。

## 非局所項の分解タイマー

Step 5 後、S2 内で最も大きく残っているコストは `s2_nonlocal` です。Step 6 では
計算内容を変えず、この集計領域を次の2つに分解するネストタイマーを追加しました。

| id | label | 計測対象 |
|---:|---|---|
| 25 | `s2_nonlocal_make` | `work2_`, `cfac_`, `ngnl_`を作る反復 |
| 26 | `s2_nonlocal_gemm` | `P`へ加算する`exnlp_gemm` |

これらは `s2_nonlocal` の内側に入っているため、以下の関係になります。

```text
s2_nonlocal ≈ s2_nonlocal_make + s2_nonlocal_gemm + loop/control overhead
```

次回の実行結果で、次の GPU 化対象を `exnlp_only_make` 側にするか、
`exnlp_gemm` 側にするか、あるいは両方にするかを判断します。

Step 6 の結果では、この領域の大半が `s2_nonlocal_gemm` であることが分かりました。

```text
s2_nonlocal       about 119.0 sec
s2_nonlocal_make  about   3.3 sec
s2_nonlocal_gemm  about 115.7 sec
```

## 実験的 OpenACC exnlp_gemm

Step 7 では `exnlp_gemm` の内側処理を OpenACC 化します。ただし `ia` loop は
`coef` を逐次更新する依存関係があるため、順序を維持します。各 `ia` の内側で
local band 方向を並列化し、dot product は実部・虚部の reduction に分けています。

この変更は意図的に保守的です。

- `ia` 更新順序は変更しません。
- complex reduction にはせず、実部・虚部の2つの実数 reduction に分けます。
- まず正しさの確認を優先します。性能は、呼び出しごとのデータ移動や kernel 起動
  overhead に制限される可能性があります。

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP7_01
```

## exnlp_gemm 分解タイマー

Step 7 で `exnlp_gemm` は正しく動作し、有効な改善になりましたが、非局所項の
中ではまだ最大のコストです。Step 8 では数値アルゴリズムを変えずに、この領域を
分解するネストタイマーを追加しました。

| id | label | 計測対象 |
|---:|---|---|
| 27 | `exnlp_gemm_data` | 転送とkernelを含むOpenACC data region全体 |
| 28 | `exnlp_gemm_dot` | `ct1`を作るdot-product/reduction kernel |
| 29 | `exnlp_gemm_update` | `ct1`と`work1`によるcoefficient update kernel |

`exnlp_gemm_data` は意図的に広い範囲です。純粋な転送時間ではなく、OpenACC
data region の寿命全体と内部 GPU kernel を含みます。次回実行でここがまだ
大きい場合は、次の段階で `enter data` / `exit data` を使い、転送時間と kernel
時間を分離します。

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP8_01
```

## exnlp_gemm 転送分解

Step 8 の結果では、`exnlp_gemm_data` が `exnlp_gemm_dot + exnlp_gemm_update`
よりかなり大きく、残りのコストは OpenACC data region の overhead、データ転送、
または未分解の初期化 kernel が支配的と考えられます。

Step 9 では `exnlp_gemm` の structured data region を明示的な `enter data` /
`exit data` に置き換え、計算内容を変えずにコストを分解します。

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP9_01
```

## S2 内での P 常駐化

Step 9 相当の結果では、`exnlp_gemm_enter` と `exnlp_gemm_exit` がまだ大きく、
`exnlp_gemm` 呼び出しごとの `P` 転送が残コストの大きな部分であることが
分かりました。

Step 10 では `P` を `S2_` 全体で device resident にします。

- 最初の非局所項処理前に `P(1:NG2Q,1:nbndloc)` を一度だけ device に転送します。
- 2回の `exnlp_gemm` は `present` な `P` を使います。
- local FFT/potential 部分も同じ device resident な `P` を使います。
- `S2_` の最後で `P` を一度だけ host に戻します。

追加タイマー:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP10_01
```

Step 10 相当の確認結果:

```text
archive label: nvhpc_cufft_1rank_02_STEP9_01
check: PASS
compare: PASS
wall_sec: 232.159
time_step_total: about 232.46 sec
s2_p_enter: about 14.05 sec
s2_p_exit: about 11.18 sec
```

この結果から、`S2_` 呼び出し単位で `P` を常駐させる方針は正しく、以前の
`exnlp_gemm` 単位の転送分解より大きく高速化することが確認できました。一方で
`s2_p_enter + s2_p_exit` がまだ約25秒残っているため、次は `P` の常駐境界を
`S2_` 単位から `TMEVL` 単位へ広げます。

## TMEVL 内での P 常駐化

Step 11 では、`P(1:NG2Q,1:nbndloc)` の GPU 常駐管理を `S2_` から外側の
`TMEVL` 4次分解経路 (`ioption.eq.4`) に移します。

実装内容:

- `TMEVL` が最初の `exkin_` 呼び出し前に `P` を一度だけ device へ転送します。
- `TMEVL` が最後の `exkin_` 呼び出し後に `P` を一度だけ host へ戻します。
- `S2_` 内部では `P` の enter/exit を行いません。
- `exkin_` は resident な `P` を OpenACC `parallel loop` で更新します。

追加タイマー:

想定する確認:

```text
LABEL=nvhpc_cufft_1rank_02_STEP10_01 ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
python3 ./tools/check_tddft_result.py check ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP10_01/tddft.err
python3 ./tools/check_tddft_result.py compare ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP10_01/tddft.err
```

主な性能確認ポイントは、`s2_p_enter` と `s2_p_exit` が active timer から消え、
time step ごとに `tmevl_p_enter` と `tmevl_p_exit` が1回ずつ出ることです。
また `exkin_acc_kernel` が出力されるため、既存の `tmevl_exkin` 集計との関係を
確認します。

Step 11 実測結果:

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

Step 10 相当の実行と比べると、`P` 転送コストは
`s2_p_enter + s2_p_exit = 約25.2秒` から
`tmevl_p_enter + tmevl_p_exit = 約5.7秒` へ減少しました。100 step の wall time
は約232秒から約180秒へ改善しました。

現時点で残っている主なコスト:

この結果から、次の有効な実験対象は `P` の転送境界拡大ではなく、`exnlp_gemm`
本体、特に呼び出しごとの data setup 削減と dot/update kernel 構造の改善と考えます。

## exnlp_gemm の冗長ゼロ初期化削除

Step 12 では、`exnlp_gemm` の内側 `ia` ループにあった `ct1` のゼロ初期化
OpenACC kernel を削除します。

理由:

- 後続の `exnlp_gemm_dot` kernel は、update kernel が `ct1` を参照する前に
  `iib = 1, nbndloc` の全要素へ `ct1(iib)` を書き込みます。
- そのため、従来の `ct1(iib) = (0.d0,0.d0)` kernel は冗長でした。
- Step 11 の測定では `exnlp_gemm_zero` が約5.8秒だったため、削除により
  kernel launch とそのタイマー領域が減ることを期待します。

想定する確認:

```text
LABEL=nvhpc_cufft_1rank_02_STEP11_01 ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
python3 ./tools/check_tddft_result.py check ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP11_01/tddft.err
python3 ./tools/check_tddft_result.py compare ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP11_01/tddft.err
```

期待する性能上のシグナルは、`exnlp_gemm_zero` がタイマー出力から消え、
`check` と relaxed `compare` が引き続き `PASS` することです。これが通れば、
次の大きめの実験として `exnlp_gemm` の dot/update 構造を見直し、不要な一時
データ準備や kernel launch overhead を減らします。

Step 12 コードの実測結果です。archive label は `STEP11_01` です。

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

期待通り、`exnlp_gemm_zero` はタイマー出力から消え、`check` と relaxed
`compare` はどちらも `PASS` のままです。wall time は約179.77秒から約172.65秒へ
改善しました。

## 現在のゴール

このブランチのゴールは、以下に置きます。

```text
Move the whole TDDFT time-step body to GPU execution where practical, and
minimize host-device memory transfers across the time-step loop.
```

```text
TDDFT のタイムステップ内部を、実用上可能な範囲で GPU 実行へ移し、
タイムステップループ中の Host-Device 間メモリ転送を最小化する。
```

つまり、最適化境界は `s2_fft_local` だけではありません。`s2_fft_local` は
回避可能な FFT 転送コストが大きかったため最初の対象にしましたが、今後は
伝播ステップ内部の主要領域全体へ対象を広げます。

## 現在の状態

達成済み:

- 検証済み経路は引き続き 1 GPU / 1 MPI rank です。
- FFT library backend として cuFFT を使用しています。
- device resident 配列と要素演算 kernel は OpenACC で管理しています。
- `P` は `S2_` 呼び出しごとではなく、`TMEVL` 伝播 block 全体で常駐します。
- S2 local FFT 経路は device pointer 版 cuFFT entry を使用しています。
- scatter、gather、local-potential multiply、kinetic phase update、非局所
  GEMM 経路の一部は OpenACC kernel 化済みです。
- Step 12 コードはコミット済み GNU 基準に対して `check` と relaxed `compare` が
  `PASS` です。

残課題:

   `work1`, `cfac`, `ngnl` はまだ `exnlp_gemm` 呼び出し単位で転送または作成
   されています。次は、この setup cost の削減、またはこれら非局所入力の
   常駐期間拡大が対象です。

   dot/update 構造は正しく動作していますが、まだ約25秒残っています。ここを
   変更する場合は、`ia` 更新順序の依存関係を壊さない必要があります。

   主要な S2 local FFT 呼び出しは device resident ですが、他の互換 host-copy
   FFT 呼び出しが残っています。これらは data ownership 境界を確認してから
   移行します。

   これは以前の S2 単位転送より大幅に小さいですが、タイムステップ全体の GPU
   常駐化には、この残りの time-step 境界転送も削減または除去する必要があります。

   現在の GPU 化は測定上のホット領域に集中しています。次段階では
   time-step 内部全体を棚卸しし、各 CPU 側処理を「CPUに残す」「OpenACC化する」
   「転送境界として分離する」に分類します。

推奨される次ステップ:

1. `exnlp_gemm_enter` をさらに転送・setup 要素へ分解する、または非局所入力
   buffer の一つをより長い OpenACC data region に移します。
2. 各ステップ後は `check_tddft_result.py check` と relaxed `compare` を継続します。
3. 成功した実行は `nvhpc_cufft_1rank_02_STEP12_01` のような単調増加 label で
   archive します。

## exnlp_gemm enter 内訳分解

Step 13 は計測のみの変更です。集計用の `exnlp_gemm_enter` は維持し、その内側の
OpenACC `enter data` を以下に分解します。

数値結果は変わらない想定です。目的は、次の実最適化対象を大きな `work1` 転送、
metadata 転送、一時配列 allocation のどれに置くべきか判断することです。

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP12_01
```

## exnlp キャッシュ可能性の確認

Step 14 も計測のみの変更です。Step 13 の結果から `exnlp_gemm_enter` の大半は
`exnlp_work1_enter` であることが分かったため、次の最適化候補は
`exnlp_gemm` に渡す非局所 projector 入力 buffer (`work1`) の再生成または再転送を
避けることです。

実際にキャッシュ化する前に、各 atom-type index と phase ごとに生成される入力が
安定しているかを確認します。

各 `NP/phase` の初回出現時に軽量な数値 signature を記録し、次を出力します。

```text
FPSEID_EXNLP_CACHE_REF np phase sig= ...
```

後続の呼び出しで signature が許容範囲を超えて変化した場合は、次を出力します。

```text
FPSEID_EXNLP_CACHE_DIFF np phase ref sig= ...
```

これは完全な bitwise 比較ではなく、現在の検証実行向けの低コストなガードです。
100 step 実行で `FPSEID_EXNLP_CACHE_DIFF` が出なければ、次の実装では `work2_` を
`NP/phase` ごとにキャッシュし、`exnlp_gemm` が device resident なキャッシュを
使う形に進めます。

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP13_01
```

確認コマンド:

```sh
grep FPSEID_EXNLP_CACHE run/tddft_archives/nvhpc_cufft_1rank_02_STEP13_01/tddft.out
```

キャッシュ化へ進むための期待結果:

- 観測された `NP/phase` に対して `FPSEID_EXNLP_CACHE_REF` が出る。
- `FPSEID_EXNLP_CACHE_DIFF` は出ない。

## exnlpキャッシュ成分別プローブ

Step 14 実行では、観測された全 `NP/phase` で `FPSEID_EXNLP_CACHE_DIFF` が出ました。
したがって `work2_ + cfac_ + ngnl_` の合成 signature は TDDFT 時間発展中に変化して
おり、`NP/phase` だけを key にした単純キャッシュは安全ではありません。

Step 15 では、signature を次の3成分に分けて再確認します。

初回 reference 行は3成分をまとめて出力します。

```text
FPSEID_EXNLP_CACHE_REF np phase ng cf wk= ...
```

後続で変化した場合、diff 行に変化成分が出ます。

```text
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... ngnl ...
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... cfac ...
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... work ...
```

解釈:

- `work` だけが変化する場合、`ngnl_` と `cfac_` は常駐/キャッシュ候補にし、
  projector 値生成を GPU 側へ寄せます。
- `cfac` も変化する場合、`ngnl_` だけを常駐候補にし、係数データは step ごとに
  生成または転送します。
- `ngnl` も変化する場合、この経路では projector metadata のキャッシュは避けます。

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP14_01
```

Step 15 実測結果:

成分別プローブでは、確認対象の非局所入力成分すべてで差分が出ました。

したがって、`NP/phase` だけを key にしたキャッシュは不採用です。`ngnl` も変化する
ため、metadata だけのキャッシュもこの検証経路では安全ではありません。この結果を
記録した後、以降の計測に診断出力や余分な host 側処理を混ぜないため、プローブは
active code から削除しました。

## 非局所入力常駐化の方針

Step 16 では、キャッシュ実験後の非局所項最適化方針を整理します。次の対象は、
古い projector 入力データの再利用ではありません。次の対象は、projector 入力の
生成を GPU 側の利用箇所へ近づけることです。

```text
exnlp_only_make -> exnlp_gemm
```

現時点のコスト構造:

- `exnlp_only_make` は `work2_`, `cfac_`, `ngnl_` を host 側で生成します。
- `exnlp_gemm` はそれらを device へ転送し、resident な `P` を更新します。
- `exnlp_work1_enter` はまだ有意な転送/setup コストとして残っています。

推奨する次の実装方針:

1. 既存の host 生成経路は correctness fallback として残します。
2. 非局所 projector 入力を GPU 側で生成し、host 往復なしで利用する実験的 OpenACC
   経路を追加します。
3. 各ステップで `check_tddft_result.py check` と relaxed `compare` を実施します。
4. `exnlp_gemm` の `ia` 更新順序は、別途 correctness 実験で許容されると確認する
   までは変更しません。

次の成功実行の推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP16_01
```

Step 16 実装内容:

- `exnlp_gemm` を、転送を持つ wrapper と共通 GPU kernel 本体に分割しました。
- `work1`, `cfac`, `ngnl`, `coef` が device 上に存在する前提で、temporary な
  `ct1` だけを作成/削除する `exnlp_gemm_present_inputs` を追加しました。
- 現在の呼び出し箇所はまだ従来の `exnlp_gemm` wrapper を使うため、この step は
  数値挙動を維持しながら、次 step で `work2_`, `cfac_`, `ngnl_` を device 上で
  生成してそのまま消費するための準備です。

期待する検証:

```text
python3 ./tools/check_tddft_result.py check \
  ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP16_01/tddft.err

python3 ./tools/check_tddft_result.py compare \
  ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP16_01/tddft.err
```

## present入力版exnlp GEMM経路の使用

Step 17 では、Step 16 で追加した `exnlp_gemm_present_inputs` を `S2_` 内の
2つの非局所項呼び出し箇所から実際に使うようにしました。

実装内容:

- `exnlp_gemm_present_inputs` 呼び出し前に、`S2_` 側で `work2_`, `cfac_`,
  `ngnl_` を明示的に device へ転送します。
- `exnlp_gemm_present_inputs` は、すでに present な入力を使って resident な
  `P` を更新します。
- GEMM 経路の終了後、呼び出し側で `work2_`, `cfac_`, `ngnl_` を明示的に
  delete します。
- 転送を内部に持つ従来の `exnlp_gemm` wrapper は fallback として残しています。

この step では、`work2_`, `cfac_`, `ngnl_` の host 生成はまだ残っています。
目的は data ownership 境界を明示し、次 step で入力生成を GPU 側へ移して
host 往復なしで present-input GEMM 経路へ渡せるようにすることです。

タイマーの見方:

- `exnlp_work1_enter` と `exnlp_meta_enter` は、呼び出し側で行う明示的な
  input copy-in を測ります。
- `exnlp_ct1_create` と `exnlp_gemm_dot/update` は
  `exnlp_gemm_present_inputs` 内に残ります。
- `exnlp_gemm_exit` には、呼び出し側の非局所入力 buffer delete も含まれます。

想定する検証 label:

```text
nvhpc_cufft_1rank_02_STEP17_01
```

Step 17 実測結果:

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

正しさは Step 16 から変わらず `PASS` です。wall time もほぼ同等で、これは想定通り
です。Step 17 は `work2_`, `cfac_`, `ngnl_` の所有境界を呼び出し側へ移しただけで、
データ生成自体はまだ host 側にあり、device へのコピーも残っています。重要なのは、
present-input 経路が実際の呼び出し箇所で検証できたことです。次 step では GEMM
consumer を再変更せず、`exnlp_only_make` 出力生成を GPU 側へ近づけられます。

## present-input exnlp GEMM の dot/update 融合

Step 18 では、検証済みの `exnlp_gemm_present_inputs` 経路だけを変更します。
転送を内部に持つ従来の `exnlp_gemm` wrapper は fallback として残しています。

実装変更:

- `exnlp_gemm_body_fused` を追加しました。
- `exnlp_gemm_present_inputs` は fused body を直接呼びます。
- fused body は local band ごとの OpenACC `parallel loop` 内で dot product を
  計算し、そのまま係数更新を行います。
- present-input 経路では、一時配列 `ct1` の device allocation を使わなくなります。
- fallback の `exnlp_gemm` wrapper 用に、従来の `exnlp_gemm_body` は残しています。

期待する性能シグナル:

- present-input 経路では `exnlp_ct1_create` が消える見込みです。
- update は `exnlp_gemm_dot` に含めるため、present-input 経路では
  `exnlp_gemm_update` も消える見込みです。
- `exnlp_gemm_dot` 単体は Step 17 より増える可能性がありますが、
  `exnlp_gemm_dot + exnlp_gemm_update + exnlp_ct1_create` の合計が下がるなら
  fused kernel は有効です。
- 正しさは relaxed TDDFT comparator で引き続き `PASS` する必要があります。

想定する検証 label:

```text
nvhpc_cufft_1rank_02_STEP18_01
```

Step 18 実測結果:

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

期待したシグナルは確認できました。fused present-input 経路では、この経路から
`ct1` allocation と独立した update kernel が消え、relaxed TDDFT 比較も維持
できています。wall time は Step 17 の約170.25秒から約163.31秒へ改善しました。
残る主なコストは `tmevl_total`, `s2_nonlocal`, `s2_fft_local` です。
`s2_nonlocal` 内では、削除済みの `ct1`/update 分離ではなく、残っている
nonlocal GEMM と入力生成コストが次の対象です。

## exnlp入力寿命の呼び出し側寄せ

Step 19 では、非局所項経路の data motion を減らすため、`exnlp_gemm` 入力の
所有をさらに `S2_` 呼び出し側へ寄せました。

Step 19 実測結果:

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

数値結果は維持できましたが、性能は Step 18 より悪化しました。
明示的な入力転送コストは `exnlp_gemm_data` からは減りましたが、その分が
`s2_nonlocal_make` 側に現れています。つまり、GEMM consumer 側は整理できた
一方で、producer 側が律速になりました。

## exnlp make lookup 転送実験

Step 20 では、`exnlp_only_make_acc` の lookup 入力配列について、まず正しく
動くことを優先した実験を行いました。大きな親配列を resident に保とうとした時の
OpenACC present-table mismatch は回避できましたが、細かい copy が大量に発生し、
大きな性能劣化を招きました。

Step 20 実測結果:

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

この結果から、現在の `exnlp_only_make_acc` lookup 転送方式は正しく動くものの、
性能面では採用すべき方向ではないことが分かります。支配的な悪化箇所は cuFFT や
fused GEMM body ではなく、`s2_nonlocal_make` です。

## 現状

現在のゴールは次です。

```text
Keep the full TDDFT time-step loop on the GPU and minimize host/device memory
transfers inside the step loop.
```

```text
TDDFT のタイムステップ内処理を GPU 上に載せ、step loop 内の host/device 間
メモリ転送を最小化する。
```

これまでに確認できた有効な結果:

- cuFFT 置き換えは relaxed TDDFT comparator で数値的に妥当です。
- 現在の基準方針は 1 rank / 1 GPU です。
- `S2_` の local/FFT 側 residency と cuFFT device-resident 実行は妥当です。
- fused present-input nonlocal GEMM 経路は妥当で、Step 18 までは性能改善しました。
- この一連の中で、明確に有効な性能点は Step 18 の約163秒です。

現在のコード状態:

- 最新コードは Step 20 系の実験を含み、`exnlp_only_make_acc` に対して
  correctness-first の lookup 入力 copy 方式を含みます。
- これは性能 baseline ではなく、実験状態として扱うべきです。
- 現 HEAD で性能測定する場合は Step 18 と比較し、`s2_nonlocal_make` が
  支配していないかを確認してから採否判断します。

## 残課題

   `ylm`, `vpj`, `extau` に対して安定した OpenACC ownership 方針が必要です。
   present-table error は、親配列の寿命と dummy argument section の扱いがまだ
   揃っていないことを示しています。細かい copyin の繰り返しは正しいですが遅すぎます。

   次の step は、まず Step 18 の約163秒水準を回復する必要があります。Step 20 は
   正しさ確認としては有用ですが、性能確認点としては不採用です。

   残る高コスト領域は `s2_nonlocal`, `tmevl_s2`, FFT 経路です。優先順位は、
   反復 loop 内で大きい配列や頻繁に使う配列を host/device 間で動かさないことです。

   OpenACC 作業は実験色が強いため、CPU/FFTW fallback と relaxed TDDFT comparator
   は引き続き重要です。各性能 step では、出力を archive し、`check` と `compare`
   の両方を通す必要があります。

## B1 YLM ownership実験とrollback

B1では、TMEVLを`YLM1..5`のdevice lifetime ownerとし、callee内のYLM section
`copyin`を`present`へ置換しました。診断では5 phaseともparent/sectionがpresentで、
address offsetも期待値と一致しました。数値結果も`check`とrelaxed `compare`の
両方がPASSしました。

3回の性能測定は次の通りです。

```text
wall_sec: 174.30, 174.05, 174.32 sec
median:   174.30 sec
Step 18:  163.31 sec
increase: about 6.7 percent
```

中央値はStep 18より約6.7%遅く、採用条件の+3%以内を満たしません。そのためB1は
不採用とし、commit `a40ddd6`でYLM ownership変更だけをrollbackしました。この
rollbackは`origin/tddft-openacc-residency`へpush済みです。VPJ/EXTAU ownershipへは
進まず、diagnostic OFFのStep 18相当条件を3回再測定してbaseline回復を確認します。

### rollback後のStep 18 baseline回復確認

コードをStep 18記録commit `732793d`相当へ戻した後、diagnostic OFF、1 GPU / 1 MPI
rankで100 stepを3回再測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_B1_ROLLBACK_01` | 162.262726068 | PASS | PASS |
| `nvhpc_cufft_1rank_02_B1_ROLLBACK_02` | 161.753436089 | PASS | PASS |
| `nvhpc_cufft_1rank_02_B1_ROLLBACK_03` | 161.717231989 | PASS | PASS |

3回中央値は`161.753436089`秒です。正式Step 18値`163.310745001`秒より約0.954%速く、
実行間の幅は約0.545秒です。+3%上限`168.210067351`秒以内であり、全runで通常checkと
relaxed compareがPASSしたため、rollback後のbaseline回復gateは完了です。

relaxed compareの各run共通最大絶対差は、ETOT `9.287000e-05`、
Eelec+Enucl-Eext-Ework `9.497180e-05`、force `9.050000e-05`、positions
`8.117602e-07`、velocities `2.087788e-07`で、すべて設定tolerance以内です。
