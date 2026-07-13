# FPSEID21 TDDFT GPU常駐化 設計書 v5（日本語）

> [English version](tddft_gpu_next_stage_design_en.md)
>
> この文書は英語版v5と同じ設計判断を、日本語で読みやすく整理したものです。
> routine名、配列名、macro名、ログfield名、コマンドはソースや実行ログと照合できるよう英語表記を維持します。

## 0. 文書の位置づけと対象revision

- [CONFIRMED] branch: `tddft-openacc-residency`
- [CONFIRMED] source baseline commit: `d5d42d6d7bf60217991dbe7e725529e429774903`
- [CONFIRMED] source tree root: `/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21`
- [CONFIRMED] review date: 2026-07-11
- [CONFIRMED] design-history commit `6b36346` はv1-v4を保存し、対象sourceを変更していません。
- [DECISION] 本書が最終v5です。v6は作成せず、以後の訂正はv5のままGit commitで識別します。
- [DECISION] source行番号は上記source baseline commitに対する番号です。source commitが変わった場合は、Step A実装前に行番号と静的結論を再確認します。
- [DECISION] 本書だけではsource変更、build、run、measurementを許可しません。

## 1. 用語と判定ラベル

### 1.1 判定ラベル

| ラベル | 意味 |
|---|---|
| `CONFIRMED` | sourceまたは保存済み結果から確認済み |
| `CURRENT` | 現行sourceが実際に行っていること |
| `TARGET` | 最終的に到達する契約 |
| `DECISION` | 本設計で採用した方針 |
| `HYPOTHESIS` | 1 commitで検証する仮説 |
| `UNVERIFIED` | 実行環境が必要で未確認 |
| `BLOCKER` | 条件を満たすまで後続実装禁止 |

### 1.2 GPU常駐化で使う用語

- **Host / Device**: HostはCPU側メモリ、DeviceはGPU側メモリです。
- **mapping**: Host配列とDevice上の領域の対応付けです。OpenACCの`copyin`、`create`、`present`などが関係します。
- **ownership**: mappingを作成、同期、削除する責任をどのroutineが持つかを表します。
- **authority**: HostとDeviceのどちらの値が最新の正本かを表します。ownershipとは別概念です。
- **parent / section**: parentは配列全体、sectionは`A(:,k)`のような部分領域です。
- **present table**: OpenACC runtimeが保持するHostアドレスとDeviceアドレスの対応表です。
- **actual / dummy argument**: 呼び出し側で渡す実引数と、callee側で受ける仮引数です。
- **pack/unpack**: 非連続sectionなどを渡すため、compilerが一時配列へ詰め替え・戻しを行う処理です。
- **producer / consumer**: 配列を書き込む処理と、その結果を読む処理です。
- **fallback**: GPU常駐経路を使わないCPU/FFTWまたはhost-copy互換経路です。
- **gate**: 次段階へ進むための合格条件です。
- **rollback**: 失敗したcommitだけをrevertし、Step 18相当へ戻すことです。

## 2. 対象、baseline、対象外

- [CONFIRMED] 正式baselineはStep 18です。wall timeは約163.31秒、result checkはPASS、GNU relaxed compareもPASSです。
- [CONFIRMED] Step 19は約178秒で不採用です。
- [CONFIRMED] Step 20は約819秒で、`s2_nonlocal_make`が約680秒へ増加したため不採用です。
- [DECISION] routine内部または細粒度sectionごとの反復`copyin`は採用しません。
- [DECISION] 対象実行モデルは1 GPU / 1 MPI rank、NVHPC OpenACC + cuFFTです。
- [DECISION] GNU+FFTW、Intel+FFTW、NVHPC+FFTW、NVHPC+cuFFT host-copyのfallbackを維持します。
- [DECISION] 数学的等価性を別途確認するまで、`ia`順序と演算順序を変更しません。

Step Aは診断専用です。Step 18相当の計算経路を観測するだけで、ownershipを変更しません。

## 3. v4からv5で確定した内容

- Step Aの観測範囲を、target parent residencyを必要としない内容へ限定しました。
- `YLM1..5`、`VPJ1..5`、`EXTAU`をphase別に診断します。
- 診断実装をguard付きFortran moduleと小さなC wrapperへ固定しました。
- C/Fortranのaddress型を`intptr_t` / `c_intptr_t`へ統一しました。
- callerのparent診断とcalleeの代表section診断を分離しました。
- A6はforward/reverseの両nonlocal blockを診断します。
- default integerと`c_int`が非互換ならdiagnostic ON buildを明示的に失敗させます。
- status、sentinel値、出力先`error_unit`を固定しました。
- fixed-form Fortranのpreprocess flagをTDDFT全体のcompiler invocationへ適用します。
- `PRESENT_BORROWED`というroleとHost/Device authorityを分離しました。
- ownership追加とcallee内部copyin除去を配列familyごとの同一commitに統合しました。

## 4. Step Aの観測境界

### 4.1 観測するもの

