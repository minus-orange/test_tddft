# FPSEID21 TDDFT GPU Residency Design v4

## 0. Source Revision

- [CONFIRMED] branch: `tddft-openacc-residency`
- [CONFIRMED] current commit: `d5d42d6d7bf60217991dbe7e725529e429774903`
- [CONFIRMED] source tree root: `/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21`
- [CONFIRMED] review date: 2026-07-11
- [DECISION] All source line numbers in this document refer to commit `d5d42d6d7bf60217991dbe7e725529e429774903`.
- [DECISION] This document is design-only. No code change, build, run, or measurement is part of v4 preparation.

## 1. Baseline And Scope

- [CONFIRMED] Formal performance baseline: Step 18.
- [CONFIRMED] Step 18 wall time: about 163.31 sec.
- [CONFIRMED] Step 18 `check_tddft_result.py check`: PASS.
- [CONFIRMED] Step 18 relaxed compare against GNU reference: PASS.
- [CONFIRMED] Step 19 was slower, about 178 sec.
- [CONFIRMED] Step 20 was rejected, about 819 sec, with `s2_nonlocal_make` around 680 sec.
- [DECISION] Routine-internal or fine-grained repeated `copyin` of large sections is rejected.
- [DECISION] Target execution model remains 1 GPU / 1 MPI rank, OpenACC + cuFFT.
- [DECISION] CPU/FFTW fallback paths must remain buildable and behaviorally separate.

## 2. v3 To v4 Change History

- [DECISION] Added explicit source revision block.
- [DECISION] Split each routine into Current Contract, Target Contract, and Transition Contract.
- [DECISION] Corrected `P` ownership: `TMEVL` owns `P`; `S2_` borrows it as `PRESENT_BORROWED`.
- [DECISION] Converted the unresolved `P` / `coef` shape issue into a Step A decision tree.
- [DECISION] Converted `YLM`, `VPJ`, and `EXTAU` mapping uncertainty into a Step A decision tree.
- [DECISION] Split current ownership and target ownership into one table.
- [DECISION] Fixed initial target design for `work2_`, `cfac_`, and `ngnl_`.
- [DECISION] Added Step A coding specification A1-A6.
- [DECISION] Re-split the commit plan into one hypothesis per commit.
- [DECISION] Separated static checklist from runtime checklist.
- [DECISION] Added stage gate matrix and stage-specific self judgement.

## 3. Review Comment Response Table

| Review request | v4 response |
|---|---|
| Add exact source revision | Section 0 records branch, commit, root, and review date. |
| Separate Current and Target | Section 5 has Current/Target/Transition contracts per routine. |
| Fix `P` ownership | Section 6 states `TMEVL` is owner and `S2_` is borrower. |
| Do not assume `P(1:NXYZ,1:nbndloc)` is correct | Section 7 treats that mapping as a current-source hazard only. |
| Make `P` / `coef` runtime-dependent | Section 7 defines Cases P1-P4. |
| Make `YLM` / `VPJ` / `EXTAU` runtime-dependent | Section 8 defines Cases A-D. |
| Clarify `exnlp_only_make_acc` internal copyin | Sections 5 and 8 separate Current internal `copyin` from Target present-only. |
| Define Step A coding | Section 12 defines A1-A6 with guards, output, validation, and rollback. |
| Split static and runtime checks | Sections 14 and 15. |
| Define stage gates | Section 16. |

## 4. Source Map

### 4.1 Main routines

| Routine | File | Lines |
|---|---|---:|
| `TMEVL` | `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f` | 15 |
| `S2_` | `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f` | 1693 |
| `exnlp_only_make` | same | 2434 |
| `exnlp_only_make_acc` | same | 2459 |
| `exnlp_gemm` | same | 2491 |
| `exnlp_gemm_present_inputs` | same | 2521 |
| `exnlp_gemm_body_fused` | same | 2534 |

### 4.2 Important declarations and call sites

| Item | Lines | Notes |
|---|---:|---|
| `P(NG2Q,MXBND)` in `TMEVL` | 54 | Owner allocation/declaration is in caller scope. |
| `YLM(NGcont,16)` in `TMEVL` | 61 | Parent array. |
| `RHO1`, `RHO2`, `VG`, `WORK2` in `TMEVL` | 67-70 | `VG` is `NXYZ`; `WORK2` is legacy static `NG2Q,7`. |
| `EXTAU(NGcont,5,NTAUQ)` in `TMEVL` | 79 | Parent array. |
| `J2G(NG2Q)`, `G2(4,NG2Q)` in `TMEVL` | 94 | Needed for bounds diagnosis. |
| `VPJ(NGcont,3,4,NTYQ)` in `TMEVL` | 106 | Parent array. |
| `S2_` calls | 549, 587, 614, 641, 668 | Time-integration calls from `TMEVL`. |
| `P` enter data | 532 | `copyin(P(1:NG2Q,1:nbndloc))`. |
| `P` exit data | 714 | `copyout(P(1:NG2Q,1:nbndloc))`. |
| `P(1:NXYZ,...)` present hazard | 1942, 1962, 2091 | Must not be assumed correct until Step A. |
| `S2_` dummy `P(NG2Q,mxbnd)` | 1707 | Borrowed view of caller `P`. |
| `S2_` dummy `YLM`, `EXTAU`, `VPJ` | 1713, 1719, 1736 | Dummy shapes match parent arrays. |
| `RHO1_`, `RHO2_`, `work2_`, `cfac_`, `ngnl_` | 1744-1747 | `S2_` local saved allocatables. |
| `work2_` allocation | 1810 | `work2_(NGcont,loopcnt)`. |
| `cfac_`, `ngnl_` allocation | 1811-1812 | `loopcnt` length. |
| `work2_` create | 1821 | `create(work2_(1:NGcont,1:work2_ncol))`. |
| `exnlp_only_make_acc` call | 1834-1838 and repeated to 1910 | Produces `work2_`, `cfac_`, `ngnl_`. |
| `cfac_`, `ngnl_` copyin | 1921 | Current small metadata bulk copy. |
| `exnlp_gemm_present_inputs` call | 1923-1924 | Current GPU consumer. |
| `work2_`, `cfac_`, `ngnl_` delete | 1926-1927 | Current S2-local lifetime. |
| `exnlp_only_make_acc` internal `copyin` | 2481-2483 | Current rejected long-term pattern. |
| `exnlp_gemm_body_fused` present clause | 2545-2548 | Uses `coef`, `work1`, `cfac`, `ngnl`. |

