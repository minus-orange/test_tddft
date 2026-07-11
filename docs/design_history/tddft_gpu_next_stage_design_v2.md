# FPSEID21 TDDFT GPU化 次段階実装前設計書 v2

対象ブランチ: `tddft-openacc-residency`

対象ディレクトリ: `FPSEID21/tddft_2022October`

主要対象ファイル: `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`

対象routine:

- `S2_`
- `exnlp_only_make`
- `exnlp_only_make_acc`
- `exnlp_gemm`
- `exnlp_gemm_present_inputs`
- `exnlp_gemm_body_fused`

前提:

- 1 GPU / 1 MPI rank
- OpenACC + cuFFT
- CPU / FFTW fallbackは維持する
- `ia` 更新順序は、数学的等価性が確認されるまで変更しない

## 記述ラベル

- **CONFIRMED**: 現在のsourceまたは測定結果で確認済み
- **HYPOTHESIS**: 妥当な仮説だが、測定または追加読解が必要
- **UNVERIFIED**: 未確認。実装判断に使ってはいけない
- **DECISION**: 本設計で採用する方針
- **BLOCKER**: 解決または明示承認なしに次段階実装へ進めない事項

## 正式Baseline

**CONFIRMED**

正式な性能baselineはStep 18とする。

- archive label: `nvhpc_cufft_1rank_02_STEP18_01`
- `wall_sec`: 約163.31秒
- `check`: PASS
- `relaxed compare`: PASS
- `s2_nonlocal_make`: 約2.88秒
- `tmevl_total`: 約92.92秒
- `frprmn`: 約154.53秒

根拠:

- [docs/tddft_gpu_progress_summary.md](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/docs/tddft_gpu_progress_summary.md:1186)
- [docs/tddft_gpu_progress_summary.md](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/docs/tddft_gpu_progress_summary.md:1242)

## 不採用実験

**CONFIRMED**

| Step | 結果 | 判定 | 理由 |
|---|---:|---|---|
| Step 19 | 約178秒 | 不採用 | Step 18より遅く、`s2_nonlocal_make` が約30.44秒へ増加 |
| Step 20 | 約819秒 | 不採用 | `s2_nonlocal_make` が約679.87秒まで増加 |

**DECISION**

routine内部またはsection単位の反復 `copyin` は採用しない。特に `exnlp_only_make_acc` 内部で `ylm`, `extau`, `vpj` を毎回 `copyin` する設計はStep 20の性能悪化と整合するため、次段階では禁止する。

根拠:

- [docs/tddft_gpu_progress_summary.md](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/docs/tddft_gpu_progress_summary.md:1282)
- [docs/tddft_gpu_progress_summary.md](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/docs/tddft_gpu_progress_summary.md:1323)

## 変更履歴

**CONFIRMED**

| 版 | 内容 |
|---|---|
| v1 | 次段階案を作成。ただしP/coef shape、YLM/VPJ/EXTAU ownership、`ngnl_` authority、Step分割が不十分 |
| v2 | 前回レビューのBlocking/Major指摘を反映。未確認点をBLOCKER/UNVERIFIEDとして分離し、Step A-Dを再設計 |

## 前回レビュー指摘への対応表

| 指摘 | v2での対応 | 残件 |
|---|---|---|
| P/coef shapeが不明確 | `P`, `coef`, data clauseを行番号付きで列挙し、`P(1:NXYZ,...)` を危険箇所として明記 | `NXYZ` と `NG2Q` の実測値、`nbegin/nend` とlocal列の対応はBLOCKER |
| YLM/VPJ/EXTAU ownership契約が曖昧 | 親配列、dummy、section、contiguity、登録/削除場所を表化 | host更新場所の完全追跡はUNVERIFIED |
| `ngnl_` のauthorityが曖昧 | A/B/C案を比較し、初期案をhost authoritativeに決定 | device authoritative化は後続Step |
| Step分割がbaselineを壊しやすい | Step A-Dへ再構成。最初は計測のみ | GPU producer接続はStep Dまで禁止 |
| array sectionとpresent table理解が不足 | Fortran column-majorとsection contiguous性を明記 | NVHPC descriptor/temporaryの有無はStep Aで確認 |
| data region lifetimeが曖昧 | S2/TMEVL/time-step/full-run単位で比較 | 採用はStep A/B後 |
| kernel launch過多リスク | 現状countから概算し、増加条件をrollback対象に設定 | Nsightで実測が必要 |
| GPUメモリ未積算 | 主要配列の式とsample推定を記載 | cuFFT workspace等はUNVERIFIED |
| fallback破壊リスク | build matrixを追加 | macro名の最終整理は実装時 |
| relaxed compare過信 | validation matrixにstrict/途中step/NaN検査を追加 | strict可否は同一compiler条件で限定 |