- runtime shape、declared bounds、active extent
- Host base address、section先頭address、byte offset
- first-dimension全域sectionのcontiguity
- phaseごとに実際に使われる`YLMk` / `VPJk`
- 現時点の`acc_is_present`結果
- 別のNsight Systems runでのH2D/D2H、allocation/free、kernel数、peak GPU memory
- 別の通常runでの数値結果とwall time

### 4.2 Step Aだけでは証明しないもの

- 将来のcaller-owned parent mappingが正しいこと
- ownership導入後にparent/section lookupが成功すること
- target calleeの`present`契約
- 将来partial-present errorが起きないこと

[CURRENT] 現行sourceでは`YLM1..5`、`VPJ1..5`、`EXTAU`にcaller-owned parent residencyがありません。そのためA3-A5で`parent_present=false`となるY0は正常です。ownership導入後のlookupはB1-B3で判定します。

## 5. 現在のcall pathと5 phase対応

```text
TMEVL
  Host側phase dataを保持
  enter data copyin P
  phase 1 S2_(YLM1, VPJ1, EXTAU, NP=1)
  phase 2 S2_(YLM2, VPJ2, EXTAU, NP=2)
  phase 3 S2_(YLM3, VPJ3, EXTAU, NP=3)
  phase 4 S2_(YLM4, VPJ4, EXTAU, NP=4)
  phase 5 S2_(YLM5, VPJ5, EXTAU, NP=5)
  exit data copyout P

S2_
  work2_ device mappingをcreate
  exnlp_only_make_accを反復
    CURRENT: YLMk / VPJk / EXTAU sectionを毎回copyin
    Device: work2_ columnを生成
    Host: cfac_ と ngnl_ を生成
  cfac_ と ngnl_ をbulk copyin
  exnlp_gemm_present_inputs
  work2_ / cfac_ / ngnl_ mappingをdelete
```

`YLM1..5`はsource 63-64行、`VPJ1..5`は108-111行です。S2_のdummyは`YLM(NGcont,16)`（1713行）、`VPJ(NGcont,3,4,NTYQ)`（1736行）、`EXTAU(NGcont,5,NTAUQ)`（1719行）です。

| phase (`NP`) | TMEVL call | YLM actual | VPJ actual | EXTAU actual |
|---:|---:|---|---|---|
| 1 | 549-562 | `YLM1` | `VPJ1` | `EXTAU(1,1,1)` |
| 2 | 587-600 | `YLM2` | `VPJ2` | `EXTAU(1,1,1)` |
| 3 | 614-627 | `YLM3` | `VPJ3` | `EXTAU(1,1,1)` |
| 4 | 641-654 | `YLM4` | `VPJ4` | `EXTAU(1,1,1)` |
| 5 | 668-681 | `YLM5` | `VPJ5` | `EXTAU(1,1,1)` |

- `NP`をphase IDとして再利用し、新しいroutine argumentは追加しません。
- `YLMk(:,lylm)`、`VPJk(:,ip,il,ity)`、`EXTAU(:,np,itseq)`はfirst dimension全域を含むためFortran上contiguousです。
- caller-parent recordはS2_呼び出し前に出し、callee内部indexを含めません。
- callee-section recordは各phase最初の`exnlp_only_make_acc`直前で代表1 sectionだけを出します。
- parentとsectionは各phase・各rankで最大1回だけ出力します。

期待offsetは次式です。

- `YLMk(1,lylm)`: `(lylm-1)*NGcont*8`
- `VPJk(1,ip,il,ity)`: `((ip-1)+3*((il-1)+4*(ity-1)))*NGcont*8`
- `EXTAU(1,np,itseq)`: `((np-1)+5*(itseq-1))*NGcont*16`

計算したoffsetとHost address差を両方出力します。

## 6. Current / Target / Transition contract

### 6.1 TMEVL

**CURRENT**

- `P(NG2Q,MXBND)` dummyは54行です。
- 532行で`P(1:NG2Q,1:nbndloc)`をmapし、714行でcopyout/deleteします。
- Section 5の5 phaseでS2_を呼びます。

**TARGET**

- TMEVLが`P`とB1-B3で選ばれたphase array familyのdevice lifetime ownerです。
- Host更新が監査済みの場合だけownerがbulk同期します。
- TMEVLが最後にPをHostへ同期してdeleteします。

**TRANSITION**

- Step Aではdata clauseを変更しません。
- B1-B3はfamilyごとにownership追加と対応するcallee copyin除去を同時に行います。

### 6.2 S2_

**CURRENT**

- P、YLM、VPJ、EXTAUを1693-1740行で受け取ります。
- `SAVE` host allocatableを1810-1814行で1回allocateします。
- nonlocal blockごとに1821/1921/1926-1927行および2121-2225行付近でdevice mappingを作成・転送・削除します。

**TARGET**

- S2_はPとphase parent arrayのborrowerです。
- Pをcopyout/deleteせず、ownerを変更しません。
- 初期producer設計ではwork2_/cfac_/ngnl_ mappingをS2_が所有します。

**TRANSITION**