## 5. Current / Target / Transition Contracts

### 5.1 `TMEVL`

**Current Contract**

- [CURRENT] Declares `P(NG2Q,MXBND)` at line 54.
- [CURRENT] Declares parent `YLM`, `EXTAU`, and `VPJ` at lines 61, 79, and 106.
- [CURRENT] Registers `P(1:NG2Q,1:nbndloc)` on the device at line 532.
- [CURRENT] Calls `S2_` five times per time integration block at lines 549, 587, 614, 641, and 668.
- [CURRENT] Copies `P(1:NG2Q,1:nbndloc)` back and releases it at line 714.
- [CURRENT] Does not yet own long-lived `YLM`, `VPJ`, or `EXTAU` device residency for the target path.

**Target Contract**

- [TARGET] `TMEVL` owns device lifetime for `P`.
- [TARGET] `TMEVL` or a clearly higher caller owns device lifetime for parent `YLM`, `VPJ`, and `EXTAU`.
- [TARGET] `S2_` receives `P`, `YLM`, `VPJ`, and `EXTAU` as borrowed present data.
- [TARGET] `TMEVL` is responsible for the final host synchronization of `P`.

**Transition Contract**

- [DECISION] Step A may add diagnostics only; it must not change `TMEVL` data clauses.
- [DECISION] Ownership commits C1-C3 are allowed only after Step A confirms mapping stability.
- [DECISION] Rollback is restoring Step 18-equivalent data clauses and disabling all diagnostic macros.

### 5.2 `S2_`

**Current Contract**

- [CURRENT] Receives `P(NG2Q,mxbnd)` at line 1707.
- [CURRENT] Receives `YLM(NGcont,16)`, `EXTAU(NGcont,5,NTAUQ)`, and `VPJ(NGcont,3,4,NTYQ)` at lines 1713, 1719, and 1736.
- [CURRENT] Allocates saved local `work2_`, `cfac_`, and `ngnl_` at lines 1810-1812.
- [CURRENT] Creates `work2_` on device at line 1821.
- [CURRENT] Calls `exnlp_only_make_acc` repeatedly from lines 1834-1910.
- [CURRENT] Copies `cfac_` and `ngnl_` to device in one bulk copy at line 1921.
- [CURRENT] Calls `exnlp_gemm_present_inputs` at lines 1923-1924.
- [CURRENT] Deletes `work2_`, `cfac_`, and `ngnl_` at lines 1926-1927.
- [CURRENT] Contains a `P(1:NXYZ,1:nbndloc)` present clause at line 1942; this is a source hazard until Step A resolves `NG2Q`/`NXYZ`.

**Target Contract**

- [TARGET] `S2_` borrows `P` as `PRESENT_BORROWED`.
- [TARGET] `S2_` must not change `P` ownership authority on return.
- [TARGET] `S2_` may own S2-local temporaries such as `work2_`, `cfac_`, and `ngnl_`.
- [TARGET] `S2_` must not add large per-call host/device transfers inside the nonlocal loop.
- [TARGET] `S2_` remains the initial owner of `work2_` device storage.

**Transition Contract**

- [DECISION] A temporary state with `PRESENT_BORROWED -> MIRRORED_HOST_AUTH` inside `S2_` is forbidden.
- [DECISION] A temporary state with both caller-owned parent sections and callee-internal large `copyin` is forbidden.
- [DECISION] If Step A detects unstable parent/section mapping, do not proceed to C ownership commits.

### 5.3 `exnlp_only_make`

**Current Contract**

- [CURRENT] CPU routine starts at line 2434.
- [CURRENT] Dummy arrays are section-oriented: `vpj(NGcont)`, `ylm(NGcont,16)`, `extau(NGcont)`, and `work1(NGcont)` at lines 2438-2439.
- [CURRENT] Computes `cfac` at lines 2443-2445.
- [CURRENT] Writes `work1(ig)` for `ig=1:ngnl` at lines 2453-2455.

**Target Contract**

- [TARGET] CPU/FFTW fallback keeps this routine available.
- [TARGET] Mathematical order and `ia` ordering must not be changed by GPU work.

**Transition Contract**

- [DECISION] Do not alter this routine for Step A.
- [DECISION] Interface changes for GPU must not break this fallback routine.

### 5.4 `exnlp_only_make_acc`

**Current Contract**

- [CURRENT] ACC routine starts at line 2459.
- [CURRENT] Dummy parents are `vpj(NGcont,3,4,NTYQ)`, `ylm(NGcont,16)`, and `extau(NGcont,5,NTAUQ)` at lines 2464-2466.
- [CURRENT] Computes scalar `cfac` on host at lines 2470-2472.
- [CURRENT] Launches an OpenACC loop at line 2480.
- [CURRENT] Performs internal `copyin` of `ylm(1:NGcont,lylm)`, `extau(1:NGcont,np,itseq)`, and `vpj(1:NGcont,ip,il,ity)` at lines 2481-2483.
- [CURRENT] Writes `work1(ig)` at lines 2484-2486.