## 現在の呼び出し経路

**CONFIRMED**

対象範囲は `S2_` 内の非局所項処理である。

```text
TDDFT time-step loop
  -> TMEVL path
    -> S2_(...)
      -> first nonlocal phase
        -> exnlp_only_make_acc(...)
          -> work2_(:,ia), cfac_(ia) generation
        -> ngnl_(ia) = ngnl(ity) on host
        -> exnlp_gemm_present_inputs(...)
          -> exnlp_gemm_body_fused(...)
      -> FFT/local/other S2 work
      -> second nonlocal phase
        -> exnlp_only_make_acc(...)
        -> ngnl_(ia) = ngnl(ity) on host
        -> exnlp_gemm_present_inputs(...)
          -> exnlp_gemm_body_fused(...)
```

主要行:

- `S2_` 定義: [tmevl10_Avec_v4.f](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/FPSEID21/tddft_2022October/tmevl10_Avec_v4.f:1693)
- first phase `exnlp_only_make_acc` 呼び出し群: [tmevl10_Avec_v4.f](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/FPSEID21/tddft_2022October/tmevl10_Avec_v4.f:1834)
- first phase `exnlp_gemm_present_inputs`: [tmevl10_Avec_v4.f](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/FPSEID21/tddft_2022October/tmevl10_Avec_v4.f:1923)
- second phase `exnlp_only_make_acc` 呼び出し群: [tmevl10_Avec_v4.f](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/FPSEID21/tddft_2022October/tmevl10_Avec_v4.f:2133)
- second phase `exnlp_gemm_present_inputs`: [tmevl10_Avec_v4.f](/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21/FPSEID21/tddft_2022October/tmevl10_Avec_v4.f:2222)

## 現在のデータフロー

**CONFIRMED**

```text
YLM, VPJ, EXTAU, NGNL, TAU, VPP, VPP2
        |
        | consumed by exnlp_only_make_acc
        v
work2_(:,ia), cfac_(ia), ngnl_(ia)
        |
        | consumed by exnlp_gemm_present_inputs
        v
exnlp_gemm_body_fused updates P/coef on device
```

**DECISION**

次段階の設計目標は、`work2_` と `cfac_` をGPU上で生成し、そのまま `exnlp_gemm_present_inputs` に渡すことである。`ngnl_` は初期案ではhost authoritativeを維持し、小容量bulk `copyin` に限定する。

## P / coef Shape整合性

### source上の宣言とdata clause

**CONFIRMED**

| 対象 | routine | 行 | 宣言またはclause |
|---|---|---:|---|
| `P` dummy | `S2_` | 1707 | `COMPLEX*16 P(NG2Q,mxbnd)` |
| `P` data clause | earlier TDDFT path | 532 | `!$acc enter data copyin(P(1:NG2Q,1:nbndloc))` |
| `P` data clause | earlier TDDFT path | 714 | `!$acc exit data copyout(P(1:NG2Q,1:nbndloc))` |
| `P` data clause | `S2_` current path | 1942 | `!$acc data present(P(1:NXYZ,1:nbndloc))` |
| `P` data clause | `S2_` current path | 1962 | `!$acc parallel loop present(P(1:NXYZ,1:nbndloc),...)` |
| `P` data clause | `S2_` current path | 2091 | `!$acc parallel loop present(P(1:NXYZ,1:nbndloc),...)` |
| `coef` dummy | `exnlp_gemm` | 2494 | `complex*16 coef(ng2q,mxbnd)` |
| `coef` dummy | `exnlp_gemm_present_inputs` | 2524 | `complex*16 coef(ng2q,mxbnd)` |
| `coef` dummy | `exnlp_gemm_body_fused` | 2537 | `complex*16 coef(ng2q,mxbnd)` |
| `coef` present | `exnlp_gemm_body_fused` | 2545 | `present(coef(1:ng2q,1:nbndloc),...)` |

### Shapeの意味

**CONFIRMED**

| Symbol | 意味 | source根拠 |
|---|---|---|
| `NG2Q` | reciprocal-space coefficient dimension for `P`/`coef` and `G2(4,NG2Q)` | `P(NG2Q,mxbnd)` line 1707, `G2(4,NG2Q)` line 1731 |
| `NXYZ` | real-space FFT grid dimension for `RHO1`, `RHO2`, `VG`, `Vloc` | `RHO1(NXYZ),RHO2(NXYZ),VG(NXYZ)` lines 1714-1719, `Vloc(NXYZ)` line 1739 |
| `mxbnd` | maximum band dimension for `P`/`coef` | `P(NG2Q,mxbnd)` line 1707 |
| `nbndloc` | local band count, `nend-nbegin+1` | line 1817 and line 2542 |
| `NGcont` | compact nonlocal vector dimension for `YLM`, `VPJ`, `EXTAU`, `work2_` | lines 1713, 1719, 1736, 1745 |

