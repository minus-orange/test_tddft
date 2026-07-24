# FPSEID21 TDDFT GPU化 PowerPoint原稿（簡略版）

この文書は、FPSEID21 TDDFTのOpenACC／cuFFT GPU化をPowerPointへ転記するための
簡略原稿である。単純なOpenACC loop化、データ常駐化、FFT最適化など、実装方式が
同じ変更は1枚へ集約した。

行番号は文書作成時点のHEADに基づく。PowerPointではファイル名とroutine名を主な
参照情報とし、行番号は補助情報として扱う。

## スライド1: タイトルと成果

### FPSEID21 TDDFTのOpenACC／cuFFTによるGPU化

- 対象: FPSEID21 TDDFT 2022 October版
- GPU: NVIDIA A100-PCIE-40GB
- 実行条件: 1 GPU / 1 MPI rank
- 検証ケース: Si111-H、100 time steps
- 実装: NVIDIA HPC SDK + OpenACC + cuFFT
- 正式採用ソース: Step 80

性能:

```text
初期cuFFT host-copy版: 約443.2秒
現在の正式baseline:    約 67.42秒
高速化:                約 6.57倍
実行時間削減:          約84.8%
```

全正式採用runで通常checkとrelaxed compareにPASSした。

参考値:

- H100でのStep 80単発runは`36.492636919秒`、check/compare PASS。
- A100正式中央値に対して約`1.85倍`だが、H100は3回測定前の参考値である。

## スライド2: GPU化の設計方針

- 計算量の大きいloopをOpenACC kernel化する。
- FFTはFFTW互換interfaceを維持したままcuFFTへ置き換える。
- 大規模配列をGPUへ常駐させ、反復H2D/D2Hを削減する。
- GPUで生成したデータをhostへ戻さず、次のGPU処理へ渡す。
- MPIやCPU処理が必要な境界だけhostへ同期する。
- 数式、配列shape、projector適用順、逐次`ia`更新順序は維持する。
- CPU/FFTW fallbackを残す。

性能採否:

- diagnostic OFFで3回測定し、中央値で比較する。
- 通常checkとrelaxed compareを両方必須とする。
- 効果のない実装は記録後にrevertする。

## スライド3: ビルド基盤とcuFFT backend

変更箇所:

- `FPSEID21/tddft_2022October/mk_ifort.sh`
- `tools/build_nvhpc.sh`
- `FPSEID21/tddft_2022October/fft_cufft.f`
- `FPSEID21/tddft_2022October/fpseid_cufft_wrap.c`
- `FPSEID21/tddft_2022October/fft_fftw.f`

ビルド条件:

```text
-O2 -acc -gpu=cc80
-gpu=mem:separate:pinnedalloc
-mp -Msave -Mlarge_arrays
```

主な変更:

- NVHPC + OpenACC + cuFFTビルド経路を追加した。
- `TDDFT_ONLY=1`でTDDFTだけをビルド可能にした。
- FFTWとcuFFTをbackendとして切り替え可能にした。
- OpenACC管理配列のdevice pointerをcuFFTへ直接渡すentryを追加した。
- `cufftPlanMany`を使うbatch FFT entryを追加した。
- CPU/FFTW側にも同名fallback entryを追加した。

主要entry:

```text
FFT3BX_fftwASL_ACC
FFT3FX_fftwASL_ACC
FFT3BX_fftwASL_ACC_BATCH
FFT3FX_fftwASL_ACC_BATCH
```

変更前後:

```text
変更前: Host -> H2D -> cuFFT -> D2H -> Host
変更後: Device上の配列 -> cuFFT -> Device上の配列
```

## スライド4: 単純なOpenACC loop化を行った箇所

同じ方式の変更を以下にまとめる。

| 対象 | ファイル／routine | GPU化内容 | 維持した条件 |
|---|---|---|---|
| S2 scatter/gather | `tmevl10_Avec_v4.f`、`S2_` | band・Gベクトル間を並列化 | `J2G` mapping |
| 局所potential | `tmevl10_Avec_v4.f`、`S2_` | `VG`生成とpotential適用 | bandごとの数式 |
| kinetic phase | `tmevl10_Avec_v4.f`、`exkin_` | coefficient要素間を並列化 | 位相計算式 |
| VPJ動径積分 | `vpj_gen.f`、`VPJ_GEN_ACC_INTEGRAL` | Gベクトル間を並列化 | 各G内の動径積分順 |
| LOCPOT | `lib4_ASL_2_check_Vext_SXACE.f`、`LOCPOT` | `G=2..NG`を並列化 | 各G内の`ITY/K/IA`順 |
| 密度scatter/集約 | `frprmn_tm12_check_Vext_Avec_v4.f`、`RHOOFK_ACC_BATCH` | band・grid間を並列化 | occupation加算順 |

