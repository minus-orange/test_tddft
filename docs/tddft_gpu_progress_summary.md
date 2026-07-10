# TDDFT GPU Progress Summary / TDDFT GPU化進捗まとめ

Date: 2026-07-10

This note summarizes the TDDFT GPU work performed on the
`tddft-openacc-residency` branch for the FPSEID21 `Si111-H` 100-step validation
case. The current policy is one GPU with one MPI rank, using OpenACC for data
residency and element-wise kernels, and cuFFT as a CUDA library backend.

このメモは、`tddft-openacc-residency` ブランチで実施した FPSEID21
`Si111-H` 100 step 検証ケースの TDDFT GPU 化内容をまとめたものです。現時点の
方針は 1 GPU / 1 MPI rank とし、データ常駐と要素演算は OpenACC、FFT は CUDA
ライブラリ backend として cuFFT を使用します。

## Scope / 対象範囲

- Target program: `FPSEID21/tddft_2022October`
- Hot routine: `S2_` in `tmevl10_Avec_v4.f`
- Main target region: local-potential FFT section, `s2_fft_local`
- Validation input: `Si111-H_tm.in_100steps`
- Validation command: `tools/check_tddft_result.py compare ...`
- Reference: `docs/runtime_logs/gnu_si111_h_tddft_100steps.out`
- Comparison policy: relaxed tolerance

対象は TDDFT の `S2_` 内にある局所ポテンシャル FFT 部です。比較基準は
コミット済み GNU 100 step ログで、通常確認は relaxed tolerance を使用します。

## Implemented Changes / 実装済み内容

### Baseline: cuFFT host-copy backend

The first cuFFT implementation added `fft_cufft.f` and `fpseid_cufft_wrap.c`.
It preserved the original Fortran FFT entry names and copied each FFT input
from host to GPU, executed cuFFT, then copied the result back.

最初の cuFFT 実装では `fft_cufft.f` と `fpseid_cufft_wrap.c` を追加しました。
Fortran 側の FFT entry 名は既存のまま維持し、各 FFT 呼び出しごとに host から
GPU へコピー、cuFFT 実行、GPU から host へコピーする方式です。

### Step 1: OpenACC local FFT data region

An OpenACC data region was added around the S2 local FFT section. The work arrays
`RHO1_`, `RHO2_`, and `VG` are created on the device, while `P`, `VGG`, `Vloc`,
and `J2G` are copied in for the local FFT block.

Step 1 では S2 の local FFT 部に OpenACC data region を追加しました。
`RHO1_`, `RHO2_`, `VG` を device 上に作成し、`P`, `VGG`, `Vloc`, `J2G` を
local FFT block 用に転送します。

At this stage the FFT path still used the host-copy cuFFT wrapper, so explicit
`update self` and `update device` calls remained around the FFT calls.

この段階では FFT 呼び出し自体は host-copy 型 cuFFT wrapper のままだったため、
FFT 前後に `update self` / `update device` が残っていました。

### Step 2: OpenACC kernels for local-potential work

The scatter, local-potential construction, local-potential multiply, and gather
loops were moved into OpenACC kernels. Additional timers were added:

- `s2_acc_update`
- `s2_acc_kernel`
- `startup_before_steps`
- `fft_plan_init`

Step 2 では scatter、local potential 作成、local potential multiply、gather の
ループを OpenACC kernel 化しました。併せて `s2_acc_update`,
`s2_acc_kernel`, `startup_before_steps`, `fft_plan_init` のタイマーを追加しました。

### Step 3: Device-resident cuFFT path

A second cuFFT wrapper API was added:

```text
fpseid_cufft_exec_device
```

This API receives an OpenACC-managed device pointer and executes cuFFT in place
without wrapper-managed host-to-device or device-to-host copies.

Step 3 では OpenACC 管理下の device pointer を受け取る cuFFT API
`fpseid_cufft_exec_device` を追加しました。この経路では wrapper 内部の
host-to-device / device-to-host コピーを行わず、device pointer 上で cuFFT を
in-place 実行します。

New Fortran entry points were added:

```text
FFT3BX_fftwASL_ACC
FFT3FX_fftwASL_ACC
```

For the cuFFT backend, these use `!$acc host_data use_device(...)` to pass the
OpenACC device pointer to the C wrapper. The forward FFT normalization is done
with an OpenACC loop on the device.

cuFFT backend では、これらの entry point が `!$acc host_data use_device(...)`
で OpenACC device pointer を C wrapper に渡します。forward FFT 後の正規化は
OpenACC loop で device 上実行します。

For FFTW compatibility, the same `_ACC` entry names were added to `fft_fftw.f`
and simply delegate to the original host FFT wrappers.

FFTW 互換性維持のため、`fft_fftw.f` にも同名の `_ACC` entry を追加し、従来の
host FFT wrapper へ委譲する形にしています。

## Performance Snapshot / 性能スナップショット

All values below are 100-step `Si111-H` TDDFT runs on the tested NVHPC/A100
environment. Exact times can vary by run, but the trend is stable.

以下は検証環境での `Si111-H` TDDFT 100 step 実行結果です。実行ごとに多少の
揺らぎはありますが、傾向確認用の値です。

| stage | check | compare | wall_sec | time_step_total | s2_fft_local | fft_wrapper | s2_acc_update | s2_acc_kernel |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cuFFT host-copy baseline | PASS | PASS | 443.2 s | 443.5 s | 183.8 s | 101.0 s | n/a | n/a |
| Step 1 | PASS | PASS | 540.2 s | 540.5 s | 282.0 s | 106.1 s | n/a | n/a |
| Step 2 | PASS | PASS | 524.9 s | 525.1 s | 267.6 s | 106.5 s | 93.3 s | 58.3 s |
| Step 3 | PASS | PASS | 360.3 s | 360.6 s | 104.6 s | 30.4 s | 11.1 s | 57.9 s |

Step 3 produced the largest improvement because the dominant transfer overhead
around the S2 FFT pair was removed.

Step 3 では S2 の FFT ペア周辺で支配的だった転送オーバーヘッドを削減できたため、
最も大きな改善が出ています。

## cuFFT Transfer Profile / cuFFT転送プロファイル

The detailed cuFFT wrapper profile changed as follows:

詳細 cuFFT wrapper profile は以下のように変化しました。

| stage | count | h2d_sec | fft_sec | d2h_sec | total_sec |
| --- | ---: | ---: | ---: | ---: | ---: |
| Step 2 | 336589 | 50.247 | 15.054 | 36.860 | 102.162 |
| Step 3 | 336589 | 6.125 | 13.636 | 6.285 | 26.045 |

The remaining H2D/D2H time indicates that some FFT calls still use the
compatibility host-copy wrapper. The major S2 local FFT path is now using the
device-resident cuFFT entry points.