**Target Contract**

- [TARGET] Callee must require parent data to be present.
- [TARGET] Callee must not perform internal `copyin` for `YLM`, `EXTAU`, or `VPJ`.
- [TARGET] Callee may generate `work2_` on device, but only when caller ownership is already established.
- [TARGET] Callee must not allocate or delete OpenACC device storage.

**Transition Contract**

- [DECISION] Current internal `copyin` is tolerated only before D1.
- [DECISION] D1 must remove callee-internal large `copyin` in the same commit that establishes a valid caller-present contract.
- [DECISION] A D1 commit that leaves both caller ownership and internal `copyin` is rejected.

### 5.5 `exnlp_gemm`

**Current Contract**

- [CURRENT] Routine starts at line 2491.
- [CURRENT] It can self-manage `work1`, `cfac`, `ngnl`, and `ct1` through copyin/create/delete at lines 2502, 2505, 2508, and 2514-2515.

**Target Contract**

- [TARGET] This routine remains a fallback or diagnostic path.
- [TARGET] Main residency path should use `exnlp_gemm_present_inputs`.

**Transition Contract**

- [DECISION] Do not remove this routine until all fallback builds are validated.

### 5.6 `exnlp_gemm_present_inputs`

**Current Contract**

- [CURRENT] Routine starts at line 2521.
- [CURRENT] It has no local data clauses and directly calls `exnlp_gemm_body_fused` at lines 2527-2529.

**Target Contract**

- [TARGET] Caller must present `work1`, `coef`, `cfac`, and `ngnl`.
- [TARGET] Routine must remain allocation-free and transfer-free.

**Transition Contract**

- [DECISION] This routine is the stable consumer endpoint for GPU-generated `work2_`.

### 5.7 `exnlp_gemm_body_fused`

**Current Contract**

- [CURRENT] Routine starts at line 2534.
- [CURRENT] `coef(ng2q,mxbnd)`, `work1(NGcont,loopcnt)`, `cfac(loopcnt)`, and `ngnl(loopcnt)` are dummy arrays at lines 2537-2539.
- [CURRENT] The present clause maps `coef(1:ng2q,1:nbndloc)`, `work1(1:NGcont,1:loopcnt)`, `cfac`, and `ngnl` at lines 2545-2548.
- [CURRENT] Host-side `ia` loop remains at line 2543.

**Target Contract**

- [TARGET] `ia` order must not change until mathematical equivalence is separately approved.
- [TARGET] The routine must not create hidden host round trips.
- [TARGET] `coef` / `P` mapping must use the correct physical and active extents determined by Step A.

**Transition Contract**

- [DECISION] If Step A reveals `coef` present ranges are wrong, GPU producer work is blocked until the mapping is corrected.

## 6. `P` Ownership State Machine

### 6.1 Owner / borrower / producer / consumer

| Role | Routine | Lines | Meaning |
|---|---|---:|---|
| Owner | `TMEVL` | 54, 532, 714 | Declares and owns device lifetime for `P`. |
| Borrower | `S2_` | 1693, 1707 | Receives `P` and may use/update it while present. |
| Producer | `S2_` kernels | 1942-2091 and related kernels | Updates `P` during the propagator. |
| Consumer | `exnlp_gemm_body_fused` | 2534-2560 | Reads and updates `coef`, where actual argument is `P`. |
| Host sync owner | `TMEVL` | 714 | Copies final `P` state back to host. |

### 6.2 State transitions

```text
TMEVL entry
  P host storage exists
  state: MIRRORED_HOST_AUTH

TMEVL line 532
  !$acc enter data copyin(P(1:NG2Q,1:nbndloc))
  state: MIRRORED_HOST_AUTH with device allocation

S2_ entry line 1693
  P borrowed by S2_
  state inside S2_: PRESENT_BORROWED

S2_ body
  kernels may update device P/coef
  state remains owned by TMEVL; S2_ must not claim ownership

S2_ return
  forbidden transition: PRESENT_BORROWED -> MIRRORED_HOST_AUTH
  allowed transition: PRESENT_BORROWED -> caller-owned still-present P

TMEVL line 714
  !$acc exit data copyout(P(1:NG2Q,1:nbndloc))
  state: MIRRORED_HOST_AUTH, device allocation released
```

- [DECISION] `S2_` is not allowed to perform final host synchronization of `P`.
- [DECISION] `TMEVL` owns `P` enter/update/delete responsibility.
- [BLOCKER] Runtime Step A must confirm whether `P` active mapping should be `NG2Q` or a narrower active extent for each consumer.

## 7. `P` / `coef` Shape Decision Tree

### 7.1 Static facts

- [CONFIRMED] `TMEVL` declares `P(NG2Q,MXBND)` at line 54.
- [CONFIRMED] `S2_` dummy declares `P(NG2Q,mxbnd)` at line 1707.
- [CONFIRMED] `exnlp_gemm_body_fused` dummy declares `coef(ng2q,mxbnd)` at line 2537.
- [CONFIRMED] Current `P` enter/exit maps `P(1:NG2Q,1:nbndloc)` at lines 532 and 714.
- [CONFIRMED] Current local-potential region uses `P(1:NXYZ,1:nbndloc)` at lines 1942, 1962, and 2091.
- [BLOCKER] Source alone does not prove the runtime relationship among `NG2Q`, `NXYZ`, `NG2`, `NGcont`, `mxbnd`, `nbndloc`, and `J2G`.
- [DECISION] `P(1:NXYZ,1:nbndloc)` is documented as a current-source hazard, not as a correct target mapping.

### 7.2 Step A required runtime values

