# FPSEID21 TDDFT GPU化 進捗報告（詳細版）

報告日: 2026-07-31

## 1. 概要

FPSEID21のTDDFT時間発展計算を対象に、NVHPC OpenACCとcuFFTを用いたGPU化を
進めた。GPU kernelの追加だけでなく、主要配列のdevice常駐化、FFTのbatch化、
不要なHost–Device転送の削減、pinned host memoryの利用を組み合わせている。

現在の採用済み数値sourceは`c46cfa9`である。CPU/FFTW fallbackと
1 GPU / 1 MPI rankのGPU検証経路を維持し、全ての正式性能値はSi111-H、
TDDFT 100 steps、diagnostic OFF、3回測定の中央値で管理している。

## 2. GPU化状況

主な実装済み項目は以下のとおり。

- S2局所FFTと電荷密度再構築のcuFFT化・batch化
- 非局所ポテンシャル計算のOpenACC化とkernel融合
- VPJ積分、LOCPOT、交換相関、EWALD計算のGPU化
- HLOCALのzero、scatter、FFT、局所ポテンシャル積、gatherをGPU内で連続実行
- COEF/COEF0や静的metadataのdevice常駐化
- band非依存データの事前計算と再利用
- pinned host memoryによる転送時間短縮
- 不要なHost–Device同期・転送境界の削減

時間発展ループ内で識別したGPU化候補39箇所のうち、26箇所にOpenACC compute処理を
実装している。候補箇所数ベースでは約66.7%である。ただし、この値はソース上の
対応箇所数であり、GPU使用率や処理時間比率を直接表すものではない。

## 3. 性能測定結果

### プラットフォーム別正式値

| プラットフォーム | 実行構成 | 中央値 | range | 正常性 |
|---|---|---:|---:|---|
| NVIDIA A100-PCIE-40GB | NVHPC/OpenACC/cuFFT、1 GPU / 1 MPI | 63.2135秒 | 0.1034秒 | PASS |
| NVIDIA H100 PCIe | NVHPC/OpenACC/cuFFT、1 GPU / 1 MPI | 34.1090秒 | 0.0906秒 | PASS |
| Intel Xeon 6980P | ifx/mpiifx＋FFTW、32 MPI x 8 OpenMP、256コア | 16.5393秒 | 0.0579秒 | PASS |

A100では、初期の採用済みGPU実装の約146.54秒から63.21秒まで短縮した。
短縮率は約56.9%、wall比では約2.32倍の高速化である。H100はA100より
約46.0%短く、wall比で約1.85倍高速だった。

x86値は256 CPUコアを用いた結果であり、GPU測定は1 GPUである。したがって、
x86とGPUの値は実測wall timeとして掲載するが、プロセッサ単体性能や電力効率の
直接比較には使用しない。

### x86構成最適化

x86ではMPI/OpenMP構成をscreeningし、16 MPI x 1 OpenMPの約29.35秒から、
32 MPI x 8 OpenMPの約16.54秒へ短縮した。約43.7%の改善である。

Intel MPIのscatter配置も試したが、IPL2 domain-size errorが発生し、
約78.17秒まで悪化したため不採用とした。正式設定はcompact配置を維持している。

## 4. 正常性と移植性

- 全正式baselineでnormal checkとrelaxed compareにPASS
- H100とx86の反復runではrun 01とのstrict compareにもPASS
- A100、H100、x86は独立したbaseline系列として管理
- CPU/FFTW fallbackを維持
- GPU実装は1 GPU / 1 MPI rankを正式検証経路として維持
- 不採用実験は記録後にsourceを採用経路へ戻している

## 5. 現在の課題

- 非局所ポテンシャルの融合kernelが主要処理として残っている
- 一部のHost処理、MPI境界、Host–Device同期が残っている
- tutorial入力はband数が32と小さく、GPUの並列度とoccupancyを確保しにくい
- SEPPOTF batch化や追加kernel融合は、正しく動作しても性能改善につながらなかった
- managed/unified memoryはpinned separate memoryより大幅に遅かった
- compiler option変更による改善は小さく、正式baseline更新には至らなかった
- production規模入力と対応する正解referenceがなく、大規模時の性能を未評価

## 6. 今後の方針

- 小規模tutorial入力に対する細かなmicro tuningは一旦停止する
- production規模入力と正解referenceを準備する
- 実運用規模でGPU利用率、kernel時間、同期、転送量を再評価する
- 残るHost処理と同期境界を対象に、GPUが連続稼働できる区間を拡大する
- A100、H100、x86のbaselineを引き続き独立管理する

現時点で保留中のA100、H100、x86実行コマンドはない。