まだ H2D/D2H が 0 ではないため、一部の FFT 呼び出しは互換用 host-copy wrapper
を通っています。ただし、主要な S2 local FFT 経路は device-resident cuFFT entry
を使用する状態になっています。

## Current Interpretation / 現時点の解釈

- Correctness is acceptable for the current validation case:
  `check_tddft_result.py check` and `compare` both pass.
- Step 3 validates the OpenACC + cuFFT device-pointer direction.
- `s2_acc_update` dropped from about 93 s to about 11 s.
- `fft_wrapper` dropped from about 106 s to about 30 s.
- `s2_acc_kernel` stayed around 58 s, so the next optimization target is now
  kernel work and remaining data movement, not the cuFFT kernel itself.

- 現在の検証ケースでは計算結果は許容範囲内です。
- Step 3 により OpenACC + cuFFT device-pointer 方針が有効であることを確認しました。
- `s2_acc_update` は約 93 秒から約 11 秒へ減少しました。
- `fft_wrapper` は約 106 秒から約 30 秒へ減少しました。
- `s2_acc_kernel` は約 58 秒で大きく変わっていないため、次の対象は cuFFT
  カーネルそのものではなく、kernel 部分と残るデータ移動です。

## Remaining Issues / 残課題

1. Identify remaining host-copy FFT calls.

   `FPSEID_CUFFT_PROFILE` still reports non-zero `h2d_sec` and `d2h_sec`.
   Locate call sites that still use `FFT3BX_fftwASL` / `FFT3FX_fftwASL` instead
   of the `_ACC` entry points, then decide whether they should also move to the
   device-resident path.

   `FPSEID_CUFFT_PROFILE` ではまだ `h2d_sec` と `d2h_sec` が 0 ではありません。
   `_ACC` 版ではなく従来の `FFT3BX_fftwASL` / `FFT3FX_fftwASL` を呼んでいる箇所を
   特定し、device-resident 経路へ移すべきか判断します。

2. Break down `s2_acc_kernel`.

   `s2_acc_kernel` remains about 58 s. Split this into scatter, local potential
   build, local-potential multiply, forward-normalization, and gather timers.

   `s2_acc_kernel` は約 58 秒残っています。scatter、local potential 作成、
   local-potential multiply、forward 正規化、gather に分けて測定します。

3. Reduce residual synchronization and update overhead.

   `s2_acc_update` is much smaller but still about 11 s. Confirm whether this is
   mostly the final `P` update back to host or other implicit synchronization.

   `s2_acc_update` は大きく減りましたが、まだ約 11 秒あります。これが主に最後の
   `P` host 戻しなのか、他の暗黙同期なのかを確認します。

4. Decide the boundary for keeping `P` resident.

   The current implementation copies `P` back before returning to CPU-side code.
   Keeping `P` resident across a larger TDDFT section may reduce transfers, but
   it also expands the GPU/CPU ownership boundary.

   現在は CPU 側処理へ戻る前に `P` を host へ戻します。より広い TDDFT 区間で
   `P` を常駐させれば転送は減る可能性がありますが、GPU/CPU の所有境界が広がります。

5. Leave multi-rank GPU execution out of scope for now.

   The current validated GPU direction is one GPU with one MPI rank. Multi-rank
   NVHPC TDDFT already showed rank-count issues in the CPU FFTW path, so it
   should be handled separately from the first GPU residency work.

   現時点の GPU 方針は 1 GPU / 1 MPI rank です。NVHPC TDDFT は CPU FFTW 経路でも
   rank 数依存の問題が確認されているため、multi-rank GPU 化は最初の GPU 常駐化
   とは分けて扱います。

## Recommended Next Step / 推奨される次ステップ

The next coding step should instrument and reduce the remaining costs in this
order:

次の実装は、以下の順に測定と削減を進めるのが妥当です。

1. Add finer timers inside `s2_acc_kernel`.
2. Identify remaining non-`_ACC` FFT wrapper calls.
3. Confirm whether final `P` copyout dominates `s2_acc_update`.
4. Only after the above, consider extending the OpenACC data lifetime beyond
   the current local FFT block.

This keeps the next experiment measurable and avoids expanding the GPU-resident
region before the remaining Step 3 costs are understood.

これにより、次の実験を測定可能な範囲に保ち、Step 3 後に残ったコストの内訳を
理解する前に GPU 常駐範囲を広げすぎることを避けられます。

## Added Fine-Grained Timers / 追加した細粒度タイマー

After the Step 3 run, additional timers were added to split the remaining
`s2_acc_kernel` and `s2_acc_update` costs. These timers are nested inside the
existing aggregate timers, so the aggregate labels remain comparable with the
previous Step 1-3 measurements.

Step 3 実行後、残っている `s2_acc_kernel` と `s2_acc_update` の内訳を見るために
細粒度タイマーを追加しました。これらは既存の集計タイマーの内側で計測するため、
従来の Step 1-3 の集計ラベルとの比較は維持されます。

| id | label | measured work |
| ---: | --- | --- |
| 19 | `s2_zero_rho2` | zero initialization of `RHO2_` |
| 20 | `s2_scatter_p` | scatter from `P` to `RHO1_` through `J2G` |
| 21 | `s2_vg_build` | build `VG = VGG + Vloc` |
| 22 | `s2_local_multiply` | apply the local-potential phase factor |
| 23 | `s2_gather_p` | gather from `RHO2_` back to `P` through `J2G` |
| 24 | `s2_copyout_p` | final `P` copyout from device to host |

These labels should appear in both `FPSEID_PROFILE` and `[Timer Output]`.

これらのラベルは `FPSEID_PROFILE` と `[Timer Output]` の両方に出力されます。

## Remaining Host-Copy FFT Calls / 残るhost-copy FFT呼び出し

The S2 local FFT block now calls `FFT3BX_fftwASL_ACC` and `FFT3FX_fftwASL_ACC`.
However, the codebase still has other compatibility FFT calls that use the
host-copy wrapper path. They are outside the current S2 local FFT residency
experiment and explain why `FPSEID_CUFFT_PROFILE` can still show non-zero
`h2d_sec` and `d2h_sec`.

S2 local FFT block は現在 `FFT3BX_fftwASL_ACC` / `FFT3FX_fftwASL_ACC` を呼びます。
一方で、コード全体にはまだ host-copy wrapper 経路を使う互換 FFT 呼び出しが
残っています。これらは現在の S2 local FFT 常駐化実験の外側にあるため、
`FPSEID_CUFFT_PROFILE` の `h2d_sec` / `d2h_sec` がまだ 0 にならない理由になります。

Main remaining call areas:

主な残存箇所:

