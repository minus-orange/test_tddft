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

## Step 21: S2 local FFTのdevice-resident batch cuFFT化

Step 21では、`S2_`がlocal bandごとに個別実行していたforward/backward cuFFTを、
`nbndloc`全体の1回のbatch cuFFTへ置き換えました。cuFFT側では
`cufftPlanMany`のbatch planを遅延生成して再利用し、既存finalizerで破棄します。
OpenACC device pointerを直接渡すため、この変更による追加の大規模H2D/D2H転送は
ありません。CPU/FFTW fallbackは従来関数をband順に呼ぶbatch entryで維持しています。

実装commitは`bad046f` (`Batch device-resident S2 cuFFT calls`)です。diagnostic OFF、
1 GPU / 1 MPI rank、100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP21_BATCHFFT_01` | 146.439893007 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP21_BATCHFFT_02` | 147.131322861 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP21_BATCHFFT_03` | 146.540076017 | PASS | PASS |

3回中央値は`146.540076017`秒です。rollback後のStep 18再測定中央値
`161.753436089`秒より約9.405%速く、正式Step 18値`163.310745001`秒より約10.269%
速い結果です。実行間の幅は約0.691秒で、Step 18再測定中央値に対する+3%上限
`166.606039172`秒より約20.066秒短く、性能採用gateを満たします。

run 01のprofileでは、`s2_fft_local`が`5.026740`秒、`fft_wrapper`が
`13.494185`秒、`tmevl_s2`が`34.768706`秒でした。従来のStep 18 profile概算値との
比較では、それぞれ約77.6%、53.1%、31.7%短縮しており、batch化の効果がFFT経路に
現れています。現在の主要コストは`s2_nonlocal`の`29.728696`秒へ移りました。

全runで通常checkとrelaxed compareがPASSし、共通の最大絶対差もStep 18回復runと
同一で設定tolerance以内です。このためStep 21 batch cuFFT変更を正式採用します。
次の性能仮説へ進む際も、このcommitをrollback先および比較点として維持します。

## Step 22: nonlocal staging bufferのdevice allocation永続化

Step 22では、`S2_`内の`work2_`、`cfac_`、`ngnl_`について、各nonlocal phaseで
繰り返していたOpenACC `enter data copyin`と`exit data delete`を廃止しました。
これらは`save`付き配列としてhost側でも初回だけallocateされるため、device側も初回に
1度だけ`create`し、各phaseではhostで再生成した内容を`update device`します。
大規模H2Dのデータ量、nonlocal計算、`ia`更新順序、YLM/VPJ/EXTAU ownershipは
変更していません。CPU/FFTW fallbackのフルリンクもPASSしました。

実装commitは`1b98197` (`Persist nonlocal staging buffers on device`)です。
diagnostic OFF、1 GPU / 1 MPI rank、100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP22_PERSIST_NLBUF_01` | 146.283041954 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP22_PERSIST_NLBUF_02` | 146.165471077 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP22_PERSIST_NLBUF_03` | 146.268707991 | PASS | PASS |

3回中央値は`146.268707991`秒で、Step 21中央値`146.540076017`秒より約0.185%
高速です。実行間の幅は約0.118秒で、Step 21比+3%上限`150.936278298`秒以内です。
全runで通常checkとrelaxed compareがPASSし、最大絶対差も従来runと同一でした。

run 01のprofileでは、`s2_nonlocal`が`29.425824`秒、`tmevl_s2`が
`34.474580`秒、`exnlp_work1_enter`が`8.071267`秒、`exnlp_meta_enter`が
`0.150348`秒でした。反復deleteに対応していた`exnlp_gemm_exit`はprofileから消え、
timer数は32から31になりました。wall改善は小さいものの、反復device allocationを
削減しながら性能非悪化gateを満たすため、Step 22を正式採用します。

## Step 23: reverse nonlocal phaseでのstaging buffer再利用

各`S2_`ではlocal potentialの前後にnonlocal projectorを適用します。前半は
`ity/it/il/ip/l`をすべて降順、後半は同じindex集合をすべて昇順に走査しており、
後半のprojector列は前半の完全な逆順です。Step 23では前半でhost生成してdeviceへ
転送した`work2_`、`cfac_`、`ngnl_`を後半でも再利用し、consumerの列indexだけを
`loopcnt-ia+1`へ変換します。これにより、元の逐次`ia`適用順序を変えず、後半の
host生成と大規模H2Dを削減します。

実装commitは`f911621` (`Reuse nonlocal staging buffers in reverse phase`)です。
CPU/FFTW fallbackのフルリンクを確認後、diagnostic OFF、1 GPU / 1 MPI rank、
100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP23_REVERSE_REUSE_01` | 140.934056997 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP23_REVERSE_REUSE_02` | 140.840327024 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP23_REVERSE_REUSE_03` | 140.451899052 | PASS | PASS |

3回中央値は`140.840327024`秒です。Step 22中央値`146.268707991`秒より約3.711%
速く、rollback後のStep 18中央値`161.753436089`秒より約12.929%速い結果です。
実行間の幅は約0.482秒で、全runの通常checkとrelaxed compareがPASSしました。

run 01では`exnlp_work1_enter`と`exnlp_meta_enter`のcountが9440から4720へ半減し、
時間もそれぞれ`4.046410`秒と`0.074782`秒へほぼ半減しました。
`exnlp_gemm_dot` countは`453120`のまま維持されています。`s2_nonlocal_make`は
`1.517394`秒、`s2_nonlocal`は`24.380108`秒、`tmevl_s2`は`29.408207`秒でした。
数値結果とprojector適用回数を維持しながら後半H2Dを削減できたため、Step 23を
正式採用します。

## Step 24: nonlocal projector kernelのia方向融合

Step 23時点の`exnlp_gemm_body_fused`は、逐次依存する`ia`順序をhost側に残し、
各`ia`でlocal band全体のOpenACC kernelを起動していました。そのため100 stepで
`exnlp_gemm_dot`が453120回となり、kernel launch overheadが残っていました。

Step 24では、相互に独立なbandをOpenACC gangへ割り当て、各band内で
`ia=1..loopcnt`を`seq`実行します。各band内のprojector適用順序、各`ia`内の`ig`
reduction、およびreverse phaseの`loopcnt-ia+1`写像は変更していません。これにより
nonlocal phaseごとに1 kernelとなり、`exnlp_gemm_dot` countを9440へ削減しました。

実装commitは`b3559f1` (`Fuse nonlocal projector kernels across ia`)です。
CPU/FFTW fallbackのフルリンクを確認後、diagnostic OFF、1 GPU / 1 MPI rank、
100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP24_IA_FUSION_01` | 133.278103113 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP24_IA_FUSION_02` | 133.268284082 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP24_IA_FUSION_03` | 133.029439926 | PASS | PASS |

3回中央値は`133.268284082`秒です。Step 23中央値`140.840327024`秒より約5.376%
速く、rollback後のStep 18中央値`161.753436089`秒より約17.610%速い結果です。
実行間の幅は約0.249秒で、全runの通常checkとrelaxed compareがPASSしました。

run 01では`exnlp_gemm_dot` countが453120から9440へ減り、時間は
`18.374716`秒から`11.048592`秒へ約39.87%短縮しました。`s2_nonlocal`は
`16.746555`秒、`tmevl_s2`は`21.786372`秒となり、Step 23 run 01比でそれぞれ
約31.31%、25.92%短縮しました。projector順序と数値結果を維持したままkernel
launchを削減できたため、Step 24を正式採用します。

## Step 25: fused nonlocal kernelのvector length 256化

Step 24のNVHPC compiler reportでは、fused nonlocal kernelがbandを`gang`、
`ia`を`seq`、2本の`ig` loopを`vector(128)`として生成されていました。Step 25では
このkernelだけに`vector_length(256)`を指定しました。数式、各band内の`ia`順序、
`ig` reduction、reverse phase写像は変更していません。CPU/FFTW fallbackの
フルリンクもPASSしました。

実装commitは`825697a` (`Tune fused nonlocal vector length to 256`)です。
diagnostic OFF、1 GPU / 1 MPI rank、100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP25_VEC256_01` | 130.607889175 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP25_VEC256_02` | 130.404011011 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP25_VEC256_03` | 130.849056005 | PASS | PASS |

3回中央値は`130.607889175`秒です。Step 24中央値`133.268284082`秒より約1.996%
速く、rollback後のStep 18中央値`161.753436089`秒より約19.255%速い結果です。
実行間の幅は約0.445秒で、全runの通常checkとrelaxed compareがPASSしました。

run 01では`exnlp_gemm_dot` countを9440に維持したまま、時間がStep 24 run 01の
`11.048592`秒から`8.444633`秒へ約23.57%短縮しました。`s2_nonlocal`は
`14.127723`秒、`tmevl_s2`は`19.169946`秒で、それぞれ約15.64%、12.01%
短縮しました。このためvector length 256を正式採用します。

## Step 26: fused nonlocal kernelのvector length 512化（不採用）

Step 25と同じfused nonlocal kernelだけを`vector_length(512)`へ変更し、その他の
数式、loop順序、data mappingは変更せずに上限側を測定しました。実装commitは
`a8b4db0` (`Tune fused nonlocal vector length to 512`)です。diagnostic OFF、
1 GPU / 1 MPI rank、100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP26_VEC512_01` | 130.546390057 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP26_VEC512_02` | 130.834260225 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP26_VEC512_03` | 133.752757072 | PASS | PASS |

3回中央値は`130.834260225`秒です。全runの通常checkとrelaxed compareはPASSし、
rollback後のStep 18中央値`161.753436089`秒より約19.115%速い一方、正式採用済みの
Step 25中央値`130.607889175`秒より約0.173%遅い結果です。実行間の幅も約3.206秒
となり、Step 25の約0.445秒より大きくなりました。

run 01のprofileでは`exnlp_gemm_dot`がStep 25 run 01の`8.444633`秒から
`8.348217`秒へ約1.14%短縮しましたが、この局所差はwall中央値の改善には
つながりませんでした。より軽い256設定に対する性能優位を確認できないため、
Step 26は不採用とし、commit `336422e` (`Restore accepted nonlocal vector length
256`)で256へ戻しました。rollback後のCPU/FFTW fallbackフルリンクはPASSしました
（既存legacy warningのみ）。