Step A must print once per rank and first relevant `S2_` call:

- `NG2Q`, `NXYZ`, `NG2`, `NGcont`
- `mxbnd`, `nbndloc`, `nbegin`, `nend`
- `minval(J2G(1:NG2Q))`, `maxval(J2G(1:NG2Q))`
- `acc_is_present(P(1:NG2Q,1:nbndloc))`
- `acc_is_present(P(1:NXYZ,1:nbndloc))` only if bounds are valid
- host base address and section address for `P`
- `acc_deviceptr(P)` only after `acc_is_present` succeeds

### 7.3 Decision cases

| Case | Runtime result | Source modification | Correct mapping range | `coef` contract | J2G gate | Step B condition | Rollback |
|---|---|---|---|---|---|---|---|
| P1 | `NG2Q == NXYZ` | Standardize clauses to `NG2Q` names; no physical extent conflict. | `P(1:NG2Q,1:nbndloc)` | `coef(1:ng2q,1:nbndloc)` is consistent. | `max(J2G) <= NXYZ` | Present checks stable and no partial-present error. | Disable Step A diagnostics. |
| P2 | `NG2Q > NXYZ` | Keep nonlocal/coef mapping at `NG2Q`; audit local-potential `NXYZ` clauses. | Nonlocal: `NG2Q`; local active: verified `NXYZ`/`J2G`. | `coef` must remain `ng2q,mxbnd`. | `J2G` must not read beyond `NXYZ` for local arrays. | Step B allowed only if both `NG2Q` and `NXYZ` sections are valid and non-overlapping in present table. | Revert to Step 18 path. |
| P3 | `NG2Q < NXYZ` | Required before ownership work; current `P(1:NXYZ,...)` would exceed declaration. | UNVERIFIED. | BLOCKED. | BLOCKED. | Step B blocked. | Revert diagnostics and stop. |
| P4 | Physical shape is `NG2Q` but active referenced extent is limited by `NXYZ` or `J2G` | Separate physical mapping from active algorithmic range. | Physical allocation: `NG2Q`; active kernel ranges individually verified. | `coef` uses physical `ng2q`; kernels may use smaller active bounds. | Print and validate all `J2G` bounds. | Step B allowed only with explicit per-kernel bound rationale. | Revert to Step 18 path. |

## 8. `YLM` / `VPJ` / `EXTAU` Decision Tree

### 8.1 Static facts

| Array | Parent declaration | Dummy declaration | Current usage |
|---|---|---|---|
| `YLM` | `YLM(NGcont,16)` at line 61 | `YLM(NGcont,16)` at line 2465 | `YLM(ig,lylm)` inside `exnlp_only_make_acc`, lines 2481 and 2485. |
| `VPJ` | `VPJ(NGcont,3,4,NTYQ)` at line 106 | `VPJ(NGcont,3,4,NTYQ)` at line 2464 | `VPJ(ig,ip,il,ity)`, lines 2483 and 2486. |
| `EXTAU` | `EXTAU(NGcont,5,NTAUQ)` at line 79 | `EXTAU(NGcont,5,NTAUQ)` at line 2466 | `EXTAU(ig,np,itseq)`, lines 2482 and 2485. |

- [CONFIRMED] Actual call sites pass parent arrays plus indices at lines 1834-1910.
- [CONFIRMED] Current OpenACC data clauses inside `exnlp_only_make_acc` use section expressions at lines 2481-2483.
- [UNVERIFIED] Runtime contiguity, section address, and potential pack/unpack behavior require Step A.

### 8.2 Decision cases

| Case | Step A result | Interface decision | Update responsibility | Callee contract | Fallback impact |
|---|---|---|---|---|---|
| A | Contiguous, parent present, section address inside parent mapping, no pack/unpack | Current parent+index dummy interface can remain; replace internal `copyin` with `present`. | Caller/owner updates parent before `S2_`. | Callee requires present parent data. | Low impact; CPU fallback unchanged. |
| B | Contiguous but section present lookup unstable | Avoid section data clauses; use parent present clauses and index ranges. | Caller owns parent full/active range. | Callee must not use per-section `copyin`. | Low to moderate; source directives change. |
| C | Noncontiguous or pack/unpack occurs | Prefer explicit parent array + index-range interface and no section actuals. | Caller owns parent; callee uses scalar indices only. | Callee present clauses target parent arrays, not sections. | Moderate; add alternate interface while preserving CPU path. |
| D | Host-side update exists during time-step | Add owner-side `update device` at a controlled point or keep Step 18 host-copy path. | Host updater becomes responsible for synchronization. | Callee remains present-only after sync. | High risk; requires separate validation. |

- [DECISION] `exnlp_only_make_acc` Target Contract is caller-owned parent present.
- [DECISION] `exnlp_only_make_acc` must not copy in `YLM`, `VPJ`, or `EXTAU` internally in the target path.

## 9. Current / Target Ownership Table

