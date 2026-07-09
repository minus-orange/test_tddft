# TDDFT GPU Residency Plan / TDDFT GPU常駐化方針

Date: 2026-07-09

This note records the next GPU optimization direction for the FPSEID21 TDDFT
`Si111-H` validation case. The scope is the current one-GPU, one-MPI-rank cuFFT
path.

このメモは、FPSEID21 TDDFT `Si111-H` 検証ケースに対する次のGPU最適化方針を
記録します。対象は、現在確認している1 GPU / 1 MPI rankのcuFFT経路です。

## Current Finding / 現状

The cuFFT version is numerically acceptable in relaxed comparison against the
committed GNU reference.

cuFFT版は、コミット済みGNU基準とのrelaxed比較で許容範囲に入っています。

Current 100-step profile snapshot:

| backend | time_step_total | tmevl_s2 | s2_fft_local | fft_wrapper |
| --- | ---: | ---: | ---: | ---: |
| FFTW | 501.068871 s | 357.088483 s | 234.100450 s | 163.592244 s |
| cuFFT | 443.502158 s | 306.979328 s | 183.825464 s | 100.969549 s |
| cuFFT + detailed timer | 450.275156 s | 312.923191 s | 190.457058 s | 109.613606 s |

The detailed cuFFT profile showed:

| item | value |
| --- | ---: |
| cuFFT calls | 336589 |
| host-to-device copy | 47.947526631 s |
| cuFFT execution | 15.640776237 s |
| device-to-host copy | 41.666117352 s |
| total wrapper time | 105.254420208 s |

The dominant cost is data transfer, not the FFT kernel itself.

支配的なコストはFFTカーネルではなく、Host <-> Device転送です。

## Source Data Flow / ソース上のデータフロー

The hot region is `S2_` in
`FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`.

ホット領域は `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f` の `S2_` です。

The measured regions map as follows:

| profile label | source role |
| --- | --- |
| `tmevl_s2` | whole `S2_` operation |
| `s2_nonlocal` | nonlocal pseudopotential application via `exnlp_only_make` and `exnlp_gemm` |
| `s2_fft_local` | local-potential FFT section |
| `fft_wrapper` | individual FFT wrapper calls |

Inside `s2_fft_local`, the data path is:

1. `P(IG,iib)` is scattered into `RHO1_(JG,iib)` using `J2G`.
2. `FFT3BX_fftwASL(..., RHO1_(1,iib), RHO2_(1,iib), ...)` is called for each band.
3. `VG(i)=VGG(i)+Vloc(i)` is prepared on the CPU.
4. The local potential is applied as
   `RHO2_(I,iib)=exp(-i*dt*VG(I))*RHO1_(I,iib)`.
5. `FFT3FX_fftwASL(..., RHO2_(1,iib), RHO1_(1,iib), ...)` is called for each band.
6. `RHO2_(JG,iib)` is gathered back into `P(IG,iib)`.

`RHO1_(NXYZ,mxbnd)` and `RHO2_(NXYZ,mxbnd)` are the first practical GPU
residency targets because each band slice is contiguous in Fortran memory.

`RHO1_(NXYZ,mxbnd)` と `RHO2_(NXYZ,mxbnd)` は、各bandスライスがFortran配列上で
連続しているため、最初にGPU常駐化する対象として扱いやすいです。

## Recommended Implementation Order / 実装順序

### Step 1: Batched local FFT wrapper

Add a new cuFFT path for the `s2_fft_local` block that processes the active
band block as a batch instead of calling cuFFT once per band.

`s2_fft_local` のactive band blockをまとめて処理するcuFFT経路を追加します。
bandごとにcuFFTを呼ぶ現状から、batch処理へ変更します。

Expected benefit:

- Fewer C/Fortran wrapper calls.
- Better cuFFT plan usage.
- Easier transition to resident buffers.

### Step 2: Keep `RHO1_` and `RHO2_` on the GPU across the local FFT pair

Move the middle local-potential operation to the GPU:

```fortran
RHO2_(I,iib)=dcmplx(dcos(fac),-dsin(fac))*RHO1_(I,iib)
```

The GPU path should perform:

```text
H2D RHO1_ batch
cuFFT inverse/bx
GPU local-potential multiply using VG
cuFFT forward/fx
GPU scaling
D2H RHO2_ batch
```

This changes the transfer granularity from one transfer pair per FFT call to
one transfer pair per local FFT block.

### Step 3: Leave nonlocal sections on CPU initially

The two `s2_nonlocal` regions use `exnlp_only_make` and `exnlp_gemm`. These
should remain CPU-side until the local FFT path is validated.

2つの `s2_nonlocal` 領域は、まずCPU側に残します。ローカルFFT部の常駐化が
正しく動くことを確認してから、次段階として検討します。

### Step 4: Reconsider larger residency only after validation

If Step 2 passes and transfer is still the dominant cost, then consider moving
the scatter/gather around `P`, `J2G`, and possibly the nonlocal GEMM path.

Step 2後も転送が支配的な場合に、`P`/`J2G` のscatter/gatherや非局所GEMMの
GPU化を検討します。

## Validation Policy / 確認方法

Use the existing TDDFT archive and comparison flow:

```sh
LABEL=<label> ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/

python3 ./tools/check_tddft_result.py check \
  ./run/tddft_archives/<label>/tddft.out \
  --err ./run/tddft_archives/<label>/tddft.err

python3 ./tools/check_tddft_result.py compare \
  ./run/tddft_archives/<label>/tddft.err
```

For performance, compare at least:

- `time_step_total`
- `tmevl_s2`
- `s2_fft_local`
- `fft_wrapper`
- `[Timer Output]` entries for `cufft_fft3bx` and `cufft_fft3fx`
- `FPSEID_CUFFT_PROFILE` transfer and FFT timings

Correctness acceptance remains the relaxed TDDFT comparison policy unless a
specific strict test is being run.

正当性確認は、特にstrict確認を指定しない限り、既存のTDDFT relaxed比較基準を
使います。

## Current Decision / 現時点の判断

The next coding target is not replacing more physics kernels immediately. The
next target is reducing transfer frequency in `s2_fft_local` by batching and
keeping the local FFT pair resident on the GPU.

次のコーディング対象は、物理カーネルを一気に置き換えることではありません。
まず `s2_fft_local` のbatch化とローカルFFTペアのGPU常駐化により、転送回数を
減らします。
