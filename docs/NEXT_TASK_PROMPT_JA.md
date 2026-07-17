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

正式baselineは論理Step 41です。

- source implementation: `4aaa33c`
- pinned build mode: `9cbb6bc`
- A100-PCIE-40GB、1 GPU / 1 MPI rank
- NVHPC + OpenACC + cuFFT
- `-gpu=mem:separate:pinnedalloc`
- Si111-H、100 steps
- diagnostic OFF 3回中央値: `107.754213095 sec`
- 全runでnormal checkとrelaxed compare PASS

現在HEADはStep 47結果記録とrollback後です。rollback `35f8542`によりStep 47実装と
Step 46診断sourceは除去され、影響sourceは正式Step 41へ戻っています。CPU/FFTW
fallback full linkはrollback後にPASSしています。最新HEADを自動的にbaseline扱い
しないでください。

最終ゴールは、タイムステップループ内を可能な限りGPU化し、大規模配列のhost/device
転送をloop入口、必須MPI/host consumer、出力へ集約して最小化することです。ただし、
性能を出す鍵はGPU化routine数ではなくGPUの連続稼働時間です。

現時点の概算:

- Step 41 run 02 `time_step_total`: `108.026444 sec`
- `tmevl_total`: `51.442021 sec`、全体の`47.620%`、GPU主体
- `electf_force`: `9.055956 sec`、現在ほぼhost
- `frprmn - tmevl_total`: `47.476614 sec`、CPU/GPU/同期等が未分解
- アルゴリズム上のGPU主体coverage: 約`48%`
- 混在領域を含む実務的推定: `48-55%`
- Step 38のCUDA kernel合計逆算: 約`12.48 sec`、trace wallの約`11.3%`
- Step 38 H2D/D2H: `1.272192545 / 0.440373299 sec`、合計約`1.55%`
- Step 38 copy回数: H2D 44,166、D2H 5,348

Step 38はStep 41 J2G/OCC residencyより前なので、現在の転送回数ではありません。

次の1テーマは、追加最適化ではなく正式Step 41 sourceの実行構造再診断です。

1. Step 41をNsight Systemsで再計測する計画と、A100で人間が実行する簡潔なコマンドを
   作成する。
2. CUDA kernel、H2D/D2H、CUDA/OpenACC API、同期、allocation、OS runtimeを収集する。
3. `47.476614 sec`のFRPRMN未分解領域をCPU演算、MPI、runtime/API、同期、GPU idleへ
   分類する。
4. traceだけで不足する場合に限り、default OFFの診断timer仮説を1件提案する。
5. 診断結果が返るまで追加最適化を実装しない。

A100は閉じた環境なので人間が操作します。CodexはA100を直接実行せず、`mk_ifort.sh`
を使う簡潔でコピー可能なbuild/profile/archive/check/compareコマンドを提示します。
profile wallを性能baselineにしないでください。

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

初回報告では、Git状態、正式baseline、Step 38とStep 41の差、現在確定している比率、
再診断で取得する指標、A100実行コマンド案だけを示し、追加実装へ進まず停止してください。

---