## Step 27: Step 25採用コードのNsight Systems診断

採用済みのvector length 256コードを変更せず、1 GPU / 1 MPI rank、100 stepを
Nsight Systems 2026.2.1で計測しました。archive labelは
`nvhpc_cufft_1rank_02_STEP27_NSYS_03`、source revisionは`deefc3e`です。
Nsight実行時wallは`134.876740932`秒ですが、trace overheadを含むため性能baseline
には使用しません。TDDFT本体ログだけを対象にした通常checkとrelaxed compareは
ともにPASSしました。Nsight CLIの単独エラー行が同じstderrへ混入したため、最初の
自動checkだけはsuspicious lineとしてFAILしました。commit `1cfde9a`で以後の
Nsight CLIログとTDDFTログを分離しました。

主要なdata movementは次の通りです。

| operation | count | total size | device time |
|---|---:|---:|---:|
| H2D | 73,230 | 54,124.284 MB | 78.231 sec |
| D2H | 35,453 | 30,054.575 MB | 39.284 sec |

OpenACC summaryでは、`P`のTMEVL entry（line 532）が944回、約2.977秒、対応する
uploadが約2.899秒でした。TMEVL exit（line 714）とdownloadも944回で、それぞれ
約2.807秒、約2.794秒でした。nonlocal staging `work2_`のupdate（line 1913）は
4,720回、約4.146秒、対応するuploadは約3.734秒でした。時間はnested eventを含む
ため相互に加算しません。

kernel summaryでは`exnlp_gemm_body_fused`が9440回、約8.206秒でGPU kernel時間の
約63%を占めました。CUDA APIでは`cuLaunchKernel`が222,996回でしたがAPI時間は
約1.16秒です。一方、実allocationは`cuMemAlloc_v2`が16回、`cuMemFree_v2`が14回、
`cudaMalloc`/`cudaFree`が各1回に限定されており、time-step loop内の反復allocation
は主要因ではありません。

この結果からscratch allocation永続化と追加launch削減の優先度を下げます。次の
第一候補は、TMEVL単位の`P/COEF` mappingをcaller所有へ拡大し、host consumer向けの
D2Hを当面維持しながら、反復H2Dを削減することです。第二候補は`work2_`をdevice上で
直接生成してline 1913のbulk H2Dを削減することです。

## Step 28: predictor-corrector区間でのCOEF常駐化

Step 27で特定したTMEVL entryの反復H2Dを削減するため、`COEF`と、その反復開始値を
保持する`COEF0`のdevice mappingをFRPRMNのpredictor-corrector区間へ移しました。
各補正反復の`COEF0`から`COEF`への復元はdevice上で実行します。TMEVL終了時のD2Hは、
直後のhost側`RHOOFK`および`SUMCHR`が`COEF`を読むため維持しています。CPU/FFTW
fallbackでは従来のhost `coefcp`経路を変更せず、フルリンクがPASSしました。

実装commitは`c3552af` (`Keep TDDFT coefficients resident across corrections`)です。
diagnostic OFF、1 GPU / 1 MPI rank、100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_01` | 129.075486183 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_02` | 127.753921986 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP28_COEF_RESIDENT_03` | 129.260547161 | PASS | PASS |

3回中央値は`129.075486183`秒です。Step 25中央値`130.607889175`秒より約1.173%
速く、rollback後のStep 18中央値`161.753436089`秒より約20.202%高速です。実行間の
幅は約1.507秒で、全runの通常checkとrelaxed compareがPASSしました。

run 01では、`tmevl_p_enter`がStep 25 run 01の`2.925959`秒から`0.001273`秒へ
ほぼ消失しました。`tmevl_total`も`61.235540`秒から`58.329469`秒へ約4.745%
短縮しました。`tmevl_p_exit`は`2.825121`秒で、意図どおりhost consumer向けD2Hを
維持しています。数値結果を保ちながら反復H2Dを削減できたため、Step 28を正式採用
します。次の候補は、Step 27で第二候補だったnonlocal `work2_`のdevice直接生成です。

## Step 29: resident COEF0のdevice初期化（不採用）

Step 28では各FRPRMNの最初に`COEF`と`COEF0`をcopyinしていました。Step 29では
`COEF0`をdevice上でcreateし、転送済み`COEF`からGPU kernelで初期化することで、
各FRPRMNにつき1本のH2Dをdevice内コピーへ置き換えました。補正反復の復元方法、
TMEVL後のD2H、数式およびloop順序は変更していません。実装commitは`94e0e0e`
(`Initialize resident coefficient backup on device`)です。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP29_COEF0_D2D_01` | 130.160923958 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP29_COEF0_D2D_02` | 129.451672077 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP29_COEF0_D2D_03` | 130.183923006 | PASS | PASS |

3回中央値は`130.160923958`秒で、Step 28中央値`129.075486183`秒より約0.841%
遅い結果です。全runの通常checkとrelaxed compareはPASSしましたが、削減した初期
H2Dは追加のdevice copy kernelを含むwall改善につながりませんでした。このため
Step 29は不採用とし、commit `bd53a88` (`Restore accepted Step28 coefficient mapping`)
でStep 28方式へ戻しました。rollback後のCPU/FFTW fallbackフルリンクはPASSしました。

## Step 30: Step 28採用コードのNsight Systems再診断

Step 28採用コードをNsight Systems 2026.2.1で再計測しました。archive labelは
`nvhpc_cufft_1rank_02_STEP30_NSYS_01`、source revisionは`1f5d474`です。trace時wall
`133.093063116`秒はbaselineには使用しません。Nsight由来の単独stderr行を除外した
`tddft.out`単独の通常checkとrelaxed compareはともにPASSしました。以後の診断では
commit `21c084a`がraw stderr検証結果を保存しつつ、この既知artifactを誤FAILにしません。

| operation | count | total size | device time |
|---|---:|---:|---:|
| H2D | 72,486 | 46,225.769 MB | 62.951 sec |
| D2H | 35,453 | 30,054.575 MB | 39.972 sec |

Step 27比でH2Dは744回、7,898.515 MB、約15.280秒減少しました。D2Hのcountと総量は
不変です。OpenACC上位項目から旧TMEVL `P` entryは消え、代わりにFRPRMN line 1382の
caller所有mappingが100回、約1.247秒、対応する200 uploadが約1.235秒となりました。
これによりStep 28のP/COEF H2D削減がNsight上でも確認できました。

最大の残存反復uploadは、line 1914の`work2_` update 4,720回、約4.184秒と、その
enqueue upload約3.745秒です。TMEVL exitのD2Hも944回、約2.892秒、対応するdownload
約2.882秒残っています。次の実装候補は`work2_`直接生成ですが、YLM・VPJ・EXTAUの
入力転送量を増やさない構成に限定して検討します。

## Step 31: TMEVL kinetic stages間でのGDUMP mapping再利用（不採用）

Step 31では、`exkin_`呼び出しごとに行っていた`GDUMP`の`copyin`を外側へ移し、
`TMEVL`の4次分解区間で`GDUMP1..5`を1回mappingして5つのkinetic stageから
`present`参照する実験を行いました。理論上のmapping回数は9,440回から4,720回へ
減ります。数式、演算順序、配列shape、`ia`更新順序は変更していません。実装commitは
`f8b6188` (`Reuse GDUMP mappings across TMEVL kinetic stages`)です。

diagnostic OFF、NVHPC + OpenACC + cuFFT、1 GPU / 1 MPI rank、A100-PCIE-40GB、
Si111-H 100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_01` | 129.635676146 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_02` | 128.958827972 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP31_GDUMP_REUSE_03` | 129.250354052 | PASS | PASS |

3回中央値は`129.250354052`秒です。正式Step 28中央値`129.075486183`秒より
`0.174867869`秒、約`0.1355%`遅く、実行間の幅は`0.676848174`秒でした。
全runで通常checkとrelaxed compareはPASSしましたが、正式baselineに対する性能優位を
確認できないためStep 31は不採用です。

run 01では、`tmevl_gdump_enter`が944回、`0.294118`秒、
`tmevl_gdump_exit`が944回、`0.002970`秒、`exkin_acc_kernel`が9,440回、
`0.348747`秒、`tmevl_total`が`57.794941`秒でした。GDUMP mapping境界の変更は
正しく動作しましたが、約`0.297088`秒のTMEVL単位enter/exitを含め、wall中央値の
改善にはつながりませんでした。

commit `8ef55bb` (`Revert "Reuse GDUMP mappings across TMEVL kinetic stages"`)で
Step 31のソース変更だけをrollbackし、正式なStep 28方式へ戻しました。次の実験でも
Step 28中央値`129.075486183`秒を性能baselineとして使用します。

## Step 32: TMEVL後の密度再構築timer

Step 32は、Step 30で残っていたTMEVL終了時の係数D2Hの次に実行されるhost処理を
分解する計測stepです。`RHOOFK`、条件付き`SUMCHR`、`RHOGET`をそれぞれ
`frprmn_rhoofk`、`frprmn_sumchr`、`frprmn_rhoget`で囲みました。数式、OpenACC
data clause、FFT経路は変更していません。実装commitは`13f9e98`
(`Measure post-TMEVL density rebuild costs`)です。

diagnostic OFF、NVHPC + OpenACC + cuFFT、1 GPU / 1 MPI rank、A100-PCIE-40GB、
Si111-H 100 stepのrun 01は次の結果でした。

```text
archive: nvhpc_cufft_1rank_02_STEP32_DENSITY_TIMERS_01
wall_sec: 129.658223152
check: PASS
relaxed compare: PASS
frprmn_rhoofk: count 472, 14.509684 sec
frprmn_rhoget: count 472, 0.440581 sec
tmevl_p_exit: count 944, 2.819788 sec
```

`NPFL=0`のため`frprmn_sumchr`はactive timerに現れませんでした。密度再構築の
計測合計は約`14.950265`秒で、その大半を`RHOOFK`が占めます。したがって次の実装
候補は、residentな`COEF`からdevice上でcharge densityを生成し、各TMEVLの
`tmevl_p_exit`を避ける経路です。Step 32は計測runであり、正式性能baselineは
引き続きStep 28中央値`129.075486183`秒です。

## Step 33: TMEVL後charge-density FFTのbatch化

Step 33では、初期密度用の`RHOOFK`は変更せず、TMEVL後の密度再構築だけを新しい
`RHOOFK_ACC_BATCH`へ切り替えました。predictor-corrector区間でresidentな`COEF`を
device上でscatterし、local bandを1回のbatched cuFFTで変換し、occupation付き密度を
device上でband順に集約します。MPI reductionに必要なlocal densityだけをhostへ戻し、
従来のfull coefficient D2Hは効果分離のため維持しました。CPU/FFTW fallbackでは
batch entryが従来のband順でscalar FFTWを呼び、フルリンクがPASSしました。

実装commitは`b2a43c9` (`Batch post-TMEVL charge-density FFTs`)です。
diagnostic OFF、NVHPC + OpenACC + cuFFT、1 GPU / 1 MPI rank、A100-PCIE-40GB、
Si111-H 100 stepで3回測定しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_01` | 116.124675989 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_02` | 117.093669176 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP33_RHOOFK_BATCH_03` | 115.763577938 | PASS | PASS |