- parent mappingを追加したまま対応section copyinを残すcommitは禁止です。
- 細粒度section転送を追加しません。

### 6.3 exnlp_only_make

- [CURRENT] 2434-2457行のCPU fallbackです。
- [TARGET] 数式と演算順序を変更せず残します。
- Step A/Bではinterfaceを変更しません。

### 6.4 exnlp_only_make_acc

**CURRENT**

- explicit-shape parent dummyは2464-2466行です。
- 2470-2472行でHost側に`cfac`を生成します。
- 2480-2486行のOpenACC loop内部でYLM、EXTAU、VPJ sectionをcopyinし、Device上の`work1`へ書きます。

**TARGET**

- callerがparent mappingを所有します。
- 変換済みfamilyはcalleeで`present`のみ要求します。
- caller-owned arrayについてcallee内のallocate/delete/update/copyin/copyoutを禁止します。

**TRANSITION**

- B1はYLM ownership追加とYLM copyin除去だけを同時に行います。
- B2はVPJ、B3はEXTAUについて同様に行います。
- 未変換familyは自分のatomic commitまではCURRENT copyinを維持できます。

### 6.5 exnlp GEMM family

- [CURRENT] `exnlp_gemm`（2491-2518行）はinput copyと`ct1`を自己管理するfallbackです。
- [CURRENT] `exnlp_gemm_present_inputs`（2521-2532行）はlocal data movementを行いません。
- [CURRENT] `exnlp_gemm_body_fused`は`coef(ng2q,mxbnd)`を受け、2543行のHost `ia` loop順を維持します。
- [TARGET] residency pathは`exnlp_gemm_present_inputs`を使い、allocate/transferを行いません。
- [TARGET] `coef`、`work1`、`cfac`、`ngnl`の正確な範囲が事前にpresentであることを要求します。

## 7. Pのownership roleとauthority

| scope | role |
|---|---|
| TMEVL | P device lifetimeの`OWNER` |
| S2_ | `BORROWER` |
| exnlp GEMM | `NESTED_BORROWER` |

`PRESENT_BORROWED`はroleでありauthority stateではありません。

```text
TMEVL mapping前
  HOST_ONLY

TMEVL 532行: enter data copyin
  MIRRORED_HOST_AUTH

最初のGPU write後
  MIRRORED_DEVICE_AUTH

S2_ return
  ownerはTMEVLのまま
  authorityもMIRRORED_DEVICE_AUTHのまま
  Host同期なし

TMEVL 714行: copyoutしてdelete
  HOST_ONLY
```

S2_は借りたDevice objectを更新できますが、ownership取得、copyout、deleteはできません。callee returnだけを理由にauthorityは変わりません。

## 8. P / coef / J2G decision tree

### 8.1 sourceから確認済みのshape

- TMEVL: `P(NG2Q,MXBND)`（54行）
- S2_: `P(NG2Q,mxbnd)`（1707行）
- GEMM: `coef(ng2q,mxbnd)`（2537行）
- parent mapping: `P(1:NG2Q,1:nbndloc)`（532、714行）
- hazard: local-potential directiveに`P(1:NXYZ,1:nbndloc)`（1942、1962、2091行）

`NXYZ < NG2Q`かつ`nbndloc > 1`の場合、各columnのleading dimensionは`NG2Q`なので、`P(1:NXYZ,1:nbndloc)`は単一の連続byte spanではありません。

1964-1968行と2093-2100行では、`IG=1:NXYZ`がPの第1次元を、`JG=J2G(IG)`が第1次元`NXYZ`のRHO配列をindexします。したがって次を別々に検証します。

- P access: `NXYZ <= NG2Q`
- J2G value: `1 <= J2G(IG) <= NXYZ`

### 8.2 A2の安全な確認順序

S2_ 1817行の後、nonlocal生成前に以下を1回行います。

1. `NG2Q,NXYZ,NG2,NGcont,mxbnd,nbndloc,nbegin,nend`を出力。
2. `NXYZ>0`と`NG2Q>0`を確認。
3. `j2g_extent=min(NXYZ,NG2Q)`を設定。
4. extentが正のときだけ`J2G(1:j2g_extent)`のmin/maxを評価し、値が`1:NXYZ`内か確認。
5. `0<=nbndloc<=mxbnd`を確認。
6. dimensionが有効な場合だけ、連続したphysical parent `NG2Q*nbndloc`をquery。
7. `NXYZ<=NG2Q`なら、最初と最後のbandについて`P(1:NXYZ,iib)`を個別query。複数columnをpacked rangeとしてqueryしない。

`exnlp_gemm_body_fused` 2543行直前では、1 rankあたり1回だけcoef bounds/address/presenceを記録します。A6では`ngnl_`生成完了後にだけ`ngnl_(1:loopcnt)`を評価します。

### 8.3 case別判断

