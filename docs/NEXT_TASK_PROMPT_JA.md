# FPSEID21 TDDFT 次タスク引き継ぎプロンプト

以下を新しいCodexタスクの最初のメッセージとして使用する。

---

あなたはFPSEID21 TDDFT OpenACC GPU化作業のMainです。旧会話の記憶ではなく、
Git、リポジトリ文書、実測archiveを正本として現在地点を再構築してください。

対象checkout:
`/Users/adabana/Documents/Codex/2026-07-14/fpseid21-tddft-openacc-gpu-users-adabana/repo`

対象branch: `tddft-openacc-residency`

最初に適用される`AGENTS.md`を全文読み、続いて少なくとも以下を確認してください。

- `docs/HANDOFF.md`
- `docs/PERFORMANCE_BASELINE.md`
- `docs/EXPERIMENT_LOG.md`
- `docs/tddft_gpu_residency_plan_ja.md`
- `docs/tddft_gpu_progress_summary_ja.md`
- `docs/tddft_gpu_progress_summary_en.md`
- `docs/VALIDATION_WORKFLOW.md`

開始時にbranch、HEAD、originとの差、tracked/staged/untracked差分を確認し、ユーザー所有の
未追跡ファイルを変更、削除、stageしないでください。

正式baselineは論理Step 107です。

- source implementation: `c46cfa9`
- pinned build mode: `9cbb6bc`
- A100-PCIE-40GB、1 GPU / 1 MPI rank
- NVHPC + OpenACC + cuFFT
- `-gpu=mem:separate:pinnedalloc`
- Si111-H、100 steps
- diagnostic OFF 3回中央値: `63.2135219574 sec`
- 3回range: `0.1034331322 sec`
- 実行幅: `0.1034331322 sec`
- 全runでnormal checkとrelaxed compare PASS

Step 86はStep 82までの採用済みGPU化を保持し、HLOCALのzero、scatter、cuFFT往復、
局所ポテンシャル積、gatherを1個の一時device data region内で完結させています。
CPU/FFTW fallback、数式、MPI境界は維持しています。Step 82中央値より
`0.1519150734 sec`（`0.22791%`）高速で、全3 runのcorrectnessと性能採否gateを満たして
正式採用済みです。最新HEADを自動的にbaseline扱いしない原則は維持します。

最終ゴールは、タイムステップループ内を可能な限りGPU化し、大規模配列のhost/device
転送をloop入口、必須MPI/host consumer、出力へ集約して最小化することです。ただし、
性能を出す鍵はGPU化routine数ではなくGPUの連続稼働時間です。

現時点の確定値:

- Step 82 median-wall run 03 `time_step_total`: `66.852572 sec`
- `frprmn`: `57.830151 sec`
- `tmevl_total`: `51.135678 sec`
- `frprmn - tmevl_total`: `6.694473 sec`
- `s2_nonlocal`: `11.383683 sec`
- `exnlp_gemm_dot`: `8.350857 sec`
- Step 51で判明した旧`VPJ_GEN` CPU積分: `36.132464 sec`

Step 48のNsight値はStep 52/57 GPU化より前なので、現在のkernel時間・転送回数・
同期構造ではありません。

Step 53による正式Step 52 sourceのNsight Systems再診断は完了済みです。

1. Step 53 trace wallは`76.0769960680 sec`で、check/compareはPASS。
2. CUDA kernel合計は約`14.26 sec`、新VPJ kernelは`1.793293070 sec`。
3. FRPRMN残差`13.608745 sec`からVPJ kernelを除いた`11.815452 sec`に、CPU/host処理と
   未分解waitが残る。
4. MPIはStep 48全run上限`0.260338098 sec`、Step 51 scoped値`0.037303 sec`で主因ではない。
5. Step 54 default-OFF timer診断は完了し、FRPRMN残差`13.094395 sec`のうち
   `13.084581 sec`、`99.9251%`を分解できた。
6. 最大区間は`frprmn_vrho_mix=3.923983 sec`、次点は
   `frprmn_vloc_prepare=2.940147 sec`。
7. Step 55診断は完了し、`frprmn_vrho_mix=3.943543 sec`のうち、
   VOFRHOは`0.937779 sec`、smoothing/FFTは`0.161545 sec`、
   interpolation/convergence/controlは`2.841719 sec`だった。
8. VRHOの`72.0600%`はhost controlで、smoothing/FFTは`4.0964%`にすぎない。
9. Step 56診断は完了し、`frprmn_vloc_prepare=2.947276 sec`のうち、
   LOCPOTは`2.764985 sec`、smoothing/FFTは`0.152869 sec`、その他は
   `0.029422 sec`だった。
10. LOCPOTはVlocの`93.8149%`で、OpenACC/CUDA処理を含まない。既存MPI上限から、
    少なくとも約`2.504647 sec`はCPU計算・host orchestrationと分類できる。
11. Step 57の3 runはすべてcheck/compare PASS。wallは`71.2373509407`、
    `71.2909028530`、`71.3753330708 sec`で、中央値と実行幅は上記の通り。
12. Step 57中央値の`frprmn`はStep 52から`2.117284 sec`減り、FRPRMN残差は
    `2.660213 sec`減ったため、LOCPOT仮説と整合して正式採用した。
13. Step 58はcheck/compare PASS。trace wallは`74.2175440788 sec`でbaselineではない。
    CUDA kernel合計は約`14.29 sec`でStep 53とほぼ同じ。MPI reportは再び空だった。
14. Step 53比でH2Dは6,756回・`844.619 MB`・`0.183726804 sec`、D2Hは606回・
    `281.417 MB`・`0.024563386 sec`増えた。606 D2HはLOCPOT 6回×FRPRMN 101回と一致する。
15. Step 59はcheck/compare PASS。現行LOCPOTは`0.305052 sec`で、Step 56比
    `2.459933 sec`（`88.9673%`）減った。Vloc全体も`83.5537%`減った。
16. LOCPOTは現行FRPRMN残差の`2.8533%`まで低下し、Step 57仮説を直接確認できた。
17. Step 60はcheck/compare PASS。VRHO control `2.787119 sec`のうち、correctorは
    `2.215861 sec`（`79.5036%`）、seedは`0.552540 sec`、predictorは`0.016408 sec`。
