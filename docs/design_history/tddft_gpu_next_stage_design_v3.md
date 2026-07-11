# FPSEID21 TDDFT GPU化 次段階設計書 v3

対象 branch: `tddft-openacc-residency`

対象 source: `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`

対象方針: 1 GPU / 1 MPI rank, OpenACC + cuFFT

この v3 は source 静的解析と設計具体化のみを目的とする。コード変更、build、run、計測は行っていない。

## 記述ラベル

- CONFIRMED: 現在の source から確認済み。
- DECISION: 現時点の設計判断。
- HYPOTHESIS: source から妥当と考えるが、実行時検証が必要。
- UNVERIFIED: 実行ログ、compiler report、Nsight 等がないと確定できない。
- BLOCKER: 実装開始前、または次 step 前に解決が必要。

## 変更履歴

- v1: 次段階 GPU 化の初期設計。
- v2: 独立レビュー指摘を反映し、Step A/B/C/D、shape、ownership、validation を詳細化。
- v3: 実装環境がない前提で source 静的解析を再整理。P / coef shape を BLOCKER として明確化し、ownership state machine、routine contract、interface 比較、failure matrix、commit 単位計画を追加。

## Baseline と不採用実験

### CONFIRMED

- 正式 baseline は Step 18。
- Step 18: `wall_sec` 約 163.31 秒、`check` PASS、`relaxed compare` PASS。
- Step 19: 約 178 秒。
- Step 20: 約 819 秒。
- Step 20 では `s2_nonlocal_make` が約 680 秒まで増加。

### DECISION

- routine 内部、または細粒度 section 単位で反復 `copyin` する方式は不採用。
- 以後の目標は TDDFT time-step loop 内を可能な限り GPU resident にし、Host-Device 間の大規模転送を最小化すること。
- Step 18 より遅い変更は、原因が明確で次 step で回復できる場合を除き原則 rollback 候補とする。

## Source Map

| 項目 | source location | 内容 |
|---|---:|---|
| `TMEVL` entry | `tmevl10_Avec_v4.f:15` | TDDFT main propagation routine |
| `P` actual declaration | `tmevl10_Avec_v4.f:54` | `COMPLEX*16 P(NG2Q,MXBND)` |
| `YLM` declaration | `tmevl10_Avec_v4.f:61` | `REAL*8 YLM(NGcont,16)` |
| `EXTAU` declaration | `tmevl10_Avec_v4.f:79` | `COMPLEX*16 EXTAU(NGcont,5,NTAUQ)` |
| `VPJ` declaration | `tmevl10_Avec_v4.f:106` | `DIMENSION VPJ(NGcont,3,4,NTYQ)` |
| `GETYLM` call | `tmevl10_Avec_v4.f:190` | `YLM` producer |
| local band range | `tmevl10_Avec_v4.f:530` | `nbndloc=nend(my_rank)-nbegin(my_rank)+1` |
| `P` enter data | `tmevl10_Avec_v4.f:532` | `copyin(P(1:NG2Q,1:nbndloc))` |
| `S2_` calls | `tmevl10_Avec_v4.f:537,549,587,614,641,668` | `S2_` repeated in `TMEVL` |
| `P` exit data | `tmevl10_Avec_v4.f:714` | `copyout(P(1:NG2Q,1:nbndloc))` |
| `S2_` entry | `tmevl10_Avec_v4.f:1693` | S2 operator routine |
| `S2_` dummy `P` | `tmevl10_Avec_v4.f:1707` | `COMPLEX*16 P(NG2Q,mxbnd)` |
| `S2_` dummy `YLM` | `tmevl10_Avec_v4.f:1713` | `REAL*8 YLM(NGcont,16)` |
| `S2_` dummy `EXTAU` | `tmevl10_Avec_v4.f:1719` | `EXTAU(NGcont,5,NTAUQ)` |
| `S2_` dummy `VPJ` | `tmevl10_Avec_v4.f:1736` | `VPJ(NGcont,3,4,NTYQ)` |
| `work2_` allocation | `tmevl10_Avec_v4.f:1745,1810-1813` | `allocatable, save` |
| `cfac_` allocation | `tmevl10_Avec_v4.f:1746,1810-1813` | `allocatable, save` |
| `ngnl_` allocation | `tmevl10_Avec_v4.f:1747,1810-1813` | `allocatable, save` |
| current unsafe `P` present | `tmevl10_Avec_v4.f:1942` | `present(P(1:NXYZ,1:nbndloc))` |
| `exnlp_only_make_acc` entry | `tmevl10_Avec_v4.f:2459` | GPU producer candidate |
| `exnlp_only_make_acc` internal copyin | `tmevl10_Avec_v4.f:2481-2483` | current copyin of `ylm`, `extau`, `vpj` |
| `exnlp_gemm_present_inputs` entry | `tmevl10_Avec_v4.f:2521` | consumer for present inputs |
| `exnlp_gemm_body_fused` entry | `tmevl10_Avec_v4.f:2534` | fused GEMM body |
| fused `coef` present | `tmevl10_Avec_v4.f:2545,2589,2611` | `coef(1:ng2q,1:nbndloc)` |

