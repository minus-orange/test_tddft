# FPSEID21 TDDFT GPU化 PowerPoint原稿（2026-08-04更新）

この文書は、FPSEID21 TDDFTのOpenACC／cuFFT GPU化を説明するPowerPoint用の
詳細原稿である。2026-08-04時点のコード、正式baseline、検証結果に合わせて更新した。

想定する伝達目標は次のとおりである。

> 発表後、聴衆が「主要計算のGPU化とデータ常駐化によってA100で約2.32倍まで高速化し、
> H100でも独立baselineを確立した一方、次の改善にはproduction規模入力が必要」と理解する。

PowerPointでは各スライドの「掲載内容」を表示し、「説明メモ」は発表者ノートとして使う。
実行時間は小数点以下3桁に統一する。A100、H100、x86のbaseline系列は独立して扱う。

## スライド1: GPU化の到達点

### 主要な時間発展処理をGPUへ移し、A100で約2.32倍高速化

掲載内容:

- 対象: FPSEID21 TDDFT 2022 October版
- 手法: NVIDIA HPC SDK、OpenACC、cuFFT
- 検証: Si111-H、100 time steps、diagnostic OFF
- 正式GPU経路: 1 GPU / 1 MPI rank / 1 OpenMP thread
- 正式x86経路: 32 MPI ranks × 8 OpenMP threads/rank = 256 CPU threads
- A100: `146.540秒 → 63.214秒`（約56.9%短縮、約2.32倍）
- H100: `34.109秒`の独立baselineを確立
- CPU/FFTW fallbackも維持

説明メモ:

- GPU kernelの追加だけでなく、配列常駐、FFT batch化、同期削減を一体で進めた。
- A100の正式baselineはStep 107、H100はStep 115である。
- 現在の採用済み数値sourceは`c46cfa9`。文書・測定支援を含む発表原稿更新時HEADは
  `4ef4d7e`で、数値計算経路は採用sourceと一致している。

## スライド2: 正しさを維持しながらGPU化した

### 性能だけでなく、数値一致とCPU経路を採用条件にした

掲載内容:

- 数式、配列shape、projector適用順、逐次`ia`更新順を維持
- CPU/FFTW版を継続してbuild・実行可能
- performance測定はdiagnostic OFF
- 同一条件で3回実行し、中央値とrangeで評価
- normal checkとrelaxed compareを全runで必須化
- 効果のない変更は記録後にrevert

説明メモ:

- H100とx86では反復run間のstrict compareもPASSしている。
- A100、H100、x86は入力が同じでもハードウェア条件が異なるため、baselineを混合しない。
- 最新HEADを自動的に正式baselineとせず、採用済み数値sourceと測定系列を分けて管理している。

## スライド3: GPU化は「計算・データ・FFT」の3層で進めた

### GPU上で処理を連結し、Host往復を減らした

掲載内容:

```text
Host入力
  ↓ 初回転送
GPU常駐配列（P、COEF、COEF0、metadata）
  ↓
OpenACC kernel ─ cuFFT batch ─ OpenACC kernel
  ↓ 必要な境界だけ同期
MPI／Host処理
```

- 計算: 主要loopをOpenACC kernel化
- データ: 大規模配列と静的metadataをGPUへ常駐
- FFT: OpenACC管理配列のdevice pointerをcuFFTへ直接渡す
- 境界: MPIやHost consumerの直前だけ同期

説明メモ:

- 初期版はFFTごとにHost→Device→cuFFT→Hostへ戻していた。
- 現在は外側routineがdevice mappingを所有し、内側routineは`present`で参照する。
- separate memoryとpinned host allocationを正式設定としている。

## スライド4: 時間発展ループの主要領域をGPU化した

### ソース上の候補39箇所中26箇所へcompute処理を実装

掲載内容:

| 計算領域 | 主なGPU化内容 |
|---|---|
| S2局所項 | scatter、局所potential、cuFFT、gather |
| 非局所項 | projector dot、係数更新、kernel融合 |
| 電荷密度 | resident COEFからの再構築、batch FFT |
| FRPRMN | COEF/COEF0常駐、同期削減、データ再利用 |
| potential | VPJ、LOCPOT、LDA交換相関、EWALD |
| HLOCAL | zeroからFFT・multiply・gatherまで連続実行 |

**ソース箇所数ベース: 26 / 39 = 約66.7%**

説明メモ:

- 66.7%はGPU使用率や実行時間比率ではなく、識別したsource candidate siteの対応率である。
- allocation、常駐範囲、同期削減、重複処理削減は、性能に効いてもsite数には表れない。