18. Step 61はcheck/compare PASS。corrector `2.240276 sec`のうち、host COEF0-to-COEF
    とVGOLD復元は`2.158536 sec`（`96.3513%`）、interpolationは`0.057358 sec`、
    VGCONVは`0.014480 sec`だった。
19. OpenACCではCOEF/COEF0が補正列全体でdevice常駐し、次補正のCOEF復元も既にdevice-local。
    失敗補正後のhost COEF0-to-COEF copyはdevice authorityを更新せず、CPU/FFTWだけに必要。
20. Step 62は、このhost copyだけを`_OPENACC`時に省略する単一性能仮説。VGOLD、device復元、
    MPI、数式順序は維持している。
21. Step 62のwallは`68.66669352055`、`68.4877460003`、`68.5734798908 sec`で全run
    check/compare PASS。中央値`68.5734798908 sec`、実行幅`0.17894752025 sec`。
22. Step 57比`2.7174229622 sec`（`3.811739%`）高速で、median-wall runのFRPRMN残差も
    `2.103294 sec`減り、Step 61の復元計測値と整合するため正式採用した。
23. 次は追加最適化ではなく、既存の広域timerを正式Step 62 sourceで再実行するStep 63。
    `./tools/run_tddft_step63.sh`を1回だけ実行し、現行FRPRMN残差を再分類する。
24. Step 63はcheck/compare PASS。FRPRMN残差`8.547452 sec`の`99.5381%`を再分類した。
    最大は`part1to5=2.137278 sec`（`25.0049%`）、次いでVRHO mix `1.801928 sec`、
    EXTAU `1.468457 sec`、energy diagnostic `0.933094 sec`。
25. 次は追加最適化ではなく、既存timerで現行`part1to5`をGETYLM、VPJ integral、MPI、
    post-reductionへ再分解してから、単一仮説を選ぶ。
26. A100では`./tools/run_tddft_step64.sh`を1回だけ実行する。diagnostic wallはbaselineに
    使用せず、通常checkとrelaxed compareを必須とする。
27. Step 64はcheck/compare PASS。`part1to5=2.140208 sec`のうち、GETYLM `0.054554`、
    legacy名`vpjgen_cpu_integral` `1.910793`、MPI `0.039413`、post-reduction
    `0.088664 sec`で、子coverageは`97.8140%`。
28. OpenACC時のlegacy timerはhost zeroing、VPP2 setup、GPU integral、必須D2Hを含む。
    次は追加最適化ではなく、この内訳を分けるStep 65診断。
29. Step 65はdefault-off timerだけを追加し、`./tools/run_tddft_step65.sh`を1回実行する。
    loop、数式、MPI、ownership、diagnostic-off経路は変更しない。
30. Step 65はcheck/compare PASS。legacy parent `1.920204 sec`のうちhost zeroing
    `0.037640`、VPP2 zeroing `0.001753`、OpenACC kernel＋D2H `1.872989 sec`
    （`97.5411%`）。host初期化省略は有力でない。
31. 次は追加最適化ではなく、既存同期境界でkernel completionとD2Hを分けるStep 66。
    diagnostic buildだけに明示waitを入れ、diagnostic-off経路は変更しない。
32. A100では`./tools/run_tddft_step66.sh`を1回だけ実行し、通常checkとrelaxed compareを
    必須とする。diagnostic wallはbaselineに使用しない。
33. Step 66はcheck/compare PASS。kernel＋D2H parent `1.886449 sec`のうちkernel完了
    `1.831545 sec`（`97.0896%`）、D2H `0.047825 sec`（`2.5352%`）。
34. 次の単一性能仮説はVPJ kernelだけの`vector_length(256)`を`128`へ変更すること。
    radial加算順、数式、ownership、D2H、MPIは維持し、diagnostic OFF 3回中央値で採否する。
35. Step 67初回は`./tools/run_tddft_step67.sh 01`だけを実行し、PASS/PASSならrun 02/03を
    `./tools/run_tddft_step67.sh 02-03`の1コマンドで取得する。
36. Step 67 run 01はcheck/compare PASS、wall `68.4441161156 sec`。Step 62中央値より
    `0.1293637752 sec`（`0.188650%`）短いが、Step 62実行幅より小さく未確定。
37. 同じrevisionのまま`./tools/run_tddft_step67.sh 02-03`を実行し、中央値で採否する。
38. Step 67の3 runは全てPASS/PASS。wallは`68.4441161156`、`68.2400159836`、
    `68.3616518974 sec`、中央値`68.3616518974 sec`、実行幅`0.2041001320 sec`。
39. Step 62比`0.2118279934 sec`（`0.308907%`）高速で、両run範囲も重ならないため
    Step 67を正式採用した。
40. 次の単一仮説Step 68はVPJ `vector_length(128)`だけを`64`へ変更する。同じ演算順と
    境界を維持し、初回は`./tools/run_tddft_step68.sh 01`だけを実行する。
41. Step 68 run 01はcheck/compare PASSだが`68.7983009815 sec`で、Step 67比
    `0.4366490841 sec`（`0.638734%`）遅く、実行幅の`2.1394x`回帰した。
42. run 02/03は省略しStep 68を不採用、VPJ vector lengthは128へ復元した。同形の64を
    再試行しない。
43. 次の単一仮説Step 69は現行`EXTAU`準備`1.468457 sec`だけを対象とする。OpenACC時に
    5個の独立な位相表を1個のdata領域でGPU生成し、入力転送をまとめる。
44. 現行host consumer用のEXTAU copyout、MPI、数式、CPU/FFTW loop、VPJ vector length
    128を維持し、ownershipなしの`work2_` GPU生成へ広げない。
45. 初回は`./tools/run_tddft_step69.sh 01`だけを実行する。PASS/PASSで明確な回帰が
    なければ、run 02/03を`./tools/run_tddft_step69.sh 02-03`の1コマンドで取得する。
46. Step 69 run 01はPASS/PASSだが`69.0177049637 sec`で、Step 67比
    `0.6560530663 sec`（`0.959680%`）、正式実行幅の`3.2144x`回帰した。
47. FRPRMN残差は`0.546599 sec`減ったが全体wallは悪化したためrun 02/03を省略し、
    Step 69を不採用としてhost EXTAU経路へ復元した。同じ grouped-copy 形を再試行しない。