| Array | Declaration | Exact shape | Active bounds | Current authority | Current owner | Current transfer | Target authority | Target owner | Target transfer | Producer | Consumer | Lifetime | Gate |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `P` | line 54, dummy line 1707 | `P(NG2Q,MXBND)` | `1:NG2Q,1:nbndloc`; hazardous `NXYZ` uses | mirrored / mixed | `TMEVL` | enter line 532, exit line 714; hazard line 1942 | caller-owned present | `TMEVL` | no S2-level owner change | `S2_` kernels | `S2_`, `exnlp_gemm_body_fused` | `TMEVL` | P1-P4 |
| `YLM` | line 61, dummy lines 1713/2465 | `YLM(NGcont,16)` | `1:NGcont,lylm` | host authoritative with callee copyin | `TMEVL`/current callee copy | copyin line 2481 | caller-owned present | `TMEVL` or enclosing owner | owner update only | `GETYLM`/setup | `exnlp_only_make_acc` | at least `S2_`, target may extend | A-D |
| `VPJ` | line 106, dummy lines 1736/2464 | `VPJ(NGcont,3,4,NTYQ)` | `1:NGcont,ip,il,ity` | host authoritative with callee copyin | `TMEVL`/current callee copy | copyin line 2483 | caller-owned present | `TMEVL` or enclosing owner | owner update only | setup / potential generation | `exnlp_only_make_acc` | at least `S2_` | A-D |
| `EXTAU` | line 79, dummy lines 1719/2466 | `EXTAU(NGcont,5,NTAUQ)` | `1:NGcont,np,itseq` | host authoritative with callee copyin | `TMEVL`/current callee copy | copyin line 2482 | caller-owned present | `TMEVL` or enclosing owner | owner update only | `SEPPOT` path | `exnlp_only_make_acc` | at least `S2_` | A-D |
| `work2_` | line 1745 | `work2_(NGcont,loopcnt)` | `1:NGcont,1:loopcnt` | device temporary | `S2_` | create line 1821, delete line 1926 | device storage | `S2_` | no host round trip | `exnlp_only_make_acc` | `exnlp_gemm_present_inputs` | S2-local initially | D2 |
| `cfac_` | line 1746 | `cfac_(loopcnt)` | `1:loopcnt` | host authoritative then bulk copy | `S2_` | copyin line 1921 | host authoritative initially | `S2_` | loopcnt bulk copy | `exnlp_only_make_acc` host scalar | `exnlp_gemm_body_fused` | S2-local | D3 |
| `ngnl_` | line 1747 | `ngnl_(loopcnt)` | `1:loopcnt` | host authoritative then bulk copy | `S2_` | copyin line 1921 | host authoritative initially | `S2_` | loopcnt bulk copy | host `ngnl(ity)` assignment line 1839 etc. | `exnlp_gemm_body_fused` | S2-local | D4 |
| `RHO1_` | line 1744 | `RHO1_(NXYZ,mxbnd)` | `1:NXYZ,1:nbndloc` | current local S2 storage | `S2_` | current clauses near local potential | unchanged initially | `S2_` | no target change in Step A-D | S2 kernels | S2 kernels | S2-local | later |
| `RHO2_` | line 1744 | `RHO2_(NXYZ,mxbnd)` | `1:NXYZ,1:nbndloc` | current local S2 storage | `S2_` | current clauses near local potential | unchanged initially | `S2_` | no target change in Step A-D | S2 kernels | S2 kernels | S2-local | later |
| `VG` | line 70, dummy line 1719 | `VG(NXYZ)` | `1:NXYZ` | current S2/local potential use | `TMEVL`/`S2_` | current local-potential clauses | unchanged initially | caller/S2 as existing | no target change in Step A-D | potential build | S2 kernels | S2/TMEVL | later |

## 10. `work2_` / `cfac_` / `ngnl_` Target Initial Design

### 10.1 `work2_`

- [DECISION] Target initial design: device storage, GPU producer, GPU consumer.
- [DECISION] Exact allocation range: `work2_(1:NGcont,1:loopcnt)` from line 1810.
- [DECISION] Exact device create range: `work2_(1:NGcont,1:work2_ncol)` at line 1821.
- [DECISION] Target consumer: `exnlp_gemm_present_inputs` at lines 1923-1924.
- [DECISION] Target goal: no host round trip for `work2_`.
- [UNVERIFIED] Step A must print `loopcnt`, `work2_ncol`, and `NGcont` to confirm exact runtime range.

### 10.2 `cfac_`

- [DECISION] Initial target: host authoritative plus `loopcnt` bulk copy.
- [DECISION] Exact copy range: `cfac_(1:loopcnt)` at line 1921.
- [DECISION] Device generation of `cfac_` is a separate step and requires separate approval.
- [DECISION] Delete responsibility remains with `S2_` at line 1926.

### 10.3 `ngnl_`

- [DECISION] Initial target: host authoritative plus `loopcnt` bulk copy.
- [DECISION] The host-side `ia` loop is preserved.
- [DECISION] Small metadata transfer is acceptable until device-authoritative `ngnl_` is separately designed.
- [DECISION] Exact copy range: `ngnl_(1:loopcnt)` at line 1921.
- [DECISION] Device-authoritative `ngnl_` is not part of the first GPU producer connection.

## 11. Data Lifetime Options

### 11.1 S2-unit lifetime

```text
S2_ entry
  enter/create work2_, cfac_, ngnl_
  producer exnlp_only_make_acc
  consumer exnlp_gemm_present_inputs
S2_ exit
  delete work2_, cfac_, ngnl_
```

- [CURRENT] This is closest to the current source at lines 1821 and 1926.
- [DECISION] Use this as initial target for `work2_`, `cfac_`, and `ngnl_`.
- [HYPOTHESIS] Lowest fallback risk; may retain repeated allocation overhead.

### 11.2 TMEVL-unit lifetime

```text
TMEVL before S2_ calls
  enter parent YLM/VPJ/EXTAU/P
S2_ calls
  borrow present data
TMEVL after time integration
  update/delete owner data
```

- [TARGET] This is the preferred ownership level for `P`, `YLM`, `VPJ`, and `EXTAU`.
- [UNVERIFIED] Requires Step A to prove parent/section mapping is stable.

### 11.3 Time-step-loop lifetime

```text
Before TDDFT time-step loop
  enter persistent arrays
Each time step
  kernels use present data
After loop
  update/delete
```

- [HYPOTHESIS] Best target for minimizing repeated host/device transfer.
- [BLOCKER] Host update locations for all parent arrays must be audited before adopting this lifetime.