3回中央値は`116.124675989`秒です。Step 28中央値`129.075486183`秒より
`12.950810194`秒、約`10.0335%`高速で、実行間の幅は`1.330091238`秒でした。
全runで通常checkとrelaxed compareがPASSしたため、Step 33を正式採用し、新しい
性能baselineとします。

run 01では`frprmn_rhoofk`がStep 32の`14.509684`秒から`0.729800`秒へ約94.97%
短縮しました。`fft_wrapper`は43,949回、`13.369605`秒から14,685回、`3.402723`秒へ
減少しました。`tmevl_total`は`58.338570`秒でほぼ不変、意図的に残した
`tmevl_p_exit`は944回、`2.880805`秒でした。次の独立仮説は、host consumerを確認した
上で、このfull coefficient D2Hをpredictor-corrector終了時まで繰り延べることです。

## Step 34: predictor-corrector間のcoefficient D2H繰延べ

Step 34ではTMEVLごとの`COEF` host同期を削除し、deviceを正本として維持します。
最終time stepのexpectation計算、`NPFL!=0`時の`SUMCHR`、またはFRPRMN終了のうち、
最初にhost COEFが必要となる境界だけで同期します。device上の補正restart、数式、
FFT経路、`ia`更新順序は変更していません。同期時間を`frprmn_coef_sync`で計測します。
実装commitは`83a030c` (`Defer coefficient downloads across corrections`)で、
CPU/FFTW fallbackのフルリンクもPASSしました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_01` | 113.896168210 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_02` | 113.491595984 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP34_COEF_D2H_DEFER_03` | 113.561361074 | PASS | PASS |

3回中央値は`113.561361074`秒です。Step 33中央値`116.124675989`秒より
`2.563314915`秒、約`2.2074%`高速で、実行間の幅は`0.404572226`秒でした。
全runで通常checkとrelaxed compareがPASSしたため、Step 34を正式採用し、新しい
性能baselineとします。Step 28比では約`12.0194%`高速です。

run 01では`frprmn_coef_sync`が103回、`0.638588`秒となり、944回だった
`tmevl_p_exit`はprofileから消えました。`tmevl_total`はStep 33 run 01の
`58.338570`秒から`55.375345`秒へ短縮しました。次はStep 34採用コードをNsight
Systemsで再診断し、D2H削減量と残る反復H2Dの優先順位を更新します。

## Step 35: Step 34採用コードのNsight Systems再診断

Step 34採用ソースrevision `7567ae83e520a79e480ee6eaaa83842526938465`を
Nsight Systems 2026.2.1で計測しました。archive labelは
`nvhpc_cufft_1rank_02_STEP35_NSYS_01`です。trace wallは
`116.000924826`秒ですが、診断runなので性能baselineには使用しません。通常checkと
relaxed compareはいずれもPASSしました。

H2Dは44,166回、`32,307.014` MB、約`5.026`秒、D2Hは5,348回、
`5,592.769` MB、約`0.831`秒でした。Step 30比ではH2Dが28,320回、
`13,918.755` MB減少し、D2Hが30,105回、`24,461.806` MB減少しました。
これによりSteps 33–34の密度FFT batch化とcoefficient D2H繰延べの効果を確認しました。

最大のGPU kernelは`exnlp_gemm_body_fused_2387_gpu`で、9,440回、約`8.303`秒、
CUDA kernel時間の66.5%でした。最大の反復uploadは引き続きline 1913の`work2_`
updateで、4,720回、OpenACC summary上で約`3.728`秒、そのうちenqueue uploadが
約`1.264`秒です。ただし`work2_`のdevice直接生成はYLM、VPJ、EXTAUのmappingを
必要とし、B1 ownership実験の大幅悪化とStep 20の細粒度copy失敗があるため、
producer入力転送を増やさない所有境界を確認するまで高リスク候補として扱います。
正式性能baselineはStep 34中央値`113.561361074`秒のままです。

## Step 36: nonlocal staging列の実使用幅化

Step 36では、`work2_`のleading dimensionを固定上限`NGcont`からactive atom typeの
最大`NGNL`へ縮小しました。各projector列は従来と同じhost loopで同じ値を生成し、
転送回数、数式、reverse phaseの再利用、逐次`ia`更新順序は変更していません。
実装commitは`24e1cc3` (`Right-size nonlocal staging columns`)で、CPU/FFTW
fallbackのフルリンクもPASSしました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_01` | 113.023494005 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_02` | 113.083628893 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP36_WORK2_RIGHTSIZE_03` | 113.681638956 | PASS | PASS |

3回中央値は`113.083628893`秒で、Step 34中央値より`0.477732181`秒、約`0.4207%`
高速です。実行間の幅は`0.658144951`秒で、全runの通常checkとrelaxed compareが
PASSしました。run 01では`exnlp_work1_enter`がStep 34 run 01の`4.040431`秒から
`3.759735`秒へ約`6.947%`短縮し、`s2_nonlocal`も`14.055285`秒から
`13.758056`秒へ約`2.115%`短縮しました。Step 36を採用し、正式性能baselineを
`113.083628893`秒へ更新します。

## Step 37: dynamic host allocationのpinned memory化

Step 37では、NVHPC 26.5の`-gpu=mem:separate:pinnedalloc`をTDDFTのOpenACC +
cuFFTビルドへ追加しました。host/deviceのseparate memory方式と既存data clauseは
維持し、動的に確保されるhost配列だけをCUDA pinned memoryへ配置します。
`tools/build_nvhpc.sh`では`ENABLE_PINNED_ALLOC=1`で有効化し、defaultはOFFです。
build-mode commitは`9cbb6bc` (`Add optional pinned allocation build mode`)です。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_01` | 108.676812287 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_02` | 107.854416847 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP37_PINNED_ALLOC_03` | 108.096301079 | PASS | PASS |

3回中央値は`108.096301079`秒で、Step 36中央値より`4.987327814`秒、約`4.4103%`
高速です。実行間の幅は`0.822395440`秒で、全runの通常checkとrelaxed compareが
PASSしました。run 01では`exnlp_work1_enter`が`3.759735`秒から`1.542147`秒、
`s2_nonlocal`が`13.758056`秒から`11.489188`秒、`tmevl_total`が`55.183834`秒から
`51.654634`秒へ短縮しました。Step 37を正式採用し、新baselineを
`108.096301079`秒とします。次はこのbuild条件でNsight Systemsを再取得します。

## Step 38: pinned allocation採用buildのNsight Systems再診断

Step 37採用buildをrevision `643e639d45a163499a71355ecee33d7dba8466a3`で
Nsight Systems 2026.2.1により計測しました。archive labelは
`nvhpc_cufft_1rank_02_STEP38_PINNED_NSYS_01`、trace wallは`110.78916502`秒です。
診断runなのでbaselineには使用しません。通常checkとrelaxed compareはPASSしました。

H2Dは44,166回、`31,234.025` MB、`1.272192545`秒、D2Hは5,348回、
`5,592.769` MB、`0.440373299`秒でした。Step 35比でH2D時間は`74.6861%`、
D2H時間は`46.9758%`短縮しました。copy回数は変わらず、H2D量の`3.3212%`減少は
主にStep 36の`work2_`実使用幅化によるものです。`work2_` OpenACC updateは
4,720回、`3.728488477`秒から`1.617571795`秒へ`56.6159%`短縮しました。

最大kernelの`exnlp_gemm_body_fused_2399_gpu`は9,440回、`8.311268224`秒、
CUDA kernel時間の66.6%でした。Step 35の正しい値`8.302662687`秒との差は
`+0.1036%`で実質不変です。従来資料のStep 35 `5.830`秒は画像転記誤りだったため、
本stepで`8.303`秒へ訂正しました。pinned host poolの初期化では
`cuMemHostAlloc`が1回、`0.273495492`秒でした。次は転送ownershipではなく、この
fused kernelのresource/occupancyを確認してから独立仮説を設計します。

## Step 39: fused nonlocal kernelのNsight Compute診断

Step 37採用buildの`exnlp_gemm_body_fused_2399_gpu`をNsight Compute 2026.1.0で
1 launchだけ計測しました。archive labelは
`nvhpc_cufft_1rank_02_STEP39_FUSED_NCU_01`、入力は2-step版です。診断時wallは
`11.1839032173`秒で、通常checkはPASSしました。2-step診断でありrelaxed compareを
実施していないため、correctnessまたはwall-time baselineの代替には使用しません。
root実行時のGit safe-directory制約によりmanifestの`git_revision`は空欄でしたが、
対象はStep 37採用buildで、ソース式と実行順序は変更していません。

対象kernelはblock size 256、grid size 32、register 63/threadでした。A100の108 SMに
対してwaves/SMは`0.07`、theoretical occupancyは`50.0%`でしたが、achieved occupancyは
`12.5%`、achieved active warps/SMは`8.0`でした。Compute (SM) throughputは`4.27%`、
memory throughputは`16.35%`、DRAM throughputは`0.45%`、1 launchのdurationは
`915.52 us`です。L1/TEX hit rateは`84.31%`でした。

Nsight Computeは、32 blockしか生成されず108 SMを満たさないlaunch形状を第一の
制約として報告しました。また、global load/storeで平均`15.5 / 32` byte/sector、
約51%のexcess sectorと、平均14.3 cycle中約7.1 cycleのscoreboard待ちも報告しました。
ただしStep 26の同一kernel `vector_length(512)`は既に3回中央値で不採用なので、単純な
block拡大は再試行しません。register制限だけを緩和しても32 blockというgrid上限は
変わりません。一方、この32 bandsは運用上想定する最小規模であり、これより小さい
入力を対象にしないため、小band専用のmulti-gang経路は追加しません。band数が増えれば
現行の1 gang/band経路は自動的にgridを拡大します。Step 39の低occupancyはtutorial固有の
下限特性として扱い、次は中・大規模データで同じkernelのscalingを確認してから、複数
規模に共通するボトルネックだけを最適化します。正式baselineはStep 37の
`108.096301079`秒を維持します。

## Step 40: fused nonlocal kernelの方向別特殊化（不採用）

実装commit `ea81633`では、fused nonlocal kernelをforward用とreverse用のroutineへ
分割し、projectorごとの方向分岐を除去しました。forward/reverseそれぞれの逐次`ia`
更新順序は維持し、A100検証前のCPU/FFTW fallback full linkもPASSしました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_01` | 107.751713037 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_02` | 107.828091860 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP40_DIRSPEC_03` | 107.690500021 | PASS | PASS |