| case | runtime関係 | 正しいparent mapping | 判断 |
|---|---|---|---|
| P1 | `NG2Q == NXYZ` | `P(1:NG2Q,1:nbndloc)`を1回 | boundsとpresentが安定しPASSならBへ進む |
| P2 | `NG2Q > NXYZ` | physical parent `NG2Q`を1回。追加section mapping禁止 | aggregate subsection clauseをparent present + kernel boundsへ修正する候補 |
| P3 | `NG2Q < NXYZ` | 現宣言ではP accessを収容できない | 即停止。宣言またはloop範囲を修正するまでBLOCKER |
| P4 | physical shapeはNG2Q、実際のIG範囲はNXYZより小さい | parentはNG2Qを1回 | 各kernelのactive rangeをsourceで証明してから進む |

[BLOCKER] A2/A6値が得られるまでP2/P4修正を許可しません。

## 9. YLM / VPJ / EXTAU decision tree

first-dimension全域sectionは静的にはcontiguousです。ただしcompiler temporaryやOpenACC lookupはruntime確認が必要です。Y4、Y3、Y2、Y1の順で最初に該当するcaseを採用します。Y0はownership導入前です。

| case | 観測 | 決定 |
|---|---|---|
| Y0 | current: parent absent、callee section copyinあり | Step Aでは正常。Step 18 pathを維持 |
| Y1 | B commit後にparent/section present、offset一致、temporaryなし | parent+index interfaceを維持しcalleeをpresent-only化 |
| Y2 | section lookup失敗、partial present、offset不一致 | B commitをrevert。parent rangeを修正。section mapping追加は禁止 |
| Y3 | compiler report/traceにpack/unpackまたはtemporary | revert。原因を特定し、別のcontiguous buffer/interfaceは別レビュー |
| Y4 | device lifetime中にHostがparentを更新 | ownerがHost生成後に監査済みbulk `update device`を1回実施 |

Step AはY0とHost layoutだけを分類します。Y1-Y4はB1-B3で判定します。

## 10. Current / Target array lifetime

### 10.1 parent/propagation array

| array | declaration/shape | CURRENT | TARGET | producer / consumer | gate |
|---|---|---|---|---|---|
| P | 54行 `NG2Q,MXBND` | TMEVL mapping前後でHost/Device authority遷移 | TMEVL owner、S2 borrower | exkin/S2 / S2/exnlp | P1-P4 |
| YLM1..5 | 63-64行 `NGcont,16` | Host authoritative | TMEVL device-lifetime owner、Device read-only | Host setup / exnlp_only_make_acc | Y0-Y4 |
| VPJ1..5 | 108-111行 `NGcont,3,4,NTYQ` | Host authoritative | TMEVL device-lifetime owner、Device read-only | Host setup / exnlp_only_make_acc | Y0-Y4 |
| EXTAU | 79行 `NGcont,5,NTAUQ` | Host authoritative | B3後TMEVL owner | Host setup / exnlp_only_make_acc | Y0-Y4 |
| RHO1_/RHO2_ | 1744行 `NXYZ,mxbnd` | S2 kernel storage | A-Cでは変更なし | S2 / S2 | 後続設計 |
| VG | 70/1719行 `NXYZ` | caller/S2で使用 | A-Cでは変更なし | Host potential setup / S2 | 後続設計 |

### 10.2 saved host allocationとdevice mapping

| array | Host lifetime | CURRENT device lifetime | 初期TARGET | owner / delete |
|---|---|---|---|---|
| work2_ | `SAVE`、1810/1813行で1回allocate | nonlocal blockごとにcreate/delete | `DEVICE_AUTH`、GPU生成・GPU消費、Host round tripなし | S2_ |
| cfac_ | `SAVE`、1811行で1回allocate | blockごとにbulk copyin/delete | `MIRRORED_HOST_AUTH`、`1:loopcnt`をblockごとに1回bulk copy | S2_ |
| ngnl_ | `SAVE`、1812行で1回allocate | blockごとにbulk copyin/delete | `MIRRORED_HOST_AUTH`、Host ia loop維持、small metadata bulk copy許容 | S2_ |

「S2-local」はdevice mapping lifetimeだけを指し、`SAVE` Host allocationの寿命とは異なります。

## 11. Step A OpenACC診断API

### 11.1 責任分担

- `mod_stepa_diag.F90`: bounds検証、byte数計算、出力回数flag、format、`error_unit`への出力を担当。
- `fpseid_stepa_acc_diag.c`: `acc_is_present`、成功後の`acc_deviceptr`、pointerから`intptr_t`への変換だけを担当。
- C wrapperは出力、allocation、同期、state管理を行いません。
- production arrayへ不要な`TARGET`属性を追加しません。

### 11.2 C interface

```c
int fpseid_acc_query_c16(const void *host, size_t nbytes,
                         intptr_t *host_addr, intptr_t *device_addr);
int fpseid_acc_query_r8(const void *host, size_t nbytes,
                        intptr_t *host_addr, intptr_t *device_addr);
int fpseid_acc_query_i4(const void *host, size_t nbytes,
                        intptr_t *host_addr, intptr_t *device_addr);
```

処理順序は固定です。