## スライド5: 26/39の残り13は単純な未対応リストではない

### arithmetic gapを、未採用・非活性・Host境界の理由別に管理する

掲載内容:

`26 / 39`はOpenACC compute construct数による暫定indexである。残り`13相当`は、
現在のsourceに1対1で対応する固定された13個の実装待ちloopではない。

| 区分 | 主な候補 | GPU化しない／残している理由 |
|---|---|---|
| memory中心の小loop | density smoothing、配列copy | 演算量よりmapping・同期・転送costが大きい |
| predictor／履歴更新 | VG0～VG5、VGOLD、interpolation | 分岐とHost authorityがあり、Step 78一括offloadで回帰 |
| potential／E-field境界 | VG、VPLT、VEXT組立 | 直後のHost consumerによりD2Hが必要 |
| reduction／行列処理 | energy、CMAT、収束判定 | reduction順序とMPI境界のriskに対して上限が小さい |
| producer／非活性経路 | EXTAU、GGA G2VXC2 | GPU生成は回帰、GGA経路はSi111-Hで非活性 |
| 正常だが不採用 | SEPPOTF batch、追加kernel融合 | checkはPASSしたが正式baselineより遅い |

説明メモ:

- 母数39はStep 80時点の採用済み19 siteと、Step 78で一時offloadしてrevertした
  20 siteから定義した。
- その後のcompute site追加はStep 78候補と必ずしも1対1対応しないため、`39-26=13`を
  そのまま13件のbacklogとは解釈しない。
- 現行tutorialでは、残候補をまとめてoffloadするより転送・同期を増やす場合がある。

## スライド6: FFTをHost往復型からGPU常駐型へ変更した

### device pointerとbatch化でFFT前後の転送・呼出しを削減

掲載内容:

```text
変更前: Host array → H2D → cuFFT → D2H → Host array
変更後: OpenACC device array → cuFFT → device array
```

- `host_data use_device`でOpenACC配列をcuFFTへ渡す
- `cufftPlanMany`でlocal bandsを一括処理
- S2局所FFTと電荷密度再構築の両方をbatch化
- FFTW backendには同名fallback entryを用意

代表的な効果:

- `s2_fft_local`: 約`22.480秒 → 5.030秒`
- `frprmn_rhoofk`: 約`14.510秒 → 0.730秒`
- FFT wrapper呼出し: `43,949回 → 14,685回`

## スライド7: 非局所projectorはkernel融合で起動回数を減らした

### band方向を並列化し、原子順序をkernel内で維持

掲載内容:

- dot productをOpenACC reduction化
- coefficient更新を同じkernelへ融合
- 一時配列とゼロ初期化kernelを削除
- bandをgangへ割り当て、band内の`ia`は`seq`
- forward/reverse phaseでstaging bufferを再利用
- 実使用最大`NGNL`に合わせてbuffer幅を縮小

代表的な効果:

- kernel起動回数: 約`453,120回 → 9,440回`
- `exnlp_gemm_dot`: 約`18.370秒 → 8.440秒`

説明メモ:

- 各band内の原子適用順とreverse phaseの逆順適用は変更していない。
- Step 116の現行source profilingでも、融合非局所kernelは主要な残存コストである。

## スライド8: FRPRMNとpotential処理もGPU内でつないだ

### 個別kernel化に加え、重複計算と同期を削減

掲載内容:

- `COEF`／`COEF0`をpredictor-corrector区間で常駐
- seed初期化をHost copy＋H2DからGPU内copyへ変更
- band非依存のYLMとphase情報を事前計算・再利用
- VPJ動径積分、LOCPOT、LDA交換相関をOpenACC化
- EWALDのG-space pairとreductionをGPU化
- HLOCALを1つのdata領域で連続実行

代表的な効果:

- VPJ CPU積分: 約`36.130秒 → 1.800秒`
- LOCPOT: 約`2.765秒 → 0.305秒`
- 不要なHost COEF復元: 約`2.159秒 → 0.003秒`

説明メモ:

- Step 107の正式改善は、FRPRMNからELECTFまでの限定COEF常駐によるものと確認済み。
- 同Stepで提案したSEPPOTF batch経路はtutorial入力では非活性だったため、採用効果へ数えない。

## スライド9: データ常駐化がGPU化の実効性を高めた

### kernel間で配列を保持し、必要な同期だけを残した

掲載内容:

| 常駐対象 | 常駐範囲・狙い |
|---|---|
| `P` | TMEVL全体で保持 |
| `COEF`, `COEF0` | predictor-correctorからELECTFまで保持 |
| `work2_`, `cfac_`, `ngnl_` | 非局所phase間で再利用 |
| `J2G`, `OCC` | time-step loop全体で保持 |
| pseudopotential表 | static metadataとしてloop外へ移動 |