**BLOCKER**

`NG2Q` と `NXYZ` はsource上で別概念であり、等しいとは確認できていない。したがって `P(1:NXYZ,1:nbndloc)` を `P` の正しいdevice登録範囲として使う設計は禁止する。`P`/`coef` の正しい範囲は、consumerである `exnlp_gemm_body_fused` と一致する `P(1:NG2Q,1:nbndloc)` を第一候補とする。

**UNVERIFIED**

`nbegin` が1でない場合に、`P(1:NG2Q,1:nbndloc)` が常に正しいか、あるいは `P(1:NG2Q,nbegin:nend)` が必要かは未確認である。`exnlp_gemm_body_fused` は `coef(ig,iib)` を `iib=1..nbndloc` で参照するため、現行interface上はlocal列が1始まりで渡される前提に見える。この前提を実測またはcaller側で確認するまで、band offsetを変える実装は禁止する。

### 判定

**DECISION**

- `P` / `coef` のOpenACC登録範囲は `1:NG2Q,1:nbndloc` を標準とする。
- `P(1:NXYZ,1:nbndloc)` は誤りまたは意図不明の部分mappingとして扱う。
- `NXYZ == NG2Q` を仮定した実装は禁止する。
- `nbegin/nend` とlocal列の対応確認をStep Aの計測項目に入れる。

## 配列Ownership表

### 大規模配列

| 配列 | 型 | shape | 宣言場所 | 更新場所 | 寿命 | authority | 方針 |
|---|---|---|---|---|---|---|---|
| `P` | `COMPLEX*16` | `P(NG2Q,mxbnd)` | `S2_` line 1707 | `exnlp_gemm_body_fused` lines 2543-2567 | band state | mirrored/device during time-step | exact range `P(1:NG2Q,1:nbndloc)` |
| `coef` | `COMPLEX*16` | `coef(ng2q,mxbnd)` | `exnlp_gemm*` lines 2494, 2524, 2537 | `exnlp_gemm_body_fused` line 2565以降 | alias of `P` | same as `P` | `P`と同じdevice登録が必要 |
| `RHO1_` | `COMPLEX*16` | `RHO1_(NXYZ,mxbnd)` | line 1744 | `S2_`内FFT/密度経路 | S2/TMEVL | mirrored | current Step 18経路を壊さない |
| `RHO2_` | `COMPLEX*16` | `RHO2_(NXYZ,mxbnd)` | line 1744 | `S2_`内FFT/密度経路 | S2/TMEVL | mirrored | Step Aでpresent確認 |
| `VG` | `COMPLEX*16` | `VG(NXYZ)` | lines 1714-1719 | local potential path | S2/TMEVL | mirrored | update箇所再確認 |
| `work2_` | `COMPLEX*16` allocatable save | `work2_(NGcont,loopcnt)` | line 1745 | `exnlp_only_make_acc` line 2484 | S2 nonlocal phase | device authoritative after producer | GPU生成・GPU消費 |
| `cfac_` | `COMPLEX*16` allocatable save | `cfac_(loopcnt)` | line 1746 | `exnlp_only_make_acc` line 2470 | S2 nonlocal phase | host/device mirrored initially | 初期はhost生成 + bulk copyin可 |
| `ngnl_` | integer allocatable save | `ngnl_(loopcnt)` | line 1747 | host assignment lines 1839 etc. | S2 nonlocal phase | host authoritative initially | 小容量bulk copyin |

### YLM / VPJ / EXTAU ownership契約

**DECISION**

`YLM`, `VPJ`, `EXTAU` はcallerがownershipを持つ。calleeである `exnlp_only_make_acc` は `present` のみを要求し、内部で `copyin` しない。partial presentを許容しない。