- `gga_lib_3_PBE.f`: PBE/GGA derivative FFTs
- `lib4_ASL_2_check_Vext_SXACE.f`: startup/external-potential related FFTs
- `frprmn_tm12_check_Vext_Avec_v4.f`: force/minimization related FFTs
- `pspw_tm11_Vext_Avec_v4_alloc.f`: PSPW setup and related transforms
- other `tmevl10_Avec_v4.f` regions outside the current S2 local FFT block

These should not be moved blindly to `_ACC` because each area has a different
data lifetime and CPU/GPU ownership boundary. The next decision should be based
on the new fine-grained timer output.

これらはデータ寿命と CPU/GPU 所有境界がそれぞれ異なるため、機械的に `_ACC` 化
しない方が安全です。次の判断は、今回追加した細粒度タイマーの出力に基づいて
行います。

## Scatter Parallelization Experiment / scatter並列化実験

The Step 4 timer output showed that `s2_scatter_p` dominated the remaining
OpenACC kernel time. The first follow-up change flattens the `P -> RHO1_`
scatter loop from a band-outer nested loop into a single
`NXYZ * nbndloc` OpenACC loop. This gives the compiler a much larger iteration
space for the scatter kernel while preserving the same `J2G` mapping.

Step 4 の timer 出力では、残っている OpenACC kernel 時間の大半が
`s2_scatter_p` でした。最初の追試として、`P -> RHO1_` の scatter loop を
band 外側の二重 loop から `NXYZ * nbndloc` の一次元 OpenACC loop に変更しました。
これにより `J2G` mapping は維持したまま、scatter kernel の並列化粒度を大きく
します。

The Step 5 run passed both `check` and relaxed `compare`. In that run,
`s2_scatter_p` dropped from about 56 s to about 0.46 s, and total wall time
dropped to about 303 s. This confirms that the scatter loop flattening is a
useful optimization for the current one-rank A100 case.

Step 5 実行では `check` と relaxed `compare` の両方が PASS しました。
`s2_scatter_p` は約 56 秒から約 0.46 秒へ減少し、wall time は約 303 秒まで
短縮しました。現在の 1 rank / A100 ケースでは、scatter loop 平坦化は有効な
最適化と判断できます。

## Step 6: Nonlocal Split Timers / 非局所項の分解タイマー

After Step 5, the largest remaining S2 cost is `s2_nonlocal`. Step 6 adds nested
timers that split this aggregate region without changing the computation:

Step 5 後、S2 内で最も大きく残っているコストは `s2_nonlocal` です。Step 6 では
計算内容を変えず、この集計領域を次の2つに分解するネストタイマーを追加しました。

| id | label | measured work |
| ---: | --- | --- |
| 25 | `s2_nonlocal_make` | repeated `exnlp_only_make` calls that build `work2_`, `cfac_`, and `ngnl_` input data |
| 26 | `s2_nonlocal_gemm` | `exnlp_gemm` accumulation into `P` |

These timers are nested inside `s2_nonlocal`, so:

これらは `s2_nonlocal` の内側に入っているため、以下の関係になります。

```text
s2_nonlocal ≈ s2_nonlocal_make + s2_nonlocal_gemm + loop/control overhead
```

Use the next run to decide whether the next GPU work should target
`exnlp_only_make` construction, `exnlp_gemm`, or both.

次回の実行結果で、次の GPU 化対象を `exnlp_only_make` 側にするか、
`exnlp_gemm` 側にするか、あるいは両方にするかを判断します。

The Step 6 result showed that `s2_nonlocal_gemm` dominates this region:

Step 6 の結果では、この領域の大半が `s2_nonlocal_gemm` であることが分かりました。

```text
s2_nonlocal       about 119.0 sec
s2_nonlocal_make  about   3.3 sec
s2_nonlocal_gemm  about 115.7 sec
```

## Step 7: Experimental OpenACC exnlp_gemm / 実験的 OpenACC exnlp_gemm

Step 7 moves the inner work of `exnlp_gemm` to OpenACC while preserving the
outer `ia` order. The `ia` loop updates `coef` sequentially and therefore is
kept on the host side for correctness. Within each `ia`, the implementation
parallelizes over local bands and uses real/imaginary reductions for the dot
product.

Step 7 では `exnlp_gemm` の内側処理を OpenACC 化します。ただし `ia` loop は
`coef` を逐次更新する依存関係があるため、順序を維持します。各 `ia` の内側で
local band 方向を並列化し、dot product は実部・虚部の reduction に分けています。

This is intentionally conservative:

この変更は意図的に保守的です。

- It does not reorder the `ia` updates.
- It avoids complex reduction syntax and uses two real reductions.
- It is expected to validate correctness first; performance may still be
  limited by per-call data movement and kernel launch overhead.

- `ia` 更新順序は変更しません。
- complex reduction にはせず、実部・虚部の2つの実数 reduction に分けます。
- まず正しさの確認を優先します。性能は、呼び出しごとのデータ移動や kernel 起動
  overhead に制限される可能性があります。

Recommended archive label:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP7_01
```

## Step 8: exnlp_gemm Split Timers / exnlp_gemm 分解タイマー

Step 7 made `exnlp_gemm` correct and useful, but it remains the largest
nonlocal contribution. Step 8 adds nested timers to split the region without
changing the numerical algorithm.

Step 7 で `exnlp_gemm` は正しく動作し、有効な改善になりましたが、非局所項の
中ではまだ最大のコストです。Step 8 では数値アルゴリズムを変えずに、この領域を
分解するネストタイマーを追加しました。

| id | label | measured work |
| ---: | --- | --- |
| 27 | `exnlp_gemm_data` | whole OpenACC data region in `exnlp_gemm`, including transfer and kernels |
| 28 | `exnlp_gemm_dot` | dot-product/reduction kernel that builds `ct1` |
| 29 | `exnlp_gemm_update` | coefficient update kernel using `ct1` and `work1` |

`exnlp_gemm_data` is intentionally broad. It is not a pure copy timer; it
contains the OpenACC data-region lifetime plus the inner GPU kernels. If this
region is still expensive after the next run, the next step should separate
explicit `enter data` / `exit data` transfer timing from kernel timing.

`exnlp_gemm_data` は意図的に広い範囲です。純粋な転送時間ではなく、OpenACC
data region の寿命全体と内部 GPU kernel を含みます。次回実行でここがまだ
大きい場合は、次の段階で `enter data` / `exit data` を使い、転送時間と kernel
時間を分離します。

Recommended archive label:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP8_01
```

## Step 9: exnlp_gemm Transfer Split / exnlp_gemm 転送分解

The Step 8 result showed that `exnlp_gemm_data` is much larger than
`exnlp_gemm_dot + exnlp_gemm_update`, so the remaining cost is likely dominated
by OpenACC data-region overhead, data transfer, or untimed setup kernels.

Step 8 の結果では、`exnlp_gemm_data` が `exnlp_gemm_dot + exnlp_gemm_update`
よりかなり大きく、残りのコストは OpenACC data region の overhead、データ転送、
または未分解の初期化 kernel が支配的と考えられます。