diagnostic OFFの3回中央値は`107.751713037`秒、実行間の幅は`0.137591839`秒で、
Step 37中央値に対する見かけの改善は`0.344588042`秒、`0.3188%`でした。一方、
変更対象の`exnlp_gemm_dot`中央値は`8.545724`秒でStep 37 run 01より`1.2310%`悪化し、
`s2_nonlocal`中央値も`11.571148`秒で`0.7134%`悪化しました。`tmevl_total`中央値は
`51.656927`秒で実質不変です。

全runのcorrectnessはPASSしましたが、狙ったtimerが一貫して悪化し、1%未満のwall差を
裏付けません。forward/reverseの重複実装は効果に見合わないためStep 40を不採用とし、
実装`ea81633`を`0726e26`でrevertしました。rollback後のCPU/FFTW fallback full linkは
PASSし、正式baselineはStep 37中央値`108.096301079`秒を維持します。

## Step 41: 静的metadataのtime-step loop外resident化

実装commit `4aaa33c`では、time-step loop中に読み取り専用の`J2G`と`OCC`を
loop外でdeviceへcopyinし、S2とbatched RHOOFK内の反復`copyin`を`present`へ
変更しました。数式、kernel loop、配列shape、逐次`ia`更新順序は変更していません。
CPU/FFTW fallback full linkと独立reviewはPASSしました。

最初のarchive `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_01`は通常checkと
relaxed compareにPASSしましたが、`115.517135143`秒でした。標準manifestに
revisionとbuild flagがなく、明示的な再buildより前のprovenance異常runとして記録を
残し、正式3回系列には含めません。diagnostic OFF、NVHPC OpenACC + cuFFT、
`-gpu=mem:separate:pinnedalloc`で再build後の結果は以下です。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_02` | 107.783477068 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_03` | 107.718405008 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP41_STATIC_METADATA_04` | 107.754213095 | PASS | PASS |

3回中央値は`107.754213095`秒、実行間の幅は`0.065072060`秒です。Step 37中央値
より`0.342087984`秒、`0.3165%`高速でした。run 02の`frprmn_rhoofk`は
`0.528846`秒でStep 37 run 01より約`5.19%`短縮し、`s2_nonlocal`の
`11.489951`秒と`exnlp_gemm_dot`の`8.441246`秒は実質不変でした。

source上では、S2の`J2G` 4,720回、RHOOFKの`J2G` 472回と`OCC` 472回の
copyinをloop外の2回へ置き換え、最大5,662回の反復H2D削減となります。実際のcopy
回数は今後Nsight Systemsで再確認できます。全正式runのcorrectnessがPASSし、
中央値も改善し、time-step loop内転送削減という最終目的へ直接寄与するため、
Step 41を採用し、正式baselineを`107.754213095`秒へ更新します。

## 2026-07-17 進捗報告用概要

FPSEID21 TDDFTでは、NVHPC OpenACCとcuFFTを用いたGPU化を段階的に進めています。
初期段階ではFFT backendをCPU FFTWからcuFFTへ移行し、その後、バンドごとに個別実行
していたS2 local FFTをlocal band数`nbndloc`単位のBatched cuFFTへ変更しました。
tutorialの1 MPI rank実行では`nbndloc=32`なので、32 bandsを1 batchとして処理します。
さらに、TMEVL後のcharge-density再構築もlocal bandsをまとめたBatched cuFFTとdevice上の
密度加算へ変更しました。

FFT以外では、nonlocal projector、運動エネルギー、密度再構築などの主要演算をGPUへ移し、
`COEF`、作業配列、`J2G`、`OCC`などのdevice residencyを延長してきました。現在は、
time-step loop内で繰り返される大規模配列転送をloop外の最小回数へ移す方針で、Step 42の
`Vloc` residencyをStep 42で検証しました。correctnessは全runでPASSしましたが、性能優位が
なかったため不採用です。以下の正式baselineはStep 41のままです。

### GPU化の代表的な性能推移

Si111-H、100 TDDFT time steps、1 MPI rankの代表値です。

| 構成・段階 | 100-step時間 (sec) | 位置付け |
|---|---:|---|
| NVHPC CPU FFT | 567.725 | 初期CPU FFT比較値 |
| 初期cuFFT backend | 496.290 | CPU FFT比12.6%短縮 |
| Step 21: S2 local FFT Batched化 | 146.540076017 | 正式採用値 |
| Step 33: charge-density FFT Batched化 | 116.124675989 | 正式採用値 |
| Step 37: pinned dynamic allocation | 108.096301079 | 正式採用値 |
| Step 41: static metadata residency | **107.754213095** | 現在のA100正式baseline |

Step 41はA100-PCIE-40GB、1 GPU / 1 MPI rank、diagnostic OFFでの3回中央値で、
全runが通常checkとrelaxed compareにPASSしています。初期cuFFT値からは約78.3%、
初期NVHPC CPU FFT値からは約81.0%短縮しました。

### Intel、GPU、NEC VE3の参考比較

| 環境 | 100-step時間 (sec) | Intel 8592+比 | 扱い |
|---|---:|---:|---|
| Intel Xeon Platinum 8592+ | 378.317744 | 1.00x | CPU版の記録値 |
| NVIDIA A100-PCIE-40GB | 107.754213095 | 3.51x | 正式3回中央値 |
| NVIDIA H100 | 59.0654609203 | 6.41x | 単発参考値、check・relaxed compare PASS |
| NEC VE3 | 21.83691485 | 17.32x | 信頼済みVE向けコードの単発参考値 |

VE3はA100正式baselineに対して単純時間比で約4.93倍高速でした。VE3値は、信頼済みの
VE向けコードと実行方法による参考性能として記録します。GPU版用のGNU referenceと
検査toolをそのまま適用すると、`FPSEID_PROFILE` block欠落に加えてforceとpositionsが
既定toleranceを超えるため、GPU版のcorrectness baselineや正式性能baselineには使用しません。

Intel、A100、H100、VE3はhardware、compiler、最適化経路、測定系列が異なります。
この表は異種architecture間の傾向を示す参考比較であり、A100内の採否判断には引き続き
同一条件のdiagnostic OFF 3回中央値だけを使用します。

## Step 42: VlocのFRPRMN correction間resident化（不採用）

実装commit `d56815e`では、FRPRMN predictor-corrector sequenceの先頭で
`Vloc(:,1:5)`をdeviceへcopyinし、S2 local potential領域の反復`copyin`を
`present`へ変更しました。数式、配列shape、kernel loop、逐次`ia`更新順序は
変更していません。A100検証前のCPU/FFTW fallback full linkと独立reviewはPASSしました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_01` | 107.732875109 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_02` | 107.809727907 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP42_VLOC_RESIDENT_03` | 107.831543922 | PASS | PASS |

diagnostic OFFの3回中央値は`107.809727907`秒、実行間の幅は`0.098668813`秒です。
Step 41中央値より`0.055514812`秒、`0.0515%`遅い結果でした。全runの通常checkと
relaxed compareはPASSし、source上の転送境界は意図どおり変更されましたが、性能優位は
ありません。転送profileも未取得でruntime上の追加効果を裏付けられないため、Step 42を
不採用とし、正式baselineはStep 41中央値`107.754213095`秒を維持します。
実装`d56815e`は`afa1678`でrevertし、rollback後のCPU/FFTW fallback full linkは
PASSしました。

## Step 43: ELECTF host領域のtimer分解

診断commit `e90c80a`では、`ELECTF`を`LOCPOTF`と`NONLOCF`へ分け、さらに
`NONLOCF`内をhost `COEF`のkinetic/current計算と、`GETYLM`＋`SEPPOTF`の
projector計算へ分けました。数式、loop、MPI、OpenACC同期は変更していません。

archive `nvhpc_cufft_1rank_02_STEP43_ELECTF_TIMERS_01`は通常checkとrelaxed
compareにPASSし、診断wallは`107.821303844`秒でした。単発診断なのでwallは
正式baselineに使用しません。

| timer | count | sec | ELECTF比 |
|---|---:|---:|---:|
| `electf_force` | 101 | 9.012769 | 100% |
| `electf_locpotf` | 101 | 4.071556 | 45.1754% |
| `electf_nonlocf` | 101 | 4.939849 | 54.8094% |
| `nonlocf_coef_kin_mpi` | 202 | 0.846204 | 9.3896% |
| `nonlocf_projector_mpi` | 202 | 4.091718 | 45.3991% |

`NONLOCF`内では`GETYLM`＋`SEPPOTF`区間が`82.8308%`を占めました。inner timerが
202回なのは、各`ELECTF`で2 k pointsを処理するためです。次はこの4.091718秒を
`GETYLM`と`SEPPOTF`へ分離してから、GPU化対象を1件に絞ります。

## Step 44: NONLOCF projector領域のtimer分解

archive `nvhpc_cufft_1rank_02_STEP44_NONLOCF_TIMERS_01`は通常checkとrelaxed
compareにPASSし、診断wallは`108.715013981`秒でした。timer付き単発診断のため、
正式性能値には使用しません。

| timer | count | sec | projector比 |
|---|---:|---:|---:|
| `nonlocf_projector_mpi` | 202 | 4.092541 | 100% |
| `nonlocf_getylm` | 202 | 0.009894 | 0.2418% |
| `nonlocf_seppotf` | 202 | 4.068364 | 99.4092% |

