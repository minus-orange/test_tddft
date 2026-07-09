# TDDFT GPU Residency Plan / TDDFT GPU常駐化方針

Date: 2026-07-09

This note records the next GPU optimization direction for the FPSEID21 TDDFT
`Si111-H` validation case. The scope is the current one-GPU, one-MPI-rank path.
The first implementation choice is OpenACC. CUDA libraries such as cuFFT may be
used, but custom CUDA kernels are not the first target.

このメモは、FPSEID21 TDDFT `Si111-H` 検証ケースに対する次のGPU最適化方針を
記録します。対象は、現在確認している1 GPU / 1 MPI rankの経路です。最初の
実装手段はOpenACCとし、cuFFTなどのCUDAライブラリは使用可とします。ただし、
独自CUDAカーネルを書く実装は最初の対象から外します。

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

## Implementation Policy / 実装方針

Use OpenACC for GPU-resident arrays and element-wise work in the TDDFT Fortran
code. Use cuFFT only as a library backend for FFT operations.

TDDFTのFortran側では、GPU常駐配列と要素ごとの処理をOpenACCで表現します。
FFT操作のみ、ライブラリbackendとしてcuFFTを使います。

The practical meaning is:

- Prefer `!$acc data`, `!$acc parallel loop`, `!$acc kernels`, and
  `!$acc host_data use_device(...)` in new TDDFT GPU work.
- Do not introduce new hand-written CUDA kernels as the primary implementation
  path.
- Keep the existing CPU/FFTW path and GNU/Intel-oriented source variants usable.
- Treat cuFFT calls as library calls that can operate on OpenACC-managed device
  buffers.
- Keep the existing host-copy cuFFT wrapper for compatibility, and add a
  separate device-pointer cuFFT wrapper for OpenACC-managed arrays.

実務上は以下の方針です。

- 新しいTDDFT GPU化では `!$acc data`, `!$acc parallel loop`,
  `!$acc kernels`, `!$acc host_data use_device(...)` を優先します。
- 独自CUDAカーネルを主実装として追加しません。
- 既存のCPU/FFTW経路、およびGNU/Intel向けsource variantは維持します。
- cuFFTはOpenACC管理下のdevice bufferに対して動作するライブラリ呼び出しとして
  扱います。
- 既存のhost-copy型cuFFT wrapperは互換性維持用として残し、OpenACC管理配列用に
  device pointerを受け取る別APIを追加します。

## cuFFT Wrapper API Boundary / cuFFT Wrapper API境界

The current cuFFT wrapper copies host arrays to a private CUDA buffer, executes
cuFFT, and copies the result back. That path should remain as the compatibility
backend because it has already passed validation.

現行のcuFFT wrapperは、host配列をprivate CUDA bufferへコピーし、cuFFTを実行して
結果をhostへ戻します。この経路は検証済みのため、互換backendとして残します。

For OpenACC residency, add a second wrapper interface that receives a device
pointer and does not perform host-device copies:

OpenACC常駐化用には、device pointerを受け取り、host-device copyを行わない
第2のwrapper interfaceを追加します。

```text
existing compatibility API:
  host array -> wrapper H2D -> cuFFT -> wrapper D2H -> host array

new OpenACC API:
  OpenACC device array -> host_data use_device -> cuFFT only
```

The new device-pointer path should:

- assume the input pointer is already a valid device pointer;
- execute cuFFT in place;
- optionally apply cuFFT normalization through OpenACC on the Fortran side;
- report errors without silently falling back to host copies.

新しいdevice-pointer経路では以下を前提にします。

- 入力pointerはすでに有効なdevice pointerである。
- cuFFTはin-placeで実行する。
- cuFFT正規化は必要に応じてFortran側OpenACC loopで行う。
- エラー時に暗黙のhost copy fallbackを行わない。

This separation is important: if the OpenACC path accidentally calls the
host-copy wrapper, transfer time will remain dominant and the experiment will
not test GPU residency.

