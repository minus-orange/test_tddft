# FPSEID21 TDDFT GPU化 次段階 実装前設計書

作成日: 2026-07-10

## 対象

- branch: `tddft-openacc-residency`
- 対象ディレクトリ: `FPSEID21/tddft_2022October`
- 主要対象ファイル: `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- 主要対象routine:
  - `S2_` (`tmevl10_Avec_v4.f:1693`)
  - `exnlp_only_make` (`tmevl10_Avec_v4.f:2434`)
  - `exnlp_only_make_acc` (`tmevl10_Avec_v4.f:2459`)
  - `exnlp_gemm` (`tmevl10_Avec_v4.f:2491`)
  - `exnlp_gemm_present_inputs` (`tmevl10_Avec_v4.f:2521`)
  - `exnlp_gemm_body_fused` (`tmevl10_Avec_v4.f:2534`)
- 実行前提: 1 GPU / 1 MPI rank
- GPU化方針: OpenACC + cuFFT
- 維持する経路: CPU/FFTW fallback

この文書は実装前設計書であり、この段階ではFortranソースの変更を行わない。

## 性能Baselineと失敗実験

### 確定事項

- baseline: Step 18
- Step 18:
  - wall_sec: 約 163.31 秒
  - `check_tddft_result.py check`: PASS
  - relaxed compare: PASS
- 失敗実験:
  - Step 19: 約 178 秒
  - Step 20: 約 819 秒
  - Step 20では `s2_nonlocal_make` が約 680 秒まで増加
  - 細粒度 `copyin` 方式は性能上不採用

### 設計上の扱い

- Step 18を次段階の性能回復基準とする。
- Step 18より遅い変更は、原因調査用の一時実験を除き、原則として採用しない。
- PASSしても、Host-Device転送が増えてStep 18より遅い場合は性能設計として不合格とする。

## 設計目標

1. TDDFT time-step loop内の大規模Host-Device転送を最小化する。
2. `exnlp_only_make` が生成する `work2_`, `cfac_`, `ngnl_` を、可能な範囲でGPU上で生成する。
3. 生成したデータをhostへ戻さず `exnlp_gemm_present_inputs` へ渡す。
4. `ylm`, `vpj`, `extau` のOpenACC ownershipを安定化する。
5. Step 18の性能を回復した後に性能改善を確認する。
6. CPU/FFTW fallback経路を維持する。
7. `ia` 更新順序は、数学的等価性が確認されるまで変更しない。

## 現在の呼び出し経路

### 確定事項

TDDFTの時間発展中、非局所項の主経路は以下である。

```text
TDDFT time-step loop
  -> S2_                      tmevl10_Avec_v4.f:1693
       -> exnlp_only_make_acc tmevl10_Avec_v4.f:2459
            generates one column of work2_ and one cfac_ element
       -> exnlp_gemm_present_inputs tmevl10_Avec_v4.f:2521
            -> exnlp_gemm_body_fused tmevl10_Avec_v4.f:2534
                 consumes work2_, cfac_, ngnl_ and updates P/coef
```

CPU/fallback側の基本経路は以下である。

```text
S2_
  -> exnlp_only_make          tmevl10_Avec_v4.f:2434
  -> exnlp_gemm               tmevl10_Avec_v4.f:2491
       -> exnlp_gemm_body     tmevl10_Avec_v4.f:2578
```

### 現在のGPU側データフロー

`S2_` 内で `loopcnt` を求め、初回のみ `work2_`, `cfac_`, `ngnl_` をallocateする。

```text
S2_
  loopcnt計算
  allocate work2_(NGcont, loopcnt)
  allocate cfac_(loopcnt)
  allocate ngnl_(loopcnt)
  enter data create(work2_)
  host loop over ity/it/il/ip/l
      exnlp_only_make_acc(...)
      ngnl_(loopcnt) = ngnl(ity)   ! 現状はhost更新
  enter data copyin(cfac_, ngnl_)
  exnlp_gemm_present_inputs(...)
  exit data delete(work2_, cfac_, ngnl_)
