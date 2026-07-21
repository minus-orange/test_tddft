# TDDFT GPU常駐化方針

> [English version](tddft_gpu_residency_plan_en.md)

> この日本語版は、TDDFTのGPU常駐化方針を実装順に読めるよう整理しています。
> 配列名、routine名、OpenACC directive、ビルド変数はソースと一致させるため原表記を維持します。

## 用語メモ

- **GPU常駐（residency）**: 複数の処理にまたがって配列をGPUメモリ上に保持する設計です。
- **ownership（所有責任）**: どのroutineがdevice mappingの作成、同期、削除を担当するかを表します。
- **authority（正本）**: HostとDeviceのどちらの値を最新かつ正しい値として扱うかを表します。
- **data region**: OpenACCで配列のGPU上の寿命を囲む範囲です。
- **host_data use_device**: OpenACC管理配列のdevice pointerをcuFFTなどのCUDAライブラリへ渡す仕組みです。

日付: 2026-07-09

このメモは、FPSEID21 TDDFT `Si111-H` 検証ケースに対する次のGPU最適化方針を
記録します。対象は、現在確認している1 GPU / 1 MPI rankの経路です。最初の
実装手段はOpenACCとし、cuFFTなどのCUDAライブラリは使用可とします。ただし、
独自CUDAカーネルを書く実装は最初の対象から外します。

実装済みの内容と各 step の測定結果は
`docs/tddft_gpu_progress_summary.md` にまとめています。

## ゴール

このブランチのゴールは、TDDFT のタイムステップ内部を実用上可能な範囲で GPU
実行へ移し、タイムステップループ中の Host-Device 間メモリ転送を最小化すること
です。

初期対象は `s2_fft_local` でしたが、これは最初に効果が大きい転送ボトルネック
だったためです。今後の最適化境界は伝播経路全体へ広げます。ただし、検証済みの
CPU/FFTW 経路と、現在の 1 GPU / 1 MPI rank 検証方針は維持します。

## 現状

cuFFT版は、コミット済みGNU基準とのrelaxed比較で許容範囲に入っています。

100 stepのprofile比較:

| backend | `time_step_total` | `tmevl_s2` | `s2_fft_local` | `fft_wrapper` |
|---|---:|---:|---:|---:|
| FFTW | 501.068871秒 | 357.088483秒 | 234.100450秒 | 163.592244秒 |
| cuFFT | 443.502158秒 | 306.979328秒 | 183.825464秒 | 100.969549秒 |
| cuFFT + detailed timer | 450.275156秒 | 312.923191秒 | 190.457058秒 | 109.613606秒 |

cuFFT詳細profile:

| 項目 | 値 |
|---|---:|
| cuFFT calls | 336589 |
| HostからDeviceへのcopy | 47.947526631秒 |
| cuFFT実行 | 15.640776237秒 |
| DeviceからHostへのcopy | 41.666117352秒 |
| wrapper合計 | 105.254420208秒 |

支配的なコストはFFTカーネルではなく、Host <-> Device転送です。

## ソース上のデータフロー

ホット領域は `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f` の `S2_` です。

| profile label | source上の処理 |
|---|---|
| `tmevl_s2` | `S2_`全体 |
| `s2_nonlocal` | `exnlp_only_make`と`exnlp_gemm`による非局所擬ポテンシャル |
| `s2_fft_local` | 局所ポテンシャルFFT部 |
| `fft_wrapper` | 個々のFFT wrapper呼び出し |

`s2_fft_local`内のdata flow:

1. `J2G`を使って`P(IG,iib)`を`RHO1_(JG,iib)`へscatterします。
2. bandごとにinverse FFTを実行します。
3. `VG(I)=VGG(I)+Vloc(I)`を作ります。
4. 局所ポテンシャルのphase factorを`RHO2_`へ適用します。
5. bandごとにforward FFTを実行します。
6. `RHO2_(JG,iib)`を`P(IG,iib)`へgatherします。

`RHO1_(NXYZ,mxbnd)` と `RHO2_(NXYZ,mxbnd)` は、各bandスライスがFortran配列上で
連続しているため、最初にGPU常駐化する対象として扱いやすいです。

## 実装方針