- TMEVLごとの`COEF` D2H 944回を削除
- 必須`COEF`同期を約103回へ集約
- metadataの反復copyinをloop外へ移動
- pinned host allocationで残る転送を短縮

説明メモ:

- HostとDeviceのどちらが正本かをroutine境界ごとに明示した。
- managed/unified memoryは正式なpinned separate memoryより2倍以上遅く、不採用とした。

## スライド10: A100では段階的に63.214秒まで短縮した

### 主要な転換点ごとに性能を積み上げた

掲載内容:

| 段階 | 主な変更 | 100-step wall |
|---|---|---:|
| 初期採用GPU実装（Step 21） | local FFT batch化 | 146.540秒 |
| Step 25 | 非局所kernel融合 | 130.608秒 |
| Step 33 | 電荷密度FFT batch化 | 116.125秒 |
| Step 37 | pinned allocation | 108.096秒 |
| Step 52 | VPJ積分GPU化 | 73.437秒 |
| Step 57 | LOCPOT GPU化 | 71.291秒 |
| Step 80 | LDA交換相関GPU化 | 67.421秒 |
| Step 86 | HLOCAL GPU内連続実行 | 66.502秒 |
| Step 99 | EWALD G-space vector reduction | 64.302秒 |
| Step 102 | band非依存S2 phase事前計算 | 63.839秒 |
| Step 107 | 限定COEF常駐 | **63.214秒** |

総合: `146.540秒 → 63.214秒`、約`2.32倍`、約`56.9%`短縮

説明メモ:

- 表はすべてA100、Si111-H、100 stepsの採用系列。診断runは含めない。
- さらに古いhost-copy cuFFT版の約443秒は実装初期の参考値で、正式採用系列とは分ける。

## スライド11: 各プラットフォームで正式baselineを確立した

### 同じ100-step入力で全系列が正常性PASS

掲載内容:

| プラットフォーム | 実行構成 | 中央値 | range | 正常性 |
|---|---|---:|---:|---|
| NVIDIA A100-PCIE-40GB | NVHPC/OpenACC/cuFFT、1 GPU × 1 MPI rank × 1 OpenMP thread | 63.214秒 | 0.103秒 | PASS |
| NVIDIA H100 PCIe | NVHPC/OpenACC/cuFFT、1 GPU × 1 MPI rank × 1 OpenMP thread | 34.109秒 | 0.091秒 | PASS |
| Intel Xeon 6980P | ifx/mpiifx＋FFTW、32 MPI ranks × 8 OpenMP threads/rank = 256 threads | 16.539秒 | 0.058秒 | PASS |
| Intel Xeon Platinum 8468 × 2 socket | ifx/mpiifx＋FFTW、32 MPI ranks × 3 OpenMP threads/rank = 96 threads | 20.597秒 | 0.056秒 | PASS |
| Intel Xeon Platinum 8592+ × 2 socket | ifx/mpiifx＋FFTW、32 MPI ranks × 4 OpenMP threads/rank = 128 threads | 19.595秒 | 0.053秒 | PASS |

- H100はA100よりwall timeが約46.0%短く、比率は約1.85倍
- CPU系列は96、128、256 CPUコアを使用しており、1 GPUとの直接的な装置性能
  比較ではない

説明メモ:

- A100はStep 107、H100はStep 115で、どちらも`mpirun -np 1`、
  `OMP_NUM_THREADS=1`の独立baseline。
- 6980P、8468、8592+はそれぞれ独立したCPU/FFTW baselineで、相互に置換しない。
- x86は16 MPI × 1 OpenMPの`29.352秒`から構成最適化で`16.539秒`へ短縮した。

## スライド12: 効果のない最適化も採否を明確にした

### 正しく動いてもwall timeが改善しない変更は残さなかった

掲載内容:

- SEPPOTF batch有効化: 正常だがA100で遅化
- compiler flags（fastmath／IPA）: 改善がrun幅付近
- managed／unified memory: 2倍以上遅化
- 非局所kernelの追加融合・特殊化: 有意な改善なし
- vector length変更: 256または128の採用値より遅化
- Intel MPI scatter配置: IPL2 errorと大幅遅化

得られた知見:

- 小さいkernelを増やすだけでは起動・同期overheadが勝つ
- 常駐範囲を広げてもHost authority境界が残ると効果は限定的
- tutorial専用micro tuningは改善上限が小さい

## スライド13: 最新profileが現行tutorialの改善限界を示している