Step 9 replaces the implicit structured data region in `exnlp_gemm` with
explicit `enter data` / `exit data` directives so that the cost can be split
without changing the computation.

Step 9 では `exnlp_gemm` の structured data region を明示的な `enter data` /
`exit data` に置き換え、計算内容を変えずにコストを分解します。

| id | label | measured work |
| ---: | --- | --- |
| 30 | `exnlp_gemm_enter` | device allocation and copy-in before the `ia` loop |
| 31 | `exnlp_gemm_zero` | `ct1` initialization kernel inside the `ia` loop |
| 32 | `exnlp_gemm_exit` | copy-out of `coef` and device deallocation after the `ia` loop |

Recommended archive label:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP9_01
```

## Step 10: Keep P Resident Across S2 / S2 内での P 常駐化

The Step 9-style run showed that `exnlp_gemm_enter` and `exnlp_gemm_exit`
remain large. This means that copying `P` into and out of each `exnlp_gemm`
call is a major part of the remaining cost.

Step 9 相当の結果では、`exnlp_gemm_enter` と `exnlp_gemm_exit` がまだ大きく、
`exnlp_gemm` 呼び出しごとの `P` 転送が残コストの大きな部分であることが
分かりました。

Step 10 keeps `P` resident across the whole `S2_` routine:

Step 10 では `P` を `S2_` 全体で device resident にします。

- `P(1:NG2Q,1:nbndloc)` is copied to the device once before the first
  nonlocal operation.
- Both `exnlp_gemm` calls use `P` through `present`.
- The local FFT/potential section also uses the same device-resident `P`.
- `P` is copied back once at the end of `S2_`.

- 最初の非局所項処理前に `P(1:NG2Q,1:nbndloc)` を一度だけ device に転送します。
- 2回の `exnlp_gemm` は `present` な `P` を使います。
- local FFT/potential 部分も同じ device resident な `P` を使います。
- `S2_` の最後で `P` を一度だけ host に戻します。

Additional timers:

追加タイマー:

| id | label | measured work |
| ---: | --- | --- |
| 33 | `s2_p_enter` | one-time `P` copy-in at the beginning of `S2_` |
| 34 | `s2_p_exit` | one-time `P` copy-out at the end of `S2_` |

Recommended archive label:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP10_01
```

Observed Step 10-equivalent result:

Step 10 相当の確認結果:

```text
archive label: nvhpc_cufft_1rank_02_STEP9_01
check: PASS
compare: PASS
wall_sec: 232.159
time_step_total: about 232.46 sec
s2_p_enter: about 14.05 sec
s2_p_exit: about 11.18 sec
```

This confirms that keeping `P` resident within each `S2_` call is correct and
substantially faster than the previous finer-grained `exnlp_gemm` transfer
split. The remaining `s2_p_enter + s2_p_exit` cost is still about 25 sec, so the
next step is to move the `P` residency boundary from `S2_` to `TMEVL`.

この結果から、`S2_` 呼び出し単位で `P` を常駐させる方針は正しく、以前の
`exnlp_gemm` 単位の転送分解より大きく高速化することが確認できました。一方で
`s2_p_enter + s2_p_exit` がまだ約25秒残っているため、次は `P` の常駐境界を
`S2_` 単位から `TMEVL` 単位へ広げます。

## Step 11: Keep P Resident Across TMEVL / TMEVL 内での P 常駐化

Step 11 moves ownership of `P(1:NG2Q,1:nbndloc)` from `S2_` to the surrounding
`TMEVL` fourth-order propagation path (`ioption.eq.4`).

Step 11 では、`P(1:NG2Q,1:nbndloc)` の GPU 常駐管理を `S2_` から外側の
`TMEVL` 4次分解経路 (`ioption.eq.4`) に移します。

Implemented changes:

実装内容:

- `TMEVL` copies `P` to the device once before the first `exkin_` call.
- `TMEVL` copies `P` back to the host once after the final `exkin_` call.
- `S2_` no longer performs its own `P` enter/exit.
- `exkin_` now updates resident `P` with an OpenACC `parallel loop`.

- `TMEVL` が最初の `exkin_` 呼び出し前に `P` を一度だけ device へ転送します。
- `TMEVL` が最後の `exkin_` 呼び出し後に `P` を一度だけ host へ戻します。
- `S2_` 内部では `P` の enter/exit を行いません。
- `exkin_` は resident な `P` を OpenACC `parallel loop` で更新します。

Additional timers:

追加タイマー:

| id | label | measured work |
| ---: | --- | --- |
| 35 | `tmevl_p_enter` | one-time `P` copy-in before the `ioption.eq.4` propagation sequence |
| 36 | `tmevl_p_exit` | one-time `P` copy-out after the `ioption.eq.4` propagation sequence |
| 37 | `exkin_acc_kernel` | OpenACC kinetic-energy phase update in `exkin_` |

Expected validation:

想定する確認:

```text
LABEL=nvhpc_cufft_1rank_02_STEP10_01 ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
python3 ./tools/check_tddft_result.py check ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP10_01/tddft.err
python3 ./tools/check_tddft_result.py compare ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP10_01/tddft.err
```

The main expected performance signal is that `s2_p_enter` and `s2_p_exit`
should disappear from the active timer list, replaced by one `tmevl_p_enter`
and one `tmevl_p_exit` per time step. `exkin_acc_kernel` should also appear and
should be checked against the existing `tmevl_exkin` aggregate.

主な性能確認ポイントは、`s2_p_enter` と `s2_p_exit` が active timer から消え、
time step ごとに `tmevl_p_enter` と `tmevl_p_exit` が1回ずつ出ることです。
また `exkin_acc_kernel` が出力されるため、既存の `tmevl_exkin` 集計との関係を
確認します。

Observed Step 11 result:

Step 11 実測結果:

```text
archive label: nvhpc_cufft_1rank_02_STEP10_01
check: PASS
compare: PASS
wall_sec: 179.769
time_step_total: about 180.06 sec
tmevl_total: about 108.94 sec
tmevl_s2: about 66.22 sec
s2_nonlocal: about 43.74 sec
s2_fft_local: about 22.46 sec
fft_wrapper: about 28.77 sec
tmevl_p_enter: about 2.99 sec
tmevl_p_exit: about 2.73 sec
exkin_acc_kernel: about 1.08 sec
```

Compared with the Step 10-equivalent run, the `P` transfer cost dropped from
about `s2_p_enter + s2_p_exit = 25.2 sec` to about
`tmevl_p_enter + tmevl_p_exit = 5.7 sec`. The 100-step wall time improved from
about 232 sec to about 180 sec.