`SEPPOTF`は`NONLOCF`の`84.0486%`、`ELECTF`全体の`45.6432%`を占めます。
次の1テーマは、数式順序、MPI境界、CPU fallbackを維持した範囲でのSEPPOTFの
限定GPU化とCOEF/data ownership確認です。正式baselineはStep 41中央値
`107.754213095`秒のままです。

## Step 45: COEF device allocationのtime-step間維持（不採用）

実装`da24adf`では、COEFのdevice allocationをtime-step loop全体へ延長し、
次stepのFRPRMNでのCOEF H2D copyin削減を狙いました。ELECTF前のD2H、COEF0の
predictor-corrector単位ownership、SEPPOTF、MPI、数式順序は変更していません。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_01` | 108.508744955 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_02` | 108.782176018 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP45_COEF_RESIDENT_03` | 111.340812922 | PASS | PASS |

3回中央値は`108.782176018`秒、実行間の幅は`2.832067967`秒です。Step 41より
`1.027962923`秒（`0.9540%`）遅く、性能優位がありません。想定したH2D削減は
Nsight Systemsで未確認です。Step 45は不採用とし、正式baselineはStep 41中央値
`107.754213095`秒を維持します。実装`da24adf`は`c406a4a`でrevertし、rollback後の
CPU/FFTW fallback full linkはPASSしました。

## Step 46: SEPPOTF data ownership診断

診断実装`edfafed`と実行保証commit `3e2c630`では、FRPRMNからELECTFまでCOEFの
device lifetimeを延長し、NONLOCFの親配列をk-point loop外でmappingしました。
SEPPOTFではtutorialのs/p projectorに必要なdummy sectionをno-op serial kernelの
`present`節で検証し、projector数式自体は変更していません。

archive `nvhpc_cufft_1rank_02_STEP46_OWNERSHIP_01`は100 stepsを
`107.869318008`秒で実行し、通常checkとrelaxed compareにPASSしました。
present/partial-present errorとownership probe failureはありませんでした。このwallは
追加転送とserial probeを含む診断値なので性能baselineには使用しません。正式baselineは
Step 41中央値`107.754213095`秒のままです。次の1仮説は、tutorialで有効な
非partitioned s/p経路だけを1 gang/bandでGPU化し、その他を元のhost経路へ
完全fallbackさせる実装です。

## Step 47: tutorial非partitioned s/p SEPPOTF GPU化（不採用）

実装`0252da9`では、tutorialで使用する非partitioned s/p projectorのphaseと
band reductionを1 gang/bandのOpenACC kernelへ移しました。ITY、原子、s、pの
順序、MPI境界、FFTWおよび未対応shapeの完全host fallbackを維持しています。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_01` | 107.598769903 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_02` | 107.722885132 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP47_SEPPOTF_SP_ACC_03` | 107.848846912 | PASS | PASS |

中央値は`107.722885132`秒、実行幅は`0.250077009`秒です。Step 41より
`0.031327963`秒（`0.0291%`）速いだけで、差は実行幅より小さく、約250行の
専用経路に見合う性能優位ではありません。Step 47を不採用とし、正式baselineは
Step 41中央値`107.754213095`秒を維持します。

rollback `35f8542`でStep 47と完了済みStep 46診断sourceを除去し、対象sourceを
正式Step 41状態へ戻しました。rollback後のCPU/FFTW fallback full linkはPASSしました。

## Step 48-51: 正式Step 41再診断とFRPRMN分解

Step 48のNsight Systems再診断では、全MPI collectiveは`0.260338098`秒で、allocationも
無視できる量でした。Step 49-51のdefault-OFF timer分解により、`Part1to5`は
`36.306091`秒、そのうち`VPJ_GEN`のCPU動径積分が`36.132464`秒、MPIが
`0.037303`秒と確定しました。CPU演算と対応するGPU idleが支配要因です。

## Step 52: Part1to5 VPJ動径積分GPU化（採用）

実装`22aad92`は、`Part1to5`から呼ばれる`VPJ_GEN`動径積分だけをGベクトル間で
GPU並列化しました。各G内の動径積分順序、host MPI境界、TMEVLのCPU経路を維持し、
static pseudopotential表をtime-step loop全体でresident化しています。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_01` | 72.9733359814 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_02` | 73.4374880791 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP52_VPJGEN_ACC_03` | 73.4901540279 | PASS | PASS |

中央値は`73.4374880791`秒、実行幅は`0.5168180465`秒です。Step 41中央値より
`34.3167250159`秒（`31.8472%`）高速で、対象FRPRMN残差の大幅減少とも整合します。
Step 52を正式baselineとして採用します。次は追加最適化ではなく、正式Step 52 sourceを
Nsight Systemsで再計測し、残るkernel、転送、runtime/API、同期、MPI、GPU idleを
再分類します。trace wallは性能baselineに使用しません。

## Step 53: 正式Step 52 sourceのNsight Systems再計測

archive `nvhpc_cufft_1rank_02_STEP53_STEP52_NSYS_01`は通常checkとrelaxed
compareにPASSしました。診断wallは`76.0769960680`秒でbaselineには使用しません。
VPJ kernelは2,000回で`1.793293070`秒、CUDA kernel合計は約`14.26`秒、trace wall比
約`18.7%`でした。H2Dは38,564回・`30,745.626` MB・`2.565299787`秒、D2Hは
7,348回・`5,846.065` MB・`0.466224230`秒です。

FRPRMN残差は`13.608745`秒で、VPJ kernelを除く約`11.815452`秒にCPU/host処理と
未分解waitが残ります。MPI reportは空でしたが、Step 48全MPI上限`0.260338098`秒と
Step 51 VPJ MPI `0.037303`秒から主因ではありません。stream/event同期の全trace合計は
`17.613188385`秒、VPJ固有OpenACC waitは`1.816791731`秒です。次は最適化ではなく、
残るFRPRMN host envelopeを既存timer外の制御、energy/reduction、density、updateへ
分けるStep 54 default-off診断です。

## Step 54-57: FRPRMN残差診断とLOCPOT GPU化（採用）

Step 54はFRPRMN残差の`99.9251%`を粗粒度timerで説明し、Step 55はVRHOの
`72.0600%`をhost control、Step 56はVlocの`93.8149%`をLOCPOTと特定しました。
Step 57実装`8646707`は、各G内のITY/K/IA順とhost MPI境界を維持してLOCPOTだけを
Gベクトル間でGPU並列化しました。

| archive label | wall_sec | check | relaxed compare |
|---|---:|---|---|
| `nvhpc_cufft_1rank_02_STEP57_LOCPOT_ACC_01` | 71.2373509407 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP57_LOCPOT_ACC_02` | 71.2909028530 | PASS | PASS |
| `nvhpc_cufft_1rank_02_STEP57_LOCPOT_ACC_03` | 71.3753330708 | PASS | PASS |

中央値は`71.2909028530`秒、実行幅は`0.1379821301`秒で、Step 52より`2.9230%`
高速です。FRPRMN中央値は`2.117284`秒、FRPRMN残差は`2.660213`秒減りました。
Step 57を正式baselineとして採用します。次は正式Step 57 sourceのNsight Systems
再診断であり、追加最適化はその分類後に選びます。

## Step 58: 正式Step 57 sourceのNsight Systems再診断

archive `nvhpc_cufft_1rank_02_STEP58_STEP57_NSYS_01`は通常checkとrelaxed
compareにPASSしました。診断wallは`74.2175440788`秒でbaselineには使用しません。
CUDA kernel合計は約`14.29`秒、fused kernelは`8.304842909`秒、VPJ kernelは
`1.793326009`秒で、Step 53から大きく変わっていません。

H2Dは45,320回・`31,590.245` MB・`2.749026591`秒、D2Hは7,954回・
`6,127.482` MB・`0.490787616`秒でした。Step 53比の増分はH2D 6,756回、D2H
606回で、D2H増分はLOCPOT 6回×FRPRMN 101回と一致します。転送時間増加は合計
`0.208290190`秒に留まり、MPI reportは空でした。

LOCPOT kernelは写真に表示された集計行から独立同定できませんでした。次は追加最適化
ではなく、既存default-off timerで現行LOCPOT全区間を直接測るStep 59診断です。

## Step 59: 現行LOCPOT全区間の直接計測

archive `nvhpc_cufft_1rank_02_STEP59_LOCPOT_TIMERS_01`は通常checkとrelaxed
compareにPASSしました。診断wallは`71.1150200367`秒でbaselineには使用しません。
Vloc parentは`0.484717`秒、LOCPOTは`0.305052`秒、smoothing/FFTは`0.151038`秒、
その他は`0.028627`秒でした。

Step 56比でLOCPOTは`2.459933`秒（`88.9673%`）、Vloc全体は`2.462559`秒
（`83.5537%`）削減されました。LOCPOTは現行FRPRMN残差の`2.8533%`に低下し、
Step 57の改善要因を直接確認できました。次はVRHO host controlをseed、predictor、
correctorへ分けるStep 60診断であり、追加最適化ではありません。

## Step 60: VRHO host controlの分解

archive `nvhpc_cufft_1rank_02_STEP60_VRHO_CONTROL_01`は通常checkとrelaxed
compareにPASSしました。診断wallは`70.9675290585`秒でbaselineには使用しません。
VRHO control `2.787119`秒のうち、seed/coefficient-copyは`0.552540`秒、
predictor/extrapolationは`0.016408`秒、corrector/interpolation/convergenceは
`2.215861`秒でした。子区間は親の`99.9171%`を説明します。

correctorはVRHO controlの`79.5036%`、現行FRPRMN残差の`20.7787%`です。次は
correctorをinterpolation、VGCONV、COEF/VGOLD復元へ分けるStep 61診断であり、
追加最適化ではありません。

## Step 61: VRHO correctorの分解

archive `nvhpc_cufft_1rank_02_STEP61_VRHO_CORRECTOR_01`は通常checkとrelaxed
compareにPASSしました。診断wallは`71.7462480068`秒でbaselineには使用しません。
corrector parent `2.240276`秒のうち、interpolationは`0.057358`秒、VGCONVは
`0.014480`秒、失敗補正後のCOEF/VGOLD復元は`2.158536`秒でした。子区間は親の
`99.5580%`を説明し、復元は`96.3513%`を占めます。

