# FPSEID21 TDDFT GPU化 PowerPoint原稿

この文書は、FPSEID21 TDDFTのOpenACC／cuFFT GPU化内容をPowerPointへ転記するための
日本語原稿である。原則として「1節＝1スライド」とし、本体GPU化、計測用変更、
不採用実験を分離している。

行番号は文書作成時点のHEADに基づく。今後の変更で移動する可能性があるため、
PowerPointではファイル名とroutine名を主な参照情報とし、行番号は補助情報として扱う。

## スライド1: タイトル

### FPSEID21 TDDFTのOpenACC／cuFFTによるGPU化

- 対象: FPSEID21 TDDFT 2022 October版
- GPU: NVIDIA A100-PCIE-40GB
- 実行条件: 1 GPU / 1 MPI rank
- 検証ケース: Si111-H、100 time steps
- コンパイラ: NVIDIA HPC SDK
- GPU実装: OpenACC + cuFFT
- 正式採用ソース: Step 74
- 正式性能中央値: `68.0681188811 sec`

## スライド2: GPU化の基本方針

- 計算量の大きいloopをOpenACC kernel化する。
- FFTはCPU FFTWからcuFFTへ移行する。
- 大規模配列をGPUに常駐させ、反復するH2D/D2H転送を削減する。
- GPU上で生成したデータを次のGPU処理へ直接渡す。
- MPIやCPU処理が必要な境界だけhostへ同期する。
- 数式と演算順序、特に逐次依存のある`ia`更新順序は維持する。
- CPU/FFTW fallbackを常に残す。

検証方法:

- 通常結果check
- relaxed toleranceによるreference比較
- 性能採否はdiagnostic OFFの3回中央値
- 効果のない実装は記録後にrevert

## スライド3: NVHPC／cuFFTビルド経路

変更内容:

- NVIDIA HPC SDK用ビルド経路を追加した。
- FFT backendをFFTWとcuFFTから選択可能にした。
- TDDFTだけをビルドする`TDDFT_ONLY=1`を追加した。
- A100向けコンパイル条件を統一した。

使用中の主要オプション:

```text
-O2 -acc -gpu=cc80
-gpu=mem:separate:pinnedalloc
-mp -Msave -Mlarge_arrays
```

変更箇所:

- `FPSEID21/tddft_2022October/mk_ifort.sh`
- `tools/build_nvhpc.sh`

補足:

- `ENABLE_GPU_FFT=1`でcuFFTを有効化する。
- `ENABLE_PINNED_ALLOC=1`でpinned host allocationを有効化する。
- GNU/FFTW版のビルド経路は維持している。

## スライド4: cuFFT backendとdevice pointer API

変更前:

```text
Host配列
  -> H2D copy
  -> cuFFT
  -> D2H copy
  -> Host配列
```

変更後:

```text
OpenACC管理のDevice配列
  -> device pointerを直接cuFFTへ渡す
  -> GPU上でFFT
  -> Device配列のまま次の処理へ
```

追加した主要entry:

```text
FFT3BX_fftwASL_ACC
FFT3FX_fftwASL_ACC
FFT3BX_fftwASL_ACC_BATCH
FFT3FX_fftwASL_ACC_BATCH
```

変更箇所:

- `fft_cufft.f`
  - device版FFT: 59行付近以降
  - batch版FFT: 88行、152行付近
- `fpseid_cufft_wrap.c`
  - `fpseid_cufft_exec_device`: 294行付近
  - `fpseid_cufft_exec_device_batch`: 346行付近
- `fft_fftw.f`
  - 同名entryをCPU/FFTW fallbackとして実装

実装上の要点:

```fortran
!$acc host_data use_device(RHOG)
call fpseid_cufft_exec_device(...)
!$acc end host_data
```

効果:

- cuFFT wrapperの反復H2D/D2Hを大幅に削減した。
- 初期cuFFT版の約443秒から、device pointer版で約360秒まで短縮した。