Step 10 相当の実行と比べると、`P` 転送コストは
`s2_p_enter + s2_p_exit = 約25.2秒` から
`tmevl_p_enter + tmevl_p_exit = 約5.7秒` へ減少しました。100 step の wall time
は約232秒から約180秒へ改善しました。

The remaining dominant regions are now:

現時点で残っている主なコスト:

- `s2_nonlocal_gemm`: about 40.8 sec
- `s2_fft_local`: about 22.5 sec
- `exnlp_gemm_dot + exnlp_gemm_update`: about 25.8 sec
- `exnlp_gemm_enter + exnlp_gemm_zero`: about 13.9 sec

This suggests that the next useful experiment should target `exnlp_gemm`
itself, especially reducing per-call data setup and improving the dot/update
kernel structure, rather than further extending `P` copy boundaries first.

この結果から、次の有効な実験対象は `P` の転送境界拡大ではなく、`exnlp_gemm`
本体、特に呼び出しごとの data setup 削減と dot/update kernel 構造の改善と考えます。

## Step 12: Remove Redundant exnlp_gemm Zero Kernel / exnlp_gemm の冗長ゼロ初期化削除

Step 12 removes the `ct1` zero-initialization OpenACC kernel from the
`exnlp_gemm` inner `ia` loop.

Step 12 では、`exnlp_gemm` の内側 `ia` ループにあった `ct1` のゼロ初期化
OpenACC kernel を削除します。

Rationale:

理由:

- The following `exnlp_gemm_dot` kernel writes `ct1(iib)` for every
  `iib = 1, nbndloc` before `ct1` is used by the update kernel.
- Therefore the previous `ct1(iib) = (0.d0,0.d0)` kernel was redundant.
- In the Step 11 measurement, `exnlp_gemm_zero` cost about 5.8 sec, so removing
  it should reduce kernel launch work and eliminate that timer region.

- 後続の `exnlp_gemm_dot` kernel は、update kernel が `ct1` を参照する前に
  `iib = 1, nbndloc` の全要素へ `ct1(iib)` を書き込みます。
- そのため、従来の `ct1(iib) = (0.d0,0.d0)` kernel は冗長でした。
- Step 11 の測定では `exnlp_gemm_zero` が約5.8秒だったため、削除により
  kernel launch とそのタイマー領域が減ることを期待します。

Expected validation:

想定する確認:

```text
LABEL=nvhpc_cufft_1rank_02_STEP11_01 ./tools/archive_tddft_result.sh ./run/Si111-H_nvhpc/
python3 ./tools/check_tddft_result.py check ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP11_01/tddft.err
python3 ./tools/check_tddft_result.py compare ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP11_01/tddft.err
```

The expected performance signal is that `exnlp_gemm_zero` should disappear
from the timer output, while `check` and relaxed `compare` should remain `PASS`.
If this passes, the next larger experiment is to restructure `exnlp_gemm` so
that the dot and update work can avoid unnecessary temporary setup or launch
overhead.

期待する性能上のシグナルは、`exnlp_gemm_zero` がタイマー出力から消え、
`check` と relaxed `compare` が引き続き `PASS` することです。これが通れば、
次の大きめの実験として `exnlp_gemm` の dot/update 構造を見直し、不要な一時
データ準備や kernel launch overhead を減らします。

Observed result with the Step 12 code, archived as `STEP11_01`:

Step 12 コードの実測結果です。archive label は `STEP11_01` です。

```text
archive label: nvhpc_cufft_1rank_02_STEP11_01
check: PASS
compare: PASS
wall_sec: 172.646986008
time_step_total: about 172.94 sec
tmevl_total: about 101.42 sec
tmevl_s2: about 58.80 sec
s2_nonlocal: about 37.05 sec
s2_fft_local: about 21.74 sec
fft_wrapper: about 28.05 sec
s2_nonlocal_make: about 2.90 sec
s2_nonlocal_gemm: about 34.13 sec
exnlp_gemm_data: about 34.11 sec
exnlp_gemm_dot: about 13.37 sec
exnlp_gemm_update: about 11.88 sec
exnlp_gemm_enter: about 8.16 sec
exnlp_gemm_exit: about 0.03 sec
tmevl_p_enter: about 3.00 sec
tmevl_p_exit: about 2.71 sec
exkin_acc_kernel: about 1.07 sec
```

The expected signal was confirmed: `exnlp_gemm_zero` no longer appears in the
timer output, while both `check` and relaxed `compare` still pass. The measured
wall time improved from about 179.77 sec to about 172.65 sec.

期待通り、`exnlp_gemm_zero` はタイマー出力から消え、`check` と relaxed
`compare` はどちらも `PASS` のままです。wall time は約179.77秒から約172.65秒へ
改善しました。

## Current Goal / 現在のゴール

The project goal for this branch is now:

このブランチのゴールは、以下に置きます。

```text
Move the whole TDDFT time-step body to GPU execution where practical, and
minimize host-device memory transfers across the time-step loop.
```

```text
TDDFT のタイムステップ内部を、実用上可能な範囲で GPU 実行へ移し、
タイムステップループ中の Host-Device 間メモリ転送を最小化する。
```

This means the optimization boundary is no longer only `s2_fft_local`.
`s2_fft_local` was the first target because it exposed the largest avoidable
FFT transfer cost, but the remaining work should expand toward all major
regions inside the propagation step.

つまり、最適化境界は `s2_fft_local` だけではありません。`s2_fft_local` は
回避可能な FFT 転送コストが大きかったため最初の対象にしましたが、今後は
伝播ステップ内部の主要領域全体へ対象を広げます。

## Current Status / 現在の状態

Accomplished:

達成済み:

- The validated path is still one GPU with one MPI rank.
- cuFFT is used as the FFT library backend.
- OpenACC manages device-resident arrays and element-wise kernels.
- `P` is resident across the `TMEVL` propagation block instead of being copied
  in/out for every `S2_` call.
- The S2 local FFT path uses device-pointer cuFFT entry points.
- Scatter, gather, local-potential multiply, kinetic phase update, and parts of
  the nonlocal GEMM path are OpenACC kernels.
- The Step 12 code passes `check` and relaxed `compare` against the committed
  GNU reference.

- 検証済み経路は引き続き 1 GPU / 1 MPI rank です。
- FFT library backend として cuFFT を使用しています。
- device resident 配列と要素演算 kernel は OpenACC で管理しています。
- `P` は `S2_` 呼び出しごとではなく、`TMEVL` 伝播 block 全体で常駐します。
- S2 local FFT 経路は device pointer 版 cuFFT entry を使用しています。
- scatter、gather、local-potential multiply、kinetic phase update、非局所
  GEMM 経路の一部は OpenACC kernel 化済みです。
- Step 12 コードはコミット済み GNU 基準に対して `check` と relaxed `compare` が
  `PASS` です。

Remaining issues:

残課題:

1. `exnlp_gemm_enter` is still about 8 sec.

   `work1`, `cfac`, and `ngnl` are still copied or created per `exnlp_gemm`
   call. The next target is to reduce this setup cost or extend the residency
   of these nonlocal inputs safely.

   `work1`, `cfac`, `ngnl` はまだ `exnlp_gemm` 呼び出し単位で転送または作成
   されています。次は、この setup cost の削減、またはこれら非局所入力の
   常駐期間拡大が対象です。

2. `exnlp_gemm_dot + exnlp_gemm_update` remains about 25 sec.

   The dot/update structure is correct but still expensive. Any change here
   must preserve the sequential `ia` update dependency.

   dot/update 構造は正しく動作していますが、まだ約25秒残っています。ここを
   変更する場合は、`ia` 更新順序の依存関係を壊さない必要があります。

3. `fft_wrapper` still reports about 28 sec.

   Major S2 local FFT calls are device-resident, but compatibility host-copy
   FFT calls remain elsewhere. These should be moved only after confirming
   their data ownership boundaries.

   主要な S2 local FFT 呼び出しは device resident ですが、他の互換 host-copy
   FFT 呼び出しが残っています。これらは data ownership 境界を確認してから
   移行します。

4. `tmevl_p_enter + tmevl_p_exit` remains about 5.7 sec.

   This is much smaller than the previous S2-level copies, but full time-step
   GPU residency will require reducing or eliminating these remaining
   time-step boundary transfers.

   これは以前の S2 単位転送より大幅に小さいですが、タイムステップ全体の GPU
   常駐化には、この残りの time-step 境界転送も削減または除去する必要があります。

5. CPU-side routines still exist inside the time-step body.

   The current GPU work has focused on the measured hot regions. A later pass
   should audit the full time-step body and classify each CPU-side section as:
   keep on CPU, move to OpenACC, or isolate behind a transfer boundary.

   現在の GPU 化は測定上のホット領域に集中しています。次段階では
   time-step 内部全体を棚卸しし、各 CPU 側処理を「CPUに残す」「OpenACC化する」
   「転送境界として分離する」に分類します。

Recommended next step:

推奨される次ステップ:

1. Split `exnlp_gemm_enter` into copy/setup components, or move one candidate
   nonlocal input buffer to a longer-lived OpenACC data region.
2. Keep using `check_tddft_result.py check` and relaxed `compare` after every
   step.
3. Archive each successful run with a monotonic label such as
   `nvhpc_cufft_1rank_02_STEP12_01`.

1. `exnlp_gemm_enter` をさらに転送・setup 要素へ分解する、または非局所入力
   buffer の一つをより長い OpenACC data region に移します。
2. 各ステップ後は `check_tddft_result.py check` と relaxed `compare` を継続します。
3. 成功した実行は `nvhpc_cufft_1rank_02_STEP12_01` のような単調増加 label で
   archive します。

## Step 13: Split exnlp_gemm Enter Cost / exnlp_gemm enter 内訳分解

Step 13 is a measurement-only change. It keeps the aggregate
`exnlp_gemm_enter` timer, but splits the OpenACC `enter data` work inside it:

Step 13 は計測のみの変更です。集計用の `exnlp_gemm_enter` は維持し、その内側の
OpenACC `enter data` を以下に分解します。

| id | label | measured work |
| ---: | --- | --- |
| 38 | `exnlp_work1_enter` | copy-in of `work1(1:NGcont,1:loopcnt)` |
| 39 | `exnlp_meta_enter` | copy-in of `cfac(1:loopcnt)` and `ngnl(1:loopcnt)` |
| 40 | `exnlp_ct1_create` | device allocation of `ct1(1:nbndloc)` |

This should not change numerical results. The purpose is to decide whether the
next real optimization should target the large `work1` transfer, metadata
transfer, or temporary allocation.

数値結果は変わらない想定です。目的は、次の実最適化対象を大きな `work1` 転送、
metadata 転送、一時配列 allocation のどれに置くべきか判断することです。

Recommended archive label:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP12_01
```

## Step 14: Probe exnlp Cache Invariance / exnlp キャッシュ可能性の確認

Step 14 is also a measurement-only change. The Step 13 result showed that
`exnlp_work1_enter` dominates `exnlp_gemm_enter`, so the next optimization
candidate is to avoid rebuilding or recopying the nonlocal projector input
buffer passed as `work1` to `exnlp_gemm`.

Step 14 も計測のみの変更です。Step 13 の結果から `exnlp_gemm_enter` の大半は
`exnlp_work1_enter` であることが分かったため、次の最適化候補は
`exnlp_gemm` に渡す非局所 projector 入力 buffer (`work1`) の再生成または再転送を
避けることです。

Before doing that, the code now probes whether the generated inputs are stable
for each atom-type index and phase:

実際にキャッシュ化する前に、各 atom-type index と phase ごとに生成される入力が
安定しているかを確認します。

- `phase=1`: the first nonlocal block in `S2_`
- `phase=2`: the second nonlocal block in `S2_`
- probed data: `work2_`, `cfac_`, and `ngnl_`

The probe records a lightweight numeric signature the first time each
`NP/phase` pair is seen and prints:

各 `NP/phase` の初回出現時に軽量な数値 signature を記録し、次を出力します。

```text
FPSEID_EXNLP_CACHE_REF np phase sig= ...
```

If the signature later changes beyond the diagnostic tolerance, it prints:

後続の呼び出しで signature が許容範囲を超えて変化した場合は、次を出力します。

```text
FPSEID_EXNLP_CACHE_DIFF np phase ref sig= ...
```

This is not an exhaustive bitwise comparison. It is a low-cost guard for the
current validation run. If no `FPSEID_EXNLP_CACHE_DIFF` lines appear in the
100-step run, the next coding step is to cache `work2_` per `NP/phase` and make
`exnlp_gemm` consume the cached, device-resident buffer.

これは完全な bitwise 比較ではなく、現在の検証実行向けの低コストなガードです。
100 step 実行で `FPSEID_EXNLP_CACHE_DIFF` が出なければ、次の実装では `work2_` を
`NP/phase` ごとにキャッシュし、`exnlp_gemm` が device resident なキャッシュを
使う形に進めます。

Recommended archive label:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP13_01
```

Suggested check:

確認コマンド:

```sh
grep FPSEID_EXNLP_CACHE run/tddft_archives/nvhpc_cufft_1rank_02_STEP13_01/tddft.out
```

Expected result for the cache experiment:

キャッシュ化へ進むための期待結果:

- `FPSEID_EXNLP_CACHE_REF` appears for the observed `NP/phase` pairs.
- `FPSEID_EXNLP_CACHE_DIFF` does not appear.

- 観測された `NP/phase` に対して `FPSEID_EXNLP_CACHE_REF` が出る。
- `FPSEID_EXNLP_CACHE_DIFF` は出ない。