Build source selection:

| file | line | 内容 |
|---|---:|---|
| `tools/build_nvhpc.sh` | 27 | default `TDDFT_FFLAGS="-O2 -mp -Msave -Mlarge_arrays"` |
| `tools/build_nvhpc.sh` | 29 | default `TDDFT_CUFFT_LIBS="-cudalib=cufft"` |
| `tools/build_nvhpc.sh` | 31 | `NVHPC_REPORT_FLAGS="-Minfo=accel -Minfo=mp"` |
| `tools/build_nvhpc.sh` | 191-196 | cuFFT build invokes `mk_ifort.sh` with `FFT_BACKEND=cufft` |
| `FPSEID21/tddft_2022October/mk_ifort.sh` | 29 | default `FFT_BACKEND=fftw` |
| `FPSEID21/tddft_2022October/mk_ifort.sh` | 136 | cuFFT source `FFT_SRC=fft_cufft.f` |
| `FPSEID21/tddft_2022October/mk_ifort.sh` | 184-185 | link includes `tmevl10_Avec_v4.f`, `bannerTDDFT.f`, FFT backend |

## 1. P / coef shape 問題

### CONFIRMED: 定義元と意味

| symbol | 定義/利用 source | source 上の意味 |
|---|---:|---|
| `NG2Q` | `TMEVL` argument at `tmevl10_Avec_v4.f:15`; `P(NG2Q,MXBND)` at line 54 | reciprocal-space wavefunction coefficient の第1次元。`J2G(NG2Q)`, `G2(4,NG2Q)` と同じ G-vector 側サイズ。 |
| `NXYZ` | `TMEVL` argument at `tmevl10_Avec_v4.f:15`; `RHO1_(NXYZ,mxbnd)` at line 1744 | real-space grid 側サイズ。FFT local real-space vector として使われる。 |
| `mxbnd` / `MXBND` | `P(NG2Q,MXBND)` at line 54; `S2_` argument and dummy at lines 1704,1707 | band dimension upper bound。global maximum band count として渡される。 |
| `nbndloc` | `tmevl10_Avec_v4.f:530`, `1941`, `2540-2542` | current rank local band count: `nend-nbegin+1`。1 GPU / 1 rank でも `mxbnd` と同一とは限らない。 |
| `NGcont` | `YLM(NGcont,16)` line 61; `VPJ(NGcont,...)` line 106; `work2_(NGcont,loopcnt)` lines 1745,1810-1813 | nonlocal / angular metadata side の contiguous count。`NG2Q` や `NXYZ` と同一とは限らない。 |

### CONFIRMED: P / coef / data clause 一覧