1. `host_addr=(intptr_t)host`
2. `host==NULL`または`nbytes==0`なら`device_addr=0`、return 0
3. `acc_is_present(host,nbytes)`
4. presentが非0の場合だけ`acc_deviceptr(host)`
5. absentなら`device_addr=0`
6. presentなら1、absentなら0を返す

### 11.3 Fortran bind(C)

```fortran
integer(c_int) function fpseid_acc_query_c16(base,nbytes,haddr,daddr) &
  bind(C,name="fpseid_acc_query_c16")
  import c_int, c_size_t, c_intptr_t, c_double_complex
  complex(c_double_complex), intent(in) :: base(*)
  integer(c_size_t), value :: nbytes
  integer(c_intptr_t), intent(out) :: haddr, daddr
end function
```

real*8版は`real(c_double) :: base(*)`、integer版は`integer(c_int) :: base(*)`です。

- byte数は`integer(c_size_t)`、addressはCで`intptr_t`、Fortranで`integer(c_intptr_t)`です。
- addressはhexadecimal `Z0`で出力します。
- element byte sizeは`c_sizeof(first_element)`で求めます。
- statusは`OK`、`ABSENT`、`SKIPPED_INVALID_BOUNDS`の3種類です。
- `ABSENT`: `present=0`, Host addressは実値、Device addressは0。
- `SKIPPED_INVALID_BOUNDS`: `present=-1`, addressとskipped min/maxは0、`*_valid=F`を正とします。
- OpenACC queryはdata movement、allocation、`acc_wait`を行いません。
- 出力はrank 0の`error_unit`だけです。
- default integerが`integer(c_int)`と互換でない場合、diagnostic ON buildを`ERROR: FPSEID Step A requires default integer == c_int`で失敗させます。

## 12. Preprocessorとbuild仕様

macro名は`FPSEID_STEP_A_DIAGNOSTIC`です。すべてのdiagnostic `use`、call、state、outputをcolumn 1の`#ifdef`で囲みます。macro未定義時はsourceから完全に除去され、runtime call、branch、出力、同期、性能差を残しません。

| compiler | preprocess flag | diagnostic ON |
|---|---|---|
| NVHPC | `-Mpreprocess` | 可 |
| GNU | `-cpp` | 不可、macro未定義 |
| Intel classic | `-fpp` | 不可、macro未定義 |

- `mk_ifort.sh`のTDDFT Fortran一括compile invocation全体へflagを1回適用します。CG/SDは変更しません。
- shell変数が`FPSEID_STEP_A_DIAGNOSTIC=1`かつNVHPCの場合だけ、`-D...`、module、C objectを追加します。
- 0または未設定では`-D...=0`を出さず、macroを未定義にします。
- GNU/IntelでON指定した場合は明示errorで停止します。
- ONではNVHPC `-acc`が必要です。
- default integer kind probeはproduction executableを置換する前にcompile-onlyで実行し、objectはlinkせず削除します。

Repository rootからのdiagnostic ON build:

```sh
ENABLE_GPU_FFT=1 \
FPSEID_STEP_A_DIAGNOSTIC=1 \
BUILD_REPORT=1 \
TDDFT_FFLAGS="-O2 -mp -Msave -Mlarge_arrays -acc" \
./tools/build_nvhpc.sh
```

通常timing用OFF build:

```sh
ENABLE_GPU_FFT=1 \
FPSEID_STEP_A_DIAGNOSTIC=0 \
BUILD_REPORT=1 \
TDDFT_FFLAGS="-O2 -mp -Msave -Mlarge_arrays -acc" \
./tools/build_nvhpc.sh
```

## 13. Step A coding仕様

### 13.1 A1-A6共通の禁止事項

- data clause、enter/exit、update、delete、ownership、routine interface、FFT path、計算順序を変更しない
- `acc_wait`を追加しない
- time-step/nonlocal loop内で新規allocationしない
- 毎step出力しない
- C wrapper以外から`acc_deviceptr`を呼ばない
- diagnostic ONまたはNsight runを性能baselineに使わない

### 13.2 A1: guard付き基盤だけ

| 項目 | 仕様 |
|---|---|
| 仮説 | guard付き基盤はcompileでき、OFF時のruntime影響は0 |
| files | `mk_ifort.sh`, `tools/build_nvhpc.sh`, 新規`mod_stepa_diag.F90`, `fpseid_stepa_acc_diag.c`, `stepa_default_int_probe.F90`, `tmevl10_Avec_v4.f`のguard付きuse |
| import位置 | complete subroutine statementの後、`implicit`前。TMEVL 50行前、S2_ 1705行前、`exnlp_only_make_acc` 2462行前、`exnlp_gemm_body_fused` 2536行前 |
| runtime call/output | なし。ONでもA1だけでは出力0 |
| validation | fallback OFF build、NVHPC ON probe/link、A1出力なし、OFF check/compare/timing |
| rollback | A1だけrevert |

### 13.3 A2: P/J2G/coef診断

