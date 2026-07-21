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

正式baselineは論理Step 52です。

- source implementation: `22aad92`
- pinned build mode: `9cbb6bc`
- A100-PCIE-40GB、1 GPU / 1 MPI rank
- NVHPC + OpenACC + cuFFT
- `-gpu=mem:separate:pinnedalloc`
- Si111-H、100 steps
- diagnostic OFF 3回中央値: `73.4374880791 sec`
- 実行幅: `0.5168180465 sec`
- 全runでnormal checkとrelaxed compare PASS

Step 52は`Part1to5`から呼ばれる`VPJ_GEN`動径積分だけをGベクトル間でGPU並列化し、
各G内の動径積分順序、host MPI境界、TMEVLのCPU経路を維持しています。Step 41中央値
より`34.3167250159 sec`（`31.8472%`）高速で、3回のcorrectnessと性能採否gateを
満たしたため正式採用済みです。最新HEADを自動的にbaseline扱いしない原則は維持します。

最終ゴールは、タイムステップループ内を可能な限りGPU化し、大規模配列のhost/device
転送をloop入口、必須MPI/host consumer、出力へ集約して最小化することです。ただし、
性能を出す鍵はGPU化routine数ではなくGPUの連続稼働時間です。

現時点の確定値:

- Step 52 run 02 `time_step_total`: `73.680412 sec`
- `frprmn`: `64.618912 sec`
- `tmevl_total`: `51.468926 sec`
- `frprmn - tmevl_total`: `13.149986 sec`
- `s2_nonlocal`: `11.536198 sec`
- `exnlp_gemm_dot`: `8.450867 sec`
- Step 51で判明した旧`VPJ_GEN` CPU積分: `36.132464 sec`

Step 48のNsight値はStep 52 VPJ GPU化より前なので、現在のkernel時間・転送回数・
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
7. 次の1テーマはStep 55診断とし、`frprmn_vrho_mix`だけをVOFRHO、
   smoothing/FFT、interpolation/convergenceへ分ける。
8. Step 55結果が返るまで追加最適化を実装しない。

Step 53/54 helperは完了済みの履歴として保持する。Step 55も長い個別コマンドへ展開せず、
TDDFTのみのbuild、run、check、compare、要約をまとめた1コマンドhelperを使用する。

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

初回報告では、Git状態、正式baseline、Step 48とStep 52の差、現在確定している比率、
再診断で取得する指標、A100実行コマンド案だけを示し、追加実装へ進まず停止してください。

---