### A100とH100のcurrent-source Nsight結果を比較する

掲載内容:

Step 116 current-source Nsight Systems（100 steps、profiler wallは正式値ではない）:

- 実行並列数: 1 GPU × 1 MPI rank × 1 OpenMP thread
- 両GPUでnormal check、relaxed compare PASS

| 項目 | A100 | H100 |
|---|---:|---:|
| profiler wall | 66.954秒 | 36.157秒 |
| fused EXNLP kernel | 8.254秒 | 3.185秒 |
| VPJ kernel | 1.565秒 | 0.718秒 |
| H2D | 45,670回、28,509 MB、2.497秒 | 45,670回、28,509 MB、0.693秒 |
| D2H | 7,961回、6,037 MB、0.483秒 | 7,961回、6,037 MB、0.124秒 |

Step 116 Nsight Compute（融合非局所kernelの1 launch）:

| 項目 | A100 | H100 |
|---|---:|---:|
| Grid × Block | 32 × 256 | 32 × 256 |
| GPU thread数／launch | 8,192 | 8,192 |
| kernel duration | 914.69 µs | 355.78 µs |
| registers／thread | 63 | 72 |
| theoretical occupancy | 50.00% | 37.50% |
| achieved occupancy | 12.50% | 12.50% |
| waves／SM | 0.07 | 0.09 |

cuFFT以外のOpenACC kernel launch形状（A100/H100で共通）:

| 代表kernel | Grid x Block | GPU thread数／launch | 性能上の位置づけ |
|---|---:|---:|---|
| 融合非局所 | 32 x 256 | 8,192 | 非cuFFT kernel時間の最大成分 |
| VPJ動径積分 | 42 x 128 | 5,376 | 第2成分 |
| S2主要3構成 | 32 x 128 | 4,096 | 小さいband幅に連動 |
| EXKIN／RHO／FFT後処理 | 最大7,257 x 128 | 最大928,896 | grid幅は十分大きい構成あり |
| FRPRMN | 14,513 x 128 | 1,857,664 | 最大grid、ただし時間寄与は小さい |

解釈:

- tutorialは32 bandsで、主要fused kernelは両GPUとも32 blocksしかない。
- 非cuFFT 24構成のGrid／BlockはA100とH100で全て一致した。
- 全kernelが低並列ではなく、性能上の問題は支配時間の大きい32～42 blocksのkernelに集中する。
- H100はfused kernelがA100より約2.59倍短いが、achieved occupancyは同じ12.50%である。
- 大きい非局所kernelは残るが、安全なmapping・cache候補は既に診断／却下済み。
- profiler wallと同期API時間はoverlapとprofiler overheadを含み、正式baselineへ使用しない。
- Step 110のSEPPOTF batchとStep 112の追加融合は、正常でもそれぞれ0.899%、0.652%遅化した。

説明メモ:

- A100はrevision `9e67ad0`、H100はrevision `ac71452`で取得し、数値sourceはいずれも`c46cfa9`である。
- profiler wall `66.954秒`／`36.157秒`は正式baselineではない。
- 現行入力で「GPU化が不足している」より、「並列幅不足と境界overheadにより追加offloadの
  効果が出にくい」ことを示す。
- `GPU thread数／launch`はGrid x Blockの総起動数であり、同時resident thread数ではない。
- 全24構成の詳細値は`docs/STEP116_OPENACC_LAUNCH_SHAPES.md`を参照する。

## スライド14: 次の課題はproduction規模での再評価

### tutorial入力の小ささが、次のGPU改善判断を難しくしている

掲載内容:

- 融合非局所kernelが主要な残存処理
- Host処理、MPI境界、同期・転送が一部残存
- tutorial入力は32 bandsで、GPU並列度とoccupancyが不足
- production入力と対応する正解referenceが未準備
- Step 116でA100／H100のcurrent-source profiler取得を完了

次の方針:

1. production規模入力と正解referenceを準備する
2. 同一production入力でA100／H100の新しいbaselineを作る
3. production規模でkernel、同期、転送量を再分類する
4. 根拠が得られた箇所だけを1仮説ずつ最適化する

説明メモ:

- 新しいprofiler根拠またはproduction入力なしに、小規模tutorialの微調整は再開しない。
- NVIDIA MPSとGPU側MPI rank増加は調査のみで終了し、実行対象にしない。
- 現在、保留中のA100、H100、x86実行コマンドはない。

# 付録

## 付録A1: 正式baselineの識別情報