- call位置: S2_ 1817行後・1818行前。coefは`exnlp_gemm_body_fused` 2543行直前。
- rank/count: rank 0、Pとcoefを各1回。
- symbol: `fpseid_stepa_diag_p`。
- `sample_np`は最初に観測したS2 phaseだけを示し、5 phase coverageを意味しません。
- J2Gは`1:min(NXYZ,NG2Q)`以外を読まない。
- ngnl_はA2で読まない。
- invalid boundsならOpenACC queryを呼ばない。

安定出力prefix:

```text
FPSEID_STEPA_P rank= sample_np= ng2q= nxyz= ng2= ngcont= mxbnd= nbndloc= nbegin= nend= p_lb1= p_ub1= p_lb2= p_ub2= j2g_lb= j2g_ub= j2g_extent= j2g_min= j2g_max= j2g_valid= p_index_bounds_ok= j2g_value_bounds_ok= parent_status= parent_present= haddr= daddr= first_col_status= first_col_present= last_col_status= last_col_present= bounds_ok=
FPSEID_STEPA_COEF rank= sample_np= ng2q= mxbnd= nbndloc= coef_lb1= coef_ub1= coef_lb2= coef_ub2= query_status= present= haddr= daddr= p_haddr= p_daddr= host_offset= device_offset=
```

validationはOFF/ON check・compare PASSとP1-P4分類です。

### 13.4 A3: YLM1-5診断

- caller parent call: 549、587、614、641、668行の各S2_直前。
- callee section call: 各NPで最初の`exnlp_only_make_acc`、2475-2479行で`lylm`決定後、2480行直前。
- symbols: `fpseid_stepa_diag_ylm_parent`, `fpseid_stepa_diag_ylm_section`。
- flags: `diagnosed_ylm_parent(5)`, `diagnosed_ylm_section(5)`。
- 各phaseでparent 1回、代表section最大1回。
- caller recordに`lylm`を含めません。
- invalid `lylm`は`SKIPPED_INVALID_BOUNDS`でqueryしません。

```text
FPSEID_STEPA_YLM_PARENT rank= phase= symbol=YLMk ngcont= parent_lb1= parent_ub1= parent_lb2= parent_ub2= parent_bytes= query_status= parent_present= parent_haddr= parent_daddr=
FPSEID_STEPA_YLM_SECTION rank= phase= symbol=YLMk ngcont= lylm= section_lb= section_ub= section_bytes= query_status= section_present= section_haddr= section_daddr= expected_offset= observed_offset= contiguous=T
```

### 13.5 A4: VPJ1-5診断

- caller parent callはA3と同じ5つのS2_直前。
- callee section callは各NP最初の2480行直前で、`ip,il,ity`決定後。
- symbols: `fpseid_stepa_diag_vpj_parent`, `fpseid_stepa_diag_vpj_section`。
- flags: `diagnosed_vpj_parent(5)`, `diagnosed_vpj_section(5)`。
- caller recordに`ip,il,ity`を含めません。
- interface/data clauseを変更しません。

```text
FPSEID_STEPA_VPJ_PARENT rank= phase= symbol=VPJk ngcont= ntyq= parent_lb1= parent_ub1= parent_lb2= parent_ub2= parent_lb3= parent_ub3= parent_lb4= parent_ub4= parent_bytes= query_status= parent_present= parent_haddr= parent_daddr=
FPSEID_STEPA_VPJ_SECTION rank= phase= symbol=VPJk ngcont= ntyq= ip= il= ity= section_lb= section_ub= section_bytes= query_status= section_present= section_haddr= section_daddr= expected_offset= observed_offset= contiguous=T
```

### 13.6 A5: EXTAU診断

- caller parent callは5つのS2_直前。
- callee section callは各NP最初の2480行直前で、`np,itseq`決定後。
- symbols: `fpseid_stepa_diag_extau_parent`, `fpseid_stepa_diag_extau_section`。
- flags: `diagnosed_extau_parent(5)`, `diagnosed_extau_section(5)`。
- caller recordに`itseq`を含めません。
- EXTAU update/copyinを変更しません。

```text
FPSEID_STEPA_EXTAU_PARENT rank= phase= ngcont= ntauq= parent_lb1= parent_ub1= parent_lb2= parent_ub2= parent_lb3= parent_ub3= parent_bytes= query_status= parent_present= parent_haddr= parent_daddr=
FPSEID_STEPA_EXTAU_SECTION rank= phase= ngcont= ntauq= np= itseq= section_lb= section_ub= section_bytes= query_status= section_present= section_haddr= section_daddr= expected_offset= observed_offset= contiguous=T
```

### 13.7 A6: nonlocal output/metadata診断

- symbol: `fpseid_stepa_diag_nonlocal`。
- flags: `diagnosed_nonlocal(2)`。1=`forward`、2=`reverse`。
- forward: 1921行後、1923行前。
- reverse: 2220行後、2222行前。
- metadata生成と対応copyin完了後、consumer前に実施。
- `loopcnt>0`のときだけmin/maxとOpenACC queryを実施。
- `loopcnt<=0`ならblockごとにskipped recordを1件だけ出力。