TDDFTのFortran側では、GPU常駐配列と要素ごとの処理をOpenACCで表現します。
FFT操作のみ、ライブラリbackendとしてcuFFTを使います。

実務上は以下の方針です。

- 新しいTDDFT GPU化では `!$acc data`, `!$acc parallel loop`,
  `!$acc kernels`, `!$acc host_data use_device(...)` を優先します。
- 独自CUDAカーネルを主実装として追加しません。
- 既存のCPU/FFTW経路、およびGNU/Intel向けsource variantは維持します。
- cuFFTはOpenACC管理下のdevice bufferに対して動作するライブラリ呼び出しとして
  扱います。
- 既存のhost-copy型cuFFT wrapperは互換性維持用として残し、OpenACC管理配列用に
  device pointerを受け取る別APIを追加します。

## cuFFT Wrapper API境界

現行のcuFFT wrapperは、host配列をprivate CUDA bufferへコピーし、cuFFTを実行して
結果をhostへ戻します。この経路は検証済みのため、互換backendとして残します。

OpenACC常駐化用には、device pointerを受け取り、host-device copyを行わない
第2のwrapper interfaceを追加します。

```text
existing compatibility API:
  host array -> wrapper H2D -> cuFFT -> wrapper D2H -> host array

new OpenACC API:
  OpenACC device array -> host_data use_device -> cuFFT only
```

新しいdevice-pointer経路では以下を前提にします。

- 入力pointerはすでに有効なdevice pointerである。
- cuFFTはin-placeで実行する。
- cuFFT正規化は必要に応じてFortran側OpenACC loopで行う。
- エラー時に暗黙のhost copy fallbackを行わない。

この分離は重要です。OpenACC経路が誤ってhost-copy wrapperを呼ぶと、転送時間が
支配的なままで、GPU常駐化の検証になりません。

## 実装順序

`S2_` のlocal FFT部にOpenACC data regionを追加し、local FFTペアの処理中に
`RHO1_`, `RHO2_`, local potential vectorをGPU上に保持します。

期待する効果:

- Fortran側でdata movementを明示し、計測可能にします。
- OpenACCとcuFFTの相互運用に安定した境界を作ります。
- 配列寿命が明確になる前に独自CUDA kernelを追加しません。

最初のdata region境界は意図的に狭くします。

```text
CPU側の非局所項処理が完了
local FFT部に必要な P, VGG, Vloc, J2G をdeviceへ転送
RHO1_, RHO2_, VG をdevice上で作成または保持
local FFT部をdevice上で実行
CPU側処理へ戻る前に P をhostへ戻す
```

非局所項をCPU側に残す段階では、この境界によりCPU/GPUの所有関係を明確にします。

初期実装メモ:

- Step 1では、既存のhost-copy型FFT wrapperを呼ぶ移行状態を許容します。
- その場合、FFT呼び出し前に `!$acc update self(...)`、FFT呼び出し後に
  `!$acc update device(...)` を明示します。
- この段階ではFFT転送オーバーヘッドはまだ削減されません。Step 2で
  device-pointer cuFFT APIを追加する前に、OpenACC data lifetimeと同期境界を
  検証することを目的とします。

OpenACC管理下のdevice memoryに対して、active band blockをcuFFTで処理します。
Fortran側ではcuFFT呼び出しの周囲で `!$acc host_data use_device(...)` を使い、
C wrapper内部でbandごとにprivate CUDA bufferへコピーする方式を減らします。

```fortran
RHO2_(I,iib)=dcmplx(dcos(fac),-dsin(fac))*RHO1_(I,iib)
```

```text
OpenACC data region for RHO1_/RHO2_/VG
cuFFT inverse/bx using OpenACC device pointer
OpenACC local-potential multiply using VG
cuFFT forward/fx using OpenACC device pointer
OpenACC scaling
copy out only the data required by the following CPU-side section
```

`VG` は、検証上の理由で一時的にCPU生成が必要な場合を除き、GPU上で `VGG` と
`Vloc` から作ります。

```fortran
VG(I)=VGG(I)+Vloc(I)
```

2つの `s2_nonlocal` 領域は、まずCPU側に残します。ローカルFFT部の常駐化が
正しく動くことを確認してから、次段階として検討します。

Step 3後も転送が支配的な場合に、`P`/`J2G` のscatter/gatherや非局所GEMMの
GPU化を検討します。