48. 次は追加実装ではなく、復元した現行Step 67 sourceをNsight Systemsで再診断し、
    kernel、転送、runtime/API、同期、MPI、GPU idleを更新する。
49. Step 70は`./tools/run_tddft_step70_nsys.sh`を1回だけ実行する。TDDFTのみを
    diagnostic OFFでbuildし、check/compareを必須とし、trace wallをbaselineにしない。
50. terminalに出るkernel、H2D/D2H、CUDA API、OpenACC、OSRT、MPI要約の写真だけを
    受け取り、次の実装は分類完了後に選ぶ。
51. Step 70はPASS/PASS。trace wall `71.0379288197 sec`はbaselineではない。kernel合計
    約`13.96 sec`（`19.65%`）、H2D+D2H `3.230806864 sec`、stream+event同期API
    `17.372092065 sec`、MPI reportは空だった。
52. 最大kernelはnonlocal fused `8.247974033 sec`（kernelの`59.1%`）だが、Step 39で
    tutorialの32 blocks/108 SM制約を診断済み。同形NCUや小band専用kernelを再試行しない。
53. 次は追加最適化ではなく、現行`frprmn_energy_diag`約`0.93 sec`をVG組立、E-field、
    expectation/off-diagonalへ分解してから単一仮説を選ぶ。
54. Step 71はdefault-off timerだけを追加する。演算、loop、ownership、MPI、通常buildを
    変更せず、`./tools/run_tddft_step71.sh`を1回だけ実行する。
55. Step 71はPASS/PASS。`frprmn_energy_diag=0.871809 sec`のうちexpectation/off-diagonalが
    `0.809350 sec`（`92.84%`）。VG組立`0.054056 sec`とE-field`0.004286 sec`は最適化しない。
56. Step 72はこの`0.809350 sec`を対角HLOCAL、対角NONLOC、内積、EE通信、
    off-diagonal全体へdefault-off timerだけで分解する。`./tools/run_tddft_step72.sh`を1回実行する。
57. Step 72はPASS/PASS。expectation`0.816429 sec`の内訳は対角HLOCAL`0.239888 sec`、
    対角NONLOC`0.299706 sec`、内積`0.012768 sec`、EE通信`0.000014 sec`、
    off-diagonal`0.258875 sec`。内積と通信は最適化しない。
58. Step 73はoff-diagonalをHLOCAL、NONLOC、行列内積、通信/copy、集約/outputへ
    default-off timerだけで分ける。`./tools/run_tddft_step73.sh`を1回実行する。
59. Step 73はPASS/PASS。off-diagonal`0.264491 sec`の内訳はHLOCAL`0.080938 sec`、
    NONLOC`0.099967 sec`、行列内積`0.079395 sec`、通信/copy`0.000005 sec`、
    集約/output`0.002409 sec`。通信とoutputは最適化しない。
60. 対角とoff-diagonalを合わせたNONLOCは約`0.399673 sec`。次は係数に依存しない
    YLM準備を各bandから各k-point 1回へまとめる単一仮説を検証する。
61. Step 74はNONLOCへ明示的reuse flagを追加し、各k-point/eventの最初のbandだけYLMを
    再構築する。係数依存のkinetic DCOEFとSEPPOTは毎回維持する。まず
    `./tools/run_tddft_step74.sh 01`、健全なら`./tools/run_tddft_step74.sh 02-03`を実行する。
62. Step 74の3 runは全てPASS/PASS。wallは`68.1138920784`、`68.0681188811`、
    `68.0592751503 sec`、中央値`68.0681188811 sec`、実行幅`0.0546169281 sec`。
    Step 67比`0.2935330163 sec`（`0.429383%`）高速なので正式採用した。
63. 次は追加実装ではなく、正式Step 74 sourceの広域FRPRMN timerをStep 75で再実行し、
    現行残差と未分類量を更新する。`./tools/run_tddft_step75.sh`を1回だけ実行する。
64. Step 75はPASS/PASS。FRPRMN残差`8.203100 sec`のうち`8.163520 sec`
    （`99.5175%`）を分類し、未分類は`0.039580 sec`。上位はPart1to5`1.939650 sec`、
    VRHO`1.799974 sec`、EXTAU`1.438920 sec`。
65. Part1to5とEXTAUには既知の不採用形がある。Step 60/61はStep 62前なので、
    次は現在sourceで既存VRHO子timerを再実行してから仮説を選ぶ。
66. Step 76は追加実装をせず、現行source上で既存VRHO子timerと3階層の未分類gapを
    まとめて再計測する。`./tools/run_tddft_step76.sh`を1回だけ実行し、diagnostic wallは
    baselineに使用しない。
67. Step 76はPASS/PASS。VRHO`1.762396 sec`の内訳はVOFRHO`0.956957`、
    smoothing/FFT`0.156599`、control`0.646548 sec`。controlの`0.549649 sec`はseedで、
    correctorは`0.078602 sec`、Step 62後の係数復元は`0.002889 sec`まで低下した。
68. 次は追加最適化ではなく、最大のVOFRHOをexchange-correlation、FFT、Hartree準備・
    加算へ分解してから単一仮説を選ぶ。
69. Step 77はVOFRHOへdefault-off子timerだけを追加する。`./tools/run_tddft_step77.sh`
    を1回実行し、diagnostic wallはbaselineに使用しない。
70. ユーザー要望によりStep 77より先に、一時的なStep 78 MAX_OFFLOADを1回だけ実行した。
    EXTAU生成、VRHO配列・制御loop、energy expectation/off-diagonal内積、収束reductionを
    まとめてOpenACC化し、MPI呼出しとscalar分岐制御はhostに維持した。
71. 初回revision `94e7176`では初期stepのCOEFがdeviceに存在せずpresent errorとなった。
    `cc65c3c`でexpectation/off-diagonal区間を1個のdata領域で囲み、COEFを区間入口で
    1回だけ用意して修正した。
72. Step 78 archive `nvhpc_cufft_1rank_02_STEP78_MAX_OFFLOAD_01`はPASS/PASS。
    wallは`68.3785300255 sec`で、Step 74中央値より`0.3104111444 sec`
    （`0.456030%`）、正式実行幅の`5.6834x`遅かった。