| item | source | declaration / clause | 判定 |
|---|---:|---|---|
| `P` actual in `TMEVL` | line 54 | `COMPLEX*16 P(NG2Q,MXBND)` | 正式な実体 shape は `NG2Q x MXBND`。 |
| `P` device lifetime in `TMEVL` | lines 532,714 | `copyin/copyout(P(1:NG2Q,1:nbndloc))` | `nbndloc` 列だけを device 登録する意図。 |
| `P` dummy in `S2_` | line 1707 | `COMPLEX*16 P(NG2Q,mxbnd)` | caller と shape 整合。 |
| `P` unsafe present in `S2_` | line 1942 | `present(P(1:NXYZ,1:nbndloc))` | BLOCKER。`P` 第1次元は source 上 `NG2Q`。`NXYZ` mapping は正しい mapping と扱わない。 |
| `P` scatter/gather use | lines 1962-1968, 2091-2100 | `P(IG,iib)` with `IG=J2G(JG)` | `IG` が `1:NG2Q` 内であることは実行時検証が必要。 |
| `coef` dummy in legacy `exnlp` | lines 2272,2355 | `coef(ng2q)` / `coef(ng2q,mxbnd)` | nonlocal update consumer。 |
| `coef` dummy in `exnlp_gemm` | line 2494 | `coef(ng2q,mxbnd)` | `P` と同型想定。 |
| `coef` dummy in present path | lines 2524,2537 | `coef(ng2q,mxbnd)` | `P` を `coef` として渡す consumer。 |
| `coef` present in fused body | lines 2545,2589,2611 | `present(coef(1:ng2q,1:nbndloc))` | `P(1:NG2Q,1:nbndloc)` と整合する可能性が高い。 |

### DECISION

- `P(1:NXYZ,1:nbndloc)` は正しい mapping とは扱わない。
- `P` の device 登録範囲の第一候補は `P(1:NG2Q,1:nbndloc)`。
- `S2_` 内で `RHO1_`, `RHO2_` との相互変換に `NXYZ` を使うことは妥当だが、`P` 自体の first dimension に `NXYZ` を使う data clause は unsafe。
- `coef` 系 routine に渡す `P` は `coef(1:ng2q,1:nbndloc)` として扱う。

### BLOCKER

- `NG2Q` と `NXYZ` の大小関係は source 静的解析だけでは確定しない。実行時ログで確認するまで、`P(1:NXYZ,...)` の data clause を新規設計に採用してはならない。
- `J2G(JG)` が常に `1:NG2Q` に収まることは、Step A で min/max 計測が必要。
- `P(1:NG2Q,1:nbndloc)` が既存 Step 18 の `enter data` と present-table 上で安定して一致することを Step A で確認する。

### Step A で確認する項目

- `NG2Q`, `NXYZ`, `mxbnd`, `nbndloc`, `NGcont`, `loopcnt` の実値。
- `J2G(1:NXYZ)` の min/max。
- `acc_is_present(P(1:NG2Q,1:nbndloc))` の真偽。
- `acc_is_present(P(1:NXYZ,1:nbndloc))` は診断対象にしてよいが、false/true にかかわらず設計上の正当化には使わない。
- `acc_deviceptr(P(1,1))` と `acc_deviceptr(coef(1,1))` が consumer 側で同一 device allocation 内を指すか。

## 2. 配列 ownership state machine

### 状態定義

| state | 定義 |
|---|---|
| HOST_ONLY | host memory のみが authoritative。device registration はない。 |
| MIRRORED_HOST_AUTH | host が authoritative。device copy は read-mostly cache。host 更新後は明示 update/copyin が必要。 |
| DEVICE_AUTH | device が authoritative。host 側参照は禁止または明示 update 後のみ許可。 |
| MIRRORED_DEVICE_AUTH | device が authoritative だが、同期点で host mirror を作る。同期前 host read は stale risk。 |
| PRESENT_BORROWED | caller が lifetime を所有し、callee は `present` のみ要求する。 |
| TRANSIENT_DEVICE | routine 内 temporary。enter/create から delete までが短い。 |

### ownership table