## 確認方法

```sh
LABEL=<label> ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/

python3 ./tools/check_tddft_result.py check \
  ./run/tddft_archives/<label>/tddft.out \
  --err ./run/tddft_archives/<label>/tddft.err

python3 ./tools/check_tddft_result.py compare \
  ./run/tddft_archives/<label>/tddft.err
```

正当性確認は、特にstrict確認を指定しない限り、既存のTDDFT relaxed比較基準を
使います。

OpenACC常駐化の初期変更では、100 step relaxed比較に進む前に短時間のstrict寄り
確認も行います。

```text
1. 2 step、または実用上最小のTDDFT runを実行する。
2. check_tddft_result.py checkがPASSすることを確認する。
3. 可能な範囲で厳しいtoleranceを使い、検証済み出力と比較する。
4. その後に100 stepのrelaxed比較を実行する。
```

目的は、同期ミス、古いdevice dataの使用、host-copy cuFFT wrapperの誤使用を
早い段階で検出することです。

## NVHPC OpenACCビルドメモ

OpenACC経路は、NVHPCのOpenACC flagを明示してビルドします。GPU architecture flag
は環境依存でよいですが、OpenACC modeであることがビルドコマンド上で分かる
ようにします。

```sh
BUILD_REPORT=1
FFLAGS="-O2 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays -Kieee"
FFT_BACKEND=cufft
```

`BUILD_REPORT=1` はcompiler report flagを追加し、最終的なビルド設定を表示します。
NVHPCでのdefault report flagは以下です。

```sh
REPORT_FLAGS="-Minfo=accel -Minfo=mp"
```

このreportにより、`S2_` のOpenACC regionが認識されているか、既存CPU OpenMP
regionが想定通りコンパイルされているかを確認します。

cuFFT linkは既存のcuFFT library設定を継続します。OpenACC device-pointer wrapper
がCUDA runtime型やcuFFT宣言を必要とする場合、include/library pathは検証済み
cuFFTビルドと同様に明示します。

## 現時点の判断

現在の検証済み方針は以下です。

- Fortran 側の GPU 常駐化と kernel 化には OpenACC を使います。
- FFT は OpenACC device pointer 経由の cuFFT library backend を使います。
- 当面は独自 CUDA kernel を追加しません。
- 検証対象は 1 GPU / 1 MPI rank とします。
- 常駐範囲は局所的な `S2_` 区間から TDDFT time-step 内部全体へ広げます。

次のコーディング対象は、物理 routine を一括で置き換えるのではなく、測定コストに
基づいて選びます。最新の検証済み実行後、次の候補は以下です。

1. `exnlp_gemm_enter` の setup/copy cost を削減します。
2. `ia` の逐次依存を変えずに、`exnlp_gemm_dot` と `exnlp_gemm_update` の kernel
   構造を改善します。
3. まだ host-copy cuFFT wrapper を使っている互換 FFT 呼び出しを特定します。
4. `TMEVL` 境界に残る `P` 転送を削減します。

## Step 47 rollback後の性能方針

TDDFTの主要数式に、原理的にGPU実行できない処理はありません。ただし、現在の
実装境界のままでは完全なdevice-only化が難しい箇所があります。

- SCF収束判定は小さなscalarをhostで読み、loop継続を判断します。
- density・forceのMPI集約と後続host consumerは現状host authorityです。
- ion/外場更新とpotential再生成はhost producerに接続されています。
- 出力、checkpoint、reference確認には必要時のD2Hが必要です。
- CPU/FFTW fallbackは維持するため、host実行文自体は削除しません。

したがって目標は、全処理を無条件にdevice-only化することではありません。大規模
配列を可能な限り広い区間でresident化し、hostへ戻すデータを収束判定scalar、
MPI/force境界で必要な値、出力対象だけへ限定します。

現在の主な阻害要因と方針は以下です。

1. `ELECTF/NONLOCF`がhost上の`COEF`を読むため、FRPRMN終了時のCOEF D2Hを
   まだ除去できません。まず`ELECTF`内部を`LOCPOTF`、`NONLOCF`、主要reduction
   へtimer分割し、その後`NONLOCF`のbounded consumerを段階的にGPU化します。