| 配列 | 実体宣言 | 親配列shape | caller実引数 | dummy shape | 使用section | contiguous性 | host更新場所 | device登録場所 | delete場所 | 契約 |
|---|---:|---|---|---|---|---|---|---|---|---|
| `YLM` | lines 1713, 2776 | `YLM(NGcont,16)` | `ylm` line 1836等 | `ylm(NGcont,16)` line 2465 | `ylm(1:NGcont,lylm)` line 2481 | full first dimension + scalar second dimなのでFortran上contiguous | `GETYLM` lines 2771, 2847-2862 | **UNVERIFIED** Step Aで確認 | **UNVERIFIED** | caller owns, callee present |
| `VPJ` | line 1736 | `VPJ(NGcont,3,4,NTYQ)` | `vpj` line 1835等 | `vpj(NGcont,3,4,NTYQ)` line 2464 | `vpj(1:NGcont,ip,il,ity)` line 2483 | full first dimension + scalar higher dimsなのでcontiguous | **UNVERIFIED** potential setup/read path | **UNVERIFIED** Step Aで確認 | **UNVERIFIED** | caller owns, callee present |
| `EXTAU` | lines 1719, 2466 | `EXTAU(NGcont,5,NTAUQ)` | `extau` line 1836等 | `extau(NGcont,5,NTAUQ)` line 2466 | `extau(1:NGcont,np,itseq)` line 2482 | full first dimension + scalar higher dimsなのでcontiguous | legacy/related generation line 2931。current pathはUNVERIFIED | **UNVERIFIED** Step Aで確認 | **UNVERIFIED** | caller owns, callee present |

**BLOCKER**

`YLM`, `VPJ`, `EXTAU` の親配列がdeviceに登録されている範囲と、dummy argument sectionのbase address/section addressがNVHPC present table上で一致することをStep Aで確認するまで、`exnlp_only_make_acc` 内部の `copyin` を削除してはいけない。

## present-table mismatchの原因候補

**CONFIRMED**

過去の実行では、`rho2_`, `ct1`, `ylm` などで `partially present` または `not found on device` が発生した。

**HYPOTHESIS**

原因候補:

1. 親配列を `enter data` した範囲と、calleeのdummy sectionで要求する範囲が異なる。
2. `P` に対して `NXYZ` と `NG2Q` を取り違えた範囲をpresent指定している。
3. Fortran array sectionがdescriptor経由となり、NVHPCが親配列とsectionを同一present entryとして解決できていない。
4. routine内部の細粒度 `copyin` とcaller側 `enter data` が重複し、partial presentを誘発している。
5. `exit data delete` の寿命が短く、後続routineで `present` 要求時にdevice側entryが消えている。

**DECISION**

次段階では、Step Aで `acc_is_present`, `acc_deviceptr`, host address相当情報、section sizeを出し、present table mismatchを実装前に潰す。

## array section渡しと親配列+index渡し

### 現行案: array sectionまたは親配列を渡す

**CONFIRMED**

現行 `exnlp_only_make_acc` は親配列 `vpj`, `ylm`, `extau` とindex群 `np`, `itseq`, `ip`, `il`, `ity` を受け取り、内部でsectionを参照している。

- dummy: `vpj(NGcont,3,4,NTYQ)` line 2464
- dummy: `ylm(NGcont,16)` line 2465
- dummy: `extau(NGcont,5,NTAUQ)` line 2466
- section: lines 2481-2483

利点:

- 親配列shapeがcalleeに見える。
- sectionは第一次元全体なのでcontiguous。
- 親配列ownership契約を作りやすい。

欠点:

- `present(ylm(1:NGcont,lylm))` のようなsection presentが親配列entryと一致するかはNVHPC依存の確認が必要。

### 第一代替案: 親配列 + index範囲のみを渡す

**DECISION**

present-table mismatchが再発する場合、array sectionをcallee側data clauseに書かず、親配列全体または親配列の正確なregistered extentを `present(ylm, vpj, extau)` とし、indexはloop内で使う方式を第一代替案とする。

欠点:

- calleeのinterfaceがGPU用に寄る。
- CPU版routineとの互換性維持にwrapperが必要になる可能性がある。

### 第二代替案: section専用dummyに分ける

**UNVERIFIED**

`vpj_slice(NGcont)`, `ylm_slice(NGcont)`, `extau_slice(NGcont)` を渡す案は、Fortran側で一時配列pack/unpackが発生する可能性がある。特に非contiguous sectionでは危険である。

今回の対象sectionはfull first dimension + scalar higher dimensionsなのでcontiguousのはずだが、NVHPCのdescriptor/temporary有無はStep Aで確認する。

## `ngnl_` Authority設計

### A. host authoritative + 呼び出しごとの小容量bulk copyin

**DECISION: 初期実装の第一候補**

| 項目 | 内容 |
|---|---|
| host参照箇所 | `ngnl_(loopcnt)=ngnl(ity)` lines 1839等 |
| device参照箇所 | `exnlp_gemm_body_fused`, `ngnl(ia)` lines 2543-2567 |
| 同期回数 | S2 nonlocal phaseごとに1回bulk `copyin` |
| 転送サイズ | `loopcnt * sizeof(integer)`。sampleでは約192 bytes程度 |
| correctness risk | 低い。現行CPU側loop順序を維持 |
| 実装難度 | 低い |