## スライド5: S2局所ポテンシャルFFT領域のOpenACC化

対象routine:

```text
S2_
```

変更箇所:

- `tmevl10_Avec_v4.f`
  - `S2_`: 1699行付近
  - backward batch FFT: 1999行付近
  - forward batch FFT: 2072行付近

GPU化した処理:

1. `P`から`RHO1_`へのscatter
2. inverse FFT
3. `VG = VGG + Vloc`
4. 局所ポテンシャルの適用
5. forward FFT
6. `RHO2_`から`P`へのgather
7. forward FFT後の正規化

配列管理:

```text
RHO1_, RHO2_, P, VG, Vloc, VGG, J2G
```

変更前:

- bandごとにhost/device転送とFFTを実行していた。
- scatterの並列度が小さかった。

変更後:

- `P`と作業配列をdevice上に保持する。
- scatterを`NXYZ x local bands`の一次元loopへ平坦化する。
- FFT前後の配列をhostへ戻さない。

効果:

- scatter時間が約56秒から約0.46秒へ短縮した。
- 局所FFT経路の支配的な転送を除去した。

## スライド6: P配列の常駐範囲拡大

対象配列:

```text
P(NG2Q, nbndloc)
```

変更箇所:

- `tmevl10_Avec_v4.f`
  - `TMEVL`: 15行付近
  - `S2_`: 1699行付近

段階的な変更:

1. `exnlp_gemm`呼び出し単位で転送
2. `S2_`全体で常駐
3. `TMEVL`全体で常駐

最終形:

```text
TMEVL開始:
  Pを1回だけDeviceへ

TMEVL内部:
  exkin、nonlocal、local FFTが同じPを使用

Host consumer境界:
  必要な場合だけPをHostへ同期
```

効果:

- S2単位のP転送: 約25.2秒
- TMEVL単位のP転送: 約5.7秒
- wall time: 約232秒から約180秒へ短縮

## スライド7: 非局所項exnlp_gemmのGPU化

対象routine:

```text
exnlp_only_make
exnlp_gemm
exnlp_gemm_present_inputs
exnlp_gemm_body_fused
```

変更箇所:

- `tmevl10_Avec_v4.f`
  - `exnlp_only_make`: 2324行付近
  - `exnlp_gemm`: 2350行付近
  - `exnlp_gemm_present_inputs`: 2380行付近
  - `exnlp_gemm_body_fused`: 2394行付近

変更内容:

- dot productをOpenACC reduction化した。
- coefficient更新をGPU化した。
- complex reductionを実部・虚部の実数reductionへ分離した。
- `work1`、`cfac`、`ngnl`、`coef`がdevice上にあることを前提とする
  present-input経路を追加した。
- 従来のhost-copy経路はfallbackとして維持した。

重要な制約:

- `ia`方向には逐次依存がある。
- `ia`の適用順序は変更していない。
- band間のみを並列化した。

## スライド8: 非局所kernelの融合

変更前:

```text
各iaについて
  dot-product kernel起動
  update kernel起動
```

変更後:

```text
各bandをOpenACC gangへ割当て
  band内のiaはseq実行
  dot-productと係数更新を同じkernel内で実行
```

変更箇所:

- `tmevl10_Avec_v4.f`
  - `exnlp_gemm_body_fused`

追加最適化:

- 一時配列`ct1`のdevice allocationを削除した。
- `ct1`の冗長なゼロ初期化kernelを削除した。
- 独立していたdot/update kernelを融合した。
- kernel起動回数を約453,120回から9,440回へ削減した。

効果:

- `exnlp_gemm_dot`: 約18.37秒から約11.05秒
- vector length調整後: 約8.44秒
- Step 23からStep 24でwallが約5.38%改善

## スライド9: 非局所staging bufferの再利用

対象配列:

```text
work2_
cfac_
ngnl_
```

変更箇所:

- `tmevl10_Avec_v4.f`

変更内容:

- phaseごとのdevice allocation/deleteを廃止した。
- device側bufferを初回だけ`create`する。
- 各phaseでは必要な範囲だけ`update device`する。
- forward phaseで作成したprojector列をreverse phaseでも再利用する。
- reverse phaseでは列番号を`loopcnt-ia+1`へ変換する。
- `work2_`の列幅を固定上限`NGcont`から実使用最大`NGNL`へ縮小した。

効果:

- reverse phaseのH2D回数を半減した。
- `exnlp_work1_enter`が約8秒から約4秒へ低下した。
- staging転送量も削減した。

注意:

- projectorの適用順序は維持した。
- hostで生成した内容自体は変更していない。

## スライド10: S2 FFTのbatch化

変更前:

```text
local bandごとにcuFFTを1回ずつ実行
```

変更後:

```text
nbndloc全体をcufftPlanManyで一括実行
```

変更箇所:

- `fft_cufft.f`
- `fpseid_cufft_wrap.c`
- `fft_fftw.f`
- `tmevl10_Avec_v4.f`

実装内容:

- `cufftPlanMany`によるbatch planを遅延生成した。
- 作成済みplanを再利用した。
- finalizerでplanを破棄した。
- OpenACC device pointerを直接batch cuFFTへ渡した。
- FFTW fallbackではbatch entry内部から従来FFTをband順に呼ぶ。

効果:

- wall中央値: 約161.75秒から約146.54秒
- `s2_fft_local`: 約22.48秒から約5.03秒
- FFT呼び出し回数と起動overheadを削減

## スライド11: COEF／COEF0のpredictor-corrector常駐化

対象配列:

```text
COEF
COEF0
```

変更箇所:

- `frprmn_tm12_check_Vext_Avec_v4.f`
- `tmevl10_Avec_v4.f`

変更内容:

- `COEF`と`COEF0`のdevice mapping所有をTMEVLからFRPRMNへ移した。
- predictor-corrector区間全体でdevice常駐させた。
- correction restart時の`COEF0 -> COEF`復元をdevice上で実行した。
- CPU/FFTWでは従来の`coefcp`を使用する。

効果:

- `tmevl_p_enter`: 約2.93秒から約0.001秒
- Step 25中央値: 約130.61秒
- Step 28中央値: 約129.08秒

同期方針:

- Device側を最新値として扱う。
- Host側で係数を読む直前だけD2Hする。

## スライド12: TMEVL後の密度再構築GPU化

対象routine:

```text
RHOOFK_ACC_BATCH
```

変更箇所:

- `frprmn_tm12_check_Vext_Avec_v4.f`
  - 呼び出し: 2215行付近
  - routine本体: 2481行付近

変更内容:

- residentな`COEF`からdevice上でwavefunctionをscatterする。
- local bandsをbatch cuFFTで変換する。
- occupation付きcharge densityをdevice上で集約する。
- MPI reductionに必要なlocal densityだけhostへ戻す。
- 初期密度用の従来`RHOOFK`は維持する。

効果:

- `frprmn_rhoofk`: 約14.51秒から約0.73秒
- FFT wrapper呼び出し: 43,949回から14,685回
- Step 28中央値: 約129.08秒
- Step 33中央値: 約116.12秒

## スライド13: COEFのD2H同期繰延べ

変更前:

```text
TMEVL終了ごとにCOEF全体をHostへdownload
```

変更後:

```text
Deviceを正本として補正計算を継続
Host consumerが現れる直前だけdownload
```

変更箇所:

- `frprmn_tm12_check_Vext_Avec_v4.f`
- `tmevl10_Avec_v4.f`

Host同期を残した境界:

- 最終time stepのexpectation計算
- `NPFL != 0`の`SUMCHR`
- FRPRMN終了時
- その他の明示的host consumer

効果:

- TMEVLごとの944回D2Hを削除した。
- 必須同期は約103回へ集約した。
- Step 33中央値: 約116.12秒
- Step 34中央値: 約113.56秒

Nsight Systems確認:

- D2H総量: 約30,054 MBから約5,593 MB
- D2H回数: 35,453回から5,348回

## スライド14: 静的metadataのloop外常駐化

対象配列:

```text
J2G
OCC
RAD
PSPOT
PSPOT2
PHIL
```

変更箇所:

- `pspw_tm11_Vext_Avec_v4_alloc.f`
  - `enter data`: 1052行付近
  - `exit data`: 1858行付近
- `tmevl10_Avec_v4.f`
- `frprmn_tm12_check_Vext_Avec_v4.f`

変更内容:

- time-step loop開始前に1回だけ`copyin`する。
- loop内部では`present`参照する。
- time-step loop終了後に`delete`する。
- S2、密度再構築、VPJ処理などで共用する。

削減対象:

- S2の`J2G`反復copyin
- RHOOFKの`J2G`と`OCC`反復copyin
- VPJのpseudopotential表転送

効果:

- 最大5,662回相当のmetadata H2Dをloop外へ集約した。
- Step 41中央値: 約107.75秒

## スライド15: pinned host memoryの採用

変更内容:

```text
-gpu=mem:separate:pinnedalloc
```

変更箇所:

- `tools/build_nvhpc.sh`

目的:

- 動的確保されるhost配列をCUDA pinned memoryに配置する。
- 既存のseparate memory設計とOpenACC data clauseは維持する。
- 転送回数は変えず、転送時間を削減する。

効果:

- H2D時間: Step 35比で約74.69%削減
- D2H時間: Step 35比で約46.98%削減
- wall中央値: 約113.08秒から約108.10秒

## スライド16: VPJ_GEN動径積分のGPU化

対象routine:

```text
VPJ_GEN
VPJ_GEN_ACC_INTEGRAL
```

変更箇所:

- `vpj_gen.f`
  - `VPJ_GEN`: 2行付近
  - GPU積分呼び出し: 148行付近
  - `VPJ_GEN_ACC_INTEGRAL`: 421行付近
  - OpenACC kernel: 429行付近
- `frprmn_tm12_check_Vext_Avec_v4.f`
  - `VPJ_GEN`呼び出し: 2995～3095行付近
- `pspw_tm11_Vext_Avec_v4_alloc.f`

変更内容:

- Gベクトル間をOpenACCで並列化した。
- 各G内の動径方向積分順序は維持した。
- static pseudopotential表をtime-step loop全体で常駐させた。
- 積分後の必須D2HとMPIはhost側に維持した。
- vector lengthを256から128へ調整した。

主要OpenACC指定:

```fortran
!$acc parallel loop gang vector vector_length(128)
```

効果:

- 旧CPU動径積分: 約36.13秒
- GPU kernel: 約1.8秒
- Step 41中央値: 約107.75秒
- Step 52中央値: 約73.44秒
- 約31.85%改善

## スライド17: LOCPOTのGPU化

対象routine:

```text
LOCPOT
```

変更箇所:

- `lib4_ASL_2_check_Vext_SXACE.f`
  - `LOCPOT`: 443行付近
- `lib4_ASL_2_check_Vext_SXACE_gnu.f`
  - CPU fallback側も同様の構造を維持
- 呼び出し側:
  - `frprmn_tm12_check_Vext_Avec_v4.f`
  - 454～655行付近

変更前:

- Gベクトル、原子種、原子、補正項をすべてhost loopで計算していた。

変更後:

- G=0は元のhost計算を維持する。
- `G=2..NG`をGベクトル間でOpenACC並列化する。
- 1 GPU threadが1 Gベクトルを担当する。
- 各G内部の`ITY -> K -> IA`順序は維持する。
- MPI reductionはhost側に維持する。

効果:

- LOCPOT: 約2.765秒から約0.305秒
- 約88.97%短縮
- Step 52中央値: 約73.44秒
- Step 57中央値: 約71.29秒

## スライド18: VRHO補正時の冗長host copy削除

対象処理:

```text
失敗したcorrector後のCOEF0 -> COEF復元
```

変更箇所:

- `frprmn_tm12_check_Vext_Avec_v4.f`
  - 977～989行付近

変更前:

```text
Device上でCOEFを復元
Host側でもCOEF0 -> COEFを全コピー
次の補正ではDevice側COEFを使用
```

問題:

- OpenACC経路ではhost copyがdevice authorityを更新しない。
- 次の補正もdevice側の`COEF0`から復元する。
- host copyはGPU経路では冗長である。

変更後:

```fortran
#ifndef _OPENACC
  call coefcp(...)
#endif
```

- OpenACC時のみhost copyを省略する。
- CPU/FFTWでは従来copyを維持する。
- `VGOLD`復元、device復元、MPI、演算順序は維持する。

効果:

- 旧host復元時間: 約2.159秒
- 現行復元時間: 約0.0029秒
- Step 57中央値: 約71.29秒
- Step 62中央値: 約68.57秒
- 約3.81%改善

## スライド19: NONLOCのYLM再利用

対象処理:

```text
NONLOC内のGETYLM
```

変更箇所:

- `frprmn_tm12_check_Vext_Avec_v4.f`
  - `iylm_reuse`初期化: 1107行付近
  - 最初の呼び出し後にreuse設定: 1136～1137行付近
- `tmevl10_Avec_v4.f`
  - `iylm_reuse`制御: 744～761行付近

変更前:

- 同じk-point/event内でもbandごとにYLMを再構築していた。

変更後:

- `iylm_reuse`をNONLOCへ明示的に渡す。
- 各k-point/eventの最初のbandだけYLMを生成する。
- 2番目以降のbandでは生成済みYLMを再利用する。

毎band維持した処理:

- kinetic `DCOEF`
- `SEPPOT`
- coefficient依存処理
- projector適用順序

効果:

- Step 67中央値: 約68.362秒
- Step 74中央値: 約68.068秒
- 約0.429%改善
- 現在の正式baseline

## スライド20: 採用しなかった変更

以下はcorrectnessにはPASSしたものの、性能効果がない、または回帰したためrevertした。

同型のvector length変更:

- fused nonlocal kernel `vector_length(512)`
- VPJ kernel `vector_length(64)`
- 採用値:
  - fused nonlocal: 256
  - VPJ: 128

常駐範囲を広げすぎた変更:

- `Vloc`のFRPRMN correction間常駐
- `COEF` allocationのtime-step全体維持
- `GDUMP` mappingのTMEVL全体再利用
- resident `COEF0`のdevice初期化

producer入力転送を増やした変更:

- `work2_`をGPU生成するための細粒度lookup copy
- ownershipを確立しないYLM直接GPU生成
- EXTAU 5表の一括OpenACC生成

kernel特殊化:

- nonlocal forward/reverse別kernel
- tutorial専用SEPPOTF s/p GPU経路

まとめ:

```text
いずれも通常check・relaxed compareを確認したうえで、
3回中央値または早期停止基準により不採用とした。
```

## スライド21: 性能推移