73. 明確な回帰のためrun 02/03は省略し、Step 78のsourceと専用helperを結果記録と同時に
    revertした。追加loopを個別転送付きでGPU化するだけでは採用しない。
74. 正式baselineは引き続きStep 74。次のbounded actionは未実施のStep 77 VOFRHO診断へ戻る。
75. Step 77はPASS/PASS。diagnostic wallは`69.1326959133 sec`でbaselineではない。
    VOFRHO `0.962422 sec`の内訳はXC `0.653802`、最終FFT `0.111733`、
    Hartree zero `0.013661`、Hartree build `0.161106`、Hartree add `0.017956`、
    gap `0.004164 sec`。
76. XCがVOFRHOの`67.9329%`で最大。次は追加最適化ではなく、G2VXC2を微分配列生成、
    9本の微分FFT、exchange、correlation、最終合成へ分けるStep 79診断を行う。
77. Step 79はtimerだけを追加し、数式、loop順、FFT呼出し、MPI、OpenACC ownership、
    diagnostic-off経路を変更しない。A100では`./tools/run_tddft_step79.sh`を1回実行する。
78. Step 79はPASS/PASS、diagnostic wall `69.1785750389 sec`。VOFRHOは`0.960509`、
    XCは`0.655301 sec`だが、G2VXC2子timerは全てinactiveでgapがXC全体と一致した。
79. Si111-H入力はGGA G2VXC2ではなくLDA S2VXC2経路を使用する。inactiveなG2VXC2を
    このbenchmark向けに最適化しない。
80. Step 80は実行されるS2VXC2の独立格子点loopだけをOpenACC化する。RHOをcopyin、
    VCSRをcopyoutし、分岐、数式、caller FFT/Hartree、MPI、CPU/FFTW経路を維持する。
81. A100では最初に`./tools/run_tddft_step80.sh 01`だけを実行する。PASS/PASSかつ明確な
    回帰がなければ`./tools/run_tddft_step80.sh 02-03`で残り2回をまとめて取得する。
82. Step 80 run 01はPASS/PASS、`67.4321370125 sec`。正式Step 74中央値より
    `0.6359818686 sec`、`0.934331%`高速で有望だが、1回だけでは採用確定しない。
83. 次は`./tools/run_tddft_step80.sh 02-03`を1回実行し、3回中央値でStep 80の採否を
    判定する。新しい最適化を追加しない。
84. Step 80 run 02/03もPASS/PASSで、`67.2197408676`、`67.4207620621 sec`。
    3回中央値は`67.4207620621 sec`、実行幅は`0.2123961449 sec`。
85. Step 74比で`0.6473568190 sec`、`0.951043%`高速なため採用候補。正式baseline変更と
    次診断は人間の明示承認待ちであり、承認前に追加実装しない。
86. ユーザーがStep 80の正式採用を承認した。Step 80は正式baselineで、中央値
    `67.4207620621 sec`、実行幅`0.2123961449 sec`。
87. 次は追加最適化ではなく、正式Step 80 sourceの既存広域FRPRMN timerを再実行する
    Step 81診断。A100では`./tools/run_tddft_step81.sh`を1回実行する。
88. ユーザーがH100でStep 80を1回試し、`36.492636919 sec`、PASS/PASSだった。
    A100 Step 80中央値比は`1.847517x`、wallは`45.873295%`短い。
89. H100値は1回のみで、正確なH100型式、revision、compiler、`cc90` build条件が未記録。
    H100正式baselineにはせず、A100 Step 81計画も変更しない。
90. ソースコードベースの履歴比較には、Step 86のNVHPC実ビルド対象OpenACC compute
    site 24個を100%とする相対indexを使う。Step 37/41は66.7%、Step 52は70.8%、
    Step 57/62/67/74は75.0%、Step 80は79.2%、Step 82は83.3%、Step 86は100.0%。
91. このindexはGPU使用率でも全並列化可能loopの絶対GPU化率でもない。cuFFT内部を
    数えず、常駐、allocation、vector length、再利用だけの改善では値が変わらない。
92. time-step loop内の既知候補に限定した暫定絶対値は、Step 86採用済み24 siteと
    Step 78で確認した未採用候補15 site、計39 siteを母数とする。
93. この候補site率はStep 37/41が41.0%、Step 52が43.6%、Step 57/62/67/74が46.2%、
    Step 80が48.7%、Step 82が51.3%、Step 86が61.5%。小loopと支配kernelを同じ1 siteで数えるため
    演算量比ではない。
94. Step 81はPASS/PASS。診断wallは`68.5029249191 sec`でbaselineではない。FRPRMN残差
    `7.878776 sec`の`7.833973 sec`（`99.4313%`）を分類し、未分類は`0.044803 sec`。
95. 上位はPart1to5 `1.947618`、EXTAU `1.448376`、VRHO `1.173977`、energy
    `1.118869 sec`。VRHOはStep 75比`0.625997 sec`（`34.7781%`）減りStep 80効果と整合。
96. 次は追加実装・再実行ではなく、`./tools/show_tddft_step81_detail.sh`で同じStep 81
    archiveのVRHO・energy子timerを写真に収め、その結果から単一仮説を選ぶ。
97. 詳細ではVOFRHO `0.359571 sec`中XCは`0.063268 sec`で、Step 77比`90.3231%`減。
    VRHO control `0.657103 sec`の方が大きく、XCは次の対象ではない。
98. energy `1.118869 sec`中E-fieldは`0.248282`、expectationは`0.778436 sec`。
    E-fieldはStep 71の`0.004286 sec`と差が大きくhost出力を含むため、まだ選ばない。
99. 次は再実行せず、`./tools/show_tddft_step81_detail.sh control`で同じarchiveの
    呼出回数とseed/predict/corrector内訳を確認してから単一仮説を選ぶ。
100. control詳細はseed `0.562341 sec`、predictor `0.016313`、corrector
     `0.076263 sec`。seedがcontrolの`85.5773%`で次の対象。
101. Step 82はOpenACC時のhost COEF→COEF0 seed copyとCOEF0 H2Dだけを、現行data入口の
     COEF copyin、COEF0 create、device copyへ置換する。区間寿命、restart、MPI、数式、
     CPU/FFTWを維持し、Step 45のtime-step全体常駐を再試行しない。