採用理由:

- `ngnl_` は小容量metadataであり、Step 18性能を壊しにくい。
- `ia` loop順序を変えない。
- GPU producer化の主目的は大きな `work2_` のhost round trip削減であり、`ngnl_` の完全device authorityは初期Stepでは不要。

### B. device authoritative + host側ia loop除去

**HYPOTHESIS**

| 項目 | 内容 |
|---|---|
| host参照箇所 | なくす必要がある |
| device参照箇所 | producer kernelとconsumer GEMM |
| 同期回数 | 0を目標 |
| 転送サイズ | 0 |
| correctness risk | 中から高。`ia`順序、`loopcnt`生成、`IBUN/MXOFL/NIDN`依存の再現が必要 |
| 実装難度 | 高い |

これはStep 18回復後の改善候補であり、初期実装では採用しない。

### C. mirrored + 明示update

**HYPOTHESIS**

| 項目 | 内容 |
|---|---|
| host参照箇所 | 現行host `ia` loop |
| device参照箇所 | GEMM consumer |
| 同期回数 | update timing次第で増えやすい |
| 転送サイズ | 小さいが頻度に注意 |
| correctness risk | 中。stale data riskあり |
| 実装難度 | 中 |

**DECISION**

Cは同期タイミングが曖昧になりやすいため、初期実装では採用しない。

## data region lifetime比較

### Lifetime図

```text
TDDFT run
  enter full-run data?        [候補4: long lifetime]
  time-step loop
    enter time-step data?     [候補3: target lifetime]
    TMEVL
      enter TMEVL data?       [候補2: near-term candidate]
      S2_
        enter S2 data         [候補1: current/safe]
        nonlocal phase 1
        FFT/local work
        nonlocal phase 2
        exit S2 data
      exit TMEVL data
    exit time-step data
  exit full-run data
```

| 候補 | copyin場所 | update場所 | delete場所 | stale data risk | GPU memory | fallback影響 | 判定 |
|---|---|---|---|---|---|---|---|
| S2単位 | `S2_`入口 | `S2_`内 | `S2_`出口 | 低 | 中 | 小 | 現在の安全基準 |
| TMEVL単位 | TMEVL入口 | `S2_`/TMEVL内 | TMEVL出口 | 中 | 中 | 中 | Step B後の候補 |
| time-step loop単位 | time-step loop入口 | loop内各routine | loop終了 | 高 | 高 | 中から高 | 最終目標に近いが未確認 |
| TDDFT実行全体 | TDDFT開始時 | 全体 | 終了時 | 高 | 高 | 高 | 当面不採用 |

**DECISION**

Step A/BではS2単位または現行Step 18相当の寿命を維持する。time-step loop単位への拡張は、Step 18性能を回復した後に別Stepで行う。

## exnlp producer / consumer設計

### 現状

**CONFIRMED**

- `work2_` は `S2_` 内で `allocate(work2_(NGcont,loopcnt))` される。line 1810
- `cfac_` は `allocate(cfac_(loopcnt))`。line 1811
- `ngnl_` は `allocate(ngnl_(loopcnt))`。line 1812
- `work2_` は `enter data create` される。line 1821
- `cfac_`, `ngnl_` はbulk `copyin` される。line 1921
- `exnlp_gemm_present_inputs` はcallerが用意したdevice resident入力を前提にする。line 2521

### GPU生成後のconsumer側設計

**DECISION**

`work2_` はdevice authoritativeとし、`exnlp_only_make_acc` で生成した後、hostへ戻さず `exnlp_gemm_present_inputs` に渡す。

`cfac_` は初期段階ではhost/device mirroredでも許容する。ただし、反復 `copyin` は禁止し、S2 phase単位のbulk同期に限定する。

`ngnl_` は初期段階ではhost authoritativeとし、S2 phase単位のbulk `copyin` に限定する。

**BLOCKER**

`work2_` のdevice生成を有効化する前に、`YLM`, `VPJ`, `EXTAU` のcaller ownershipが安定していることをStep A/B/Cで確認する。

## OpenACC directive案

### Step A: measurement only

**DECISION**

計算経路はStep 18と同じまま、以下のみ追加する。

```fortran
! diagnostic only, guarded by compile-time macro
! acc_is_present(parent, bytes)
! acc_deviceptr(parent)
! print section bounds and expected bytes
```

禁止:

- data lifetime変更
- `exnlp_only_make_acc` 接続変更
- `copyin` 削除
- kernel追加

### Step B: ownership establishment