## Step 15: Component Probe for exnlp Cache / exnlpキャッシュ成分別プローブ

The Step 14 run showed `FPSEID_EXNLP_CACHE_DIFF` for all observed `NP/phase`
pairs. This means the combined `work2_ + cfac_ + ngnl_` signature changes during
the TDDFT time evolution, so a simple cache keyed only by `NP/phase` is not safe.

Step 14 実行では、観測された全 `NP/phase` で `FPSEID_EXNLP_CACHE_DIFF` が出ました。
したがって `work2_ + cfac_ + ngnl_` の合成 signature は TDDFT 時間発展中に変化して
おり、`NP/phase` だけを key にした単純キャッシュは安全ではありません。

Step 15 refines the probe by splitting the signature into three components:

Step 15 では、signature を次の3成分に分けて再確認します。

- `ng`: integer `ngnl_` projector lengths
- `cf`: complex `cfac_` coefficients
- `wk`: sampled `work2_` projector values

The reference line now prints all three component signatures:

初回 reference 行は3成分をまとめて出力します。

```text
FPSEID_EXNLP_CACHE_REF np phase ng cf wk= ...
```

If a component changes later, the diff line identifies the component:

後続で変化した場合、diff 行に変化成分が出ます。

```text
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... ngnl ...
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... cfac ...
FPSEID_EXNLP_CACHE_DIFF np phase comp= ... work ...
```

Interpretation:

解釈:

- If only `work` changes, keep `ngnl_` and `cfac_` resident/cached and move
  projector value generation closer to GPU.
- If `cfac` also changes, keep only `ngnl_` resident and generate/copy
  coefficient data per step.
- If `ngnl` changes, do not cache the projector metadata for this path.

- `work` だけが変化する場合、`ngnl_` と `cfac_` は常駐/キャッシュ候補にし、
  projector 値生成を GPU 側へ寄せます。
- `cfac` も変化する場合、`ngnl_` だけを常駐候補にし、係数データは step ごとに
  生成または転送します。
- `ngnl` も変化する場合、この経路では projector metadata のキャッシュは避けます。

Recommended archive label:

推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP14_01
```

Observed Step 15 result:

Step 15 実測結果:

The component probe showed differences in all checked nonlocal input
components:

成分別プローブでは、確認対象の非局所入力成分すべてで差分が出ました。

- `ngnl`
- `cfac`
- `work`

Therefore a cache keyed by only `NP/phase` is rejected. Caching only metadata is
also not safe for this validation path because `ngnl` changes. The probe was
removed from the active code after recording this result so that later timing
runs are not polluted by diagnostic output or extra host-side work.

したがって、`NP/phase` だけを key にしたキャッシュは不採用です。`ngnl` も変化する
ため、metadata だけのキャッシュもこの検証経路では安全ではありません。この結果を
記録した後、以降の計測に診断出力や余分な host 側処理を混ぜないため、プローブは
active code から削除しました。

## Step 16: Nonlocal Input Residency Direction / 非局所入力常駐化の方針

Step 16 resets the nonlocal optimization direction after the cache experiment.
The next target is not reuse of old projector input data. Instead, the target
is to move projector input generation closer to its GPU consumer:

Step 16 では、キャッシュ実験後の非局所項最適化方針を整理します。次の対象は、
古い projector 入力データの再利用ではありません。次の対象は、projector 入力の
生成を GPU 側の利用箇所へ近づけることです。

```text
exnlp_only_make -> exnlp_gemm
```

The current cost model is:

現時点のコスト構造:

- `exnlp_only_make` builds `work2_`, `cfac_`, and `ngnl_` on the host.
- `exnlp_gemm` copies those inputs to the device, then updates resident `P`.
- `exnlp_work1_enter` remains a measurable transfer/setup cost.

- `exnlp_only_make` は `work2_`, `cfac_`, `ngnl_` を host 側で生成します。
- `exnlp_gemm` はそれらを device へ転送し、resident な `P` を更新します。
- `exnlp_work1_enter` はまだ有意な転送/setup コストとして残っています。

The preferred next implementation path is:

推奨する次の実装方針:

1. Keep the existing host-generated path as the correctness fallback.
2. Add an experimental OpenACC path that generates the nonlocal projector input
   and consumes it without a host round trip.
3. Validate each step with `check_tddft_result.py check` and relaxed `compare`.
4. Keep the `ia` update order in `exnlp_gemm` unchanged unless a separate
   correctness experiment proves the reorder acceptable.

1. 既存の host 生成経路は correctness fallback として残します。
2. 非局所 projector 入力を GPU 側で生成し、host 往復なしで利用する実験的 OpenACC
   経路を追加します。
3. 各ステップで `check_tddft_result.py check` と relaxed `compare` を実施します。
4. `exnlp_gemm` の `ia` 更新順序は、別途 correctness 実験で許容されると確認する
   までは変更しません。

Recommended archive label for the next successful run:

次の成功実行の推奨 archive label:

```text
nvhpc_cufft_1rank_02_STEP16_01
```

Implemented Step 16 change:

Step 16 実装内容:

- Split `exnlp_gemm` into a transfer-owning wrapper and a shared GPU kernel
  body.
- Added `exnlp_gemm_present_inputs`, which assumes `work1`, `cfac`, `ngnl`,
  and `coef` are already present on the device and only creates/deletes the
  temporary `ct1` buffer.
- The current call sites still use the original `exnlp_gemm` wrapper, so this
  step is intended to preserve numerical behavior while preparing the next
  step where `work2_`, `cfac_`, and `ngnl_` can be generated and consumed on
  the device.

- `exnlp_gemm` を、転送を持つ wrapper と共通 GPU kernel 本体に分割しました。
- `work1`, `cfac`, `ngnl`, `coef` が device 上に存在する前提で、temporary な
  `ct1` だけを作成/削除する `exnlp_gemm_present_inputs` を追加しました。
- 現在の呼び出し箇所はまだ従来の `exnlp_gemm` wrapper を使うため、この step は
  数値挙動を維持しながら、次 step で `work2_`, `cfac_`, `ngnl_` を device 上で
  生成してそのまま消費するための準備です。

Expected validation:

期待する検証:

```text
python3 ./tools/check_tddft_result.py check \
  ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP16_01/tddft.err

python3 ./tools/check_tddft_result.py compare \
  ./run/tddft_archives/nvhpc_cufft_1rank_02_STEP16_01/tddft.err