| array | declaration | 初期状態 | producer | consumer | 推奨 target state | stale data risk / 禁止事項 |
|---|---:|---|---|---|---|---|
| `P` | line 54 | MIRRORED_HOST_AUTH | CG/SD input, `S2_` update | `S2_`, `exnlp_gemm_present_inputs` | MIRRORED_DEVICE_AUTH during TDDFT step loop | host が time-step 中に読む場合は update 必須。`P(1:NXYZ,...)` mapping 禁止。 |
| `YLM` | line 61 | HOST_ONLY after `GETYLM` | `GETYLM` lines 2771-2862 | `exnlp_only_make_acc` | MIRRORED_HOST_AUTH or PRESENT_BORROWED | callee 内反復 `copyin` 禁止。caller ownership 必須。 |
| `VPJ` | line 106 | HOST_ONLY after `SEPPOT` path | `SEPPOT` family | `exnlp_only_make_acc` | MIRRORED_HOST_AUTH or PRESENT_BORROWED | actual section が noncontiguous なら pack/unpack risk。 |
| `EXTAU` | line 79 | HOST_ONLY | `SEPPOT` / setup path | `exnlp_only_make_acc` | MIRRORED_HOST_AUTH or PRESENT_BORROWED | dummy section と親配列の present-table mismatch risk。 |
| `work2_` | line 1745 | TRANSIENT_DEVICE candidate | `exnlp_only_make_acc` | `exnlp_gemm_present_inputs` | DEVICE_AUTH | host round trip 禁止。Step 20 の細粒度 copyin 再導入禁止。 |
| `cfac_` | line 1746 | small metadata | `S2_` host loop | `exnlp_gemm_present_inputs` | MIRRORED_HOST_AUTH initial | small bulk copy は許容。device generation は後段。 |
| `ngnl_` | line 1747 | small metadata | `S2_` host loop from `ngnl(ity)` | `exnlp_gemm_present_inputs` | MIRRORED_HOST_AUTH initial | host ia loop が読む限り device authoritative にしない。 |
| `RHO1_` | line 1744 | TRANSIENT_DEVICE | FFT/scatter | local potential multiply | TRANSIENT_DEVICE | `P` との shape 混同禁止。 |
| `RHO2_` | line 1744 | TRANSIENT_DEVICE | local potential multiply | FFT/gather | TRANSIENT_DEVICE | partially present 回避のため exact create range が必要。 |
| `VG` | line 1719 | TRANSIENT_DEVICE | `VGG+Vloc` lines 2020-2025 | local multiply | TRANSIENT_DEVICE | `VGG`, `Vloc` host update 後 stale risk。 |

### state transition rules

| transition | trigger | 許可 routine | 禁止 |
|---|---|---|---|
| HOST_ONLY -> MIRRORED_HOST_AUTH | `enter data copyin` / `update device` | caller side only (`TMEVL` or `S2_` owner block) | callee `exnlp_only_make_acc` 内での反復 copyin |
| MIRRORED_HOST_AUTH -> PRESENT_BORROWED | subroutine call with present contract | `exnlp_only_make_acc`, `exnlp_gemm_present_inputs` | callee delete |
| PRESENT_BORROWED -> MIRRORED_HOST_AUTH | return to caller | caller | callee による ownership 解放 |
| MIRRORED_HOST_AUTH -> DEVICE_AUTH | GPU producer fully replaces host producer | later Step C only | host 側 ia loop が同じ配列を読む状態での移行 |
| DEVICE_AUTH -> MIRRORED_DEVICE_AUTH | `update host` at explicit checkpoint | validation/archive only | time-step 内反復 update |
| TRANSIENT_DEVICE -> deleted | `exit data delete` | owner routine | consumer が残っている状態で delete |

## 3. Routine contract