```text
FPSEID_STEPA_NONLOCAL rank= block=forward|reverse loopcnt= work2_ncol= ngcont= ng2q= ngnl_min= ngnl_max= ngnl_valid= ngnl_bounds_ok= work2_status= work2_present= cfac_status= cfac_present= ngnl_status= ngnl_present= work2_haddr= work2_daddr= cfac_haddr= cfac_daddr= ngnl_haddr= ngnl_daddr=
```

両blockが出力され、boundsがtrue、check/compareがPASSすることを要求します。

## 14. Step Aで保存する証跡

archive labelは`nvhpc_cufft_1rank_o2_STEPA_01`のように単調増加させ、次を保存します。

B1以降のownership診断ログは、YLMについて次のコマンドで5 phaseのY1条件を
自動確認できます。

```sh
python3 ./tools/check_stepa_ownership.py --family ylm /path/to/tddft.err
```

このcheckはparent/sectionの`query_status=OK`、present値、symbol、contiguity、
expected/observed offset、`ngcont`一致を確認します。数値結果と性能gateは別途
`check_tddft_result.py`と保存済みwall timeで判定します。

- source commitとbuild command
- compiler versionと`-Minfo` report
- A1-A6出力
- diagnostic OFF runのstdout/stderr、check/compare
- diagnostic ON runのstdout/stderr、check/compare
- Nsight Systems reportとH2D/D2H、allocation、kernel、GPU idle gapのsummary
- GPU model、driver、peak memory
- OFF timing 3回とmedian

## 15. 1 commit = 1 hypothesisの実装計画

| commit | 仮説 | 前提 | 変更範囲 | gate | rollback |
|---|---|---|---|---|---|
| A1 | guard基盤はOFF影響0 | source baseline一致 | Section 13.2だけ | fallback/ON link/OFF median | A1 revert |
| A2 | P/J2Gを安全に分類できる | A1 | A2だけ | PASS、P1-P4出力 | A2 revert |
| A3 | YLM 5 familyと代表sectionを観測できる | A2 | A3だけ | 5 parent + 5 section、PASS | A3 revert |
| A4 | VPJ 5 familyと代表sectionを観測できる | A3 | A4だけ | 同上 | A4 revert |
| A5 | EXTAU parent/sectionを観測できる | A4 | A5だけ | 同上 | A5 revert |
| A6 | 両nonlocal blockのrange契約が成立 | A5 | A6だけ | forward/reverse valid、PASS | A6 revert |
| B1 | YLM parent residencyでYLM section copyinを置換可能 | A3完了 | YLM owner追加 + YLM copyin除去 + presentを同一commit | Y1またはY2-Y4に従う、PASS、+3%以内 | B1 revert |
| B2 | VPJについて同上 | B1 PASS、A4完了 | VPJだけ | 同上 | B2 revert |
| B3 | EXTAUについて同上 | B2 PASS、A5完了 | EXTAUだけ | 同上 | B3 revert |
| C1 | work2_ lifetimeを転送変更なしで固定可能 | B1-B3 PASS、A6完了 | exact create/delete/assertion | PASS、allocation増加なし | C1 revert |
| C2 | GPU producerからpresent consumerへ直結可能 | C1 PASS、P gate解決 | work2_ producer-consumer chain | PASS、Step 18 gate | C2 revert |
| C3 | cfac_ Host authoritative bulk transferで十分 | C2 PASS | `cfac_(1:loopcnt)`をblockごと1回 | 設計通りの転送回数 | C3 revert |
| C4 | ngnl_ Host authoritative bulk transferで十分 | C3 PASS | `ngnl_(1:loopcnt)`をblockごと1回 | bounds/transfer/PASS | C4 revert |
| D1 | 残るwork2_ Host round tripを削除可能 | C2-C4 PASS | work2_だけ | PASS、遅くない | D1 revert |
| D2 | metadata転送をさらに削減可能 | D1 PASS | cfac_/ngnl_だけ | strict auditと性能向上 | D2 revert |

caller ownershipを追加したまま対応callee copyinを残すcommitは禁止します。B runtime evidenceでY2/Y3が出ない限り、現行parent+index interfaceを維持します。

## 16. 性能・数値gate

### 16.1 性能

- diagnostic macro OFF
- 同一node、GPU、input、compiler flags、MPI/OpenMP設定
- baseline/candidateを原則3回実行しmedian比較
- 正式な再測定Step 18相当medianに対し悪化3%以内
- 163.31秒から計算した168.2秒は過去単発値からの参考上限であり、正式baselineではない
- diagnostic ON、Nsight、nested timerの単純和を性能判定に使わない
- 主判定は同じ範囲の`wall_sec`

### 16.2 数値

各runtime commitで次を要求します。

- `check_tddft_result.py check`: PASS
- GNU relaxed compare: PASS
- Step 18 archiveとの直接比較: 承認済みtoleranceでPASS
- 新規NaN/Infなし
- 2-step smoke後に50/100-step
- `ia`順序とforce/position/velocity件数を維持