102. A100では`./tools/run_tddft_step82.sh 01`だけを実行し、PASS/PASSかつ明確な回帰が
     なければ02/03をまとめて取得する。
103. Step 82 run 01はPASS/PASS、`66.8839480877 sec`。Step 80正式中央値より
     `0.5368139744 sec`（`0.796215%`）高速で、seed測定値`0.562341 sec`とも近い。
104. 1 runではbaselineを更新しない。次は`./tools/run_tddft_step82.sh 02-03`で残りを
     一括取得し、3 run中央値で採否を決める。
105. Step 82 run 02/03もPASS/PASSで、`66.6139972210`、`66.6539101601 sec`。
     3回中央値は`66.6539101601 sec`、実行幅は`0.2699508667 sec`。
106. Step 80比`0.7668519020 sec`（`1.137412%`）高速で、全runが旧中央値より速いため
     Step 82を正式baselineとして採用する。
107. 次は追加最適化ではなく、`./tools/run_tddft_step83.sh`で正式Step 82 sourceの
     VRHO seed/control子timerを1回再診断する。diagnostic wallはbaselineにしない。
108. Step 83はPASS/PASS。seedは`0.000497 sec`でStep 81比`99.9116%`減、VRHO controlは
     `0.103696 sec`、VRHO parentは`0.622439 sec`となり、Step 82の機序を確認した。
109. 次はbuild/rerunせず、`./tools/show_tddft_step83_next.sh`で同じarchiveの現行広域
     envelopeとenergy子timerを表示し、既却下形を避けた単一仮説を選ぶ。
110. 現行はPart1to5 `1.941613`、EXTAU `1.440404`、VRHO `0.622439`、energy
     `0.847562 sec`。Part1to5/EXTAUの単純offload形はhost consumer境界で既却下。
111. Step 84はNONLOCのband不変kinetic factorをRHOAへ格納して直後に1回読む冗長passを
     DCOEF更新へ融合するだけとし、ownership、MPI、HLOCAL、YLM再利用、数式を維持する。
112. A100では`./tools/run_tddft_step84.sh 01`だけを実行し、PASS/PASSかつ明確な回帰が
     なければ02/03をまとめて取得する。
113. Step 84の3 runは`66.7368218899`、`66.7220189571`、`66.8331620693 sec`で全て
     PASS/PASS。中央値`66.7368218899 sec`はStep 82比`0.124391%`遅く、利得なし。
114. Step 84を却下して正式Step 82式へ戻し、Step 82をbaselineとして維持する。
115. 次は`./tools/run_tddft_step85.sh`を1回だけ実行し、energy HLOCALをzero、scatter、
     inverse FFT、VG multiply、forward FFT、gatherへ分解する。diagnostic wallはbaselineにしない。
116. Step 85はPASS/PASS。全768 HLOCAL callはzero `0.013984`、scatter `0.067270`、
     inverse FFT `0.128601`、VG multiply `0.040314`、forward FFT `0.141528`、
     gather `0.090866 sec`、合計`0.482563 sec`。
117. 768 callは対角384、非対角128、TMEVL 256。初回helperの負gapは全768子timerと
     対角/非対角512親timerを比較した表示上の誤りで、個別計測値は有効。
118. Step 86はHLOCALだけを一時device data regionにまとめ、host staged FFT 2往復と
     4 host loopをGPU内に置く。CPU/FFTW経路は維持する。
119. A100では`./tools/run_tddft_step86.sh 01`だけを実行し、結果確認前に02/03を流さない。
120. Step 86の3 runは`66.5019950867`、`66.6454100609`、`66.3501911163 sec`で全て
     PASS/PASS。中央値`66.5019950867 sec`、実行幅`0.2952189446 sec`。
121. Step 82比`0.1519150734 sec`（`0.22791%`）高速なため、Step 86を正式baselineとして
     採用する。現在のtime-step候補GPU化率は24/39=`61.5%`。
122. 次は追加最適化ではなく、正式Step 86 sourceのHLOCAL全768 callを1本の親timerで
     再診断するStep 87。A100では`./tools/run_tddft_step87.sh`を1回だけ実行する。
123. Step 87のdiagnostic wallはbaselineに使わず、Step 85の旧HLOCAL合計
     `0.482563 sec`との差と、対角・非対角・TMEVL寄与を確認する。
124. Step 87はPASS/PASS。device HLOCAL全768 callは`0.247780 sec`で、対角
     `0.128030`、非対角`0.040771`、derived TMEVL `0.078979 sec`。
125. Step 85のhost staged HLOCAL `0.482563 sec`から`0.234783 sec`
     （`48.653%`）減り、Step 86の改善機序を直接確認した。
126. 次は追加実装・再実行せず、`./tools/show_tddft_step87_next.sh`で同じarchiveの
     energy階層を表示し、残る単一仮説を選ぶ。
127. 現行energy expectation `0.634219 sec`の最大成分はNONLOCで、対角
     `0.274122`＋非対角`0.090716`=`0.364838 sec`（`57.53%`）。
128. Step 84の単純kinetic host pass融合は既却下なので再試行しない。Step 88は
     NONLOCをkinetic、YLM、SEPPOTへdefault-off timerだけで分解する。
129. A100では`./tools/run_tddft_step88.sh`を1回だけ実行し、diagnostic wallを
     baselineに使わない。内訳確認前に追加最適化しない。
130. Step 88はPASS/PASS。全768 NONLOC callはkinetic `0.056220`（`10.325%`）、
     YLM `0.003207`（`0.589%`）、SEPPOT `0.485064 sec`（`89.086%`）。
131. 次のStep 89はSEPPOTをEXTAU位相表とs/p/d/f軌道channelへdefault-off timerだけで
     分解する。最大channelの確認前にSEPPOT全体を一括GPU化しない。
132. A100では`./tools/run_tddft_step89.sh`を1回だけ実行する。diagnostic wallは
     baselineに使わない。
133. Step 89はPASS/PASS。SEPPOT `0.547832 sec`の分類内訳はEXTAU
     `0.188158`（`36.414%`）、s `0.103150`（`19.963%`）、p `0.225405 sec`
     （`43.623%`）。d/fはこの入力ではinactive、分類gapは`0.031119 sec`。
