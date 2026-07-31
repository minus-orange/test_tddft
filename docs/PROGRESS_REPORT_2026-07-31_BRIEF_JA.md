# FPSEID21 TDDFT GPU化 進捗報告（短縮版）

報告日: 2026-07-31

## GPU化状況

TDDFTの主要な時間発展処理をOpenACCとcuFFTでGPU化した。

- 非局所ポテンシャル、FFT、電荷密度、局所ポテンシャルなどをGPU化
- 配列のGPU常駐化とHost–Device転送削減を実施
- GPU化候補箇所の約67%に対応
- CPU/FFTW実行経路も維持

## 性能

Si111-H、TDDFT 100 steps、diagnostic OFFの正式測定値。

| プラットフォーム | 実行構成 | 実行時間 |
|---|---|---:|
| NVIDIA A100 | 1 GPU / 1 MPI | 約63.2秒 |
| NVIDIA H100 | 1 GPU / 1 MPI | 約34.1秒 |
| Intel Xeon 6980P | 256コア、32 MPI x 8 OpenMP | 約16.5秒 |

A100ではGPU化初期の約146.5秒から約63.2秒へ短縮し、約2.3倍高速化した。
H100はA100より約1.85倍高速だった。全正式測定で計算結果の正常性を確認済み。

## 今後の課題

- 一部のHost処理とHost–Device同期が残っている
- 小規模tutorial入力ではGPU並列度が不足する
- production規模入力での性能・GPU利用率評価が必要