## 17. Static checklist

- [ ] branch/source commitがSection 0と一致
- [ ] final v5がGit追跡済み
- [ ] phase call lineとactual symbolが一致
- [ ] dummy/actualの型、rank、explicit shapeが一致
- [ ] P/J2G診断が全bound評価をguard
- [ ] C wrapperと`iso_c_binding`の型が一致
- [ ] production arrayへ`TARGET`を追加していない
- [ ] macro default OFF、production参照がpreprocessで完全除去
- [ ] GNU/IntelからNVHPC専用symbolが見えない
- [ ] saved Host allocationとDevice mapping責任を分離
- [ ] owner enterとowner deleteが1対1
- [ ] B commitで対応callee copyinを同時削除
- [ ] CPU/FFTW interface不変
- [ ] symbol、timer/diagnostic label重複なし

## 18. Runtime checklist

- [ ] A2でactual NG2Q/NXYZ/mxbnd/nbndlocと安全なJ2G rangeを取得
- [ ] A3-A5で各5 parent + 5 representative section、offset一致
- [ ] A6でforward/reverse各1 record
- [ ] Y0 absenceを正常として記録
- [ ] ngnl min/maxとwork2_/metadata presence
- [ ] compiler reportにunexpected temporary/packなし
- [ ] NsightでH2D/D2H、allocation/free、kernel数、peak memory
- [ ] OFF resultと3回median gate
- [ ] B1-B3後のtarget parent/section present lookup
- [ ] partial-present/duplicate registrationなし
- [ ] C2-C4のtransfer range/frequencyとproducer-consumer chain

## 19. 段階gate

| 段階 | READY条件 | v5判定 |
|---|---|---|
| Step A coding | API、preprocess、5 phase、safe J2G、A1-A6の位置/guard/outputが確定 | READY FOR CODING |
| Ownership B1-B3 | 対応Step A証跡、owner range選択、atomic owner+present patch、Y1-Y4 runtime gate | DESIGNED BUT RUNTIME-GATED |
| Callee present conversion | 独立段階にせずB1-B3内でatomicに実施 | ownership commitへ統合 |
| GPU producer C2 | P/J2G/ngnl解決、B1-B3 PASS、work2 lifetime固定、fallback PASS、Step 18 median gate | DESIGNED BUT RUNTIME-GATED |

## 20. 失敗時の切り分けとrollback

| 症状 | 原因候補 | 最初に見る証跡 | 対応 |
|---|---|---|---|
| A3-A5 parent absent | current Y0 | Step A record | 正常。Step Aをfailにしない |
| Bでpartially present | duplicate/section registration、parent range誤り | present tableとoffset | 該当B commitだけrevert |
| P query invalid | NG2Q/NXYZ/mxbnd gate失敗 | A2 | API call前に停止しP3/BLOCKER |
| unexpected pack/temp | compiler/interface | `-Minfo`, Nsight | B revert、別buffer/interfaceは別設計 |
| numerical mismatch | stale authority、update不足、順序変更 | check、Step 18 compare | 現commit revert |
| repeated large H2D/D2H | callee copyin残存、誤build path | Nsight | revertしてsource selection確認 |
| allocation/free増加 | data regionが反復loop内 | Nsight | revert |
| medianが3%超悪化 | transfer/launch/sync/allocation | 3回medianとtrace | 原則reject/revert |

## 21. 実行環境復旧後に確認する未解決事項

| 質問 | 確認方法 | 必要log | 合格条件/分岐 |
|---|---|---|---|
| NG2Q/NXYZ関係 | A2 | `FPSEID_STEPA_P` | P1/P2/P4 valid、P3は停止 |
| J2G/ngnl bounds | A2/A6 | P/NONLOCAL record | 全indexがrange内 |
| current transfer数 | Nsight Step A | memory summary | Step Aで計算経路不変 |
| 5 family offset | A3/A4 | familyごと5 parent+5 section | expected=observed |
| EXTAU offset | A5 | 5 parent+5 section | expected=observed |
| 両nonlocal block | A6 | forward/reverse各1 | valid、skip/invalidなし |
| target parent lookup | B1-B3 | present table/B diagnostic | Y1、Y2-Y4はtreeに従う |
| target lifetime中Host更新 | B trace/source audit | update log | audited bulk updateまたはrollback |
| peak GPU memory | Nsight/`nvidia-smi` | peak report | 対象GPU容量に合意済みmargin |
| 性能再現性 | baseline/candidate各3回 | timing table | candidate median <= baseline*1.03 |

## 22. 最終自己判定

- **Step A diagnostic coding: READY FOR CODING**
- **Ownership implementation: DESIGNED BUT RUNTIME-GATED**
- **Callee present conversion: ownership commitへ統合**
- **GPU producer connection: DESIGNED BUT RUNTIME-GATED**

[DECISION] 実行環境が復旧したら、追加のarchitecture判断なしでA1から実装できます。

[BLOCKER] B1以降は、各runtime gateを満たすまで実装禁止です。