| 段階 | 主な変更 | 100-step wall |
|---|---|---:|
| 初期cuFFT host-copy | FFTごとにH2D/D2H | 約443.2秒 |
| Step 3 | device pointer cuFFT | 約360.3秒 |
| Step 5 | scatter平坦化 | 約303秒 |
| Step 12 | P常駐＋冗長kernel削除 | 約172.65秒 |
| Step 18 | nonlocal dot/update融合 | 約163.31秒 |
| Step 21 | local FFT batch化 | 約146.54秒 |
| Step 24 | nonlocal ia融合 | 約133.27秒 |
| Step 25 | nonlocal vector length 256 | 約130.61秒 |
| Step 28 | COEF predictor-corrector常駐 | 約129.08秒 |
| Step 33 | charge-density FFT batch化 | 約116.12秒 |
| Step 34 | coefficient D2H繰延べ | 約113.56秒 |
| Step 37 | pinned allocation | 約108.10秒 |
| Step 41 | static metadata常駐 | 約107.75秒 |
| Step 52 | VPJ動径積分GPU化 | 約73.44秒 |
| Step 57 | LOCPOT GPU化 | 約71.29秒 |
| Step 62 | 冗長host復元削除 | 約68.57秒 |
| Step 67 | VPJ vector length 128 | 約68.36秒 |
| Step 74 | YLM再利用 | 約68.07秒 |

総合結果:

- 約443.2秒から約68.07秒
- 約6.51倍高速化
- 実行時間を約84.6%削減
- 全正式採用runで通常check・relaxed compare PASS

## スライド22: 現在のソース構成

| ファイル | 主な役割 |
|---|---|
| `tmevl10_Avec_v4.f` | TMEVL、S2、exkin、nonlocal GEMM、local FFT |
| `frprmn_tm12_check_Vext_Avec_v4.f` | COEF常駐、密度再構築、VRHO、YLM再利用 |
| `fft_cufft.f` | device pointer版・batch版cuFFT entry |
| `fpseid_cufft_wrap.c` | CUDA/cuFFT wrapperとplan管理 |
| `fft_fftw.f` | CPU/FFTW fallback |
| `vpj_gen.f` | VPJ動径積分GPU kernel |
| `lib4_ASL_2_check_Vext_SXACE.f` | LOCPOT GPU化、VOFRHO |
| `pspw_tm11_Vext_Avec_v4_alloc.f` | time-step loop、静的metadata常駐 |
| `electf4_Vext_Avec.f` | ELECTF、NONLOCF、SEPPOTF |
| `mk_ifort.sh` | compiler/backend選択 |
| `tools/build_nvhpc.sh` | NVHPCビルド条件 |

GNU版で同様の変更を持つファイル:

```text
lib4_ASL_2_check_Vext_SXACE_gnu.f
pspw_tm11_Vext_Avec_v4_alloc_gnu.f
rarr3_gnu.f
tm_inputs_gnu.f
```

## スライド23: 現在の残課題

正式Step 74 sourceのFRPRMN残差:

```text
frprmn - tmevl_total = 約8.2 sec
```

Step 76で再分類したVRHO:

| 項目 | 時間 |
|---|---:|
| VRHO全体 | 1.762396秒 |
| VOFRHO | 0.956957秒 |
| seed制御 | 0.549649秒 |
| smoothing/FFT | 0.156599秒 |
| corrector | 0.078602秒 |
| COEF復元 | 0.002889秒 |

現在の診断:

- Step 77でVOFRHOを以下へ分解する。
  - exchange-correlation
  - FFT
  - Hartree zeroing
  - Hartree生成
  - Hartree加算
- Step 77は計測用timer追加であり、新たなGPU化ではない。
- 正式性能baselineは引き続きStep 74である。

残る高速化方針:

- CPU処理を闇雲にGPU化せず、1秒前後の領域から分解する。
- GPU化後に転送や同期が増えないownership境界を設計する。
- 小さな処理は単独kernel化せず、既存GPU領域との融合を優先する。
- GPU kernel時間だけでなく、CPU、同期、runtime/API、GPU idleを含めて評価する。

## 正式baselineと文書の位置づけ

- 正式baseline: 論理Step 74
- source implementation commit: `3687243`
- pinned build-mode commit: `9cbb6bc`
- A100 3回中央値: `68.0681188811 sec`
- Step 75以降は、Step 74 sourceを対象とした診断・分類作業である。
- PowerPointで性能を示す場合は、診断wallと正式baselineを混在させない。
