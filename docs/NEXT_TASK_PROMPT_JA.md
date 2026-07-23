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

正式baselineは論理Step 67です。

- source implementation: `39a181e`
- pinned build mode: `9cbb6bc`
- A100-PCIE-40GB、1 GPU / 1 MPI rank
- NVHPC + OpenACC + cuFFT
- `-gpu=mem:separate:pinnedalloc`
- Si111-H、100 steps
- diagnostic OFF 3回中央値: `68.3616518974 sec`
- 実行幅: `0.2041001320 sec`
- 全runでnormal checkとrelaxed compare PASS

Step 67は、採用済みStep 57のVPJ/LOCPOT GPU化とStep 62のhost copy省略を保持し、VPJ
kernelだけのvector lengthを256から128へ変更しています。OpenACC補正失敗経路でdevice
authorityを更新しない冗長なhost COEF0-to-COEF copyだけを省略しています。VGOLD、device
復元、MPI、数式順序、CPU/FFTW fallbackは維持しています。Step 62中央値より
`0.2118279934 sec`（`0.308907%`）高速で、全3 runのcorrectnessと性能採否gateを満たして
正式採用済みです。最新HEADを自動的にbaseline扱いしない原則は維持します。

最終ゴールは、タイムステップループ内を可能な限りGPU化し、大規模配列のhost/device
転送をloop入口、必須MPI/host consumer、出力へ集約して最小化することです。ただし、
性能を出す鍵はGPU化routine数ではなくGPUの連続稼働時間です。

現時点の確定値:

- Step 67 median-wall run 03 `time_step_total`: `68.578084 sec`
- `frprmn`: `59.581569 sec`
- `tmevl_total`: `51.412947 sec`
- `frprmn - tmevl_total`: `8.168622 sec`
- `s2_nonlocal`: `11.469054 sec`
- `exnlp_gemm_dot`: `8.453116 sec`
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

初回報告では、Git状態、正式Step 67 baseline、Step 52からの改善、現在確定している比率、
再診断で取得する指標、簡潔なA100実行コマンド案だけを示し、追加実装へ進まず停止してください。

---