| routine | Precondition | Postcondition | Forbidden operations |
|---|---|---|---|
| `TMEVL` (`line 15`) | Owns TDDFT high-level lifetime. `P`, `YLM`, `VPJ`, `EXTAU` host definitions are valid. | `P` final state is copied back at line 714 unless fallback path. | 1 GPU / 1 rank assumptionを global API に固定化しない。time-step 中の不要 host read。 |
| `S2_` (`line 1693`) | Caller passed `P(NG2Q,mxbnd)`, `YLM`, `VPJ`, `EXTAU`, band range. | Updates `P` mathematically equivalent to CPU path. | `P(1:NXYZ,...)` ownership前提。ia order change。host/device 同時更新。 |
| `exnlp_only_make` (`line 2434`) | CPU fallback path. host arrays valid. | host `work1`, `ngnl`, `cfac` equivalent to existing CPU. | OpenACC-only interface dependency。 |
| `exnlp_only_make_acc` (`line 2459`) | Caller owns lifetime for `YLM`, `VPJ`, `EXTAU`; output buffer is valid. | Produces one `work2_` column and metadata equivalent to CPU path. | Internal `copyin/copyout` for `ylm`, `extau`, `vpj` in final design; allocation/deallocation; host update; ia reorder. |
| `exnlp_gemm` (`line 2491`) | Legacy wrapper may copyin temporary arrays. | Updates `coef`. | Use as final resident path if it reintroduces large transfers. |
| `exnlp_gemm_present_inputs` (`line 2521`) | `work1`, `coef`, `ngnl`, `cfac` are present according to caller contract. | Calls fused body and updates `coef`. | Owns no data lifetime; no copyin of large arrays. |
| `exnlp_gemm_body_fused` (`line 2534`) | `coef(1:ng2q,1:nbndloc)` and metadata present. | Performs fused update preserving ia order. | Changing ia update order, hidden host temporaries, per-ia allocation/free. |

## 4. Interface 比較: YLM / VPJ / EXTAU

### A. 現在の array section 渡し

| 項目 | 評価 |
|---|---|
| contiguity | `YLM(1,lylm)` や `VPJ(1,ip,il,ity)` の first dimension slice は column-major 上 contiguous と考えられる。ただし dummy が親 shape で宣言され、内部 section がさらに使われるため compiler descriptor 挙動は UNVERIFIED。 |
| descriptor 依存 | assumed-size ではなく explicit-shape dummy。actual が section の場合、compiler が base address と descriptor をどう扱うかは Step A で確認。 |
| present-table 安定性 | 親配列を `enter data copyin(YLM(1:NGcont,1:16))` しても、callee section `ylm(1:NGcont,lylm)` が親 allocation と一致するかは確認が必要。 |
| pack/unpack 可能性 | first dimension contiguous section なら低いが、non-unit lower bound や multi-dim section ではゼロではない。 |
| fallback 互換性 | 高い。既存 routine signature を維持できる。 |
| コード侵襲 | 低い。 |
| デバッグ容易性 | present-table mismatch 時に原因追跡が難しい。 |

### B. 親配列 + index 範囲渡し

| 項目 | 評価 |
|---|---|
| contiguity | 親配列全体を渡し、callee 内で index を使うため section temporary risk を下げられる。 |
| descriptor 依存 | explicit parent shape を維持しやすい。 |
| present-table 安定性 | 親 allocation を登録して親 allocation を参照するため最も安定。 |
| pack/unpack 可能性 | 低い。 |
| fallback 互換性 | wrapper が必要。CPU fallback signature を維持するなら二重 interface が必要。 |
| コード侵襲 | 中。call site と callee indexing 変更が必要。 |
| デバッグ容易性 | 高い。address と bounds を診断しやすい。 |

### DECISION

- Step A/B では A を維持し、診断だけ行う。
- `partial present` または pack/unpack が確認された場合、第一代替案として B を採用する。
- GPU producer 接続前に、B の未使用 wrapper/interface を追加する commit を独立させる。

## 5. ngnl_ 設計