```

同様の非局所項処理が `S2_` 内で前半・後半に存在する。`exnlp_gemm_body_fused` は `ia=1..loopcnt` の順序で `coef` を更新する。

## 配列Inventory

型サイズは `REAL*8=8 bytes`, `COMPLEX*16=16 bytes`, default integerは実装依存だが通常4 bytesとして扱う。正確な実測サイズはNsight SystemsまたはOpenACC present tableで確認する。

| 配列 | 宣言場所 | 型 / shape | 主な更新場所 | 主なconsumer | 寿命 | Authority分類 |
| --- | --- | --- | --- | --- | --- | --- |
| `P` | `S2_`, `tmevl10_Avec_v4.f:1707` | `COMPLEX*16 P(NG2Q,mxbnd)` | `S2_`, `exnlp_gemm_body_fused` | FFT/local/nonlocal全体 | TDDFT状態 | mirroredからdevice authoritativeへ移行候補 |
| `HP` | `S2_`, `tmevl10_Avec_v4.f:1707` | `COMPLEX*16 HP(NG2Q)` | 力/期待値側 | 出力・力評価 | 呼び出し範囲 | host authoritative |
| `YLM` | `S2_`, `tmevl10_Avec_v4.f:1713` | `REAL*8 YLM(NGcont,16)` | 入力準備側 | `exnlp_only_make_acc` | 計算中ほぼread-only | mirroredまたはdevice resident read-only |
| `G2` | `S2_`, `tmevl10_Avec_v4.f:1731` | `G2(4,NG2Q)` | 入力準備側 | phase/kinetic/FFT関連 | 計算中read-only | host authoritative, 必要部のみcopyin |
| `J2G` | `S2_`, `tmevl10_Avec_v4.f:1731` | `J2G(NG2Q)` | 入力準備側 | scatter/gather | 計算中read-only | device resident read-only候補 |
| `RHO1`, `RHO2` | `S2_`, `tmevl10_Avec_v4.f:1714` | `COMPLEX*16 RHO1(NXYZ), RHO2(NXYZ)` | FFT/local項 | local potential | routine内一時 | device temporary候補 |
| `RHO1_`, `RHO2_` | `S2_`, `tmevl10_Avec_v4.f:1744` | `COMPLEX*16 RHO1_(NXYZ,mxbnd), RHO2_(NXYZ,mxbnd)` | `S2_` local項 | FFT/local項 | `S2_`内一時 | device temporary |
| `VG` | `S2_`, `tmevl10_Avec_v4.f:1719` | `COMPLEX*16 VG(NXYZ)` | FFT/local項 | local potential | routine内一時 | device temporary |
| `VGG` | `S2_`, `tmevl10_Avec_v4.f:1720` | `VGG(NXYZ)` | 入力準備側 | local potential | read-only | device resident read-only候補 |
| `Vloc` | `S2_`, `tmevl10_Avec_v4.f:1739` | `Vloc(NXYZ)` | 入力準備側 | local potential | read-only | device resident read-only候補 |
| `VPJ` | `S2_`, `tmevl10_Avec_v4.f:1736` | `VPJ(NGcont,3,4,NTYQ)` | 入力準備側 | `exnlp_only_make_acc` | 計算中read-only | mirroredまたはdevice resident read-only |
| `VPP` | `S2_`, `tmevl10_Avec_v4.f:1736` | `VPP(3,4,NTYQ)` | 入力準備側 | `exnlp_only_make_acc` | 小規模metadata | host authoritative, scalar copy可 |
| `VPP2` | `S2_`, `tmevl10_Avec_v4.f:1736` | `VPP2(16,3,NTYQ)` | 入力準備側 | `exnlp_only_make_acc` | 小規模metadata | host authoritative, scalar copy可 |
| `EXTAU` | `S2_`, `tmevl10_Avec_v4.f:1719` | `COMPLEX*16 EXTAU(NGcont,5,NTAUQ)` | 入力準備側 | `exnlp_only_make_acc` | 計算中read-only | mirroredまたはdevice resident read-only |
| `NP` | `S2_`, `tmevl10_Avec_v4.f:1702` | scalar argument | host loop | section選択 | scalar | host authoritative |
| `NGNL` | `S2_`, `tmevl10_Avec_v4.f:1740` | `NGNL(NTYQ)` | 入力準備側 | host loop, `ngnl_`生成 | 小規模metadata | host authoritative |
| `work2_` | `S2_`, `tmevl10_Avec_v4.f:1745` | allocatable save `COMPLEX*16 work2_(:,:)` | `exnlp_only_make_acc` | `exnlp_gemm_present_inputs` | `S2_` nonlocal block | device authoritative候補 |
| `cfac_` | `S2_`, `tmevl10_Avec_v4.f:1746` | allocatable save `COMPLEX*16 cfac_(:)` | `exnlp_only_make_acc` | `exnlp_gemm_present_inputs` | `S2_` nonlocal block | mirroredからdevice authoritative候補 |
| `ngnl_` | `S2_`, `tmevl10_Avec_v4.f:1747` | allocatable save `integer ngnl_(:)` | 現状host loop | `exnlp_gemm_body_fused` loop bound | `S2_` nonlocal block | small metadata, mirrored候補 |
| `plancfp`, `plancbp` | `S2_`, `tmevl10_Avec_v4.f:1730` | `integer*8` FFT plan | FFT初期化 | cuFFT/FFTW wrapper | 実行期間 | backend依存 |
| `ct1` | `exnlp_gemm`, `tmevl10_Avec_v4.f:2494` | `COMPLEX*16 ct1(mxbnd)` | fallback body | fallback body | fallback一時 | device temporary in fallback |

## `ylm`, `vpj`, `extau` の親配列とdummy argument section対応

### 現在の対応

| 親配列 | 親配列宣言 | CPU版dummy | ACC版dummy | 備考 |
| --- | --- | --- | --- | --- |
| `YLM` | `YLM(NGcont,16)`, `tmevl10_Avec_v4.f:1713` | `ylm(NGcont,16)`, `tmevl10_Avec_v4.f:2438` | `ylm(NGcont,16)`, `tmevl10_Avec_v4.f:2465` | `lylm`列を参照 |
| `VPJ` | `VPJ(NGcont,3,4,NTYQ)`, `tmevl10_Avec_v4.f:1736` | `vpj(NGcont)`, `tmevl10_Avec_v4.f:2438` | `vpj(NGcont,3,4,NTYQ)`, `tmevl10_Avec_v4.f:2464` | CPU版はsection渡し想定、ACC版は親配列+index |
| `EXTAU` | `EXTAU(NGcont,5,NTAUQ)`, `tmevl10_Avec_v4.f:1719` | `extau(NGcont)`, `tmevl10_Avec_v4.f:2439` | `extau(NGcont,5,NTAUQ)`, `tmevl10_Avec_v4.f:2466` | CPU版はsection渡し想定、ACC版は親配列+index |

### 推奨

OpenACC側は親配列 + index渡しを維持する。

理由:

- OpenACC present tableはhost pointerとsection範囲で管理されるため、親配列とsectionが混在するとpartial presentを起こしやすい。
- `vpj(1:NGcont,ip,il,ity)` や `extau(1:NGcont,np,itseq)` のようなsectionをcallee側で `copyin` すると、親配列がpresentな場合にも別entryやpartial presentが発生し得る。
- 親配列 + scalar indexで統一すれば、ownershipは `S2_` またはその外側で一元管理できる。

## Present-table mismatchの原因候補

### 確定事項

過去の実験で以下の類型のOpenACC runtime errorが出ている。

- `partially present`
- `data in PRESENT clause was not found`
- `copyin` または `present` 対象のsectionサイズ不一致

### 原因候補

1. 親配列とdummy sectionの混在
   - 例: 親配列 `EXTAU(NGcont,5,NTAUQ)` をpresentにした後、calleeで `extau(1:NGcont,np,itseq)` を別sectionとして `copyin`/`present` する。
2. section境界の不一致
   - `NGcont`, `NG2Q`, `nbndloc`, `loopcnt` のどれかがcaller/calleeで異なる範囲として扱われる。
3. data region寿命の不一致
   - `S2_` 内の `exit data delete` 後に、calleeまたは次のkernelが同じhost pointerをpresentとして参照する。
4. `copyin` と `present` の混在
   - 既に親配列がdeviceに存在する状態で、子sectionを `copyin` するとpartial presentの温床になる。
5. Fortran array sectionの一時配列化
   - 非連続sectionを渡すとコンパイラが一時配列を作る可能性がある。host pointerが親配列と一致せず、present table管理が複雑になる。
6. fallback pathとの混在
   - `exnlp_gemm` はfallback用に内部で `enter data copyin` を行う。resident pathでは `exnlp_gemm_present_inputs` を使い、同じ配列に二重ownershipを作らない必要がある。

## Array section渡しと親配列+index渡しの比較

| 方式 | 利点 | 欠点 | 採用判断 |
| --- | --- | --- | --- |
| array section渡し | CPU版に近く、routine内部の添字が単純 | OpenACC present tableでpartial presentを起こしやすい。非連続sectionでは一時配列化の可能性がある。sectionごとのcopyinが発生しやすい | GPU resident pathでは不採用 |
| 親配列 + index渡し | ownershipを親配列単位で一元管理できる。present clauseが安定しやすい。大規模copyinを外側へ移せる | routine interfaceが長くなる。添字ミスのリスクがある | GPU resident pathの推奨 |

## Authority分類と転送方針

### Host authoritative

hostが正とするデータ。GPU側へ必要に応じてcopyinする。

- `NGNL(NTYQ)`
- `VPP(3,4,NTYQ)`
- `VPP2(16,3,NTYQ)`
- `TAU(3,NTAUQ)`
- scalar metadata: `NP`, `ity`, `itseq`, `ip`, `il`, `l`, `ngnl`, `loopcnt`

小規模metadataは、転送量よりも同期回数が問題になる。まとめてcopyinし、inner loopで細粒度転送しない。

### Device authoritative

GPU上の値を正とし、hostへ戻さずconsumerへ渡す。

- `work2_(NGcont,loopcnt)` のGPU生成後
- 将来的な `cfac_(loopcnt)` のGPU生成後
- 将来的な `ngnl_(loopcnt)` のGPU生成後
- `P(NG2Q,mxbnd)` はtime-step loop内でdevice authoritativeへ移行する候補

### Mirrored

hostとdeviceの両方に必要なデータ。更新点を明確化する。

- `YLM(NGcont,16)`
- `VPJ(NGcont,3,4,NTYQ)`
- `EXTAU(NGcont,5,NTAUQ)`
- `J2G(NG2Q)`
- `VGG(NXYZ)`, `Vloc(NXYZ)`

read-onlyとして扱える区間ではdevice resident read-onlyに寄せる。host更新が入る場合は、その直後だけ `update device` する。

## `exnlp_only_make_acc` 内部でcopyinしない設計

### 現状

`exnlp_only_make_acc` は `tmevl10_Avec_v4.f:2480-2483` 付近で以下の性質を持つ。

```fortran
!$acc parallel loop present(work1(1:NGcont))
!$acc& copyin(ylm(1:NGcont,lylm))
!$acc& copyin(extau(1:NGcont,np,itseq))
!$acc& copyin(vpj(1:NGcont,ip,il,ity))
```

この細粒度 `copyin` はStep 20の大幅な性能悪化と整合するため、次段階では不採用とする。

### 推奨設計

`exnlp_only_make_acc` 内部では `copyin` しない。

```fortran
!$acc parallel loop present(work1(1:NGcont))
!$acc& present(ylm(1:NGcont,1:16))
!$acc& present(extau(1:NGcont,1:5,1:NTAUQ))
!$acc& present(vpj(1:NGcont,1:3,1:4,1:NTYQ))
```

ただし、上記の正確なdirective構文はNVHPCでコンパイル確認する。固定形式Fortranの継続行制約も考慮する。

### 所有者

`ylm`, `vpj`, `extau` のcopyin/updateは `S2_` またはその外側のowner regionで行う。calleeはpresent前提にする。

## Data region粒度比較

| 粒度 | 内容 | 利点 | 欠点 | 推奨度 |
| --- | --- | --- | --- | --- |
| S2単位 | `S2_` の入口/出口で主要配列をresident化 | 既存構造に近い。rollbackしやすい。present範囲を追いやすい | `S2_` 呼び出しごとにcopyin/deleteが残る | 次ステップの第一候補 |
| TMEVL単位 | `tmevl10`相当の上位routineでresident化 | `S2_` 複数回の転送を削減できる可能性 | 上位routineの全呼び出し経路確認が必要。CPU fallbackとの分岐が複雑化 | S2単位で安定後 |
| time-step loop単位 | TDDFT time-step loop全体でresident化 | 目標1に最も合う。大規模転送最小化の本命 | host出力、restart、force、fallbackとの同期点を全て整理する必要がある | 最終目標 |

推奨順序は、S2単位でownership確立、TMEVL単位へ拡張、最後にtime-step loop単位へ拡張する。

## `work2_`, `cfac_`, `ngnl_` をGPU生成した場合のconsumer設計

### 現在

- `work2_`: `exnlp_only_make_acc` がdevice側で生成する。
- `cfac_`: `exnlp_only_make_acc` 内でscalar `cfac` として計算されるが、host配列 `cfac_` との同期設計が重要。
- `ngnl_`: 現状はhost loopで `ngnl_(loopcnt)=ngnl(ity)` と更新され、後でcopyinされる。
- consumerは `exnlp_gemm_present_inputs` -> `exnlp_gemm_body_fused`。

### 推奨

1. `work2_` はdevice authoritativeにする。
2. `cfac_` はまずhost生成+一括copyinを維持し、性能が安定した後にdevice生成へ移す。
3. `ngnl_` は小規模metadataなので、当面host生成+一括copyinでよい。
4. `exnlp_gemm_present_inputs` は `work2_`, `cfac_`, `ngnl_`, `coef/P` がすべてpresentであることを前提にする。
5. `exnlp_gemm_body_fused` の `ia=1..loopcnt` 順序は変えない。

## `ngnl_` をhost側 `ia` loopが読む場合の同期方法

### 現状

`exnlp_gemm_body_fused` の `do ia=1,loopcnt` はhost側の外側loopだが、`ngnl(ia)` はdevice kernel内のloop boundとして参照される。

### 方針

- `ngnl_` をhostで生成する間は、consumer前に一括 `enter data copyin(ngnl_(1:loopcnt))` する。
- `ngnl_` をGPUで生成する場合は、host側が `ngnl_(ia)` を分岐やloop長決定に使わない形に限定する。
- どうしてもhost側で読む必要がある場合は、生成後に `!$acc update self(ngnl_(1:loopcnt))` を1回だけ行う。
- `ia` 順序は数学的等価性が確認されるまで維持する。

## 大規模配列と小規模metadataの転送方針

### 大規模配列

対象:

- `P`
- `YLM`
- `VPJ`
- `EXTAU`
- `work2_`
- `RHO1_`, `RHO2_`
- `VG`
- `J2G`, `VGG`, `Vloc`

方針:

- time-step loop内の繰り返しcopyin/copyoutを避ける。
- owner regionでまとめて `enter data copyin/create` する。
- calleeでは `present` のみ使う。
- device authoritativeな配列はhostへ戻さない。

### 小規模metadata

対象:

- `VPP`, `VPP2`
- `TAU`
- `NGNL`
- `NUMTY`, `NIDN`, `MXOFL`
- scalar index群

方針:

- 細粒度copyinを避け、S2またはTMEVL単位でまとめる。
- scalarはOpenACC kernel argumentとして渡してよい。
- 小さいからといってinner loopで何度もcopyinしない。

## OpenACC directive案

### S2単位ownership確立案

`S2_` (`tmevl10_Avec_v4.f:1693`) の非局所項前にread-only親配列をdeviceへ配置する。

```fortran
!$acc enter data copyin(YLM(1:NGcont,1:16))
!$acc enter data copyin(VPJ(1:NGcont,1:3,1:4,1:NTYQ))
!$acc enter data copyin(EXTAU(1:NGcont,1:5,1:NTAUQ))
```

ただし、すでに上位でresident化している場合は二重copyinしない。NVHPCの `present_or_copyin` を使うか、compile-time branchでownerを一箇所に限定する。

### `exnlp_only_make_acc` present-only案

```fortran
!$acc parallel loop present(work1(1:NGcont))
!$acc& present(YLM(1:NGcont,1:16))
!$acc& present(EXTAU(1:NGcont,1:5,1:NTAUQ))
!$acc& present(VPJ(1:NGcont,1:3,1:4,1:NTYQ))
```

`copyin(ylm(...))`, `copyin(extau(...))`, `copyin(vpj(...))` は削除する。

### consumer側

```fortran
!$acc parallel loop gang present(coef(1:ng2q,1:nbndloc))
!$acc& present(work1(1:NGcont,1:loopcnt))
!$acc& present(cfac(1:loopcnt), ngnl(1:loopcnt))
```

`work1`, `cfac`, `ngnl` はcaller側でpresentにする。

## Routine interface変更案

### 推奨案

GPU resident pathでは親配列 + index渡しを維持する。

```text
exnlp_only_make_acc(...,
  vpj(NGcont,3,4,NTYQ),
  ylm(NGcont,16),
  extau(NGcont,5,NTAUQ),
  np, itseq, ip, il, ity,
  work1(NGcont), cfac, ...)
