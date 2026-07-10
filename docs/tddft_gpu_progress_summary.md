# TDDFT GPU Progress Summary / TDDFT GPU化進捗まとめ

Date: 2026-07-09

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