この分離は重要です。OpenACC経路が誤ってhost-copy wrapperを呼ぶと、転送時間が
支配的なままで、GPU常駐化の検証になりません。

## Recommended Implementation Order / 実装順序

### Step 1: OpenACC data region for the local FFT work arrays

Add an OpenACC data region around the `S2_` local FFT section so `RHO1_`,
`RHO2_`, and the local-potential vector can remain on the GPU while the local
FFT pair is evaluated.

`S2_` のlocal FFT部にOpenACC data regionを追加し、local FFTペアの処理中に
`RHO1_`, `RHO2_`, local potential vectorをGPU上に保持します。

Expected benefit:

- Makes data movement explicit and measurable in Fortran.
- Gives a stable base for cuFFT/OpenACC interoperability.
- Avoids introducing custom CUDA kernels before the data lifetime is clear.

The first data-region boundary should be deliberately narrow:

```text
CPU-side nonlocal section completes
copyin P, VGG, Vloc, J2G as needed for the local FFT section
create/copy RHO1_, RHO2_, VG on device
run local FFT section on device
copyout P before returning to CPU-side/nonlocal code
```

最初のdata region境界は意図的に狭くします。

```text
CPU側の非局所項処理が完了
local FFT部に必要な P, VGG, Vloc, J2G をdeviceへ転送
RHO1_, RHO2_, VG をdevice上で作成または保持
local FFT部をdevice上で実行
CPU側処理へ戻る前に P をhostへ戻す
```

This keeps the CPU/GPU ownership clear while the nonlocal sections remain on the
CPU.

非局所項をCPU側に残す段階では、この境界によりCPU/GPUの所有関係を明確にします。

Initial implementation note:

初期実装メモ:

- Step 1 may still call the existing host-copy FFT wrapper.
- In that transitional state, use explicit `!$acc update self(...)` before FFT
  calls and `!$acc update device(...)` after FFT calls.
- This does not remove FFT transfer overhead yet. It verifies the OpenACC data
  lifetime and synchronization boundary before adding the device-pointer cuFFT
  API in Step 2.

- Step 1では、既存のhost-copy型FFT wrapperを呼ぶ移行状態を許容します。
- その場合、FFT呼び出し前に `!$acc update self(...)`、FFT呼び出し後に
  `!$acc update device(...)` を明示します。
- この段階ではFFT転送オーバーヘッドはまだ削減されません。Step 2で
  device-pointer cuFFT APIを追加する前に、OpenACC data lifetimeと同期境界を
  検証することを目的とします。

### Step 2: Use cuFFT through OpenACC device pointers

Process the active band block using cuFFT on OpenACC-managed device memory.
The Fortran side should enter `!$acc host_data use_device(...)` around the cuFFT
library call instead of copying each band to a private CUDA buffer inside the C
wrapper.

OpenACC管理下のdevice memoryに対して、active band blockをcuFFTで処理します。
Fortran側ではcuFFT呼び出しの周囲で `!$acc host_data use_device(...)` を使い、
C wrapper内部でbandごとにprivate CUDA bufferへコピーする方式を減らします。

### Step 3: Move the local-potential multiply with OpenACC

Move the middle local-potential operation to the GPU:

```fortran
RHO2_(I,iib)=dcmplx(dcos(fac),-dsin(fac))*RHO1_(I,iib)
```

The GPU path should perform:

```text
OpenACC data region for RHO1_/RHO2_/VG
cuFFT inverse/bx using OpenACC device pointer
OpenACC local-potential multiply using VG
cuFFT forward/fx using OpenACC device pointer
OpenACC scaling
copy out only the data required by the following CPU-side section
```

This changes the transfer granularity from one transfer pair per FFT call to
one transfer pair per local FFT block.

Build `VG` on the GPU from `VGG` and `Vloc` unless a validation issue requires a
temporary CPU-generated `VG`:

```fortran
VG(I)=VGG(I)+Vloc(I)
```

`VG` は、検証上の理由で一時的にCPU生成が必要な場合を除き、GPU上で `VGG` と
`Vloc` から作ります。

```fortran
VG(I)=VGG(I)+Vloc(I)
```

### Step 4: Leave nonlocal sections on CPU initially

The two `s2_nonlocal` regions use `exnlp_only_make` and `exnlp_gemm`. These
should remain CPU-side until the local FFT path is validated.

2つの `s2_nonlocal` 領域は、まずCPU側に残します。ローカルFFT部の常駐化が
正しく動くことを確認してから、次段階として検討します。

### Step 5: Reconsider larger residency only after validation

If Step 3 passes and transfer is still the dominant cost, then consider moving
the scatter/gather around `P`, `J2G`, and possibly the nonlocal GEMM path.

Step 3後も転送が支配的な場合に、`P`/`J2G` のscatter/gatherや非局所GEMMの
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

For the first OpenACC residency changes, also run a short strict-oriented check
before relying on the 100-step relaxed comparison:

OpenACC常駐化の初期変更では、100 step relaxed比較に進む前に短時間のstrict寄り
確認も行います。

```text
1. 2-step or smallest practical TDDFT run.
2. check_tddft_result.py check must pass.
3. compare against the current validated output with tighter tolerances where
   practical.
4. then run the 100-step relaxed comparison.
```

The goal is to catch synchronization mistakes, stale device data, or accidental
use of the host-copy cuFFT wrapper early.

目的は、同期ミス、古いdevice dataの使用、host-copy cuFFT wrapperの誤使用を
早い段階で検出することです。

## NVHPC OpenACC Build Notes / NVHPC OpenACCビルドメモ

The OpenACC path should be built explicitly with NVHPC OpenACC flags. The exact
GPU architecture flag can be environment-specific, but the build must make the
OpenACC mode visible in the command line.

OpenACC経路は、NVHPCのOpenACC flagを明示してビルドします。GPU architecture flag
は環境依存でよいですが、OpenACC modeであることがビルドコマンド上で分かる
ようにします。

Typical direction:

```sh
BUILD_REPORT=1
FFLAGS="-O2 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays -Kieee"
FFT_BACKEND=cufft
```

`BUILD_REPORT=1` appends compiler-report flags and prints the final build
settings. For NVHPC the default report flags are:

`BUILD_REPORT=1` はcompiler report flagを追加し、最終的なビルド設定を表示します。
NVHPCでのdefault report flagは以下です。

```sh
REPORT_FLAGS="-Minfo=accel -Minfo=mp"
```

Use the report to confirm whether OpenACC regions in `S2_` are recognized and
whether CPU OpenMP regions are still being compiled as expected.

このreportにより、`S2_` のOpenACC regionが認識されているか、既存CPU OpenMP
regionが想定通りコンパイルされているかを確認します。

For cuFFT linkage, keep using the existing cuFFT library settings. If the
OpenACC device-pointer wrapper needs CUDA runtime types or cuFFT declarations,
include/library paths should remain explicit as in the validated cuFFT build.

cuFFT linkは既存のcuFFT library設定を継続します。OpenACC device-pointer wrapper
がCUDA runtime型やcuFFT宣言を必要とする場合、include/library pathは検証済み
cuFFTビルドと同様に明示します。

## Current Decision / 現時点の判断

The next coding target is not replacing more physics kernels immediately and
not writing custom CUDA kernels. The next target is reducing transfer frequency
in `s2_fft_local` by using OpenACC data regions and cuFFT/OpenACC device-pointer
interoperability.

次のコーディング対象は、物理カーネルを一気に置き換えることではありません。
また、独自CUDAカーネルを書くことでもありません。まずOpenACC data regionと
cuFFT/OpenACC device pointer連携により、`s2_fft_local` の転送回数を減らします。
