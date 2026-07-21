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

正式baselineは論理Step 57です。

- source implementation: `8646707`
- pinned build mode: `9cbb6bc`
- A100-PCIE-40GB、1 GPU / 1 MPI rank
- NVHPC + OpenACC + cuFFT
- `-gpu=mem:separate:pinnedalloc`
- Si111-H、100 steps
- diagnostic OFF 3回中央値: `71.2909028530 sec`
- 実行幅: `0.1379821301 sec`
- 全runでnormal checkとrelaxed compare PASS

Step 57は、Step 52の`VPJ_GEN` GPU化を保持したうえで、LOCPOTだけをGベクトル間で
GPU並列化しています。各G内のITY/K/IA加算順、G=0 host処理、host MPI境界を維持し、
Step 52中央値より`2.1465852261 sec`（`2.9230%`）、Step 41中央値より
`36.4633102420 sec`（`33.8393%`）高速です。3回のcorrectnessと性能採否gateを満たして
正式採用済みです。最新HEADを自動的にbaseline扱いしない原則は維持します。

最終ゴールは、タイムステップループ内を可能な限りGPU化し、大規模配列のhost/device
転送をloop入口、必須MPI/host consumer、出力へ集約して最小化することです。ただし、
性能を出す鍵はGPU化routine数ではなくGPUの連続稼働時間です。

現時点の確定値:

- Step 57 run 02 `time_step_total`: `71.511959 sec`
- `frprmn`: `62.501628 sec`
- `tmevl_total`: `52.011855 sec`
- `frprmn - tmevl_total`: `10.489773 sec`
- `s2_nonlocal`: `11.490492 sec`
- `exnlp_gemm_dot`: `8.453381 sec`
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
    MPI、数式順序は維持する。初回は`./tools/run_tddft_step62.sh 01`だけを実行する。
21. run 01がcheck/compare PASSした場合、run 02/03は
    `./tools/run_tddft_step62.sh 02-03`の1コマンドで続ける。

Step 53-61 helperは完了済みの履歴として保持する。次の実験も長い個別コマンドへ
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

初回報告では、Git状態、正式Step 57 baseline、Step 52からの改善、現在確定している比率、
再診断で取得する指標、簡潔なA100実行コマンド案だけを示し、追加実装へ進まず停止してください。

---