OpenACCではCOEF/COEF0が補正列全体でdevice常駐し、次補正のCOEF復元もdevice-local
です。Step 62はGPU経路で不要なhost COEF0-to-COEF copyだけを省略し、VGOLD復元、
device復元、MPI、CPU fallbackを維持する単一性能仮説です。

## Step 62: 冗長なhost補正復元の省略

revision `7475ccb`のrun 01は通常checkとrelaxed compareにPASSしました。wallは
`68.66669352055`秒で、正式Step 57中央値より`2.62420933245`秒（`3.6810%`）短い値です。
ただし単発の予備結果であり、run 02/03を取得して3回中央値で採否を決めます。

run 02/03も両checkにPASSし、wallは`68.4877460003`秒と`68.5734798908`秒でした。
3回中央値は`68.5734798908`秒、実行幅は`0.17894752025`秒で、Step 57中央値より
`2.7174229622`秒（`3.811739%`）高速です。median-wall runのFRPRMN残差も
`2.103294`秒減り、計測した復元区間と整合するため、Step 62を正式採用します。

次は追加最適化ではなく、正式Step 62 sourceで既存の広域FRPRMN timerを再実行し、
現行残差を再分類するStep 63診断です。

Step 63は両checkにPASSし、FRPRMN残差`8.547452`秒の`99.5381%`を再分類しました。
最大は`part1to5=2.137278`秒（`25.0049%`）、次いでVRHO mix `1.801928`秒、
EXTAU準備`1.468457`秒です。次は既存timerで現行`part1to5`の子区間を再計測します。

Step 64は測定専用で、既存timerを使ってGETYLM、VPJ integral、MPI all-reduce、
post-reduction、親との差を分類してから実装を選びます。

Step 64は両checkにPASSしました。`part1to5=2.140208`秒の`97.8140%`を説明し、
legacy名VPJ integral区間が`1.910793`秒、MPIは`0.039413`秒でした。OpenACC時の
legacy区間はhost zeroing、VPP2 setup、GPU integral、D2H同期を含むため、Step 65で
追加最適化なしに分解します。

Step 65はhost VPJWORK/VPJ zeroing、VPP2 zeroing、OpenACC kernel＋必須D2Hの
default-off timerだけを追加し、演算とownershipは変更しません。

Step 65は両checkにPASSしました。legacy parentのうちOpenACC kernel＋D2Hは
`1.872989`秒（`97.5411%`）、hostとVPP2 zeroingの合計は`0.039393`秒でした。
host初期化省略は選ばず、Step 66で既存同期境界のkernel完了とD2Hを分けます。

Step 66はdefault-offのkernel-waitとD2H子timerだけを追加します。明示waitは診断buildの
既存同期境界だけに置き、production動作は変更しません。

Step 66は両checkにPASSしました。GPU kernel完了は`1.831545`秒（親の`97.0896%`）、
D2Hは`0.047825`秒でした。次はこのkernelだけのvector lengthを256から128へ変え、
radial加算順とownershipを維持する単一性能仮説です。

Step 67はこのparameter変更だけを実装し、Step 62中央値に対するdiagnostic OFF 3回gateで
採否を決めます。

run 01は両checkにPASSし、wallは`68.4441161156`秒でした。Step 62中央値比の改善は
`0.188650%`でbaseline実行幅より小さいため、run 02/03取得前には採否を決めません。

run 02/03も両checkにPASSしました。3回中央値は`68.3616518974`秒、実行幅は
`0.2041001320`秒でStep 62より`0.308907%`高速です。Step 67最遅runもStep 62最速run
より速く、実測範囲が重ならないためStep 67を正式採用します。

Step 68は同じ限定的launch-shape探索としてVPJ vector lengthだけを128から64へ変更し、
Step 67に対する標準3回gateで採否します。

run 01は両checkにPASSしましたが`68.7983009815`秒で、Step 67より`0.638734%`遅く
実行幅の2倍を超えて回帰しました。run 02/03は省略しStep 68を不採用、128へ戻します。

Step 69は現行EXTAU準備`1.468457`秒だけを対象とします。OpenACC時に5個の独立な位相表を
1個のdata領域内でGPU生成し、G21..G25とTAU1..TAU5の入力転送をまとめます。現行host
consumer用のEXTAU copyout、MPI、数式、CPU/FFTW loop、VPJ vector length 128は維持します。
初回は`tools/run_tddft_step69.sh 01`だけを実行します。

run 01は両checkにPASSしましたが`69.0177049637`秒で、Step 67中央値より
`0.6560530663`秒（`0.959680%`）遅く、正式実行幅の`3.2144`倍回帰しました。
FRPRMN残差は`0.546599`秒減りましたが全体wallは悪化したため、run 02/03は省略して
Step 69を不採用とし、host EXTAU経路へ戻します。次は復元後の現行sourceをNsight
Systemsで再診断します。

Step 70は両checkにPASSしました。trace wall `71.0379288197`秒はbaselineではありません。
CUDA kernel合計は約`13.96`秒（trace wallの`19.65%`）で、nonlocal fused kernelが
`8.247974033`秒（kernelの`59.1%`）、VPJ kernelが`1.574436754`秒（`11.3%`）でした。
H2D+D2Hは`3.230806864`秒、stream+event同期APIは重複を含む`17.372092065`秒、MPIは
空でした。最大kernelはStep 39で32-block制約を診断済みなので同形NCUは繰り返さず、
次は現行`frprmn_energy_diag`を分解します。

## Step 71-74: energy診断とNONLOC YLM再利用

Step 71-73のdefault-off timer診断は全て両checkにPASSしました。
`frprmn_energy_diag=0.871809`秒のうちexpectation/off-diagonalが
`0.809350`秒でした。さらに、対角HLOCAL `0.239888`秒、対角NONLOC
`0.299706`秒、off-diagonal `0.258875`秒へ分解しました。off-diagonal内の
通信/copyは`0.000005`秒で、主要部はHLOCAL `0.080938`秒、NONLOC
`0.099967`秒、行列内積`0.079395`秒でした。

Step 74はNONLOCのband非依存YLM準備を各k-point/eventの最初のbandだけへ集約し、
係数依存のkinetic DCOEFとSEPPOTは毎回維持します。3 runは全て両checkにPASSし、
wallは`68.1138920784`、`68.0681188811`、`68.0592751503`秒でした。中央値
`68.0681188811`秒はStep 67より`0.2935330163`秒（`0.429383%`）高速で、
実行幅は`0.0546169281`秒です。Step 74を新しい正式baselineとして採用します。

## Step 75-81: FRPRMN再分類とLDA交換相関loopのGPU化

Step 75-77で正式Step 74 sourceのFRPRMN残差、VRHO、VOFRHOを段階的に再分類しました。
VOFRHO `0.962422`秒のうち交換相関が`0.653802`秒で最大でした。Step 79ではGGA
G2VXC2子timerが全てinactiveとなり、このSi111-H入力がLDA S2VXC2経路を通ることを
確認しました。

Step 80は実行されるS2VXC2の独立格子点loopだけをOpenACC化し、RHOをcopyin、
VCSRをcopyoutしました。分岐、数式、caller FFT/Hartree、MPI、CPU/FFTW経路は
維持しています。3 runは全て両checkにPASSし、wallは`67.4321370125`、
`67.2197408676`、`67.4207620621`秒でした。中央値`67.4207620621`秒はStep 74より
`0.6473568190`秒（`0.951043%`）高速で、実行幅は`0.2123961449`秒です。
Step 80を新しい正式baselineとして採用します。

次は追加最適化ではなく、正式Step 80 sourceで既存の広域FRPRMN timerを再実行し、
改善後の残差を再分類するStep 81診断です。

Step 81は両checkにPASSしました。診断wall `68.5029249191`秒はbaselineではありません。
FRPRMN残差は`7.878776`秒で、`7.833973`秒（`99.4313%`）を既存の排他的timerで分類し、
未分類は`0.044803`秒でした。上位はPart1to5 `1.947618`秒、EXTAU準備
`1.448376`秒、VRHO `1.173977`秒、energy diagnostic `1.118869`秒です。
VRHOはStep 75の`1.799974`秒から`0.625997`秒（`34.7781%`）減り、Step 80の正式な
wall改善`0.6473568190`秒と整合しました。次の実装を選ぶ前に、同じarchive内のVRHOと
energy子timerを`tools/show_tddft_step81_detail.sh`で表示します。再build・再実行は不要です。

既存archiveの詳細ではVOFRHO `0.359571`秒のうち、XCは`0.063268`秒、最終FFT
`0.110018`秒、Hartree build `0.154377`秒でした。XCはStep 77比`0.590534`秒
（`90.3231%`）減り、次の対象ではありません。現在はVRHO control `0.657103`秒の方が
大きい状態です。energy `1.118869`秒のうちE-fieldは`0.248282`秒、expectationは
`0.778436`秒でした。E-fieldはStep 71で`0.004286`秒だったうえhost出力を含むため、
`tools/show_tddft_step81_detail.sh control`で同じarchiveの呼出回数とVRHO control子timerを
確認してから次の単一仮説を選びます。再実行は不要です。

control詳細ではseed初期化が`0.562341`秒でVRHO controlの`85.5773%`を占め、
predictorは`0.016313`秒、correctorは`0.076263`秒でした。Step 82はOpenACC時だけhostの
COEF→COEF0 seed copyとCOEF0 H2Dを省き、現行predictor-corrector data入口でCOEFを
copyin、COEF0をcreateしてdevice上で1回コピーします。区間寿命、補正restart、MPI、数式、
CPU/FFTW copyは維持するため、Step 45のtime-step全体COEF常駐とは異なります。まず
`tools/run_tddft_step82.sh 01`だけを実行します。

Step 82 run 01は両checkにPASSし、wallは`66.8839480877`秒でした。正式Step 80中央値より
`0.5368139744`秒（`0.796215%`）高速で、Step 81で測定したseed処理`0.562341`秒とも
近い結果です。ただし1 runだけではbaselineを更新せず、run 02/03を一括取得して
3 run中央値で採否を決めます。