| 案 | host 参照 | device 参照 | 同期回数 | 転送サイズ | correctness risk | 実装難度 | 評価 |
|---|---|---|---:|---:|---|---|---|
| host authoritative + bulk copy | `S2_` host ia loop | `exnlp_gemm_present_inputs` | S2 内 2 回程度 | `loopcnt * sizeof(int)` | 低 | 低 | 初期候補 |
| mirrored | host producer / device consumer | device consumer | explicit update 必要 | 小 | stale risk 中 | 中 | Step C 以降 |
| device authoritative | host は読まない | device producer/consumer | 低 | 小 | ia loop除去が必要 | 高 | 後段 |
| GPU生成後に小容量だけhostへ戻す | host ia loopが後続で読む場合 | device producer | 反復 update の危険 | 小だが回数依存 | 性能 risk | 中 | 原則不採用 |
| host側ia loopを残す | あり | consumerのみ | bulk copy | 小 | 低 | 低 | 初期実装 |
| ia loop GPU化 | なし | 全 device | 低 | 低 | ia順序変更 risk | 高 | 数学的等価性確認後 |

### DECISION

- 初期実装は `ngnl_` host authoritative + 小容量 bulk copy。
- `work2_` は device 生成、device 消費を目標にする。
- `cfac_` は `ngnl_` と同じ小容量 metadata として初期は host authoritative。

### UNVERIFIED

- `ngnl(ity)` の生成元と `loopcnt` の最大値は source と実行時双方で追加確認する。
- ia loop を GPU 化しても数学的に順序不変かは未確認。ia 更新順序は変更しない。

## 6. Data lifetime 図

### 案 1: S2 単位

```text
TMEVL
  call S2_
    enter: RHO1_, RHO2_, VG, work2_, cfac_, ngnl_
    producer: local potential / exnlp_only_make_acc
    consumer: FFT / exnlp_gemm_present_inputs
    update: only small metadata if needed
    delete: S2_ exit
  return
```

- GPU memory peak: 低から中。
- stale risk: 小さい。
- fallback 影響: 低い。
- 欠点: S2 ごとに allocation/delete が残る。

### 案 2: TMEVL 単位

```text
TMEVL enter
  P, YLM, VPJ, EXTAU, reusable work buffers
  repeated S2_
    present-only callee
TMEVL exit
  update/copyout P
  delete reusable buffers
```

- GPU memory peak: 中。
- stale risk: ownership contract が守られれば中以下。
- fallback 影響: compile-time branch が必要。
- 利点: repeated transfer/allocation を削減できる。

### 案 3: time-step loop 単位

```text
TDDFT time-step loop enter
  persistent P and static metadata
  each step
    TMEVL / S2_ use present data
  optional checkpoint update
loop exit
  copyout final observables
```

- GPU memory peak: 中から高。
- stale risk: 高い。host diagnostics/checkpoint と衝突しやすい。
- fallback 影響: 大。
- 採用時期: TMEVL 単位が安定後。

### 案 4: TDDFT 実行全体

```text
program start
  enter all reusable arrays
CG/SD/TDDFT phases
  keep arrays resident
program end
  copyout final state
```

- GPU memory peak: 高。
- stale risk: 高。
- fallback 影響: 最大。
- 現時点では採用しない。

### DECISION

- 次段階は S2 単位から TMEVL 単位への移行可能性を測る。
- Step A は lifetime を変更しない。
- Step B 以降も、TMEVL 単位 ownership 確立までは GPU producer 接続しない。

## 7. Commit 単位の実装計画