2. `work2_`のdevice直接生成には`YLM`、`VPJ`、`EXTAU`のownershipが必要です。
   B1とStep 20の既知悪化があるため、producer入力をbulk resident化できる設計なしに
   再着手しません。
3. density側のD2HはMPI、収束判定、host potential生成が直後に読むため、consumerを
   一緒に移すまでは維持します。
4. reduction順序の変更は丸め差へ影響するため、通常checkとrelaxed compareを維持し、
   数値アルゴリズム変更として別承認なしに行いません。

性能を出す鍵は、GPU化routine数ではなくGPUの連続稼働時間です。Step 41 run 02では
`tmevl_total`が`51.442021 / 108.026444`秒、すなわち全体の`47.620%`を占めます。
この領域はGPU主体ですが、Step 38 Nsight Systemsから逆算したCUDA kernel合計は
trace wallの約`11.3%`にとどまります。明示的H2D/D2Hは合計約`1.55%`です。
したがって現在の主な問題は、転送帯域そのものより、host準備、細粒度launch、同期、
runtime呼び出し、低並列度launch、GPU idleによってGPU化領域が分断されていることです。

アルゴリズム領域として確実にGPU主体といえる比率は約`48%`で、未分解の混在処理を
含めた実務的な推定範囲は`48-55%`です。この値をCUDA kernelの純粋な実行時間比と
混同しません。また、Step 38はStep 41のJ2G/OCC常駐化前なので、現在の転送回数を
確定する資料ではありません。

次の作業順序は以下です。

1. rollback済みの正式Step 41 sourceをNsight Systemsで再診断し、H2D/D2H、CUDA
   kernel、CUDA/OpenACC API、同期、allocation、OS runtimeを同じtraceで取得します。
2. Step 41 run 02で`frprmn - tmevl_total = 47.476614`秒ある未分解領域を、既存sourceと
   traceでCPU演算、MPI、runtime/API、同期、GPU idleへ分離します。
3. traceだけで最大成分を特定できない場合に限り、default OFFの診断timerを追加します。
4. 診断結果から、広いdata residency区間または十分な仕事量を持つbatch/fusionとして
   実装可能な仮説を1件だけ選びます。
5. 大規模配列のauthorityをFRPRMN/TMEVL、必要ならELECTFまで広げ、転送をloop入口、
   必須MPI/host consumer、出力へ集約します。
6. 最後にdensity/MPI/ion/output境界を再監査し、不可避な最小D2Hだけを残します。

Step 47のSEPPOTF専用GPU経路はcorrectness PASSでしたが、約250行の追加に対して
中央値改善が`0.0291%`だけだったため不採用・rollback済みです。単独routineを小さい
kernelへ移すだけの同形実装は再試行しません。Step 45のtime-step全体COEF allocation、
Step 42のVloc常駐化も同じ形では再試行しません。

細粒度section copy、Step 31型GDUMP再利用、ownership未設計のYLM/`work2_`経路、
小band専用kernelは再試行しません。異なるhardwareや入力サイズは独立baselineで
評価します。

## Step 52採用後の更新

Step 48-51で上記FRPRMN未分解領域を再診断し、`Part1to5`内の`VPJ_GEN` CPU動径積分
`36.132464`秒を主因として特定しました。Step 52実装`22aad92`でこの積分だけを
GPU化し、3回中央値`73.4374880791`秒、Step 41比`31.8472%`高速となったため、
Step 52を正式baselineとして採用しました。

これ以前の「次の作業順序」は完了済みの履歴です。現在の次テーマは追加最適化ではなく、
正式Step 52 sourceのNsight Systems再計測です。残る`13.149986`秒のFRPRMN残差を含め、
CUDA kernel、H2D/D2H、runtime/API、同期、MPI、GPU idleを再分類してから、次の
bounded hypothesisを1件だけ選びます。trace wallは性能baselineに使用しません。

Step 53で再計測は完了しました。CUDA kernelはtrace wallの約`18.7%`、新VPJ kernelは
`1.793293070`秒でした。FRPRMN残差`13.608745`秒からVPJ kernelを除いた
`11.815452`秒のhost/wait envelopeが次の診断対象です。Step 54では既存timer外の
predictor/corrector制御、energy/reduction、density、updateをdefault-off timerで
分け、結果が返るまで追加最適化を選びません。