134. Step 47のtutorial専用s/p全体offloadは既却下なので再導入しない。Step 90は最大の
     p channelをprojector生成、係数reduction、DCOEF更新へtimerだけで分解する。
135. A100では`./tools/run_tddft_step90.sh`を1回だけ実行する。数式、loop順、
     ownership、MPI、diagnostic-off経路は変更せず、wallをbaselineに使わない。
136. Step 90はPASS/PASS。p channel `0.284428 sec`の内訳はprojector生成
     `0.095651`（`39.103%`）、係数reduction `0.069291`（`28.327%`）、
     DCOEF更新`0.079670 sec`（`32.570%`）、gap `0.039816 sec`。
137. 各子は9,216回呼ばれ、単独上限が`0.1 sec`未満で支配子もない。Step 47の却下結果と
     合わせてSEPPOTの細粒度GPU化を終了し、個別kernelを追加しない。
138. 次のStep 91は追加最適化ではなく、正式Step 86 sourceをdiagnostic OFFでNsight
     Systems再診断する。Step 70以後のSteps 74/80/82/86を含む現行kernel、転送、
     API、同期、MPI、GPU idleを`./tools/run_tddft_step91_nsys.sh`で更新する。
139. Step 91 trace wallはbaselineに使わず、通常checkとrelaxed compareを必須とする。
140. Step 91はPASS/PASS。trace wallは`69.98909358414 sec`でbaselineではない。
     CUDA kernel合計は約`13.90 sec`（`19.86%`）、fused nonlocalは
     `8.200543838 sec`、VPJは`1.559553328 sec`。
141. H2Dは45,663回・`28,361.039 MB`・`2.479428511 sec`、D2Hは7,759回・
     `6,036.924 MB`・`0.482051802 sec`。stream+event同期は重複を含む
     `17.235587864 sec`、MPI reportは空。
142. Step 70比で直接転送時間は`0.269326551 sec`、H2D量は`3,229.206 MB`減ったが、
     同期と主要kernelはほぼ不変。kernel外約`56.09 sec`を純GPU idleと解釈しない。
143. 次は追加実装・再実行せず、`./tools/show_tddft_step91_detail.sh`で既存Step 91
     archiveのTMEVL update/waitとCUDA同期/copy行だけを表示し、必須host consumer境界と
     回避可能な反復stagingを区別してから単一ownership仮説を選ぶ。
144. line 1930 `work2_` updateは4,720回、inclusive `1.609217948 sec`で、内包Waitは
     `1.530650988 sec`。line 1933 metadata updateは`0.148298132 sec`、内包Waitは
     `0.137812074 sec`。inclusive Updateと内包Waitを加算しない。
145. line 2405 fused-kernel完了Waitは`8.360886829 sec`で、CUDA kernel
     `8.200543838 sec`が引き続き支配的。転送削除だけでなく、同じ値・逐次projector順を
     保つdevice生成が必要。
146. 次は`./tools/show_tddft_step91_next.sh`で既存Step 88/91 archiveからhost生成、
     update、metadata、fused GEMM timerを一括表示する。build/rerunせず、上限確認前に
     `work2_`直接生成を実装しない。
147. 一括表示では`s2_nonlocal=11.548827`、host make `1.348333`、
     owner-side `work2_` setup `1.550889`、metadata setup `0.088045`、
     fused dot/update `8.400202 sec`。host生成とowner-side setupの上限は
     `2.987267 sec`だが、各timerとNsight inclusive行は重複するためwallへ加算しない。
148. `work2_`直接GPU生成はYLM/VPJ/EXTAU ownershipを必要とし、B1 YLM ownership
     `+6.7%`またはStep 20細粒度copy `819.404727936 sec`の却下形を繰り返すため選ばない。
149. Step 92は数式・ownershipを変更せず、5個のSuzuki-Trotter phaseごとに連続TMEVL
     callのactive `work2_`/`cfac_`/`ngnl_`全値が完全一致するかを数える診断。
     `./tools/run_tddft_step92.sh`を1回だけ実行し、equal/changed比からhost生成cacheの
     可否を決める。診断wallはbaselineに使用しない。
150. Step 92はPASS/PASS。全phaseでobservations `944`、比較対象`943`回のうち
     exact equal `0`、changed `943`、equal率`0.000%`。完全なhost生成cache再利用は
     不可なので実装しない。診断wall `71.3717830181 sec`はbaselineに使用しない。
151. Step 93は追加最適化を行わず、同じphaseの連続call間で`ngnl_`、`cfac_`、
     `work2_`を個別に完全比較する。`./tools/run_tddft_step93.sh`を1回だけ実行し、
     metadataが一定なら反復metadata updateの1回化だけを次候補として検討する。
152. Step 93はPASS/PASS。diagnostic wall `72.5525600910 sec`はbaselineではない。
     5 phaseすべてで943比較を行い、`ngnl_pct`、`cfac_pct`、`work2_pct`、`all_pct`は
     すべて`0.000%`だった。
153. metadataもprojector値とともに毎回変化するため、反復metadata updateの1回化は
     不成立。Steps 92/93でphase単位の`work2_`全体cacheとmetadata-only cacheを閉じ、
     同形を再試行しない。正式baselineはStep 86の`66.5019950867 sec`のまま。
154. 次は追加最適化ではなくStep 94で現行ELECTF `LOCPOTF`を再診断する。旧Step 43の
     `4.071556 sec`親にはEWALD、local G-vector/force生成、MPI、energy、XC、Hartreeが
     混在するため、直接offloadの根拠にしない。
155. Step 94はdefault-off timerで`LOCPOTF`全体とlocal生成からMPI境界までを測る。
     A100では`./tools/run_tddft_step94.sh`を1回だけ実行し、両checkを必須とし、
     diagnostic wallはbaselineに使用しない。
156. Step 94はPASS/PASS。diagnostic wall `72.0893621445 sec`はbaselineではない。
     `LOCPOTF=4.345268 sec`中、local生成・force蓄積・MPIは`1.193364 sec`
     （`27.464%`）、残差は`3.151904 sec`（`72.536%`）だった。
157. local/MPI区間は支配的でないため直接offloadしない。次のStep 95で残差をEWALD、
     local energy、XC、Hartree、未分類gapへ分解してから単一仮説を選ぶ。
