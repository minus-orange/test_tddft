# Step 116 Non-cuFFT OpenACC Launch Shapes

Step 116のcurrent-source Nsight Systems archiveから、cuFFT library kernelを
除いたNVHPC OpenACC kernel 24構成のlaunch shapeを集計した。A100は
`nvhpc_cufft_1rank_02_STEP116_A100_CURRENT_NSYS_03`、H100は
`nvhpc_cufft_1rank_02_STEP116_H100_CURRENT_NSYS_01`を使用した。

両platformでGrid、Block、threads/launch、launch回数は全24構成とも一致した。
`threads/launch`は`Grid x Block`で求めた1 launch当たりの総起動thread数であり、
同時resident thread数や有効loop反復数ではない。時間はprofiler overheadを含む
診断値で、正式baselineには使用しない。

| Kernel | Grid x Block | threads/launch | launches | A100 total ms | A100 reg/thread | H100 total ms | H100 reg/thread |
|---|---:|---:|---:|---:|---:|---:|---:|
| `exnlp_gemm_body_fused_2531_gpu` | 32 x 256 | 8,192 | 9,440 | 8,253.502 | 63 | 3,184.705 | 72 |
| `vpj_gen_acc_integral_429_gpu` | 42 x 128 | 5,376 | 2,000 | 1,565.170 | 60 | 718.420 | 60 |
| `s2__2090_gpu` | 32 x 128 | 4,096 | 4,720 | 592.181 | 40 | 253.899 | 43 |
| `s2__1974_gpu` | 7,257 x 128 | 928,896 | 4,720 | 409.062 | 16 | 192.207 | 20 |
| `s2__2053_gpu` | 32 x 128 | 4,096 | 4,720 | 324.654 | 61 | 143.445 | 63 |
| `exkin__1282_gpu` | 7,257 x 128 | 928,896 | 9,440 | 219.666 | 44 | 95.790 | 46 |
| `s2__1961_gpu` | 32 x 128 | 4,096 | 4,720 | 133.635 | 23 | 50.166 | 29 |
| `fft3fx_fftwASL_acc_batch_179_gpu` | 7,257 x 128 | 928,896 | 4,720 | 85.424 | 34 | 35.044 | 40 |
| `rhoofk_acc_batch_2550_gpu` | 7,257 x 128 | 928,896 | 944 | 80.868 | 16 | 32.383 | 20 |
| `s2__2025_gpu` | 227 x 128 | 29,056 | 4,720 | 27.111 | 44 | 10.041 | 46 |
| `ewaldy_835_gpu` | 196 x 128 | 25,088 | 101 | 26.343 | 71 | 14.838 | 75 |
| `locpot_529_gpu` | 227 x 128 | 29,056 | 606 | 24.502 | 62 | 10.026 | 62 |
| `frprmn_1630_gpu` | 14,513 x 128 | 1,857,664 | 372 | 17.979 | 36 | 12.530 | 40 |
| `rhoofk_acc_batch_2563_gpu` | 7,257 x 128 | 928,896 | 944 | 17.086 | 34 | 7.008 | 38 |
| `rhoofk_acc_batch_2542_gpu` | 7,257 x 128 | 928,896 | 944 | 13.891 | 34 | 5.925 | 40 |
| `rhoofk_acc_batch_2571_gpu` | 227 x 128 | 29,056 | 944 | 12.284 | 40 | 4.505 | 40 |
| `hlocal_2657_gpu` | 227 x 128 | 29,056 | 768 | 5.465 | 16 | 1.810 | 16 |
| `frprmn_1615_gpu` | 14,513 x 128 | 1,857,664 | 100 | 4.971 | 36 | 3.320 | 40 |
| `s2vxc2_137_gpu` | 227 x 128 | 29,056 | 573 | 4.891 | 48 | 2.054 | 52 |
| `hlocal_2672_gpu` | 227 x 128 | 29,056 | 768 | 4.150 | 16 | 1.438 | 18 |
| `hlocal_2665_gpu` | 227 x 128 | 29,056 | 768 | 3.592 | 24 | 1.283 | 24 |
| `fft3fx_fftwASL_acc_144_gpu` | 227 x 128 | 29,056 | 768 | 3.161 | 16 | 1.170 | 16 |
| `hlocal_2653_gpu` | 227 x 128 | 29,056 | 768 | 2.771 | 16 | 0.939 | 16 |
| `ewaldy_881_gpu` | 1 x 128 | 128 | 101 | 0.334 | 40 | 0.158 | 42 |

## Interpretation

- 支配的な融合非局所kernelは32 blocks、VPJ kernelは42 blocksに限られる。
  Step 116 NSYSで両者は非cuFFT kernel時間の大部分を占めるため、tutorial入力の
  小さいband並列幅が性能上の重要な制約である。
- `s2__2090_gpu`、`s2__2053_gpu`、`s2__1961_gpu`も32 blocksである。一方、
  EXKIN、RHO操作、FFT後処理、FRPRMNなどには数百から14,513 blocksのgridがあり、
  GPU経路全体を一律に「並列度不足」とは評価できない。
- block sizeは融合非局所kernelだけが256で、残る23構成は128である。A100/H100間で
  geometryは不変だが、register/threadは一部で異なる。これはarchitecture targetと
  compiler code generationの差を含む。
- 次の性能判断では、production規模入力で支配kernelのgrid幅、occupancy、kernel時間が
  どのように変わるかを再測定する。小さいtutorial上でgridの広い低コストkernelを
  個別微調整する根拠にはしない。