## Step 57採用後の更新

Step 54-56の診断でLOCPOTを主要なCPU支配区間として分離し、Step 57実装
`8646707`でLOCPOTだけをGベクトル間でGPU並列化しました。3回のdiagnostic-OFF runは
すべてcheck/compare PASS、中央値`71.2909028530`秒、実行幅`0.1379821301`秒でした。
Step 52比`2.9230%`高速で、FRPRMN中央値も`2.117284`秒短縮したため、Step 57を正式
baselineとして採用します。

次は追加最適化ではなく、正式Step 57 sourceのNsight Systems再診断です。LOCPOT kernel、
CUDA kernel合計、H2D/D2H、runtime/API、同期、MPI、GPU idleをStep 53と比較してから、
新しいbounded hypothesisを1件だけ選びます。trace wallは性能baselineに使用しません。

Step 58の正式Step 57 source再traceはcheck/compare PASSでした。CUDA kernel合計は
約`14.29`秒でStep 53とほぼ同じでした。LOCPOT追加に対応してH2Dは6,756回、D2Hは
606回増えましたが、転送時間の増加は合計`0.208290190`秒です。MPI reportは空でした。
LOCPOT kernel時間を写真の集計行から独立同定できなかったため、次は既存timerだけを
有効化して現在のLOCPOT全区間を測るStep 59診断とします。追加最適化は選びません。

Step 59で現行LOCPOTは`0.305052`秒と測定され、Step 56比`88.9673%`削減を直接確認
しました。Vloc全体も`83.5537%`削減され、LOCPOTは現行FRPRMN残差の`2.8533%`
です。次は残る最大既知host区間であるVRHO controlをseed、predictor、correctorの
3排他区間へ分けるStep 60診断とし、結果前に追加最適化を選びません。

Step 60ではVRHO control `2.787119`秒のうちcorrectorが`2.215861`秒
（`79.5036%`）、seedが`0.552540`秒、predictorが`0.016408`秒でした。次は
correctorをinterpolation計算、収束判定、COEF/VGOLD復元へ分けるStep 61診断です。
結果前に追加最適化を選びません。

Step 61ではcorrector `2.240276`秒のうち、失敗補正後のCOEF/VGOLD復元が
`2.158536`秒（`96.3513%`）でした。OpenACCのCOEF/COEF0はdevice常駐し、次補正の
復元もdevice-localなので、このhost COEF0-to-COEF copyはGPU経路では不要です。
Step 62はこのcopyだけを`_OPENACC`時に省略し、VGOLD、device復元、MPI、CPU fallbackを
維持する単一性能仮説とします。

Step 62 run 01は両correctness checkにPASSし、wallは`68.66669352055`秒で正式
Step 57中央値より`3.6810%`短い値でした。run 02/03と3回中央値の確認まではStep 57を
正式baselineとして維持します。

run 02/03も両checkにPASSしました。3回中央値は`68.5734798908`秒、実行幅は
`0.17894752025`秒で、Step 57より`3.811739%`高速です。Step 62を正式採用し、以後の
性能仮説はこのbaselineと比較します。

Step 63では追加最適化を行わず、正式Step 62 sourceで既存の広域FRPRMN timerを再実行
します。Step 57/62以前の古い内訳ではなく、現行残差から次の仮説を選びます。

Step 63で現行残差`8.547452`秒の`99.5381%`を分類し、最大排他区間は
`part1to5=2.137278`秒でした。追加実装前に既存の子timerを現行sourceで再実行します。

Step 64は既存のdefault-off子timerを1コマンドhelperから再利用する測定専用診断です。
ソース最適化は含みません。

Step 64ではlegacy VPJ integral区間が`1.910793`秒、MPIは`0.039413`秒でした。Step 65で
legacy区間をhost zeroing、VPP2 setup、GPU kernel＋D2H同期へ分けてから仮説を選びます。

Step 65はこの3区間を分けるtimer専用診断で、diagnostic-off経路と演算は変更しません。

Step 65ではOpenACC kernel＋D2Hが親の`97.5411%`で、host zeroing 2区間の合計は
`0.039393`秒でした。Step 66でkernel waitとD2Hを分けてから次の仮説を選びます。