| commit | 仮説 | 変更対象 | 非変更対象 | 検証条件 | rollback 条件 | 想定リスク |
|---|---|---|---|---|---|---|
| A1 | diagnostic macro だけなら計算経路を変えない | build flags, diagnostic stubs | OpenACC data region, computation | check PASS, relaxed compare PASS | 出力以外の差分、wall 大幅悪化 | printf overhead |
| A2 | address/contiguity 診断で present-table を理解できる | `TMEVL`, `S2_` limited diagnostics | ownership, copyin/delete | `P`, `YLM`, `VPJ`, `EXTAU` address log取得 | hidden sync/大量出力 | acc_deviceptr sync overhead |
| B1 | 親配列 + index interface を未使用追加しても fallback を壊さない | new wrapper/interface only | call site | GNU/Intel/NVHPC compile可能 | fallback compile break | symbol collision |
| B2 | ACC側 call site を fallback 保持で切替可能 | ACC branch call site | CPU path | check/compare PASS | numerical mismatch | section/index bug |
| B3 | caller ownership を確立できる | caller `enter data/delete` | callee internals | no duplicate copyin, no partial present | partial present | lifetime mismatch |
| B4 | callee present 契約化できる | `exnlp_only_make_acc` copyin removal | producer algorithm | no internal copyin, check PASS | present false | parent/section mismatch |
| C1 | GPU producer 接続で work2_ を device 生成できる | `exnlp_only_make_acc` output path | ia order | check PASS, compare PASS | Step 18比 regression | launch増加 |
| C2 | work2_ host round trip を削除できる | `work2_` dataflow | metadata policy | Nsightで large H2D/D2H 減少 | hidden copy remains | present contract bug |
| C3 | metadata転送を最小化できる | `cfac_`, `ngnl_` bulk transfer | ia order | small transfer only | sync復活 | stale metadata |

## 8. Failure matrix

| symptom | 原因候補 | 切り分け手順 |
|---|---|---|
| partially present | 親配列登録範囲と dummy section 不一致、`P(1:NXYZ,...)` 誤用、section base mismatch | `NV_ACC_DEBUG`, `acc_is_present`, host/device ptr, exact bounds log |
| `acc_is_present` false | caller ownership 未確立、wrong section bounds、delete 済み | owner routine entry/exit log、present table dump |
| segmentation fault | bounds mismatch、Fortran temporary lifetime、uninitialized pointer | static bounds check、debug compile、minimal step |
| numerical mismatch | ia order change、metadata stale、precision/order difference | strict/relaxed compare、per-step energy/norm log |
| NaN/Inf | stale `P`/metadata、uninitialized device array、FFT scaling error | NaN scan after producer/consumer boundaries |
| performance regression | copyin loop復活、allocation/free増加、kernel launch過多 | Nsight Systems、profile timer、OpenACC report |
| unexpected H2D/D2H | implicit copy due to absent present, pack/unpack | `NVCOMPILER_ACC_NOTIFY`, Nsight memcpy track |
| allocation/free増加 | transient data region inside loop、cuFFT plan/workspace再生成 | Nsight allocation track、timer `fft_plan_init` |
| kernel launch増加 | fine-grained kernels per ia/np/phase | compiler report and Nsight kernel count |
| pack/unpack発生 | noncontiguous section actual、descriptor temporary | compiler messages, address/stride diagnostics |

## 9. Static verification checklist

- [ ] `P`, `coef` first dimension is never newly mapped with `NXYZ`.
- [ ] `NG2Q`, `NXYZ`, `NGcont`, `mxbnd`, `nbndloc` are logged before Step B.
- [ ] Every dummy/actual pair has matching rank and intended bounds.
- [ ] `YLM`, `VPJ`, `EXTAU` section contiguity is classified before ownership change.
- [ ] `work2_`, `cfac_`, `ngnl_` allocation/deallocation pairs are balanced.
- [ ] `enter data` / `exit data` pairs are owned by caller, not callee.
- [ ] compile-time macro defaults are OFF for experimental diagnostics.
- [ ] GNU + FFTW and Intel + FFTW source paths do not require OpenACC-only interfaces.
- [ ] NVHPC + FFTW path remains buildable without cuFFT-only symbols.
- [ ] NVHPC + cuFFT host-copy path remains available as rollback.
- [ ] no duplicate external symbol is introduced by new interface wrappers.
- [ ] timer IDs remain unique.
- [ ] `mod_timer` nested totals are not treated as wall time.

## 10. Unresolved questions