run 02/03も両checkにPASSし、`66.6139972210`、`66.6539101601`秒でした。3 run中央値
`66.6539101601`秒、実行幅`0.2699508667`秒で、Step 80より`0.7668519020`秒
（`1.137412%`）高速です。全runが旧中央値より速いためStep 82を正式採用します。
次のStep 83は追加最適化ではなく、正式Step 82 sourceのVRHO seed/control timerを
再測定して改善箇所を確認します。

Step 83は両checkにPASSしました。seedは`0.000497`秒でStep 81比`99.9116%`減、
VRHO controlは`0.103696`秒、VRHO全体は`0.622439`秒となり、Step 82の高速化要因を
確認しました。次は同じarchiveから現行広域envelopeとenergy子timerを表示し、
再実行せずに次の単一仮説を選びます。

現行上位はPart1to5 `1.941613`秒、EXTAU `1.440404`秒、energy `0.847562`秒です。
Part1to5とEXTAUの単純GPU化は直後のhost consumer境界により既に回帰しました。
Step 84はenergy内NONLOCでband不変kinetic factorを一度RHOAへ格納して直後に読む
冗長host passだけをDCOEF更新へ融合します。ownership、MPI、HLOCAL、YLM再利用は
変更しません。3 run中央値は`66.7368218899`秒でStep 82より`0.124391%`遅く、
正しさは全runで確認できたものの性能利得がないため却下し、正式Step 82式へ戻しました。

次のStep 85は追加最適化ではなく、energy内HLOCALをzero、scatter、逆FFT、
局所ポテンシャル積、順FFT、gatherへ分解する診断です。現行の対角HLOCAL
`0.237196`秒と非対角HLOCAL `0.080948`秒のどこに次のGPU化余地があるか確認しました。
全768回の合計は`0.482563`秒で、FFT往復が`55.978%`、scatter/gatherが`32.770%`です。

Step 86ではHLOCALだけを一時device data regionへまとめ、zero、scatter、VG積、
gatherとcuFFT往復をGPU内で完結させます。CPU/FFTW経路は変更しません。

Step 86の3 runは全て両checkにPASSし、wallは`66.5019950867`、`66.6454100609`、
`66.3501911163`秒でした。中央値`66.5019950867`秒、実行幅`0.2952189446`秒で、
Step 82より`0.1519150734`秒（`0.22791%`）高速なため正式採用します。ソースコード
ベースのtime-step候補GPU化率は20/39=`51.3%`から24/39=`61.5%`になりました。
次のStep 87は追加最適化ではなく、採用済みdevice HLOCAL全体を1本の親timerで測り、
Step 85の旧`0.482563`秒からの減少量を確認します。

Step 87は両checkにPASSしました。device HLOCAL全768回は`0.247780`秒で、対角
`0.128030`、非対角`0.040771`、TMEVL由来`0.078979`秒です。Step 85のhost staged
`0.482563`秒から`0.234783`秒（`48.653%`）減り、Step 86の改善機序を直接確認しました。
次は同じarchiveからenergy階層を表示し、再実行せずに次の単一仮説を選びます。

同じStep 87 archiveのenergy expectationは`0.634219`秒でした。最大成分は対角
NONLOC `0.274122`秒と非対角NONLOC `0.090716`秒の合計`0.364838`秒（`57.53%`）です。
Step 84の単純kinetic pass融合は既に不採用なので、Step 88では追加最適化をせず、
NONLOC全呼出しをkinetic、YLM、SEPPOTへ分解します。

Step 88は両checkにPASSしました。全768回のNONLOC呼出しは、kinetic
`0.056220`秒（`10.325%`）、YLM `0.003207`秒（`0.589%`）、SEPPOT
`0.485064`秒（`89.086%`）でした。したがって、次の有意な候補はSEPPOTです。
Step 89では追加最適化を行わず、SEPPOTをEXTAU位相表生成とs/p/d/f軌道channelへ
分解し、支配channelを特定してから一箇所ずつGPU化を検討します。

Step 89は両checkにPASSしました。SEPPOT `0.547832`秒の分類内訳はEXTAU
`0.188158`秒（`36.414%`）、s channel `0.103150`秒（`19.963%`）、p channel
`0.225405`秒（`43.623%`）で、d/fはこの入力ではinactiveでした。Step 47で
tutorial専用s/p全体offloadは既に不採用なので再試行しません。Step 90は追加最適化を
せず、最大のp channelをprojector生成、係数reduction、DCOEF更新へ分解します。

Step 90は両checkにPASSしました。p channel `0.284428`秒の内訳はprojector生成
`0.095651`秒（`39.103%`）、係数reduction `0.069291`秒（`28.327%`）、DCOEF更新
`0.079670`秒（`32.570%`）でした。各子は9,216回呼ばれ、単独上限が`0.1`秒未満で
支配子もありません。個別kernel化はlaunch・同期負けの可能性が高いためSEPPOT経路を
閉じます。次は追加最適化ではなく、Steps 74/80/82/86後の正式Step 86 sourceを
Nsight Systemsで再診断し、現在のkernel・転送・同期・GPU idle構造を更新します。

Step 91は両checkにPASSしました。trace wall `69.98909358414`秒はbaselineではありません。
CUDA kernel合計は約`13.90`秒（trace wallの`19.86%`）で、nonlocal fused kernelは
`8.200543838`秒、VPJ kernelは`1.559553328`秒でした。H2Dは45,663回、
`28,361.039` MB、`2.479428511`秒、D2Hは7,759回、`6,036.924` MB、
`0.482051802`秒でした。stream+event同期APIは重複を含む`17.235587864`秒で、
MPI reportは空でした。

Step 70比でH2D+D2Hは`0.269326551`秒、H2D量は`3,229.206` MB減りましたが、
同期と主要kernelはほぼ横ばいです。kernel外約`56.09`秒にはCPU計算、runtime、wait、
profiler overheadが重なるため純GPU idleではありません。次は再実行せず、既存Step 91
archiveからTMEVL update/wait行だけを表示し、source attributionを確定してから単一の
ownership仮説を選びます。

既存archiveの詳細では、line 1930 `work2_` updateは4,720回、
inclusive `1.609217948`秒、内包Wait `1.530650988`秒でした。line 1933 metadata
updateは`0.148298132`秒、内包Waitは`0.137812074`秒です。line 2405の
fused-kernel完了Waitは`8.360886829`秒で、CUDA fused kernel `8.200543838`秒と
整合します。Updateと内包Waitは重複するため加算しません。次は再実行せず、既存Step 88
timerからhost生成、update、metadata、fused GEMMを同時表示して実装上限を確認します。

Step 88/91の一括表示では、nonlocal親`11.548827`秒に対してhost make
`1.348333`秒、owner-side `work2_` setup `1.550889`秒、metadata setup
`0.088045`秒、fused dot/update `8.400202`秒でした。host生成とsetupの合計上限は
`2.987267`秒ですが、直接GPU生成は既却下のYLM ownershipまたは細粒度copyを必要と
するため進めません。Step 92では数値経路を変えず、5 phase別に連続callの
`work2_`/`cfac_`/`ngnl_`が全要素完全一致するかを数え、host生成cacheの可能性を
先に確認します。

Step 92は両checkにPASSしました。5 phaseすべてで比較可能な943回の完全一致は0回、
changedは943回、equal率は`0.000%`でした。したがって`work2_`一式のhost生成cache
再利用は不可能です。Step 93では追加最適化せず、`ngnl_`、`cfac_`、`work2_`を
個別比較し、metadataだけが一定なら反復metadata updateの1回化を検討します。

Step 93はrevision `0c63c84`で両checkにPASSしました。diagnostic wall
`72.5525600910`秒はbaselineではありません。5 phaseそれぞれ943比較で、`ngnl_`、
`cfac_`、`work2_`、全体の完全一致率はすべて`0.000%`でした。metadataもprojector値と
ともに変化するため、反復metadata updateの1回化は成立しません。Steps 92/93で
phase単位の`work2_`全体cacheとmetadata-only cacheのreuse経路を閉じ、同形を再試行
しません。正式Step 86中央値は`66.5019950867`秒のままです。

次のStep 94は追加最適化ではなく、現行sourceのELECTF `LOCPOTF`再診断です。旧Step 43
の`4.071556`秒にはEWALD、local G-vector/force生成、MPI、energy、XC、Hartreeが混在
するため、そのままGPU化上限とは扱えません。default-off timerで`LOCPOTF`全体と
local生成からMPI境界までを測り、残差を導出します。`./tools/run_tddft_step94.sh`を
1回だけ実行し、両checkを必須とし、diagnostic wallはbaselineに使用しません。

Step 94はrevision `f7cf9d7`で両checkにPASSしました。diagnostic wall
`72.0893621445`秒はbaselineではありません。`LOCPOTF`全体`4.345268`秒のうち、
local G生成・force蓄積・MPIは`1.193364`秒（`27.464%`）、残差は`3.151904`秒
（`72.536%`）でした。local/MPI区間は支配的でないため直接offloadせず、Step 95で
残差をEWALD、local energy、XC、Hartree、未分類gapへ分解します。

Step 95はdefault-off timerだけを追加し、既存のEWALDY call、local-energy reduction、
XC call、Hartree reduction/final assemblyを個別計測します。timer表は120から124 entryへ
整合して拡張し、数式、loop順、MPI、OpenACC ownership、CPU/FFTW、diagnostic-off経路は
変更しません。A100では`./tools/run_tddft_step95.sh`を1回だけ実行します。

Step 95はPASS/PASSで、LOCPOTF残差`3.159508`秒のうちEWALDが`3.024790`秒
（`95.736%`）でした。local energy、XC、Hartree、gapの合計は`4.264%`です。
Step 96は実装前の限定診断として、固定核の101回のEWALDY出力`EWA`とactive-atom
`FORCE`を直前callとexact比較します。100比較すべて一致した場合だけ初回出力cacheを
次の候補にします。

Step 96はPASS/PASSでしたが、100比較すべてで`EWA`と`FORCE`が変化し、完全一致率は
各`0.000%`でした。出力cacheは不採用です。EWALDは`3.024790`秒の高価値targetなので、
Step 97でG-space、R-space、MPI、setup/AGEN gapへ分け、最大compute区間を次の直接
GPU化候補にします。

Step 97ではG-spaceが`2.795064`秒（EWALDYの`92.404%`）を占めました。Step 98は
EWALDY callごとの1 data region内でatom pairをGPU並列化し、pair内G-vector加算順と
MPI pair分担を維持、共有FORCEだけをatomic更新します。まずdiagnostic OFF run 01で
正しさと性能を判定します。