**HYPOTHESIS**

```fortran
! caller side only
!$acc enter data copyin(ylm(1:NGcont,1:16))
!$acc enter data copyin(vpj(1:NGcont,1:3,1:4,1:NTYQ))
!$acc enter data copyin(extau(1:NGcont,1:5,1:NTAUQ))
```

注意:

- CPU版 `exnlp_only_make` を維持する。
- `exnlp_only_make_acc` へはまだ接続しない。
- 二重 `copyin` が発生したらrollback。

### Step C: callee present contract

**DECISION**

caller ownershipとcallee `present` 化を同じcommitで行う。

```fortran
! exnlp_only_make_acc
!$acc parallel loop present(work1(1:NGcont))
!$acc& present(ylm(1:NGcont,1:16))
!$acc& present(extau(1:NGcont,1:5,1:NTAUQ))
!$acc& present(vpj(1:NGcont,1:3,1:4,1:NTYQ))
```

または、present-table mismatchが出る場合:

```fortran
!$acc parallel loop present(work1, ylm, extau, vpj)
```

### Step D: GPU producer connection

**DECISION**

`exnlp_only_make_acc` で `work2_` を生成し、`exnlp_gemm_present_inputs` に直接渡す。

```fortran
! S2 phase
!$acc enter data create(work2_(1:NGcont,1:work2_ncol))
! optional small metadata bulk copyin for ngnl_/cfac_
call exnlp_only_make_acc(...)
call exnlp_gemm_present_inputs(...)
!$acc exit data delete(work2_(...))
```

## routine interface変更案

### 推奨案

**DECISION**

現行 `exnlp_only_make_acc` の親配列 + index引数方式を維持する。

理由:

- `vpj`, `ylm`, `extau` の親配列shapeがcalleeで明示されている。
- sectionは第一次元全体なのでcontiguous。
- `present` を親配列に寄せられる。

### 代替案

**HYPOTHESIS**

present mismatchが残る場合、GPU用routineを以下のinterfaceへ変更する。

```fortran
subroutine exnlp_only_make_acc_parent(...,
     & vpj_parent, ylm_parent, extau_parent,
     & np, itseq, ip, il, ity, ...)
```

calleeでは親配列全体を `present` とし、section `copyin` を書かない。

欠点:

- GPU path用のinterfaceが増える。
- CPU fallbackとの分岐が増える。

## compile-time fallback案

**DECISION**

CPU/FFTW fallbackを壊さないため、GPU residency pathはcompile-time guardで分離する。

候補macro:

- `FPSEID_USE_CUFFT`
- `FPSEID_USE_OPENACC`
- `FPSEID_TDDFT_GPU_RESIDENCY`
- `FPSEID_TDDFT_GPU_DIAG`

GPU専用routineを呼ぶ箇所は、必ずCPU/FFTW pathへ戻せる構造にする。

## fallback build matrix

| 構成 | 使用routine | macro | source selection | interface互換性 | fallback |
|---|---|---|---|---|---|
| GNU + FFTW | CPU `fft_fftw`, CPU nonlocal | none or GNU build flag | original/gnu sources | 基準 | yes |
| Intel + FFTW | CPU `fft_fftw`, CPU nonlocal | none or Intel build flag | original ifort-oriented sources | 基準 | yes |
| NVHPC + FFTW | CPU FFTW with NVHPC | `FFT_BACKEND=fftw` | NVHPC-compatible source selection | 要保持 | yes |
| NVHPC + cuFFT host-copy | cuFFT wrapper + host/device copy | `FFT_BACKEND=cufft` | cuFFT source selection | Step 18以前の互換 | yes |
| NVHPC + cuFFT OpenACC residency | cuFFT + OpenACC resident arrays | `FPSEID_TDDFT_GPU_RESIDENCY` | experimental branch | CPU fallback必須 | yes, macro off |

## kernel launch数見積もり

**CONFIRMED / HYPOTHESIS**

測定profile countからの概算:

| region | 100 step count | 1 step平均 | 備考 |
|---|---:|---:|---|
| `fft_wrapper` | 336589 | 3365.89 | cuFFT wrapper呼び出し含む |
| `tmevl_total` | 944 | 9.44 | TMEVL/S2関連 |
| `tmevl_exkin` | 9440 | 94.4 | 1 stepあたり約94回 |
| `tmevl_s2` | 4720 | 47.2 | S2 nonlocal単位の目安 |
| `s2_nonlocal` | 9440 | 94.4 | 非局所項 |
| `exnlp_gemm_dot/update` | 453120 | 4531.2 | Step 18以前のdot/update系count |

**HYPOTHESIS**