| item | status | 確認方法 | 必要ログ | 合格条件 |
|---|---|---|---|---|
| `NG2Q` vs `NXYZ` actual values | BLOCKER | Step A diagnostic | values at `TMEVL`/`S2_` entry | `P` mapping uses `NG2Q`, not inferred `NXYZ` |
| `J2G` bounds | BLOCKER | min/max scan | `minval(J2G)`, `maxval(J2G)` | all values within `1:NG2Q` |
| `YLM` section present stability | UNVERIFIED | `acc_is_present`, ptr log | parent and section ptrs | section maps inside parent allocation |
| `VPJ` section pack/unpack | UNVERIFIED | compiler report + Nsight | pack/unpack or memcpy events | no repeated large temporary transfer |
| `EXTAU` section pack/unpack | UNVERIFIED | compiler report + Nsight | pack/unpack or memcpy events | no repeated large temporary transfer |
| `ngnl_` host/device sync count | UNVERIFIED | Nsight memcpy count | transfer size/count | small bulk copy only |
| peak GPU memory | UNVERIFIED | Nsight / nvidia-smi | peak allocation | fits target GPU with margin |
| Step 18 variance | UNVERIFIED | repeated timing | wall_sec series | regression threshold can be set |

## 11. Step A measurement-only requirements

### DECISION

Step A は computation path、data lifetime、copyin/delete の意味を変えない。診断は macro OFF by default とし、diagnostic run と timing run を分ける。

### 計測対象

- host base address。
- section address。
- `acc_is_present` result。
- `acc_deviceptr` result。
- shape and bounds。
- contiguity / stride。
- H2D/D2H count。
- allocation/free count。
- peak GPU memory。
- kernel launch count。
- Step 18 比 wall time。

### Step B へ進む合格条件

- check PASS。
- relaxed compare PASS。
- Step 18 比 wall time 悪化が計測揺らぎ内。
- 新規大規模 H2D/D2H なし。
- partially present error なし。
- unexpected pack/unpack なし。
- address mapping が設計想定と一致。
- peak memory が許容範囲内。

## 12. 数値検証方針

- 2 step、50 step、100 step を最低確認する。
- `check_tddft_result.py check` を実行する。
- `check_tddft_result.py compare` の relaxed mode を実行する。
- 可能なら strict compare も実行するが、platform 差分で fail する場合は relaxed の各項目差分を記録する。
- Step 18 archive との直接比較を行う。
- NaN/Inf 検査を追加する。
- `ETOT`, `Eelec+Enucl-Eext-Ework`, force, position, velocity の最終値だけでなく、可能な範囲で途中 step 推移も比較する。

## 13. Timer 解釈

- profile timer は inclusive の可能性がある。
- `mod_timer` の `TOTAL` は nested region の単純和であり、wall time ではない。
- 親 timer と子 timer を単純加算しない。
- 性能比較では同一範囲、同一定義の timer のみを比較する。
- Step 18 との比較では `wall_sec`、`time_step_total`、主要 child timer を分けて見る。

## 14. 実装開始前に人間が承認すべき事項

- `P` の device 登録範囲を `P(1:NG2Q,1:nbndloc)` とすること。
- `P(1:NXYZ,1:nbndloc)` を正当な mapping として扱わないこと。
- Step A は計測のみで、ownership 変更を含めないこと。
- `YLM`, `VPJ`, `EXTAU` は caller ownership / callee present 契約へ向かうこと。
- `exnlp_only_make_acc` 内部の反復 `copyin` は最終設計で削除するが、Step A ではまだ変更しないこと。
- `ngnl_` 初期設計は host authoritative + small bulk copy とすること。
- ia 更新順序は数学的等価性が確認されるまで変更しないこと。

## 自己判定

- Blocking issue 残件数: 2
  - `NG2Q` と `NXYZ` の実値および `J2G` bounds 未確認。
  - `P(1:NXYZ,1:nbndloc)` 既存 clause の扱いを実行時 present-table で確認する必要。
- Major issue 残件数: 4
  - `YLM`, `VPJ`, `EXTAU` section present stability 未確認。
  - pack/unpack 有無未確認。
  - GPU memory peak 未確認。
  - Step 18 timing variance 未確認。
- 実装開始判定: READY FOR STATIC REVIEW

Step A measurement-only は、上記 BLOCKER を解消するための診断としてのみ開始可能。GPU producer 接続、ownership 拡張、data region lifetime 変更はまだ NOT READY。