### 11.4 TDDFT-run lifetime

```text
TDDFT setup
  enter long-lived arrays
Whole run
  device remains authoritative where possible
Finalization
  copy required outputs and delete
```

- [HYPOTHESIS] Maximum residency benefit.
- [BLOCKER] Not ready until fallback behavior and all host reads are audited.

## 12. Step A Coding Specification

Step A is measurement only. It must be safe to implement without changing computational results.

### 12.1 Global Step A rules

- [DECISION] Add compile-time guard `FPSEID_STEP_A_DIAGNOSTIC`.
- [DECISION] Default is OFF.
- [DECISION] Macro OFF must introduce no OpenACC runtime calls.
- [DECISION] Step A may add diagnostic subroutines or guarded print code only.
- [DECISION] Output is rank-limited, preferably rank 0 only.
- [DECISION] Output is first-call or bounded-call only; no every-step output.
- [DECISION] `acc_deviceptr` may be called only after `acc_is_present` succeeds.
- [DECISION] Diagnostic run and timing run are separate. Nsight overhead must not be mixed with normal wall timing.

### 12.2 Step A prohibitions

Step A must not change:

- data clauses
- `enter data`, `exit data`, `copyin`, `copyout`, `update`, or `delete`
- routine interfaces
- calculation order
- FFT path
- ownership
- host/device authority
- `acc_wait`
- per-time-step print volume

### 12.3 A1: diagnostic macro / no-op scaffolding

| Field | Specification |
|---|---|
| Hypothesis | A disabled diagnostic guard can be added with zero runtime effect. |
| Files | `tmevl10_Avec_v4.f`; build scripts only if explicit preprocessing flag is required. |
| Added symbols | `FPSEID_STEP_A_DIAGNOSTIC`; optional `fpseid_stepa_*` diagnostic helpers. |
| Output | None when OFF. With ON, a single banner is allowed. |
| Call position | No computational call position required. |
| Forbidden | Any OpenACC runtime call when OFF. |
| Validation | Build matrix still selects same source paths; no code path change when OFF. |
| Rollback | Revert one commit. |

- [UNVERIFIED] Because this is fixed-form `.f`, preprocessing support must be confirmed before coding. If not available, use a compile-time include flag pattern that still defaults OFF.

### 12.4 A2: `P` / `coef` shape, bounds, present, address diagnostic

| Field | Specification |
|---|---|
| Hypothesis | `P` / `coef` mapping can be classified into P1-P4 without changing data movement. |
| Files | `tmevl10_Avec_v4.f`. |
| Added symbols | `fpseid_stepa_diag_p`. |
| Output format | `FPSEID_STEPA_P rank=... ng2q=... nxyz=... ng2=... ngcont=... mxbnd=... nbndloc=... nbegin=... nend=... j2g_min=... j2g_max=... present_ng2q=... present_nxyz=... host_base=... section_addr=... device_ptr=...` |
| Output count | Once per rank or rank 0 first `S2_` call only. |
| Call position | In `S2_` after `nbndloc=nend-nbegin+1` at line 1817 and before nonlocal allocation work. |
| Forbidden | Calling `acc_deviceptr` if `acc_is_present` is false. |
| Validation | check PASS, relaxed compare PASS, no new transfer in normal timing run. |
| Rollback | Revert A2 only. |

### 12.5 A3: `YLM` diagnostic

| Field | Specification |
|---|---|
| Hypothesis | `YLM(1:NGcont,lylm)` can be mapped to a stable parent-present range. |
| Output format | `FPSEID_STEPA_YLM rank=... lylm=... ngcont=... parent_present=... section_present=... host_base=... section_addr=... device_ptr=... contiguous=...` |
| Call position | First `exnlp_only_make_acc` call path, guarded before line 2480. |
| Forbidden | Any `copyin` change or section materialization introduced only for diagnostic. |
| Validation | Same as A2. |

### 12.6 A4: `VPJ` diagnostic

| Field | Specification |
|---|---|
| Hypothesis | `VPJ(1:NGcont,ip,il,ity)` is stable enough for caller-owned present data. |
| Output format | `FPSEID_STEPA_VPJ rank=... ip=... il=... ity=... ngcont=... parent_present=... section_present=... host_base=... section_addr=... device_ptr=... contiguous=...` |
| Call position | First guarded `exnlp_only_make_acc` call before line 2480. |
| Validation | Same as A2. |

### 12.7 A5: `EXTAU` diagnostic

| Field | Specification |
|---|---|
| Hypothesis | `EXTAU(1:NGcont,np,itseq)` is stable enough for caller-owned present data. |
| Output format | `FPSEID_STEPA_EXTAU rank=... np=... itseq=... ngcont=... parent_present=... section_present=... host_base=... section_addr=... device_ptr=... contiguous=...` |
| Call position | First guarded `exnlp_only_make_acc` call before line 2480. |
| Validation | Same as A2. |

### 12.8 A6: nonlocal output diagnostic

| Field | Specification |
|---|---|
| Hypothesis | `work2_`, `cfac_`, and `ngnl_` current ranges are sufficient for target producer/consumer contracts. |
| Output format | `FPSEID_STEPA_NONLOCAL rank=... loopcnt=... work2_ncol=... ngcont=... work2_present=... cfac_present=... ngnl_present=... work2_ptr=... cfac_ptr=... ngnl_ptr=...` |
| Call position | After `copyin(cfac_,ngnl_)` line 1921 and before `exnlp_gemm_present_inputs` line 1923. |
| Validation | Same as A2; no change to `work2_` lifetime. |

## 13. Commit Plan: One Commit = One Hypothesis