158. Step 95はdefault-off timerだけを追加し、timer表を120から124 entryへ整合して
     拡張する。数式、loop順、MPI、OpenACC ownership、CPU/FFTW、diagnostic-off経路を
     変更しない。
159. A100では`./tools/run_tddft_step95.sh`を1回だけ実行し、両checkを必須とする。
     4子区間の残差比率と未分類gapを確認するまで実装を選ばず、wallはbaselineにしない。
160. revision `6952f54`の初回A100実行はarchiveと両checkまで成功したが、末尾要約だけが
     A100側`awk`で組み込み関数名`split`を変数に使ったため停止した。計算は再実行せず、
     修正版をpullして`./tools/report_tddft_step95.sh`で既存archiveを再check・再要約する。
     diagnostic wallは`72.0551159382`秒でありbaselineには使わない。
161. Step 95のLOCPOTF残差`3.159508 sec`中、EWALDは`3.024790 sec`
     （`95.736%`）、local energyは`0.266%`、XCは`3.338%`、Hartreeは`0.587%`、
     未分類gapは`0.073%`だった。
162. Step 96は固定核の101回のEWALDYについて、`EWA`とactive-atom `FORCE`を直前callと
     exact比較する診断だけを行う。100比較すべて一致した場合だけ初回出力cacheを次の
     単一実装仮説とし、変化があればこのreuse経路を閉じる。
163. Step 96はrevision `4902b4f`でPASS/PASSだったが、100比較すべてが変化し、
     `ewa_pct`、`force_pct`、`all_pct`はいずれも`0.000%`だった。出力cache経路を閉じる。
     diagnostic wall `71.6179108620`秒はbaselineにしない。
164. EWALDは`3.024790 sec`の高価値targetなので、Step 97ではG-space、R-space、MPIを
     default-off timerで分解し、setup/AGEN gapを導出する。最大compute子区間を次の
     直接GPU化候補とし、sub-percentのLOCPOTF子区間は先に最適化しない。
165. Step 97はrevision `02fa239`でPASS/PASS。EWALDY `3.024816 sec`中、G-space
     `2.795064 sec`（`92.404%`）、R-space `0.205414 sec`、MPI `0.019249 sec`、
     setup/AGEN gap `0.005089 sec`だった。diagnostic wallはbaselineにしない。
166. Step 98はG-spaceを直接対象にし、EWALDY callごとに1 data region、atom-pair並列、
     pair内G加算順維持、共有FORCEのみatomic updateとする。MPI pair分担とCPU/FFTW原形を
     維持し、まずdiagnostic OFF run 01のPASS/PASSとwallを確認する。
167. Step 98は3 runすべてPASS/PASS、`66.1477772789`、`66.14293359913`、
     `66.4177260399`秒、中央値`66.1477772789`秒、range `0.27479244077`秒だった。
     Step 86比`0.3542178078`秒（`0.532642%`）高速なので正式採用する。
168. Step 99はStep 98のdata region、atomic FORCE、MPI分担、pair内演算を維持し、
     atom pairをgang、内側G-vector loopをvector reductionへ割り当てる。まず
     `./tools/run_tddft_step99.sh 01`を実行し、Step 98中央値と比較する。
169. Step 99は3 runすべてPASS/PASS、`64.5138220787`、`64.2798080444`、
     `64.3024969101`秒、中央値`64.3024969101`秒、range `0.2340140343`秒だった。
     Step 98比`1.8452803688`秒（`2.789633%`）、Step 86比`2.1994981766`秒
     （`3.307417%`）高速なので正式採用する。
170. Step 100は現行sourceの既存timerを診断ONで1回だけ採取し、主要区間を再順位付け
     する。数値経路やownershipは変更せず、診断wallをbaselineに使用しない。
171. Step 100はrevision `f1e22c2`でPASS/PASS、diagnostic wall
     `70.6082198620`秒だった。`tmevl_s2=20.759666`、`s2_nonlocal=16.100488`、
     make `1.432096`、gemm `10.169891`秒。残差`4.498501`秒はSteps 92/93の
     diagnostic-only全配列reuse比較なので性能targetにしない。
172. Step 101は再build・再runを行わず、既存Step 100 archiveからnonlocal transferと
     S2 local内部timerを表示する。結果で未分類`4.659178`秒のactionable区間を判定する。
173. Step 101ではfused kernel `8.402617`秒、work2 upload `1.551925`秒、metadata
     upload `0.088854`秒、S2 local `4.612063`秒、local phase multiply
     `0.917904`秒、local gap `2.277363`秒だった。
174. Step 102は`VG=VGG+Vloc`と同じphase式を維持し、格子点ごとに複素phaseを1回だけ
     計算して全local bandsで再利用する。逐次ia、MPI、FFT ownership、CPU/FFTW fallback
     は変更せず、diagnostic OFF run 01から性能判定する。
175. Step 102は3 runすべてPASS/PASS、中央値`63.8388190269`秒、range
     `0.24778998752`秒。Step 99比`0.4636778832`秒（`0.721088%`）、Step 86比
     `2.6631760598`秒（`4.004656%`）高速なので正式採用する。
176. Step 103は再build・再runせず既存Step 100 archiveから`tmevl_exkin`と
     `exkin_acc_kernel`を表示し、同じband共通phase前計算の上限を確認する。
177. Step 103では`tmevl_exkin=0.671559`秒、`exkin_acc_kernel=0.635902`秒、
     wrapper gap `0.035657`秒だった。
178. Step 104は独立なloop mappingをband×G collapseからG-vector GPU並列＋local-band
     内側seqへ変え、Gごとのkinetic phaseを1回だけ計算して32 bandsに再利用する。
     各要素式、MPI、ownership、call回数、CPU/FFTW fallbackは維持する。
179. Step 104 run 01はPASS/PASSだが`64.0659618378`秒で、Step 102中央値より
     `0.2271428109`秒（`0.355807%`）遅かった。run 02/03は早期停止し、band方向並列を
     失うmappingを不採用としてsourceとhelperを削除、Step 102へ復元する。

Step 53-62 helperは完了済みの履歴として保持する。次の実験も長い個別コマンドへ
展開せず、TDDFTのみのbuild、run、check、compare、要約をまとめた1コマンドhelperを使う。