`exnlp_gemm_body_fused` は `ia=1..loopcnt` をhost側で回しており、`loopcnt` が約48の場合、S2 phaseごとに約48 kernel launch相当になる可能性がある。100 stepでは数千から数十万launch規模になるため、GPU producerを追加するときはlaunch数増加を必ずNsightで見る。

**DECISION**

GPU producer追加でkernel launchが増える場合、Step 18比でwall timeが改善しない限り採用しない。特に小kernelを `ia` 単位に増やす設計は禁止候補とする。

## GPU memory積算

**UNVERIFIED**

以下はsource shapeと過去present tableのsample sizeからの概算である。正確な値はStep Aで実測する。

| 配列 | 型 | bytes式 | sample推定 |
|---|---|---:|---:|
| `P` / `coef` | complex*16 | `16 * NG2Q * nbndloc` | 約14,860,800 bytes |
| `RHO1_` | complex*16 | `16 * NXYZ * nbndloc` | 未確定。P同等なら約14.9 MB |
| `RHO2_` | complex*16 | `16 * NXYZ * nbndloc` | 未確定。P同等なら約14.9 MB |
| `VG` | complex*16 | `16 * NXYZ` | 未確定 |
| `VGG` | real*8 | `8 * NXYZ` | 未確定 |
| `work2_` | complex*16 | `16 * NGcont * loopcnt` | 約4,052,736 bytes |
| `cfac_` | complex*16 | `16 * loopcnt` | 約768 bytes |
| `ngnl_` | integer | `4 * loopcnt` | 約192 bytes |
| `YLM` | real*8 | `8 * NGcont * 16` | 約675,456 bytes if `NGcont=5277` |
| `VPJ` | real*8 | `8 * NGcont * 3 * 4 * NTYQ` | 約1,013,184 bytes if `NTYQ=2` |
| `EXTAU` | complex*16 | `16 * NGcont * 5 * NTAUQ` | 約5,910,240 bytes if `NTAUQ=14` |
| FFT work buffer | backend依存 | `UNVERIFIED` | Nsight/cuFFT queryが必要 |
| cuFFT workspace | cuFFT plan依存 | `UNVERIFIED` | `cufftGetSize*`相当で確認 |
| その他temporary | mixed | `UNVERIFIED` | Step Aでpresent table取得 |

通常時:

- `P`, `RHO1_`, `RHO2_`, `VG/VGG`, `YLM`, `VPJ`, `EXTAU`, cuFFT plan/workspaceが主。

Peak時:

- `work2_`, `cfac_`, `ngnl_`, `RHO*`, FFT temporaryが重なる。

**HYPOTHESIS**

A100 40GBではsample問題に対して余裕がある。小容量GPUではcuFFT workspaceと複数band配列が制約になる可能性がある。

**BLOCKER**

GPU memory使用量をStep Aで実測し、A100以外の小容量GPUに対する最低必要容量をdocsに記録するまで、問題サイズ拡大を前提にした実装判断は禁止する。

## validation matrix

| 検証 | 目的 | 合格条件 |
|---|---|---|
| 2 step check | 早期crash/NaN検出 | PASS |
| 50 step check | 短期安定性 | PASS |
| 100 step check | baseline比較 | PASS |
| relaxed compare | cross compiler差を許容した比較 | PASS |
| strict compare | 同一compiler/同一flags時の退行検出 | 可能な場合PASS |
| Step 18 archive直接比較 | 正式baselineからの差分確認 | relaxed PASS |
| NaN/Inf検査 | 数値破綻検出 | 0件 |
| energy/norm途中推移 | relaxed compareが見逃す局所破綻検出 | Step 18と同傾向 |
| force/position/velocity | 最終物理量確認 | 許容値内 |
| Nsight Systems | data motion/launch確認 | 下記条件を満たす |

**DECISION**

relaxed compareだけで実装採用しない。Step 18 direct compare、NaN/Inf、途中step推移、Nsightを合わせて判定する。

## Nsight Systems合格条件

**DECISION**

次段階の採用条件:

- time-step loop内の大規模H2D/D2H転送回数がStep 18以下。
- `exnlp_only_make_acc` 由来の反復H2D/D2Hが0。
- `cudaMalloc/cudaFree` またはOpenACC allocationが反復loop内に残らない。
- kernel launch数が意図しない形でStep 18より増えない。増える場合はwall time改善で正当化する。
- GPU idle gapがStep 18より悪化しない。
- wall timeがStep 18の約163.31秒より悪化しない。計測誤差として一時的に+3%以内は調査継続可だが、採用にはStep 18同等以上が必要。

## timerの解釈

**CONFIRMED**