| Commit | Hypothesis | Preconditions | Exact scope | Non-goals | Validation gate | Performance gate | Rollback |
|---|---|---|---|---|---|---|---|
| A1 | Diagnostic guard can be added with no runtime effect. | Source revision fixed. | Macro/no-op scaffolding only. | No measurements. | Build when env returns; macro OFF path unchanged. | No timing required when OFF. | Revert A1. |
| A2 | `P`/`coef` mapping can be classified. | A1. | P diagnostics only. | No data clauses. | check/compare PASS. | Wall within Step 18 noise in timing run with diagnostics OFF. | Revert A2. |
| A3 | `YLM` mapping can be classified. | A2. | YLM diagnostics only. | No ownership. | PASS. | Same as A2. | Revert A3. |
| A4 | `VPJ` mapping can be classified. | A3. | VPJ diagnostics only. | No ownership. | PASS. | Same. | Revert A4. |
| A5 | `EXTAU` mapping can be classified. | A4. | EXTAU diagnostics only. | No ownership. | PASS. | Same. | Revert A5. |
| A6 | Nonlocal temp ranges are sufficient. | A5. | `work2_`/`cfac_`/`ngnl_` diagnostics only. | No producer change. | PASS. | Same. | Revert A6. |
| B1 | Parent+index interfaces can be added unused. | Step A classifies sections. | Add unused alternate interface only. | No call-site switch. | CPU/NVHPC builds. | No runtime change. | Revert B1. |
| B2 | YLM call site can use selected interface. | B1 and YLM case decided. | YLM call path only. | No VPJ/EXTAU changes. | PASS. | Not slower than Step 18 beyond gate. | Revert B2. |
| B3 | VPJ call site can use selected interface. | B2. | VPJ call path only. | No EXTAU change. | PASS. | Gate. | Revert B3. |
| B4 | EXTAU call site can use selected interface. | B3. | EXTAU call path only. | No producer change. | PASS. | Gate. | Revert B4. |
| C1 | YLM caller ownership can be established. | B2 PASS. | Enter/update/delete for YLM only. | No callee present conversion. | PASS, no partial present. | Step 18 or better. | Revert C1. |
| C2 | VPJ caller ownership can be established. | B3 PASS. | VPJ only. | No EXTAU. | PASS. | Gate. | Revert C2. |
| C3 | EXTAU caller ownership can be established. | B4 PASS. | EXTAU only. | No producer change. | PASS. | Gate. | Revert C3. |
| D1 | `exnlp_only_make_acc` can become present-only. | C1-C3 PASS. | Remove internal large copyin; require present. | No work2 producer change. | PASS, no partial present. | Step 18 or better. | Revert D1. |
| D2 | `work2_` GPU producer can connect to present consumer. | D1 PASS. | Generate `work2_` on device and consume on device. | No cfac/ngnl authority change. | PASS. | Step 18 or better. | Revert D2. |
| D3 | `cfac_` transfer/generation can be isolated. | D2 PASS. | `cfac_` only. | No ngnl change. | PASS. | Gate. | Revert D3. |
| D4 | `ngnl_` host-authoritative bulk transfer is stable. | D3 PASS. | `ngnl_` only. | No device-authoritative ngnl. | PASS. | Gate. | Revert D4. |
| E1 | `work2_` host round trip can be fully removed. | D2-D4 PASS. | Remove any remaining `work2_` host sync. | No metadata redesign. | PASS. | Better than Step 18. | Revert E1. |
| E2 | Metadata transfer can be minimized. | E1 PASS. | `cfac_`/`ngnl_` optimization. | No ia order change. | PASS plus stricter numeric audit. | Better than E1. | Revert E2. |

## 14. Static Checklist

These are valid without a runtime environment:

- [ ] Source revision recorded.
- [ ] Declarations line numbers match current source.
- [ ] Dummy/actual argument consistency is reviewed.
- [ ] Bounds expressions are source-visible.
- [ ] Compile-time branch names are unique.
- [ ] Interface additions do not collide with existing symbols.
- [ ] CPU fallback source selection remains intact.
- [ ] Macro default is OFF.
- [ ] Allocation/deallocation responsibility is documented.
- [ ] Enter/delete responsibility is documented.
- [ ] Timer IDs and labels are not duplicated.

## 15. Runtime Checklist

These must not be treated as statically confirmed:

- [ ] Runtime `NG2Q`, `NXYZ`, `NG2`, `NGcont`, `mxbnd`, `nbndloc`.
- [ ] `J2G` min/max bounds.
- [ ] `acc_is_present` results.
- [ ] `acc_deviceptr` values after present success.
- [ ] Parent/section address mapping.
- [ ] Pack/unpack or temporary creation.
- [ ] Actual H2D/D2H counts.
- [ ] Allocation/free counts.
- [ ] Kernel launch counts.
- [ ] Peak GPU memory.
- [ ] Wall time vs Step 18.
- [ ] Numerical validation: check, relaxed compare, strict compare where possible.

## 16. Step Gate Matrix

| Stage | READY condition | Current judgement |
|---|---|---|
| Step A coding | Static design complete; macro default OFF; no ownership/data movement changes. | READY FOR CODING |
| Ownership establishment | Step A resolves P1-P4 and YLM/VPJ/EXTAU Cases A-D. | DESIGNED BUT RUNTIME-GATED |
| Callee present conversion | Ownership commits PASS and no partial-present or pack/unpack blocker remains. | DESIGNED BUT RUNTIME-GATED |
| GPU producer connection | Present conversion PASS, P/coef blocker resolved, mapping stable, Step 18 performance recovered. | DESIGNED BUT RUNTIME-GATED |

## 17. Step A Post-Result Decision Tree