A100は閉じた環境なので人間が操作します。CodexはA100を直接実行せず、`mk_ifort.sh`
を使う簡潔でコピー可能なbuild/profile/archive/check/compareコマンドを提示します。
profile wallを性能baselineにしないでください。

A100で人間が実行するコマンドは短く、直接コピー可能な形に限定してください。既存の
wrapper 1コマンドを優先し、手順が長くなる場合は、長いshellコマンド列を提示せず、
用途を限定した実行用スクリプトをGitへ登録してください。

閉じたA100環境からCodexへ返せるデータは、画面の写真または人間が手打ちするテキスト
だけです。raw trace、archive、CSV、logなどのファイル受け渡しを要求しないでください。
profiler実行用wrapperはrevision、実行条件、correctness、主要診断値を少数の写真に
収まる簡潔なterminal summaryとして出力し、不足時だけ対象を絞った追加表示を依頼して
ください。

再試行禁止事項:

- Step 47と同形のtutorial専用SEPPOTF s/p経路
- Step 45と同形のtime-step全体COEF allocation
- Step 42と同形のVloc residency
- 細粒度section単位の反復copyin
- ownership設計なしの`work2_`直接GPU生成
- GDUMP/YLM mappingの既知不採用形
- fused kernel `vector_length(512)`
- 小band専用kernel
- 数学的同値性確認なしの`ia`更新順序変更

CPU/FFTW fallback、fixed-form Fortran、correctness toleranceを維持してください。
性能採否はdiagnostic OFF、normal checkとrelaxed compare、同条件3回中央値で行います。
production入力と対応referenceはまだ存在しないため、推測で生成しないでください。

180. Step 104 run 01はPASS/PASSでしたが`64.0659618378`秒で、Step 102中央値より
     `0.2271428109`秒（`0.355807%`）遅く、run 02/03を省略して不採用・復元済みです。
181. 現行timerの`electf_force=6.249443`秒から`LOCPOTF=1.373461`秒を除いた
     `4.875982`秒（正式wallの`7.638%`）が最大の未分解候補です。
182. Step 105は追加最適化せず、現行ELECTF NONLOCFをsetup、係数kinetic/current＋MPI、
     GETYLM、SEPPOTF、最終集計へdefault-off timerだけで分解します。
183. A100では`./tools/run_tddft_step105.sh`を1回だけ実行し、両checkを必須とし、
     `FPSEID_NONLOCF_SPLIT_BEGIN`から`FPSEID_NONLOCF_SPLIT_END`までの写真を返します。
184. Step 105はrevision `91f27a0`でPASS/PASS。diagnostic wall
     `70.5463471413`秒はbaselineではない。NONLOCF `4.975987`秒のうちSEPPOTFは
     `4.061892`秒（`81.630%`）、係数kinetic/current＋MPIは`0.898982`秒だった。
185. SEPPOTFは正式Step 102 wallの`6.362730%`で最大のactionable child。ただし
     Step 47型s/p全体GPU化は既却下で、同形を再試行しない。
186. 旧Step 47 GPU形は、現行host形がband間で再利用するWORK/DCOEF投影量生成を
     band reduction内で再計算していた。Step 106は最適化せず、現行SEPPOTFを
     位相生成、非partition s/pの投影量生成・band reduction、MPI、gapへ分解する。
187. A100では`./tools/run_tddft_step106.sh`を1回だけ実行し、両checkを必須とし、
     `FPSEID_SEPPOTF_DETAIL_BEGIN`から`FPSEID_SEPPOTF_DETAIL_END`までの写真を返す。
     diagnostic wallはbaselineに使用しない。
188. Step 106はrevision `9ef703b`でPASS/PASS、diagnostic wall
     `70.2937791348`秒。SEPPOTF `4.101524`秒のうちs/p band reductionは
     `1.270594`＋`2.537915`=`3.808509`秒（`92.856%`）だった。
189. band reduction合計は正式Step 102 wallの`5.965820%`で、別構造GPU化に十分な
     上限がある。projector生成とMPIは直接targetにしない。
190. Step 107は原子ごとの非partition s/p投影量を一度生成し、原子×local-bandを
     GPU gangへ展開する。最終type→atom→s→p順を維持し、partition/d/fはhost fallback、
     COEF常駐は同一time-stepのFRPRMN→直後ELECTFだけとする。
191. GNU MPI＋FFTW full build/linkはPASS。A100ではdiagnostic OFFの
     `./tools/run_tddft_step107.sh 01`だけを先に実行し、両checkとwallを返す。
     不正解または明確に遅ければrun 02/03を早期停止する。
192. Step 107は3 runすべてPASS/PASS。wallは`63.1300778389`、
     `63.2335109711`、`63.2135219574`秒、中央値`63.2135219574`秒、range
     `0.1034331322`秒だった。
193. Step 102中央値より`0.6252970695`秒（`0.979493%`）高速なため、revision
     `c46cfa9`を新しいsource・性能baselineとして正式採用する。
194. Step 108はsourceを変更せず、正式Step 107 sourceの既存default-off timerを
     再計測する。diagnostic wallはbaselineにせず、主要区間の順位だけを次の
     単一仮説選定に使う。
195. Step 108はrevision `4ccf7dc`でPASS/PASS、diagnostic wall
     `70.2021420002`秒。S2 NONLOCAL `16.045700`秒は最大だが、安全なfused-kernel
     mapping/cache候補は既に分類済みである。
196. 次のactionable親区間はELECTF NONLOCF `5.076909`秒、その中のbatched
     SEPPOTF `4.262210`秒。Step 109は数値経路を変えず、projector、s/p batch、
     final、download、MPI、gapへdefault-off timerだけで分解する。
197. Step 109はPASS/PASSだったがtimer IDs 140--144が表示されず、wrapperのcount
     checkで停止した。親`4.263925`秒、MPI `0.000369`秒までは確認済み。100-stepを
     再実行せず、既存archive reportで旧IDs 134--138の有無を先に確認する。

次は`./tools/report_tddft_step109.sh`を実行し、`FPSEID_STEP109_DEBUG_BEGIN`から
`FPSEID_STEP109_DEBUG_END`までの写真を受け取ってください。build・再runはしません。

---