- profile timerはinclusiveの場合がある。
- `mod_timer` の `TOTAL` はnested regionの単純和であり、wall timeではない。
- 親timerと子timerを単純加算してはいけない。
- 性能比較では同一範囲・同一定義のtimerだけを比較する。
- wall timeの正式値は `check_tddft_result.py` が抽出する `wall_sec` とする。

## Step実装計画

### Step A: measurement only

**DECISION**

目的:

- `acc_is_present`
- `acc_deviceptr`
- 配列section address
- contiguity
- 転送回数
- GPU memory

だけを確認する。計算経路はStep 18と同じ。

rollback条件:

- 数値差分が変化する。
- wall timeがStep 18から+3%超悪化する。
- 計測コードによりkernel/data regionが増える。

成功条件:

- check PASS
- relaxed compare PASS
- present範囲の不一致なし
- `P(1:NG2Q,1:nbndloc)` とconsumer範囲が一致

### Step B: ownership establishment

**DECISION**

目的:

- `YLM`, `VPJ`, `EXTAU` 親配列の `enter data` / `delete` のみを追加する。
- CPU版 `exnlp_only_make` を維持する。
- `exnlp_only_make_acc` にはまだ接続しない。
- 二重copyinが発生しないことを確認する。

rollback条件:

- partial present発生。
- routine内部copyinが残ったまま二重登録される。
- Step 18より明確に遅い。

### Step C: callee present contract

**DECISION**

目的:

- caller ownershipとcallee `present` 化を同じcommitで行う。
- `exnlp_only_make_acc` 内部の `copyin(ylm...)`, `copyin(extau...)`, `copyin(vpj...)` を残さない。
- partial presentを許容しない。

rollback条件:

- `partially present` または `not found on device`。
- host/device同期が復活。
- Step 18より遅い。

### Step D: GPU producer connection

**DECISION**

目的:

- `exnlp_only_make_acc` で `work2_` 等を生成する。
- `work2_` をhostへ戻さず `exnlp_gemm_present_inputs` へ渡す。
- `ngnl_` は初期案ではhost authoritative + phase単位bulk copyin。

rollback条件:

- `s2_nonlocal_make` がStep 18比で増加。
- Step 19/20型の性能悪化。
- relaxed compare FAIL。
- kernel launch数が増え、wall time改善がない。

## Git commit分割案

**DECISION**

1. `docs: revise TDDFT GPU residency design v2`
2. `tddft: add OpenACC residency diagnostics`
3. `tddft: establish parent ownership for exnlp lookup arrays`
4. `tddft: require present lookup arrays in exnlp_only_make_acc`
5. `tddft: connect GPU producer to present-input GEMM`
6. `docs: record validation and Nsight results for each step`

各commitには以下を記録する。

- archive label
- check結果
- relaxed compare結果
- wall_sec
- 主要profile timer
- rollback可否

## 実装開始前に人間が承認すべき事項

**BLOCKER**

1. Step 18を正式baselineとして固定すること。
2. Step Aは計測のみであり、性能改善を狙わないこと。
3. `P` のdevice登録範囲を `P(1:NG2Q,1:nbndloc)` とする方針。
4. `P(1:NXYZ,1:nbndloc)` を新規実装で使わないこと。
5. `ngnl_` は初期実装ではhost authoritativeとすること。
6. `work2_` はdevice生成・device消費を目標にすること。
7. `exnlp_only_make_acc` 内部の細粒度 `copyin` を最終形では残さないこと。
8. Step 18より遅い変更は、診断目的以外では採用しないこと。
9. CPU/FFTW fallbackを壊す変更は受け入れないこと。
10. `ia` 更新順序は、数学的等価性が確認されるまで変更しないこと。

## 自己判定

**BLOCKER残件数: 4**

1. `NG2Q` と `NXYZ` の実測大小関係、および `P` data clauseの最終範囲確認。
2. `nbegin/nend` と `P` local列 `1:nbndloc` の対応確認。
3. `YLM`, `VPJ`, `EXTAU` の親配列device登録場所/delete場所の完全確認。
4. GPU memory peakとcuFFT workspaceの実測。

**Major issue残件数: 5**

1. NVHPCによるarray section temporary pack/unpackの有無。
2. `exnlp_only_make_acc` producer追加時のkernel launch増加量。
3. `ngnl_` device authoritative化の可否。
4. time-step loop単位data regionへ拡張した場合のstale data risk。
5. relaxed compare以外の途中step validation整備。

**実装開始判定: READY FOR MEASUREMENT ONLY**

Step Aの計測のみ開始可能。ownership step、GPU producer stepは、上記BLOCKERをStep Aで確認するまで開始しない。