```text
Step A PASS + P1/P2/P4 valid + YLM/VPJ/EXTAU Case A
  -> Prefer minimal present-only conversion, keep current parent+index interface.

Step A PASS + any YLM/VPJ/EXTAU Case B
  -> Use parent present clauses only; avoid section present lookup.

Step A PASS + any YLM/VPJ/EXTAU Case C
  -> Implement explicit parent + index range interface before ownership.

Step A detects Case D host update
  -> Add owner-side update design before ownership, or stop.

Step A detects P3
  -> Stop. Correct P mapping before Step B.

Step A check/compare fails
  -> Revert Step A commit and inspect diagnostic side effects.

Step A introduces new large H2D/D2H, allocation/free, or pack/unpack
  -> Do not proceed to ownership; remove or isolate diagnostic.
```

## 18. Validation And Performance Gates

Minimum validation for each runtime step:

- `check_tddft_result.py check`: PASS.
- relaxed compare against GNU reference: PASS.
- direct compare against Step 18 archive: PASS under approved relaxed tolerances.
- NaN/Inf scan: no new non-finite values.
- Step A and later timing runs must be separated from diagnostic/Nsight runs.

Performance gates:

- Step A diagnostics OFF: wall time must be within normal Step 18 measurement variation.
- Step A diagnostics ON: overhead may exist, but must be bounded and not used as performance baseline.
- Ownership and producer steps: Step 18 wall time must not regress unless the commit is explicitly diagnostic-only.
- Nsight Systems gate: no new repeated large H2D/D2H from `exnlp_only_make_acc`; no loop-level allocation/free; no unexpected pack/unpack.

## 19. Failure Matrix

| Symptom | Likely causes | First split | Required evidence |
|---|---|---|---|
| partially present | Parent/section mismatch; wrong extent; duplicate ownership | Check A2-A5 address and present logs | Present table dump, Step A address lines |
| `acc_is_present` false | Missing owner enter; wrong bounds; macro path not compiled | Verify owner line and exact range | A2-A6 output |
| segmentation fault | Bounds mismatch; `NG2Q`/`NXYZ` conflict; bad dummy interface | Compare static shape and runtime bounds | stderr, A2 values |
| numerical mismatch | ia order changed; stale device data; missing update | Compare outputs and update points | check/compare logs |
| NaN/Inf | Invalid device input; uninitialized temp; wrong metadata | Check producer inputs and metadata | NaN scan, A6 output |
| performance regression | repeated copyin; pack/unpack; kernel launch growth | Nsight run | H2D/D2H and kernel counts |
| unexpected H2D/D2H | callee internal copyin remains; fallback path used | Grep compile and Nsight trace | Nsight event list |
| allocation/free increase | enter/delete inside loop; OpenACC temp creation | Nsight allocation view | allocation/free counts |
| kernel launch increase | fine-grained producer kernels | Count launches per S2 and time step | Nsight kernel summary |
| pack/unpack | noncontiguous section or descriptor temporary | Detect compiler/runtime messages | `-Minfo`, Nsight memory copies |

## 20. Build / Fallback Matrix

| Build | FFT backend | Expected source path | GPU residency path | Required protection |
|---|---|---|---|---|
| GNU + FFTW | FFTW | CPU routines | No | Must ignore OpenACC-only diagnostics. |
| Intel + FFTW | FFTW | CPU routines | No | Must not require NVHPC-only symbols. |
| NVHPC + FFTW | FFTW | NVHPC Fortran, FFTW wrapper | Optional diagnostics only | Macro OFF must keep Step 18-like behavior. |
| NVHPC + cuFFT host-copy | cuFFT | cuFFT wrapper plus current OpenACC | Current Step 18 baseline | Must remain rollback target. |
| NVHPC + cuFFT OpenACC residency | cuFFT | target path | Yes | Gated by Step A-D. |

- [UNVERIFIED] Fixed-form preprocessing flags must be confirmed before coding `FPSEID_STEP_A_DIAGNOSTIC`.
- [DECISION] If preprocessing cannot be guaranteed, use a build-script-controlled include or parameter that preserves macro-OFF behavior.

## 21. Unresolved Runtime Questions

| Question | Confirmation method | Required log | Pass condition |
|---|---|---|---|
| What are actual `NG2Q`, `NXYZ`, `NG2`, and `NGcont`? | A2 output | `FPSEID_STEPA_P` | Case P1, P2, or P4 with valid bounds. |
| Is `P(1:NXYZ,...)` ever out of bounds? | A2 plus `J2G` min/max | A2 output | No invalid section or P3 blocker. |
| Are `YLM` sections stable? | A3 output and Nsight | A3 + trace | Case A or B without pack/unpack. |
| Are `VPJ` sections stable? | A4 output and Nsight | A4 + trace | Case A or B without pack/unpack. |
| Are `EXTAU` sections stable? | A5 output and Nsight | A5 + trace | Case A or B without pack/unpack. |
| Do diagnostics add transfers? | Nsight diagnostic and timing runs | H2D/D2H summary | No new large transfer in normal timing run. |
| Does Step A preserve results? | check and relaxed compare | check logs | PASS. |
| Is peak memory acceptable? | Nsight or `nvidia-smi` | memory summary | Fits target GPU with margin. |

## 22. Self Judgement

- Step A diagnostic coding: READY FOR CODING.
- Ownership implementation: DESIGNED BUT RUNTIME-GATED.
- Callee present conversion: DESIGNED BUT RUNTIME-GATED.
- GPU producer connection: DESIGNED BUT RUNTIME-GATED.

Overall:

- [DECISION] v4 is ready to guide Step A diagnostic implementation when the environment returns.
- [BLOCKER] Ownership and GPU producer work must not begin until Step A resolves `P` / `coef` and parent/section mapping decisions.