Step 98は3 runすべてPASS/PASSで、中央値`66.1477772789`秒、range
`0.27479244077`秒でした。Step 86比`0.532642%`高速なため正式採用します。Step 99は
同じdata regionと演算を維持し、atom pairをgang、内側G-vectorをvector reductionへ
割り当てて、残る逐次G loopを直接短縮します。

Step 99は3 runすべてPASS/PASSで、中央値`64.3024969101`秒、range
`0.2340140343`秒でした。Step 98比`2.789633%`、Step 86比`3.307417%`高速なため
正式採用します。Step 100では数値経路を変えず、現行sourceの主要timerを診断ONで
1回だけ再計測し、次の実装対象を最大のactionable区間から選びます。診断wallは
baselineに使用しません。

Step 100は両checkにPASSしました。diagnostic wall `70.6082198620`秒はbaselineでは
ありません。表示された`s2_nonlocal`親区間内の`4.498501`秒残差はSteps 92/93の
diagnostic-only全配列reuse比較で、通常性能処理ではありません。実計算ではfused
kernel `8.402617`秒が最大ですが、tutorialの32-block制約と安全なmapping/cache候補は
診断・却下済みです。Step 101は再build・再runせず既存archiveを読み、nonlocal転送と
S2 local内部timerを表示します。

Step 101ではfused wrapperの大半がkernel `8.402617`秒で、最初の`work2_` uploadは
`1.551925`秒でした。S2 localは`4.612063`秒で、local phase multiplyが
`0.917904`秒、elementwise子区間外が`2.277363`秒です。Step 102は同一phase式を
格子点ごとに1回だけ評価し、その複素factorを全local bandsで再利用します。

Step 102は3 runすべてPASS/PASSで、中央値`63.8388190269`秒、range
`0.24778998752`秒でした。Step 99比`0.721088%`、Step 86比`4.004656%`高速なため
正式採用します。Step 103は再build・再runせず既存Step 100 archiveから未変更の
kinetic phase上限を表示し、同じ前計算を実装する価値があるか判定します。

Step 103ではkinetic親区間`0.671559`秒、9,440回のGPU kernelが`0.635902`秒でした。
Step 104はG-vectorをGPU並列にし、band共通kinetic phaseをGごとに1回だけ計算して
32 local bandsへ適用します。各要素式、call回数、MPI、ownershipは変更しません。

Step 104 run 01はPASS/PASSでしたが`64.0659618378`秒で、Step 102中央値より
`0.2271428109`秒（`0.355807%`）遅い結果でした。run 02/03は早期停止します。
phase計算削減よりband方向並列性低下の影響が大きいため不採用とし、Step 102の
mappingへ復元します。

Step 100の現行timerでは`electf_force=6.249443`秒、
`electf_locpotf_total=1.373461`秒で、差分`4.875982`秒は正式Step 102 wallの
`7.638%`です。旧Steps 43/44ではほぼ同じNONLOCF区間をSEPPOTFが支配しましたが、
Step 47型のtutorial専用s/p全体GPU化は既に不採用なので再試行しません。

次のStep 105は追加最適化ではなく、現行ELECTF NONLOCFの再診断です。default-off
timerでNONLOCF全体、setup、係数kinetic/current＋MPI、GETYLM、SEPPOTF、最終
force/energy集計を測り、coverageと未分類gapを導出します。数式、loop順、MPI境界、
OpenACC ownership、CPU/FFTW、diagnostic-off経路は変更しません。A100では
`./tools/run_tddft_step105.sh`を1回だけ実行し、両checkを必須とし、diagnostic wallは
baselineに使用しません。

Step 105はrevision `91f27a0`でPASS/PASSでした。diagnostic wall
`70.5463471413`秒はbaselineではありません。ELECTF NONLOCF `4.975987`秒のうち、
setup `0.000899`、係数kinetic/current＋MPI `0.898982`、GETYLM `0.011795`、
SEPPOTF `4.061892`、最終集計`0.000562`、未分類gap `0.001857`秒でした。
SEPPOTFはNONLOCFの`81.630%`、正式Step 102 wallの`6.362730%`で最大の
actionable childです。

Step 47型s/p全体GPU化は再試行しません。旧GPU形は現行host形がband間で再利用する
WORK/DCOEF投影量生成をband reduction内で再計算していました。Step 106は数値経路を
変えず、現行SEPPOTFを位相生成、非partition s/pの投影量生成とband reduction、MPI、
未分類gapへ分解します。A100では`./tools/run_tddft_step106.sh`を1回だけ実行し、
両checkを必須とします。band reductionに実質的な上限が確認できた場合だけ、投影量を
一度生成してbandへ適用する別構造の二段GPU化を検討します。

Step 106はrevision `9ef703b`でPASS/PASSでした。diagnostic wall
`70.2937791348`秒はbaselineではありません。SEPPOTF `4.101524`秒のうち、phase
`0.091686`、s投影量生成`0.047953`、s band reduction `1.270594`、p投影量生成
`0.122658`、p band reduction `2.537915`、MPI `0.000391`、gap `0.030327`秒でした。
s/p band reduction合計は`3.808509`秒でSEPPOTFの`92.856%`、正式Step 102 wallの
`5.965820%`に相当し、別構造GPU化に十分な上限が確認できました。

Step 107は原子ごとの非partition s/p投影量を一度だけ生成し、原子×local-bandを
gangとして一括縮約します。最終集計はbandごとにtype、atom、s→pの元順序を維持します。
既存`EXTAU(NGcont,5,NTAUQ)`をscratchとして再利用し、追加は
`SEPRED(16,NTAUQ,MXBND2)`だけです。COEF常駐は同一time-stepのFRPRMNから直後の
ELECTFまでに限定してELECTF後にdeleteし、Step 45型のtime-step全体常駐には戻しません。
partitioned projectorとd/f形は既存host経路を維持し、GNU MPI＋FFTW fallbackの
full build/linkはPASSしています。まずdiagnostic OFFで
`./tools/run_tddft_step107.sh 01`だけを実行し、PASS/PASSとwallを確認します。

Step 107はdiagnostic OFFの3 runすべてで両checkにPASSしました。wallは
`63.1300778389`、`63.2335109711`、`63.2135219574`秒、中央値
`63.2135219574`秒、range `0.1034331322`秒です。Step 102中央値より
`0.6252970695`秒（`0.979493%`）高速なため、batched SEPPOTF経路を新しいsource・
性能baselineとして正式採用します。

Step 108はsourceや数値経路を変更せず、正式Step 107 sourceで既存default-off timerを
再計測します。TMEVL/S2、FRPRMN、ELECTF/NONLOCF、HLOCAL、EWALDの現行順位を
小さなterminal summaryへまとめます。diagnostic wallは性能baselineに使用しません。

Step 108はrevision `4ccf7dc`で両checkにPASSしました。diagnostic wall
`70.2021420002`秒はbaselineではありません。最大親区間はS2 NONLOCAL
`16.045700`秒ですが、fused kernelの安全なmapping/cache候補は既に分類済みです。
次のactionable親区間はELECTF NONLOCF `5.076909`秒で、そのうち採用済みbatched
SEPPOTFが`4.262210`秒です。Step 109は数値経路を変えず、このbatched経路を
projector、s/p reduction、最終GPU集計、download、MPI、gapへ分解します。

Step 109は両checkにPASSしましたが、実際には旧SEPPOTF経路が動いていました。
入力は`NTYPE=2`、符号付き`NUMTY=12,-2`で、旧SEPPOTFは一貫して
`ABS(NUMTY)`を使いますが、Step 107 guardだけが負値を未対応扱いしていました。
したがってStep 107の採用済み改善は限定COEF常駐によるもので、batch経路は未実行です。
Step 110はguardとatom loopだけを旧経路と同じ`ABS(NUMTY)`規約へ合わせます。

Step 110 run 01はdiagnostic OFFでPASS/PASSでしたが、wall
`63.7820260525`秒は正式Step 107中央値より`0.5685040951`秒（`0.899339%`）遅く、
差はStep 107 run rangeの`5.496344x`でした。run 02/03は早期停止します。
符号付き`NUMTY`で有効化したbatch経路は不採用とし、sourceとhelperを削除して
負値を除外するguardへ復元します。Step 107 baselineと限定COEF常駐は維持します。
このtutorial入力で同じSEPPOTF batch形を再試行しません。

次のStep 111は追加最適化ではなく、Step 108で`0.799754`秒だった
NONLOCF係数kinetic/current＋MPI区間を、2つのG-vector準備、2つのhost band reduction、
各MPI交換、YLM半径準備へdefault-off timerだけで分解します。数式、loop順、MPI、
OpenACC ownership、diagnostic-off経路は変更しません。親区間は正式Step 107 wallの
約`1.265%`なので、compute子区間が大半を占める場合だけ実装候補にします。

Step 111はrevision `2415d30`でPASS/PASSでした。diagnostic wall
`69.0858860016`秒はbaselineではありません。親`0.814936`秒のうち、
kinetic/current band reductionは`0.470508`秒、A-vector energy band reductionは
`0.287670`秒で、合計`0.758178`秒（`93.037%`）でした。MPI 2区間の合計は
`0.000745`秒だけです。

Step 112は最初のband/G loopで既に計算する`WFAC=|COEF|^2`をA-vector energyにも
同じG順で使用し、後続の2回目COEF全走査を削除します。2つのMPI交換と下流順序、
OpenACC ownership、allocationは維持します。削減上限は約`0.287670`秒、
正式Step 107 wallの`0.455%`です。
まずdiagnostic OFFで`./tools/run_tddft_step112.sh 01`を実行し、両checkとwallを
確認します。有望な場合だけ`02-03`へ進みます。

Step 112 run 01はPASS/PASSでしたが`63.6258358955`秒で、正式Step 107中央値より
`0.4123139381`秒（`0.652256%`）、run rangeの`3.986285x`遅い結果でした。
run 02/03は早期停止し、2本の元loopとtimer境界へ復元してhelperを削除します。
Step 84のenergy側pass融合も既に不採用なので、tutorial入力で同じCOEF-pass融合を
閉じます。新しいproduction入力またはprofiler根拠なしに、上限の小さい微調整を
続けません。