```

利点:

- present tableの親配列ownershipと整合しやすい。
- section temporaryを避けやすい。
- CPU版 `exnlp_only_make` を維持できる。

欠点:

- interfaceが長い。
- 添字指定ミスが数値差に直結する。

### 代替案: section渡しに戻す

欠点が大きいため非推奨。

- `vpj(1:NGcont,ip,il,ity)` のようなsection渡しは、present mismatchの再発リスクが高い。
- 非連続sectionではcompiler temporaryが入る可能性がある。

### 代替案: wrapper routineを追加する

`exnlp_only_make_acc_owner` のようなwrapperを追加し、内部で親配列 + indexを扱う。

利点:

- 既存routineを直接大きく変更しない。

欠点:

- call階層が増える。
- OpenACC routine boundaryでpresent指定が複雑になる。

## Compile-time fallback案

### 確定事項

`mk_ifort.sh` は現在、FFTW/cuFFTのbackend切替を担う。次段階でも以下を維持する。

- CPU/FFTW: `FFT_BACKEND=fftw`
- GPU/cuFFT: `FFT_BACKEND=cufft`

### 推奨

OpenACC residency実験はcompile-timeに明示的に切り替える。

候補:

```text
OPENACC_RESIDENCY=0  従来互換
OPENACC_RESIDENCY=1  S2単位resident
OPENACC_RESIDENCY=2  TMEVL単位resident
```

Fortran側は固定形式のため、cppを使う場合はNVHPCの前処理オプションを明示する。preprocessを避けるなら、環境変数でsource selectionする。

## Timer追加案

### 目的

Step 18回復後、どの転送・kernelが支配的かを安定して追跡する。

### 追加候補

既存 `prof_start/prof_stop` と同じ箇所、または同一粒度で `mod_timer` を埋め込む。

候補label:

- `owner_ylm_vpj_extau_enter`
- `owner_ylm_vpj_extau_exit`
- `exnlp_make_present_only`
- `exnlp_make_cfac_ngnl_host`
- `exnlp_make_cfac_ngnl_device`
- `exnlp_gemm_present_inputs`
- `exnlp_gemm_body_fused`
- `s2_owner_region_total`

方針:

- 既存profileと対応付ける。
- 各rank出力でよいが、1 MPI rank前提なのでrank 0だけでも解析可能。
- Timer追加だけのstepを設け、性能に影響がないことを確認する。

## Nsight Systems確認項目

次段階では、PASS/compareだけでなくNsight Systemsで以下を確認する。

- time-step loop中のHtoD/DtoH転送回数
- `ylm`, `vpj`, `extau` 相当の大規模HtoDがinner loopで発生していないこと
- `work2_` 生成kernelと `exnlp_gemm_body_fused` kernelの間に不要なDtoHがないこと
- cuFFT呼び出しの回数と時間
- OpenACC kernelsの粒度
- `s2_nonlocal_make` がStep 20のように増加していないこと
- GPU idle時間
- kernel launch数
- `cudaMemcpy` / `cuMemcpy` のサイズ別一覧

## 数値検証方法

各stepで以下を実施する。

```bash
python3 ./tools/check_tddft_result.py check <archive-or-output>
python3 ./tools/check_tddft_result.py compare <archive-or-output>
```

基準:

- `check`: PASS必須
- relaxed compare: PASS必須
- 比較対象: `docs/runtime_logs/gnu_si111_h_tddft_100steps.out`
- archive label: 単調増加させる

例:

```text
nvhpc_cufft_1rank_02_STEP21_01
nvhpc_cufft_1rank_02_STEP22_01
```

失敗時に比較する値:

- `ETOT`
- `Eelec+Enucl-Eext-Ework`
- final force
- final positions
- final velocities
- profile timers

## 性能採用基準

### 必須

- `check`: PASS
- relaxed compare: PASS
- wall_secがStep 18の約163.31秒以下、または同等範囲
- `s2_nonlocal_make` がStep 20のように異常増加しない
- 細粒度copyinがNsight Systems上で残っていない

### 暫定許容

計測・ownership確立だけのstepでは一時的な微小悪化を許容する。ただし、その変更を最終採用するにはStep 18性能へ戻す必要がある。

### 不採用

- Step 18より明確に遅い
- `s2_nonlocal_make` が顕著に増える
- present-table errorが再発する
- `ia` 更新順序を変えて数値差の原因が説明できない
- CPU/FFTW fallbackが壊れる

## Rollback条件

以下のいずれかに該当したら、そのstepはrollbackする。

- OpenACC runtime error:
  - `partially present`
  - `data in PRESENT clause was not found`
  - invalid device pointer
- relaxed compare FAIL
- `s2_nonlocal_make` がStep 18比で大幅増加
- wall_secがStep 18から明確に悪化し、原因が転送削減の準備として説明できない
- CPU/FFTW fallbackのコンパイルまたは実行が失敗
- `ia` 順序変更による数値差が出た

## 実装Step案

1 Step = 1仮説とする。成功結果は単調増加のarchive labelで保存する。

### Step 21: 計測・ownership確認のみ

仮説:

- 既存Step 18相当の経路で、`ylm`, `vpj`, `extau`, `work2_`, `cfac_`, `ngnl_` のpresent状態を観測できる。

内容:

- 可能ならTimerまたはdebug出力のみ追加。
- 計算順序・data movementは変更しない。

採用条件:

- check PASS
- relaxed compare PASS
- wall_secがStep 18と同等

### Step 22: `ylm`, `vpj`, `extau` のS2単位ownership確立

仮説:

- 親配列単位で `ylm`, `vpj`, `extau` をS2内resident化すれば、section単位copyinを排除できる。

内容:

- ownerを `S2_` に限定する。
- `exnlp_only_make_acc` 接続はまだ最小限にし、present mismatchが起きないことを確認する。

採用条件:

- present-table errorなし
- Step 18より遅くない

### Step 23: `exnlp_only_make_acc` をpresent-onlyへ接続

仮説:

- `exnlp_only_make_acc` 内部の細粒度copyinを削除し、owner regionのpresent配列を使えばStep 20の悪化を避けられる。

内容:

- `copyin(ylm(...))`, `copyin(extau(...))`, `copyin(vpj(...))` を使わない。
- 親配列 + index渡しを維持。

採用条件:

- check PASS
- relaxed compare PASS
- `s2_nonlocal_make` がStep 18と同等以下

### Step 24: `cfac_`, `ngnl_` の一括転送整理

仮説:

- 小規模metadataはhost生成+一括copyinのままで十分速く、inner loop copyinを避ければよい。

内容:

- `cfac_`, `ngnl_` のcopyinをconsumer直前の1回に限定する。
- `ngnl_` をhost側で読む設計を維持する。

採用条件:

- `s2_nonlocal_make` と `exnlp_gemm` が悪化しない

### Step 25: `work2_` device authoritative化の明文化

仮説:

- `work2_` は生成後hostへ戻す必要がない。

内容:

- `work2_` は `create` + present consumerに統一。
- debug用のhost参照が必要なら明示的な一時 `update self` のみにする。

採用条件:

- Nsight Systemsで `work2_` の不要DtoHがない

### Step 26以降: TMEVL単位、time-step loop単位へ拡張

仮説:

- S2単位で安定したownershipを上位へ広げることで、time-step loop内の大規模転送をさらに減らせる。

内容:

- TMEVL単位resident化
- time-step loop単位resident化
- `P` のdevice authoritative化

採用条件:

- Step 18より速い
- fallback維持
- 出力・restart・force評価の同期点が明確

## 代替案と欠点

### 代替案A: `exnlp_only_make_acc` 内で必要sectionだけ `copyin`

欠点:

- Step 20の性能悪化と整合する。
- inner loopで大量のHtoD転送が発生する。
- present-table mismatchの再発リスクが高い。

判断:

- 不採用。

### 代替案B: `work2_`, `cfac_`, `ngnl_` を全てhost生成してから一括copyin

欠点:

- `work2_` は大規模であり、time-step loop内の大規模HtoD転送が残る。
- 設計目標1, 2, 3に反する。

判断:

- CPU fallbackとしては維持可。GPU resident pathでは不採用。

### 代替案C: `ia` loopを並べ替えてGEMM化を強める

欠点:

- 数学的等価性が未確認。
- 浮動小数点の加算順序差だけでなく、物理量差につながる可能性がある。

判断:

- 現段階では不採用。等価性検証後に別branchで扱う。

### 代替案D: S2単位を飛ばしてtime-step loop単位resident化する

欠点:

- 変更範囲が大きい。
- fallback、restart、出力、force評価の同期点が一度に複雑化する。

判断:

- 最終目標としては正しいが、次段階の最初には採用しない。

## 確定事項

- 1 GPU / 1 MPI rankを前提にする。
- OpenACC + cuFFTを使う。
- CPU/FFTW fallbackは維持する。
- Step 18を性能baselineにする。
- Step 19/20の結果から、細粒度copyin方式は採用しない。
- `ia` 更新順序は変更しない。
- GPU pathでは親配列 + index渡しを優先する。
- `exnlp_only_make_acc` 内部のcopyinは次段階で削除対象にする。

## 仮説

- `ylm`, `vpj`, `extau` の親配列ownershipをS2単位で安定化すれば、present-table mismatchを避けながら細粒度copyinを削減できる。
- `work2_` をdevice authoritativeにすれば、consumer側の `exnlp_gemm_present_inputs` へhost転送なしで接続できる。
- `cfac_`, `ngnl_` は小規模metadataなので、最初はhost生成+一括copyinでもStep 18性能を回復できる。
- TMEVL単位またはtime-step loop単位へresident化を広げると、Step 18より速くできる可能性がある。

## 未確認事項

- `YLM`, `VPJ`, `EXTAU` がtime-step中にhost更新される正確な箇所。
- `P` をdevice authoritativeにした場合の全host参照点。
- `cfac_` をGPU生成した場合の最小同期設計。
- `ngnl_` をGPU生成してもhost `ia` loopの意味を保てるか。
- NVHPCで `present_or_copyin` を使うべきか、明示的なowner分岐にするべきか。
- Nsight Systems上のStep 18とStep 20の転送差分。
- CPU/FFTW fallbackで同じsourceを保つべきか、GPU専用sourceを分けるべきか。

## Git commit分割案

1. 設計書追加
   - `docs/tddft_gpu_next_stage_design.md`
2. 計測追加
   - `mod_timer` / `prof`対応の追加のみ
3. ownership確立
   - `ylm`, `vpj`, `extau` のowner region追加
4. `exnlp_only_make_acc` present-only化
   - 内部copyin削除
5. metadata転送整理
   - `cfac_`, `ngnl_` の一括転送・同期点整理
6. `work2_` device authoritative化
   - consumer接続整理
7. TMEVL/time-step loop resident化
   - 大規模転送削減の本命変更

各commitでcheckとrelaxed compare結果、archive label、wall_secをcommit messageまたはdocsに記録する。

## 実装開始前に人間が承認すべき事項

- Step 18を正式な性能baselineとして採用すること。
- 次の最初の実装stepを「計測またはS2単位ownership確立のみ」に限定すること。
- `exnlp_only_make_acc` 内部の細粒度copyinを削除する方針。
- GPU pathでは親配列 + index渡しを標準にすること。
- `cfac_`, `ngnl_` は初期段階ではhost生成+一括copyinを許容すること。
- `ia` 更新順序を変更しないこと。
- Step 18より遅い変更は、診断目的を除いて採用しないこと。
- CPU/FFTW fallbackを壊さないため、fallback確認を各大きな変更後に行うこと。