代表的なdirective:

```fortran
!$acc parallel loop gang vector
```

主要な効果:

- S2 scatter: 約56秒から約0.46秒
- VPJ CPU動径積分: 約36.13秒からGPU kernel約1.8秒
- LOCPOT: 約2.765秒から約0.305秒

CPU版では同じroutineの従来host loopを維持する。

## スライド5: データ常駐化と同期削減

実装方式が同じ変更を以下にまとめる。

| 配列 | 常駐範囲 | 主な変更箇所 |
|---|---|---|
| `P` | `TMEVL`全体 | `tmevl10_Avec_v4.f` |
| `COEF`, `COEF0` | FRPRMN predictor-corrector全体 | `frprmn_tm12_check_Vext_Avec_v4.f` |
| `work2_`, `cfac_`, `ngnl_` | nonlocal phase間 | `tmevl10_Avec_v4.f` |
| `J2G`, `OCC` | time-step loop全体 | `pspw_tm11_Vext_Avec_v4_alloc.f` |
| `RAD`, `PSPOT`, `PSPOT2`, `PHIL` | time-step loop全体 | 同上 |

変更前:

```text
各routine開始時にcopyin
各routine終了時にcopyout/delete
```

変更後:

```text
外側routineがmappingを所有
内側routineはpresent参照
Host consumer直前だけupdate self
```

主な効果:

- P転送: S2単位約25.2秒からTMEVL単位約5.7秒
- TMEVLごとのCOEF D2H 944回を削除
- 必須COEF同期を約103回へ集約
- metadataの最大5,662回相当の反復copyinをloop外へ移動

## スライド6: FFTと密度再構築のbatch化

変更箇所:

- `fft_cufft.f`
- `fpseid_cufft_wrap.c`
- `fft_fftw.f`
- `tmevl10_Avec_v4.f`、`S2_`
- `frprmn_tm12_check_Vext_Avec_v4.f`、`RHOOFK_ACC_BATCH`

S2 local FFT:

```text
変更前: local bandごとにcuFFTを実行
変更後: nbndloc全体をcufftPlanManyで一括実行
```

TMEVL後の密度再構築:

- residentな`COEF`をdevice上でscatterする。
- local bandsをbatch cuFFTで変換する。
- occupation付きcharge densityをdevice上で集約する。
- MPIに必要なlocal densityだけhostへ戻す。

効果:

- `s2_fft_local`: 約22.48秒から約5.03秒
- `frprmn_rhoofk`: 約14.51秒から約0.73秒
- FFT wrapper呼び出し: 43,949回から14,685回
- Step 28からStep 33で約10.03%高速化

## スライド7: 非局所projector kernelの最適化

変更箇所:

- `tmevl10_Avec_v4.f`
  - `exnlp_only_make`
  - `exnlp_gemm`
  - `exnlp_gemm_present_inputs`
  - `exnlp_gemm_body_fused`

変更内容:

- dot productをOpenACC reduction化した。
- coefficient更新をGPU化した。
- present-input経路を追加し、内部copyinを削減した。
- dot productとcoefficient更新を同一kernelへ融合した。
- 一時配列`ct1`とゼロ初期化kernelを削除した。
- bandをgangへ割り当て、各band内の`ia`を`seq`実行した。
- forward phaseのstaging bufferをreverse phaseでも再利用した。
- `work2_`の列幅を`NGcont`から実使用最大`NGNL`へ縮小した。

維持した条件:

- 各band内の`ia`更新順序
- reverse phaseの逆順適用
- 各`ig` reduction

効果:

- kernel起動回数: 約453,120回から9,440回
- `exnlp_gemm_dot`: 約18.37秒から約8.44秒
- fused kernelの採用vector length: 256

## スライド8: FRPRMN領域の追加最適化

### VPJ_GEN動径積分

変更箇所:

- `vpj_gen.f`
- `frprmn_tm12_check_Vext_Avec_v4.f`

変更:

- Gベクトル間をOpenACC並列化した。
- static pseudopotential表をtime-step loop全体で常駐させた。
- VPJ kernelの`vector_length`を128へ調整した。

効果:

```text
Step 41: 107.75秒
Step 52:  73.44秒
改善:     約31.85%
```

### LOCPOT

変更箇所:

- `lib4_ASL_2_check_Vext_SXACE.f`
- `lib4_ASL_2_check_Vext_SXACE_gnu.f`