| 系列 | logical step | source／tested revision | 条件 |
|---|---|---|---|
| A100 | Step 107 | `c46cfa9` | cc80、1 GPU × 1 MPI rank × 1 OpenMP thread、diagnostic OFF |
| H100 | Step 115 | `e6ad059` | cc90、1 GPU × 1 MPI rank × 1 OpenMP thread、diagnostic OFF |
| x86 | x86 formal baseline | `7318e59`系列 | ifx/mpiifx、32 MPI ranks × 8 OpenMP threads/rank = 256 threads |

発表原稿更新時HEAD: `4ef4d7e`

注意:

- HEADには文書、検証、x86測定支援の更新を含む。
- GPUの採用済み数値計算経路は`c46cfa9`と一致する。
- H100とA100のbaselineは混合・置換しない。

## 付録A2: 主な変更ファイル

| ファイル | 主な役割 |
|---|---|
| `tmevl10_Avec_v4.f` | S2、exkin、非局所kernel、P常駐 |
| `frprmn_tm12_check_Vext_Avec_v4.f` | COEF常駐、密度再構築、再利用 |
| `electf4_Vext_Avec.f` | ELECTF境界、EWALD、限定COEF常駐 |
| `fft_cufft.f` | device pointer版・batch版cuFFT |
| `fpseid_cufft_wrap.c` | cuFFT wrapperとplan管理 |
| `fft_fftw.f` | CPU/FFTW fallback entry |
| `vpj_gen.f` | VPJ動径積分kernel |
| `lib4_ASL_2_check_Vext_SXACE.f` | LOCPOT、交換相関 |
| `pspw_tm11_Vext_Avec_v4_alloc.f` | loop外metadata常駐 |
| `tools/build_nvhpc.sh` | NVHPC/OpenACC/cuFFT build |

## 付録A3: cuFFTをdevice pointer版へ変更

```fortran
      SUBROUTINE FFT3BX_fftwASL_ACC(...)
      ...
!$acc host_data use_device(RHOG)
      call fpseid_cufft_exec_device(plancbp,RHOG,NG,1,ierr)
!$acc end host_data
```

- OpenACC管理配列のdevice pointerをcuFFTへ直接渡す。
- forward FFTとbatch FFTにも同じ境界を用いる。
- CPU/FFTW側は互換entryを維持する。

## 付録A4: bandごとのFFTをbatch化

変更前:

```fortran
      do ib=nbegin,nend
         CALL FFT3BX_fftwASL_ACC(...,RHO1_(1,iib),RHO2_(1,iib),...)
      enddo
```

変更後:

```fortran
      CALL FFT3BX_fftwASL_ACC_BATCH(...,nbndloc,RHO1_,RHO2_,...)
```

- 複数bandを`cufftPlanMany`で一括実行する。
- wrapper呼出しと同期を削減する。

## 付録A5: 非局所kernelで原子順序を保持

```fortran
!$acc parallel loop gang vector_length(256) present(...)
      do iib = 1, nbndloc
!$acc loop seq
         do ia = 1, loopcnt
            ja = ia
            if (reverse_order) ja = loopcnt-ia+1
            ...
!$acc loop vector reduction(+:sr,si)
            do ig = 1, ngnl(ja)
               ...
            end do
         end do
      end do
```

- band間を並列化し、各band内の逐次`ia`適用順を保つ。
- reverse経路の逆順も維持する。

## 付録A6: OpenACC時の不要なHost復元を省略

```fortran
#ifndef _OPENACC
      call coefcp(coef0(1,1,ik0),coef(1,1,ik0),ng2q*nblng)
#endif
```

- OpenACC経路ではdevice上の`COEF0`が正本である。
- CPU/FFTW経路のHost copyは維持する。

## 付録A7: PowerPoint作成時の図表案

- スライド3: Host／Device境界を1本のフロー図で示す。
- スライド4: 計算領域をTDDFT time-step順に色分けする。
- スライド10: A100実行時間の段階的短縮を折れ線グラフにする。
- スライド11: 3プラットフォームの値は表で示し、x86の256コア条件を脚注に置く。
- スライド13: A100／H100のStep 116 NSYSとNCUを比較し、正式baselineではないと明記する。
- 変更前は灰色、GPU上で連続する区間は青、残るHost同期は橙で示す。

## 付録A8: 数値の出典

- A100／H100／x86正式値: `docs/PERFORMANCE_BASELINE.md`
- 採否と各Stepの履歴: `docs/EXPERIMENT_LOG.md`
- 現在地点と保留事項: `docs/HANDOFF.md`
- GPU化率と実装履歴: `docs/tddft_gpu_progress_summary_ja.md`
- 進捗報告用の短縮説明: `docs/PROGRESS_REPORT_2026-07-31_JA.md`