```

## Step 17: Use Present-Input exnlp GEMM Call Path / present入力版exnlp GEMM経路の使用

Step 17 connects the new `exnlp_gemm_present_inputs` routine to the two
nonlocal call sites in `S2_`.

Step 17 では、Step 16 で追加した `exnlp_gemm_present_inputs` を `S2_` 内の
2つの非局所項呼び出し箇所から実際に使うようにしました。

Implemented change:

実装内容:

- `work2_`, `cfac_`, and `ngnl_` are explicitly copied to the device at the
  `S2_` call site before `exnlp_gemm_present_inputs`.
- `exnlp_gemm_present_inputs` consumes those already-present inputs and updates
  the resident `P`.
- The call site explicitly deletes `work2_`, `cfac_`, and `ngnl_` after the
  GEMM path returns.
- The original transfer-owning `exnlp_gemm` wrapper is kept as the fallback
  implementation.

- `exnlp_gemm_present_inputs` 呼び出し前に、`S2_` 側で `work2_`, `cfac_`,
  `ngnl_` を明示的に device へ転送します。
- `exnlp_gemm_present_inputs` は、すでに present な入力を使って resident な
  `P` を更新します。
- GEMM 経路の終了後、呼び出し側で `work2_`, `cfac_`, `ngnl_` を明示的に
  delete します。
- 転送を内部に持つ従来の `exnlp_gemm` wrapper は fallback として残しています。

This step does not yet remove the host generation of `work2_`, `cfac_`, and
`ngnl_`. It makes the data ownership boundary explicit so that the next step can
move selected input generation onto the GPU and feed the present-input GEMM
path without a host round trip.

この step では、`work2_`, `cfac_`, `ngnl_` の host 生成はまだ残っています。
目的は data ownership 境界を明示し、次 step で入力生成を GPU 側へ移して
host 往復なしで present-input GEMM 経路へ渡せるようにすることです。

Timer interpretation:

タイマーの見方:

- `exnlp_work1_enter` and `exnlp_meta_enter` now measure the caller-side
  explicit input copy-in.
- `exnlp_ct1_create` and `exnlp_gemm_dot/update` remain inside
  `exnlp_gemm_present_inputs`.
- `exnlp_gemm_exit` now also includes caller-side deletion of the explicit
  nonlocal input buffers.

- `exnlp_work1_enter` と `exnlp_meta_enter` は、呼び出し側で行う明示的な
  input copy-in を測ります。
- `exnlp_ct1_create` と `exnlp_gemm_dot/update` は
  `exnlp_gemm_present_inputs` 内に残ります。
- `exnlp_gemm_exit` には、呼び出し側の非局所入力 buffer delete も含まれます。

Expected validation label:

想定する検証 label:

```text
nvhpc_cufft_1rank_02_STEP17_01
```

Observed Step 17 result:

Step 17 実測結果:

```text
archive label: nvhpc_cufft_1rank_02_STEP17_01
check: PASS
compare: PASS
wall_sec: 170.24688876
time_step_total: about 170.53 sec
tmevl_total: about 100.45 sec
tmevl_s2: about 58.46 sec
s2_nonlocal: about 36.39 sec
s2_fft_local: about 22.06 sec
fft_wrapper: about 28.39 sec
s2_nonlocal_make: about 2.68 sec
s2_nonlocal_gemm: about 33.69 sec
exnlp_gemm_data: about 25.39 sec
exnlp_gemm_dot: about 13.35 sec
exnlp_gemm_update: about 11.25 sec
exnlp_work1_enter: about 8.08 sec
exnlp_meta_enter: about 0.16 sec
exnlp_ct1_create: about 0.02 sec
tmevl_p_enter: about 2.97 sec
tmevl_p_exit: about 2.72 sec
```

The correctness result is unchanged from Step 16. The wall time is also nearly
unchanged, which is expected because Step 17 only moves the explicit ownership
of `work2_`, `cfac_`, and `ngnl_` to the caller. The data is still generated on
the host and copied to the device. The important outcome is that the
present-input path is now validated at the real call sites, so the next step can
start moving `exnlp_only_make` output generation toward the GPU without changing
the GEMM consumer again.

正しさは Step 16 から変わらず `PASS` です。wall time もほぼ同等で、これは想定通り
です。Step 17 は `work2_`, `cfac_`, `ngnl_` の所有境界を呼び出し側へ移しただけで、
データ生成自体はまだ host 側にあり、device へのコピーも残っています。重要なのは、
present-input 経路が実際の呼び出し箇所で検証できたことです。次 step では GEMM
consumer を再変更せず、`exnlp_only_make` 出力生成を GPU 側へ近づけられます。

## Step 18: Fuse Present-Input exnlp GEMM Dot/Update / present-input exnlp GEMM の dot/update 融合

Step 18 changes only the already validated `exnlp_gemm_present_inputs` path.
The older transfer-owning `exnlp_gemm` wrapper is kept as the fallback path.

Step 18 では、検証済みの `exnlp_gemm_present_inputs` 経路だけを変更します。
転送を内部に持つ従来の `exnlp_gemm` wrapper は fallback として残しています。

Implementation change:

実装変更:

- Added `exnlp_gemm_body_fused`.
- `exnlp_gemm_present_inputs` now calls the fused body directly.
- The fused body computes the dot product and immediately applies the
  coefficient update inside the same OpenACC `parallel loop` over local bands.
- The temporary `ct1` device allocation is no longer used by the
  present-input path.
- The original `exnlp_gemm_body` remains in place for the fallback
  `exnlp_gemm` wrapper.

- `exnlp_gemm_body_fused` を追加しました。
- `exnlp_gemm_present_inputs` は fused body を直接呼びます。
- fused body は local band ごとの OpenACC `parallel loop` 内で dot product を
  計算し、そのまま係数更新を行います。
- present-input 経路では、一時配列 `ct1` の device allocation を使わなくなります。
- fallback の `exnlp_gemm` wrapper 用に、従来の `exnlp_gemm_body` は残しています。

Expected performance signal:

期待する性能シグナル:

- `exnlp_ct1_create` should disappear from the present-input path.
- `exnlp_gemm_update` should disappear from the present-input path because the
  update is included in `exnlp_gemm_dot`.
- `exnlp_gemm_dot` should increase relative to Step 17, but the combined
  `exnlp_gemm_dot + exnlp_gemm_update + exnlp_ct1_create` cost should decrease
  if the fused kernel is effective.
- Correctness should continue to pass with the relaxed TDDFT comparator.

- present-input 経路では `exnlp_ct1_create` が消える見込みです。
- update は `exnlp_gemm_dot` に含めるため、present-input 経路では
  `exnlp_gemm_update` も消える見込みです。
- `exnlp_gemm_dot` 単体は Step 17 より増える可能性がありますが、
  `exnlp_gemm_dot + exnlp_gemm_update + exnlp_ct1_create` の合計が下がるなら
  fused kernel は有効です。
- 正しさは relaxed TDDFT comparator で引き続き `PASS` する必要があります。

Expected validation label:

想定する検証 label:

```text
nvhpc_cufft_1rank_02_STEP18_01
```