変更:

- Gベクトル間だけをOpenACC並列化した。
- G=0、MPI、各G内の原子・補正項の順序は維持した。

効果:

```text
LOCPOT: 2.765秒 -> 0.305秒
Step 52: 73.44秒
Step 57: 71.29秒
```

## スライド9: 不要処理の削除と再利用

### 冗長なhost COEF復元の省略

変更箇所:

- `frprmn_tm12_check_Vext_Avec_v4.f`、977～989行付近

OpenACCでは`COEF/COEF0`のdevice側が正本であり、次補正の復元もdevice上で行う。
そのためGPU経路で不要なhost `COEF0 -> COEF` copyだけを省略した。

```fortran
#ifndef _OPENACC
  call coefcp(...)
#endif
```

- CPU/FFTWのhost copyは維持した。
- host復元時間: 約2.159秒から約0.0029秒
- Step 57からStep 62で約3.81%高速化

### NONLOCのYLM再利用

変更箇所:

- `frprmn_tm12_check_Vext_Avec_v4.f`
- `tmevl10_Avec_v4.f`

変更:

- 各k-point/eventの最初のbandだけYLMを生成する。
- 2番目以降のbandでは生成済みYLMを再利用する。
- coefficient依存の`DCOEF`と`SEPPOT`は毎band実行する。

効果:

- Step 67からStep 74で約0.429%高速化
- Step 74を正式baselineとして採用

## スライド10: 採用しなかった変更と得られた知見

vector length:

- nonlocal `vector_length(512)`は256より遅く不採用
- VPJ `vector_length(64)`は128より遅く不採用

常駐範囲の拡大:

- `Vloc`のcorrection間常駐
- `COEF` allocationのtime-step全体維持
- `GDUMP` mappingの再利用
- `COEF0`のdevice初期化

いずれも正しく動作したが、同期・kernel起動・管理overheadを含むwall timeは改善しなかった。

producer側GPU生成:

- 細粒度`work2_` lookup copy
- ownershipなしのYLM GPU生成
- EXTAU 5表の一括GPU生成

転送やruntime overheadが増え、全体性能は回帰した。

kernel特殊化:

- forward/reverse別nonlocal kernel
- tutorial専用SEPPOTF s/p kernel

対象timerまたは3回中央値で有意な改善がなく、不採用とした。

## スライド11: 性能推移

| 段階 | 主な変更 | 100-step wall | 相対ソースGPU化率 |
|---|---|---:|---:|
| 初期cuFFT host-copy | FFTごとにH2D/D2H | 約443.2秒 | 対象外 |
| Step 3 | device pointer cuFFT | 約360.3秒 | 対象外 |
| Step 12 | P常駐＋冗長kernel削除 | 約172.65秒 | 対象外 |
| Step 21 | local FFT batch化 | 約146.54秒 | 57.9% |
| Step 25 | nonlocal kernel融合・調整 | 約130.61秒 | 57.9% |
| Step 33 | charge-density FFT batch化 | 約116.12秒 | 84.2% |
| Step 34 | coefficient D2H繰延べ | 約113.56秒 | 84.2% |
| Step 37 | pinned allocation | 約108.10秒 | 84.2% |
| Step 41 | static metadata常駐 | 約107.75秒 | 84.2% |
| Step 52 | VPJ動径積分GPU化 | 約73.44秒 | 89.5% |
| Step 57 | LOCPOT GPU化 | 約71.29秒 | 94.7% |
| Step 62 | 冗長host復元削除 | 約68.57秒 | 94.7% |
| Step 67 | VPJ vector length 128 | 約68.36秒 | 94.7% |
| Step 74 | YLM再利用 | 約68.07秒 | 94.7% |
| Step 80 | LDA交換相関loop GPU化 | 約67.42秒 | 100.0% |

総合結果:

```text
443.2秒 -> 67.42秒
約6.57倍高速化
実行時間を約84.8%削減
```

相対ソースGPU化率は、Step 80のNVHPC実ビルド対象にあるOpenACC compute site
19個を100%とした履歴比較値である。GPU使用率や、理論上並列化可能な全loopに対する
絶対率ではない。データ常駐、allocation、vector length、重複処理削減では
compute site数が増えないため、性能が向上しても率は同じ場合がある。

## スライド12: 現在のソースと残課題

主要ファイル:

| ファイル | GPU化内容 |
|---|---|
| `tmevl10_Avec_v4.f` | S2、exkin、nonlocal kernel、P常駐 |
| `frprmn_tm12_check_Vext_Avec_v4.f` | COEF常駐、密度再構築、YLM再利用 |
| `fft_cufft.f` | device pointer版・batch版cuFFT |
| `fpseid_cufft_wrap.c` | cuFFT wrapperとplan管理 |
| `vpj_gen.f` | VPJ動径積分kernel |
| `lib4_ASL_2_check_Vext_SXACE.f` | LOCPOT、VOFRHO、LDA交換相関 |
| `pspw_tm11_Vext_Avec_v4_alloc.f` | time-step loop外metadata常駐 |
| `tools/build_nvhpc.sh` | NVHPC、pinned allocation設定 |

現在の正式baseline:

```text
Step 80
67.4207620621 sec
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

Step 80でGPU化した交換相関:

- Si111-Hで実行されるLDA S2VXC2の独立格子点loopだけをGPU化した。
- 3回中央値でStep 74より`0.951043%`高速化した。
- 次はStep 81で改善後のFRPRMN残差を再分類する。

## 正式baselineと文書の位置づけ

- 正式baseline: 論理Step 80
- source implementation commit: `59686f0`
- pinned build-mode commit: `9cbb6bc`
- A100 3回中央値: `67.4207620621 sec`
- Step 81はStep 80 sourceを対象とした診断・分類作業である。
- PowerPointでは診断wallと正式baselineを混在させない。

# 任意付録: 変更前／変更後の実コード

以下はGit履歴に残る実コードから抜粋した。PowerPointで読みやすくするため、
宣言や変更のない処理は `...` で省略している。本編は前述の12枚のままとし、
説明が必要な方式だけを付録として追加する。

## 付録A1: cuFFTをhost copy版からdevice pointer版へ変更

対象:

- `FPSEID21/tddft_2022October/fft_cufft.f`
- `FPSEID21/tddft_2022October/fpseid_cufft_wrap.c`

変更前:

```fortran
      SUBROUTINE FFT3BX_fftwASL(...)
      ...
      call fpseid_cufft_exec(plancbp,RHOG,NG,1,ierr)
```

変更後:

```fortran
      SUBROUTINE FFT3BX_fftwASL_ACC(...)
      ...
!$acc host_data use_device(RHOG)
      call fpseid_cufft_exec_device(plancbp,RHOG,NG,1,ierr)
!$acc end host_data
```

要点:

- 変更前はwrapper内でhost/deviceコピーを伴う実行経路だった。
- 変更後はOpenACC配列のdevice pointerをcuFFTへ直接渡す。
- 同じ方式でforward FFTとbatch FFTも実装した。

## 付録A2: 単純OpenACC化でscatter loopを平坦化

対象:

- `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- `S2_`

変更前:

```fortran
!$acc parallel loop present(P(...),RHO1_(...),J2G(...))
      do ib=nbegin,nend
       iib=ib-nbegin+1
         DO 100 IG=1,NXYZ
         JG=J2G(IG)
  100    RHO1_(JG,iib)=P(IG,iib)
      enddo
```

変更後:

```fortran
!$acc parallel loop present(P(...),RHO1_(...),J2G(...))
      do idx=1,NXYZ*nbndloc
         IG=mod(idx-1,NXYZ)+1
         iib=(idx-1)/NXYZ+1
         JG=J2G(IG)
         RHO1_(JG,iib)=P(IG,iib)
      enddo
```

要点:

- bandと格子点の二重loopを1本のGPU loopへ平坦化した。
- 小さい外側loopごとのkernel分割を避け、GPU並列度を増やした。
- 同種の単純OpenACC化は密度生成、LOCPOT、VOFRHO、VPJにも適用した。

## 付録A3: bandごとのFFTをbatch FFTへ集約

対象:

- `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- `FPSEID21/tddft_2022October/fft_cufft.f`

変更前:

```fortran
      do ib=nbegin,nend
       iib=ib-nbegin+1
       CALL FFT3BX_fftwASL_ACC(NRX,NRY,NRZ,NXYZ,
     & RHO1_(1,iib),RHO2_(1,iib),plancfp,plancbp)
      enddo
```

変更後:

```fortran
      CALL FFT3BX_fftwASL_ACC_BATCH(NRX,NRY,NRZ,NXYZ,
     & nbndloc,RHO1_,RHO2_,plancfp,plancbp)
```

要点:

- 変更前はband数だけcuFFTを呼び出していた。
- 変更後は複数bandを1回のbatch cuFFTで処理する。
- forward FFTにも同じ変更を適用し、呼出し回数と同期を削減した。

## 付録A4: nonlocal kernelを原子単位からband単位へ融合

対象:

- `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- `exnlp_gemm_body_fused`

変更前:

```fortran
      do ia = 1, loopcnt
         ja = ia
         if (reverse_order) ja = loopcnt-ia+1
!$acc parallel loop gang present(...)
         do iib = 1, nbndloc
            ...
!$acc loop vector reduction(+:sr,si)
            do ig = 1, ngnl(ja)
               ...
            end do
         end do
      end do
```

変更後:

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

要点:

- 変更前は原子loopごとにGPU kernelを起動していた。
- 変更後はbandを外側のGPU並列loopとし、原子処理を1 kernel内に融合した。
- kernel起動回数を減らし、band方向の並列性を利用した。

## 付録A5: OpenACC時の不要なhost COEF復元を除去

対象:

- `FPSEID21/tddft_2022October/frprmn_tm12_check_Vext_Avec_v4.f`

変更前:

```fortran
       nblng=nend(my_rank)-nbegin(my_rank)+1
       do ik0=1,numkq
       call coefcp(coef0(1,1,ik0),coef(1,1,ik0),
     &             ng2q*nblng)
       enddo
```

変更後:

```fortran
#ifndef _OPENACC
c *** CPU/FFTW restart state.
       nblng=nend(my_rank)-nbegin(my_rank)+1
       do ik0=1,numkq
       call coefcp(coef0(1,1,ik0),coef(1,1,ik0),
     &             ng2q*nblng)
       enddo
#endif
```

要点:

- OpenACC経路ではdevice上の `COEF0` が正本であり、host側 `COEF` への復元は不要だった。
- CPU/FFTW経路の処理はプリプロセッサ条件で維持した。
- 正しさを保ったまま、反復ごとのhostコピー処理を省いた。

## 付録A6: band間で不変なYLMを再利用

対象:

- `FPSEID21/tddft_2022October/frprmn_tm12_check_Vext_Avec_v4.f`
- `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- `NONLOC`

変更前:

```fortran
      do ib=nbegin(my_rank),nend(my_rank)
         ...
         CALL NONLOC(...,NGcont)
      enddo

c --- NONLOC内
      DO 588 IG=1,NG2
  588 RHOA(IG)=SQRT(G2(4,IG))*TPIBA
      CALL GETYLM(NG2Q,NGcont,G2,RHOA,YLM,TPIBA,NGcont)
      CALL SEPPOT(...)
```

変更後:

```fortran
      iylm_reuse=0
      do ib=nbegin(my_rank),nend(my_rank)
         ...
         CALL NONLOC(...,NGcont,iylm_reuse)
         iylm_reuse=1
      enddo

c --- NONLOC内
      IF (IYLM_REUSE.EQ.0) THEN
         ...
         CALL GETYLM(NG2Q,NGcont,G2,RHOA,YLM,TPIBA,NGcont)
      ENDIF
      CALL SEPPOT(...)
```

要点:

- `YLM` は同一k点のband間で不変である。
- 最初のbandだけ計算し、以後のbandでは結果を再利用する。
- 数値計算の内容を変えず、重複計算を削減した。

## 付録A7: 実行されるLDA交換相関loopをGPU化

対象:

- `FPSEID21/tddft_2022October/lib4_ASL_2_check_Vext_SXACE.f`
- routine `S2VXC2`

変更前:

```fortran
      DO 10 IG=1,NXYZ
      VCSR(IG)=0.D0
      IF(RHO(IG).GT.0.D0) THEN
         ...
      ENDIF
   10 CONTINUE
```

変更後:

```fortran
!$acc parallel loop copyin(RHO(1:NXYZ))
!$acc& copyout(VCSR(1:NXYZ))
!$acc& private(RS,EC,VX,CC,VC,VXC2)
      DO 10 IG=1,NXYZ
      VCSR(IG)=0.D0
      IF(RHO(IG).GT.0.D0) THEN
         ...
      ENDIF
   10 CONTINUE
```

要点:

- 診断によりSi111-HがGGAではなくLDA S2VXC2を通ることを確認してから変更した。
- 格子点間で独立なloopだけをGPU化し、分岐と各格子点内の数式順序を維持した。
- Step 74比で3回中央値を`0.951043%`短縮した。

## 付録コードを載せる場合の推奨構成

- 本編では変更を「単純OpenACC化」「データ常駐」「FFT集約」
  「kernel融合」「重複処理削減」の5種類に集約する。
- 発表時間が短い場合は、付録A2、A3、A5だけを使用する。
- 技術説明を重視する場合は、A1からA7までを末尾へ追加する。
- PowerPointでは変更前を灰色、変更後の追加行とOpenACC指示行を青色で示す。
