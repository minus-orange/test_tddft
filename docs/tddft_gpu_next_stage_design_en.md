# FPSEID21 TDDFT GPU Residency Design v5 (English)

> [Japanese version](tddft_gpu_next_stage_design_ja.md)

## 0. Document Status And Source Revision

- [CONFIRMED] Branch: `tddft-openacc-residency`.
- [CONFIRMED] Source baseline commit: `d5d42d6d7bf60217991dbe7e725529e429774903`.
- [CONFIRMED] Source tree root: `/Users/adabana/Documents/Codex/2026-06-25/aist-fpseid21`.
- [CONFIRMED] Review date: 2026-07-11.
- [CONFIRMED] Design-history commit `6b36346` preserves design revisions v1-v4 and does not alter the reviewed FPSEID21 source.
- [DECISION] This English file is the final v5 design. No v6 is planned; subsequent corrections retain the v5 title and are identified by the Git commit that contains this exact file content.
- [DECISION] An embedded design-file commit hash is intentionally not used because it would be self-referential. Git history is authoritative for the design revision; the source baseline hash above is authoritative for source line numbers.
- [DECISION] Every source line number in this document refers to the source baseline commit above, not to the design-history commit.
- [DECISION] This revision is design-only. It does not authorize a source change, build, run, or measurement.
- [DECISION] If the source commit changes, line numbers and static conclusions must be revalidated before Step A coding.

## 1. Scope, Baseline, And Non-Goals

- [CONFIRMED] Formal baseline is Step 18: about 163.31 seconds, result check PASS, relaxed GNU comparison PASS.
- [CONFIRMED] Step 19 was about 178 seconds and was not adopted.
- [CONFIRMED] Step 20 was about 819 seconds; `s2_nonlocal_make` increased to about 680 seconds.
- [DECISION] Repeated routine-internal or fine-grained section `copyin` is not an acceptable target design.
- [DECISION] Target execution model is 1 GPU / 1 MPI rank with NVHPC OpenACC and cuFFT.
- [DECISION] GNU+FFTW, Intel+FFTW, NVHPC+FFTW, and NVHPC+cuFFT host-copy fallback paths remain protected.
- [DECISION] `ia` ordering and numerical operation ordering are unchanged until separately proven equivalent.

Step A is diagnostic only. It observes the current Step 18-equivalent path and does not establish target ownership.

## 2. v4 To v5 Change History

- [DECISION] Limited Step A to observations possible without target parent residency.
- [DECISION] Added phase-specific maps for `YLM1`-`YLM5` and `VPJ1`-`VPJ5`.
- [DECISION] Fixed the OpenACC diagnostic implementation to a guarded Fortran module plus a small C wrapper.
- [DECISION] Fixed preprocessing flags and diagnostic ON/OFF build commands.
- [DECISION] Made `J2G` and `ngnl_` diagnostics bounds-safe.
- [DECISION] Separated `P` ownership role from authority state.
- [DECISION] Corrected Case P2 to use one parent mapping containing the smaller `NXYZ` sections.
- [DECISION] Replaced the old YLM/VPJ/EXTAU cases with Y0-Y4 and defined precedence.
- [DECISION] Separated saved host allocation lifetime from OpenACC device mapping lifetime.
- [DECISION] Replaced separate ownership and callee-present commits with atomic per-family commits.
- [DECISION] Expanded A1-A6 to the same coding-detail level.
- [DECISION] Added a numerical performance gate based on three-run medians.
- [DECISION] Finalized A3-A5 as separate caller-parent and callee-section diagnostics.
- [DECISION] Unified C/Fortran address storage as `intptr_t` / `c_intptr_t`.
- [DECISION] Extended A6 to both forward and reverse nonlocal blocks.
- [DECISION] Fixed integer-kind failure behavior, sentinel values, diagnostic output unit, and whole-TDDFT preprocessing scope.

## 3. Review Finding Response

| v4 review finding | v5 resolution |
|---|---|
| Active calls use `YLM1..5` and `VPJ1..5` | Section 5 maps all five calls; A3/A4 diagnose each phase once. |
| A3-A5 cannot prove target parent residency | Section 4 limits Step A; Y0 is the expected current result; target lookup is a B-stage gate. |
| OpenACC API details were missing | Section 11 fixes C and Fortran interfaces, types, absence behavior, and call ordering. |
| Preprocessor mechanism was undecided | Section 12 fixes compiler-specific preprocessing and build commands. |
| Caller diagnostics required callee-only indices | A3-A5 now split caller-parent and callee representative-section records. |
| C `uintptr_t` did not match Fortran `c_intptr_t` | Section 11 uses `intptr_t` / `c_intptr_t` exclusively. |
| A6 observed only the first nonlocal block | A6 now records forward and reverse blocks independently. |
| Integer-kind and sentinel behavior remained open | Section 11 fixes build-fail behavior, statuses, sentinel values, and `error_unit`. |
| `J2G(1:NG2Q)` may read an invalid/uninitialized tail | A2 uses only `1:min(NXYZ,NG2Q)` after positive-extent checks. |
| P authority was conflated with borrowing | Section 7 separates role and authority state. |
| Case P2 incorrectly required non-overlap | Section 8 defines one `NG2Q` parent registration and contained column sections. |
| Current sections were described as possibly noncontiguous | Section 9 confirms first-dimension sections are contiguous; compiler temporaries remain a runtime check. |
| Saved host allocation and device lifetime were conflated | Section 10 gives separate host and device lifetimes. |
| C1-C3 then D1 created a forbidden transitional state | Section 15 makes ownership and callee present conversion atomic per array family. |

## 4. Step A Observation Boundary

### 4.1 Step A observes

- [DECISION] Host-side shapes, declared bounds, and runtime extents.
- [DECISION] Host base addresses, first-element addresses, and byte offsets.
- [DECISION] Statically known contiguity of the selected first-dimension columns.
- [DECISION] The actual `YLMk`/`VPJk` family used by each TMEVL phase.
- [DECISION] Current `acc_is_present` state only.
- [DECISION] Current H2D/D2H count and size, allocation/free count, kernel count, and peak GPU memory through a separate Nsight Systems run.
- [DECISION] Current numerical result and wall time through separate validation/timing runs.

### 4.2 Step A does not prove

- [DECISION] Correctness of a future caller-owned parent mapping.
- [DECISION] Parent/section lookup after target ownership is introduced.
- [DECISION] The target callee `present` contract.
- [DECISION] Absence of a future partial-present error.

- [CURRENT] `YLM1..5`, `VPJ1..5`, and `EXTAU` have no caller-owned OpenACC parent residency in the current source.
- [DECISION] Therefore `parent_present=false` in A3-A5 is the expected Y0 result and is not a Step A failure.
- [DECISION] Target ownership lookup is validated only in atomic ownership commits B1-B3.

## 5. Current Call Path And Phase Map

### 5.1 Current path

```text
TMEVL
  host-side phase data available
  enter data copyin P
  phase 1 S2_(YLM1, VPJ1, EXTAU, NP=1)
  phase 2 S2_(YLM2, VPJ2, EXTAU, NP=2)
  phase 3 S2_(YLM3, VPJ3, EXTAU, NP=3)
  phase 4 S2_(YLM4, VPJ4, EXTAU, NP=4)
  phase 5 S2_(YLM5, VPJ5, EXTAU, NP=5)
  exit data copyout P

S2_
  create work2_ device mapping
  repeated exnlp_only_make_acc
    current per-section copyin YLMk / VPJk / EXTAU
    device write work2_ column
    host write cfac_ and ngnl_
  bulk copyin cfac_ and ngnl_
  exnlp_gemm_present_inputs
  delete work2_ / cfac_ / ngnl_ mappings
```

### 5.2 Phase 1-5 actual/dummy map

`YLM1..5` are declared at source lines 63-64. `VPJ1..5` are declared at lines 108-111. The S2 dummies are `YLM(NGcont,16)` at line 1713, `VPJ(NGcont,3,4,NTYQ)` at line 1736, and `EXTAU(NGcont,5,NTAUQ)` at line 1719.

| Phase (`NP`) | TMEVL call | Actual YLM | Actual VPJ | Actual EXTAU | Dummy correspondence |
|---:|---:|---|---|---|---|
| 1 | 549-562 | `YLM1(NGcont,16)` | `VPJ1(NGcont,3,4,NTYQ)` | `EXTAU(1,1,1)` | `YLM`, `VPJ`, `EXTAU`; `NP=1` |
| 2 | 587-600 | `YLM2(NGcont,16)` | `VPJ2(NGcont,3,4,NTYQ)` | `EXTAU(1,1,1)` | same dummies; `NP=2` |
| 3 | 614-627 | `YLM3(NGcont,16)` | `VPJ3(NGcont,3,4,NTYQ)` | `EXTAU(1,1,1)` | same dummies; `NP=3` |
| 4 | 641-654 | `YLM4(NGcont,16)` | `VPJ4(NGcont,3,4,NTYQ)` | `EXTAU(1,1,1)` | same dummies; `NP=4` |
| 5 | 668-681 | `YLM5(NGcont,16)` | `VPJ5(NGcont,3,4,NTYQ)` | `EXTAU(1,1,1)` | same dummies; `NP=5` |

- [CONFIRMED] `NP` already identifies the five phases; Step A does not add a routine argument.
- [CONFIRMED] Each `YLMk(:,lylm)`, `VPJk(:,ip,il,ity)`, and `EXTAU(:,np,itseq)` section spans the complete first dimension and is Fortran-contiguous.
- [DECISION] A3 and A4 keep independent parent/section flags:
  `diagnosed_ylm_parent(5)`, `diagnosed_ylm_section(5)`,
  `diagnosed_vpj_parent(5)`, and `diagnosed_vpj_section(5)`.
- [DECISION] A5 likewise uses `diagnosed_extau_parent(5)` and
  `diagnosed_extau_section(5)`.
- [DECISION] A caller-parent record contains only information available before `S2_`: phase, actual-family symbol, parent bounds/address, bytes, and presence. It never prints `lylm`, `ip`, `il`, `ity`, or `itseq`.
- [DECISION] A callee-section record is emitted at the first `exnlp_only_make_acc` call for each `NP`, where `lylm`, `ip`, `il`, `ity`, and `itseq` are defined. It records one representative section for that phase and does not claim to enumerate every section.
- [DECISION] Each parent and representative section is emitted at most once per phase per rank. No diagnostic is emitted on every time step.

Byte offsets from a parent base are computed, not inferred from array descriptors:

- `YLMk(1,lylm)`: `(lylm-1)*NGcont*8`.
- `VPJk(1,ip,il,ity)`: `((ip-1)+3*((il-1)+4*(ity-1)))*NGcont*8`.
- `EXTAU(1,np,itseq)`: `((np-1)+5*(itseq-1))*NGcont*16`.

The diagnostic must compare the computed offset with the observed host address difference and print both.

## 6. Current, Target, And Transition Contracts

### 6.1 TMEVL

**Current**

- [CURRENT] Declares dummy `P(NG2Q,MXBND)` at line 54 and the five YLM/VPJ families at lines 63-64 and 108-111.
- [CURRENT] Calls `MPI_COMM_RANK` at line 147.
- [CURRENT] Maps `P(1:NG2Q,1:nbndloc)` at line 532 and copies it out/deletes it at line 714.
- [CURRENT] Calls `S2_` five times using the phase map in Section 5.

**Target**

- [TARGET] TMEVL is device-lifetime owner for `P` and for the phase-array families selected by B1-B3.
- [TARGET] TMEVL performs owner-side bulk synchronization only where an audited host update requires it.
- [TARGET] TMEVL performs final P host synchronization and deletion.

**Transition**

- [DECISION] Step A changes no data clause or ownership.
- [DECISION] B1-B3 each atomically add ownership and remove the corresponding callee copyin.

### 6.2 S2_

**Current**

- [CURRENT] Receives P, a phase YLM family, a phase VPJ family, and EXTAU at lines 1693-1740.
- [CURRENT] Saved host allocatables are allocated once at lines 1810-1814.
- [CURRENT] Device mappings are created/copied/deleted around the nonlocal blocks at lines 1821, 1921, and 1926-1927, and again near 2121-2225.
- [CURRENT] Calls `exnlp_only_make_acc` repeatedly and calls `exnlp_gemm_present_inputs` at lines 1923-1924.

**Target**

- [TARGET] S2_ is a borrower of P and the phase parent arrays.
- [TARGET] S2_ does not synchronize P to host and does not change its owner.
- [TARGET] S2_ owns work2_/cfac_/ngnl_ device mappings for the initial producer design.

**Transition**

- [DECISION] No transitional commit may register a parent while leaving its matching callee `copyin` in place.
- [DECISION] No fine-grained section transfer may be added.

### 6.3 exnlp_only_make

**Current/Target**

- [CURRENT] CPU fallback routine at lines 2434-2457 uses section-oriented explicit-shape dummies.
- [TARGET] It remains available and its mathematical order is unchanged.
- [DECISION] Step A and B do not change its behavior or interface.

### 6.4 exnlp_only_make_acc

**Current**

- [CURRENT] Explicit-shape parent dummies are at lines 2464-2466.
- [CURRENT] Scalar `cfac` is generated on host at lines 2470-2472.
- [CURRENT] The OpenACC loop at lines 2480-2486 copies YLM, EXTAU, and VPJ sections internally and writes `work1` on device.

**Target**

- [TARGET] Caller owns the parent mapping.
- [TARGET] Callee uses `present` only for a family after that family's atomic B commit.
- [TARGET] Callee performs no allocation, delete, update, copyin, or copyout for caller-owned arrays.

**Transition**

- [DECISION] B1 removes only YLM copyin while establishing all YLM family mappings.
- [DECISION] B2 removes only VPJ copyin while establishing all VPJ family mappings.
- [DECISION] B3 removes only EXTAU copyin while establishing EXTAU mapping.
- [DECISION] Remaining not-yet-converted families may retain their current copyin until their own atomic commit.

### 6.5 exnlp_gemm / exnlp_gemm_present_inputs / exnlp_gemm_body_fused

- [CURRENT] `exnlp_gemm` self-manages input copies and `ct1` at lines 2491-2518; it remains a fallback.
- [CURRENT] `exnlp_gemm_present_inputs` at lines 2521-2532 has no local data movement.
- [CURRENT] `exnlp_gemm_body_fused` receives `coef(ng2q,mxbnd)` and present inputs at lines 2534-2548 and preserves the host `ia` loop at line 2543.
- [TARGET] The residency path uses `exnlp_gemm_present_inputs`; it allocates and transfers nothing.
- [TARGET] `coef`, `work1`, `cfac`, and `ngnl` exact ranges must already be present.
- [TARGET] The `ia` sequence is unchanged.

## 7. P Ownership Role And Authority State

### 7.1 Roles

| Scope | Role |
|---|---|
| TMEVL | `OWNER` of P device lifetime |
| S2_ | `BORROWER` |
| exnlp GEMM routines | `NESTED_BORROWER` |

`PRESENT_BORROWED` is a role/contract description, not an authority state.

### 7.2 Authority transitions

```text
Before TMEVL mapping
  HOST_ONLY

TMEVL line 532: enter data copyin
  MIRRORED_HOST_AUTH

First GPU kernel that writes P/coef
  MIRRORED_DEVICE_AUTH

S2_ return
  owner remains TMEVL
  authority remains MIRRORED_DEVICE_AUTH
  no host synchronization

TMEVL line 714: copyout
  MIRRORED_HOST_AUTH during synchronization
  then delete device mapping
  HOST_ONLY
```

- [DECISION] S2_ may update the borrowed device object but may not claim ownership, copy it out, or delete it.
- [DECISION] A callee return never changes authority merely because borrowing ends.

## 8. P / coef / J2G Decision Tree

### 8.1 Static facts

- [CONFIRMED] TMEVL P physical dummy shape is `P(NG2Q,MXBND)` at line 54.
- [CONFIRMED] S2_ P dummy shape is `P(NG2Q,mxbnd)` at line 1707.
- [CONFIRMED] GEMM `coef` dummy shape is `coef(ng2q,mxbnd)` at line 2537.
- [CONFIRMED] Parent P mapping is `P(1:NG2Q,1:nbndloc)` at lines 532 and 714.
- [CONFIRMED] Current local-potential directives use hazardous `P(1:NXYZ,1:nbndloc)` expressions at lines 1942, 1962, and 2091.
- [CONFIRMED] If `NXYZ < NG2Q` and `nbndloc > 1`, `P(1:NXYZ,1:nbndloc)` is not one contiguous byte span because each P column has leading dimension `NG2Q`.
- [CONFIRMED] At lines 1964-1968 and 2093-2100, `IG=1:NXYZ` indexes the first dimension of P, while `JG=J2G(IG)` indexes `RHO1_`/`RHO2_`, whose first dimension is `NXYZ`.
- [DECISION] Consequently, `NXYZ<=NG2Q` proves the P access extent, while every active J2G value must satisfy `1<=J2G(IG)<=NXYZ`. These are separate checks.
- [DECISION] A2 never treats that multi-column subsection as one C byte range.

### 8.2 Safe A2 evaluation order

At S2_ line 1817, before nonlocal generation:

1. Print `NG2Q`, `NXYZ`, `NG2`, `NGcont`, `mxbnd`, `nbndloc`, `nbegin`, and `nend`.
2. Require `NXYZ>0` and `NG2Q>0` before any min/max operation.
3. Set `j2g_extent=min(NXYZ,NG2Q)`.
4. Evaluate `minval/maxval(J2G(1:j2g_extent))` only when `j2g_extent>0` and require every value to be in `1:NXYZ`, because J2G values index RHO storage.
5. Check `nbndloc>=0` and `nbndloc<=mxbnd`.
6. Query the contiguous physical parent P range `NG2Q*nbndloc` only when dimensions are valid.
7. If `NXYZ<=NG2Q`, query bounded per-column active ranges `P(1:NXYZ,iib)` for `iib=1` and `iib=nbndloc`; do not query a packed aggregate.

At `exnlp_gemm_body_fused`, immediately before the host `ia` loop at line 2543 and only once per rank:

8. Print the `coef(ng2q,mxbnd)` dummy bounds, `nbndloc`, host address, present result, and device address.
9. Query `coef(1:ng2q,1:nbndloc)` only after positive extent and `nbndloc<=mxbnd` checks.
10. Compare its host/device addresses with the P parent record from S2_; this is an observation, not a proof that a future mapping is correct.

At A6, after line 1921 and only when `loopcnt>0` and `ngnl_` is fully generated:

11. Evaluate `minval(ngnl_(1:loopcnt))>=0`.
12. Evaluate `maxval(ngnl_(1:loopcnt))<=NGcont` and `<=NG2Q`.
13. Record failing index/value if either condition fails.

`ngnl_` is not read in A2 because it has not yet been generated there.

### 8.3 Cases

| Case | Runtime relation | Parent mapping | Additional mapping allowed? | Required bounds | Source action | Gate |
|---|---|---|---|---|---|---|
| P1 | `NG2Q == NXYZ` | One `P(1:NG2Q,1:nbndloc)` mapping | No duplicate mapping | `nbndloc<=mxbnd`; active J2G values in `1:NXYZ`; ngnl valid | Normalize clause spelling to NG2Q after measurement | Stable present and PASS |
| P2 | `NG2Q > NXYZ` | One physical `P(1:NG2Q,1:nbndloc)` mapping | No `P(1:NXYZ,:)` registration | Each `P(1:NXYZ,iib)` is contained; active J2G values in `1:NXYZ`; ngnl valid | Replace hazardous aggregate subsection clauses with parent mapping plus kernel bounds/present contract | B stage must show contained lookup without partial present |
| P3 | `NG2Q < NXYZ` | Current physical declaration cannot contain the `IG=1:NXYZ` P access | No | BLOCKED before any P active-section query; inspect declarations and kernel ranges | Correct declaration/range before ownership | Stop and rollback |
| P4 | Physical NG2Q and a statically identified kernel uses a smaller active IG range than NXYZ | One physical NG2Q parent | No duplicate section mapping | Proven IG range within `1:NG2Q`; corresponding J2G values in `1:NXYZ`; ngnl valid | Document the exact per-kernel active range; do not infer it only from values | Explicit per-kernel source proof and PASS |

- [BLOCKER] P2/P4 source corrections are not authorized until A2/A6 values are available.

## 9. YLM / VPJ / EXTAU Decision Tree

### 9.1 Static properties

- [CONFIRMED] The selected sections span the complete first dimension and are contiguous in Fortran storage order.
- [CONFIRMED] Current active call sites pass parent arrays plus scalar indices; they do not pass noncontiguous section actual arguments to `exnlp_only_make_acc`.
- [UNVERIFIED] A compiler-generated temporary or unexpected OpenACC mapping behavior remains possible and is checked with compiler reports and Nsight.

### 9.2 Cases and precedence

Apply the first matching condition in this order: Y4 host update, Y3 compiler temporary, Y2 lookup failure, Y1 success. Y0 describes the pre-ownership current state.

| Case | Observation | Decision |
|---|---|---|
| Y0 | Current source: no parent residency; `parent_present=false`; callee section copyin exists | Expected Step A result. Keep Step 18 path. Proceed to B only after shape/address logs are complete. |
| Y1 | After an atomic B commit: parent present, section lookup succeeds, offsets match, no temporary | Keep current parent+index interface; callee uses present-only. |
| Y2 | After ownership: section lookup fails, partial present occurs, or device/base offset differs | Roll back B commit. Correct parent range or use parent-base present plus scalar index; do not add section mapping. |
| Y3 | Compiler report or trace shows pack/unpack/temporary | Roll back. Identify declaration/compiler cause; use a dedicated contiguous buffer or a specifically named alternate interface only after separate review. |
| Y4 | Host modifies parent during its device lifetime | Owner performs one audited bulk `update device` after host production; callee transfer remains forbidden. |

- [DECISION] Step A classifies Y0 and host layout only. Y1-Y4 are evaluated in B1-B3 runtime gates.
- [DECISION] No generic “noncontiguous section” branch is retained because static layout already proves contiguity.

## 10. Current And Target Array Lifetimes

### 10.1 Parent and propagation arrays

| Array | Host declaration/shape | Current authority/owner | Target authority/owner | Producer | Consumer | Runtime gate |
|---|---|---|---|---|---|---|
| P | line 54, `NG2Q,MXBND` | HOST_ONLY then TMEVL-mapped | TMEVL owner; device auth while kernels run | exkin/S2 kernels | S2/exnlp | P1-P4 |
| YLM1..5 | lines 63-64, each `NGcont,16` | host authoritative; higher host producer UNVERIFIED | TMEVL device-lifetime owner, read-only device borrower | host setup | `exnlp_only_make_acc` read | Y0-Y4 per phase |
| VPJ1..5 | lines 108-111, each `NGcont,3,4,NTYQ` | host authoritative; higher host producer UNVERIFIED | TMEVL device-lifetime owner, read-only device borrower | host setup | `exnlp_only_make_acc` read | Y0-Y4 per phase |
| EXTAU | line 79, `NGcont,5,NTAUQ` | host authoritative | TMEVL device-lifetime owner after B3 | host setup | `exnlp_only_make_acc` read | Y0-Y4 |
| RHO1_/RHO2_ | line 1744, `NXYZ,mxbnd` | S2-owned current kernel storage | unchanged in A-C | S2 kernels | S2 kernels | later design |
| VG | line 70/1719, `NXYZ` | current caller/S2 use | unchanged in A-C | host potential setup | S2 kernels | later design |

### 10.2 Saved host allocation versus device mapping

| Array | Host allocation lifetime | Current device mapping lifetime | Initial target authority | Owner | Producer | Consumer | Delete responsibility |
|---|---|---|---|---|---|---|---|
| work2_ | `SAVE`; allocated once at lines 1810/1813; no source deallocation found | Created/deleted for each nonlocal block, lines 1821/1926 and 2121/2225 | DEVICE_AUTH while mapped | S2_ | exnlp_only_make_acc | exnlp_gemm_present_inputs | S2_ deletes device mapping only |
| cfac_ | `SAVE`; allocated once at line 1811 | Bulk copyin/delete per nonlocal block | MIRRORED_HOST_AUTH initially | S2_ | host scalar generation | GEMM device kernel | S2_ device delete |
| ngnl_ | `SAVE`; allocated once at line 1812 | Bulk copyin/delete per nonlocal block | MIRRORED_HOST_AUTH initially | S2_ | host ia metadata loop | GEMM host ia loop/device kernel | S2_ device delete |

- [DECISION] “S2-local” in this design refers only to device mapping lifetime, not the saved host allocation lifetime.
- [DECISION] Initial target keeps `cfac_` and `ngnl_` host authoritative and transfers exactly `1:loopcnt` once per nonlocal block.
- [DECISION] Initial target keeps the host `ia` loop. Device-authoritative metadata requires a separate design.
- [TARGET] work2_ is device-generated and device-consumed with no host round trip.

## 11. Step A OpenACC Diagnostic API Specification

### 11.1 Chosen implementation

- [DECISION] Diagnostics are implemented only for the NVHPC/OpenACC build.
- [DECISION] A guarded Fortran module `mod_stepa_diag.F90` uses `iso_c_binding` and `iso_fortran_env`, but does not call the OpenACC runtime directly.
- [DECISION] Host/device address and presence queries use a small C wrapper `fpseid_stepa_acc_diag.c` including `<openacc.h>`.
- [DECISION] This avoids adding `TARGET` to production arrays and avoids relying on compiler-specific Fortran pointer return types.
- [DECISION] GNU and Intel builds never compile or reference this module/wrapper when the macro is OFF.

### 11.2 C-facing functions

The C file exposes three typed binding labels with identical C pointer semantics:

```c
int fpseid_acc_query_c16(const void *host, size_t nbytes,
                         intptr_t *host_addr, intptr_t *device_addr);
int fpseid_acc_query_r8(const void *host, size_t nbytes,
                        intptr_t *host_addr, intptr_t *device_addr);
int fpseid_acc_query_i4(const void *host, size_t nbytes,
                        intptr_t *host_addr, intptr_t *device_addr);
```

Each calls the same internal helper:

1. Set `host_addr=(intptr_t)host`.
2. If `host==NULL` or `nbytes==0`, set `device_addr=0` and return 0.
3. Call C OpenACC `acc_is_present((void *)host,nbytes)`.
4. Call `acc_deviceptr((void *)host)` only when present is nonzero.
5. Set `device_addr=0` when absent.
6. Return `1` for present and `0` for absent.

### 11.3 Fortran `bind(C)` contract

The module defines specific procedures for complex*16, real*8, and default integer. Their first dummy is an interoperable assumed-size array, not `type(c_ptr),value`, so callers pass the first array element without `TARGET` or `c_loc`.

```fortran
integer(c_int) function fpseid_acc_query_c16(base,nbytes,haddr,daddr) &
  bind(C,name="fpseid_acc_query_c16")
  import c_int, c_size_t, c_intptr_t, c_double_complex
  complex(c_double_complex), intent(in) :: base(*)
  integer(c_size_t), value :: nbytes
  integer(c_intptr_t), intent(out) :: haddr, daddr
end function
```

Equivalent typed interfaces use `real(c_double) :: base(*)` and `integer(c_int) :: base(*)`.

- [DECISION] Byte counts use `integer(c_size_t)`.
- [DECISION] C address outputs use `intptr_t`; Fortran address outputs use `integer(c_intptr_t)`. The C helper casts host/device pointers to `intptr_t`. No `uintptr_t` object is passed through a `c_intptr_t` interface.
- [DECISION] Addresses are printed with hexadecimal `Z0`. Decimal address output is not part of the stable diagnostic format.
- [DECISION] Element byte size is obtained with `c_sizeof(first_element)`; total bytes are checked for positive extents before multiplication.
- [DECISION] Query status is printed as one of `OK`, `ABSENT`, or `SKIPPED_INVALID_BOUNDS`. For `ABSENT`, `present=0`, `haddr` is the observed host address, and `daddr=0`. For `SKIPPED_INVALID_BOUNDS`, `present=-1`, `haddr=0`, `daddr=0`, and every skipped min/max field is `0`; the corresponding `*_valid=F` field is authoritative.
- [DECISION] The C wrapper is the sole location that calls `acc_deviceptr`, and only after present succeeds.
- [DECISION] No diagnostic API calls `acc_wait` or performs allocation/data movement.
- [DECISION] `mod_stepa_diag` owns bounds validation, byte-count calculation, saved diagnosed flags, stable-format rendering, and all diagnostic output. The C wrapper owns only `acc_is_present`/`acc_deviceptr` calls and pointer-to-`intptr_t` conversion; it performs no output, allocation, synchronization, or state management.
- [DECISION] All `FPSEID_STEPA_*` records are written by rank 0 to `error_unit` from `iso_fortran_env`; stdout remains reserved for the application result and existing profile output.
- [DECISION] Diagnostic ON supports the existing default-integer arrays only when default integer is interoperable with `integer(c_int)`. A1 adds a compile-only kind probe using the same TDDFT Fortran flags and a call from a default-integer actual to an `integer(c_int)` explicit interface. Probe failure terminates the diagnostic-ON build with `ERROR: FPSEID Step A requires default integer == c_int`. No alternate integer wrapper or implicit reinterpretation is permitted in Step A. Diagnostic OFF does not run this probe.

### 11.4 Rank and bounded-output state

- [DECISION] `mod_stepa_diag` obtains `my_rank` once using `MPI_COMM_RANK`; this is a local MPI query and not a synchronization.
- [DECISION] The supported Step A run is `-np 1`; output still includes `rank=`.
- [DECISION] Saved flags bound A2 P and coef records to once each; A3-A5 parent and representative-section records to once per phase; and A6 to once for each of the forward and reverse blocks.

## 12. Preprocessor And Build Specification

### 12.1 Compile guard

- [DECISION] Guard name is `FPSEID_STEP_A_DIAGNOSTIC`.
- [DECISION] All diagnostic `use`, calls, state, and output in production source are enclosed by `#ifdef FPSEID_STEP_A_DIAGNOSTIC` with `#` in column 1.
- [DECISION] Undefined macro means complete source removal; OFF has no runtime call, output, branch, synchronization, or performance effect.

### 12.2 Compiler preprocessing flags

`mk_ifort.sh` compiler detection will select exactly one preprocessing flag:

| Compiler | Fixed-form preprocessing flag | Diagnostic allowed |
|---|---|---|
| NVHPC | `-Mpreprocess` | Yes |
| GNU | `-cpp` | No; macro remains undefined |
| Intel classic | `-fpp` | No; macro remains undefined |

- [DECISION] `mk_ifort.sh` currently compiles all TDDFT Fortran sources in one compiler invocation (current lines 176-185). A1 therefore adds the selected preprocessing flag once to that complete TDDFT Fortran invocation. It does not split `tmevl10_Avec_v4.f` into a separate object build.
- [DECISION] Applying `-Mpreprocess`, `-cpp`, or `-fpp` to the complete TDDFT Fortran invocation is the fixed implementation. The macro remains undefined for OFF builds, so guarded source is removed. CG and SD commands are unchanged.
- [DECISION] `-DFPSEID_STEP_A_DIAGNOSTIC=1`, `mod_stepa_diag.F90`, and `fpseid_stepa_acc_diag.o` are added only when shell variable `FPSEID_STEP_A_DIAGNOSTIC=1` and the compiler probe identifies NVHPC.
- [DECISION] A shell value of `0` or an unset variable does not emit a `-D...=0`; the preprocessor symbol remains undefined so `#ifdef` blocks are removed.
- [DECISION] Requesting diagnostic ON for GNU/Intel terminates the build with a clear error.
- [DECISION] Diagnostic ON requires NVHPC `-acc`; the C wrapper is compiled with `nvc -acc` and linked into the MPI Fortran executable.
- [DECISION] In `mk_ifort.sh`, the optional module is placed before `tmevl10_Avec_v4.f` in the line 176-184 source list, and the optional C object is placed with `$FFT_OBJS`; no production symbol refers to either when OFF.
- [DECISION] `tools/build_nvhpc.sh` defines `FPSEID_STEP_A_DIAGNOSTIC=${FPSEID_STEP_A_DIAGNOSTIC:-0}` near the existing build switches at lines 13-15 and forwards it in the TDDFT subshell at lines 185-200. It does not forward the diagnostic to CG or SD.
- [DECISION] A1's default-integer/c_int compile probe runs only after NVHPC detection and before compiling the wrapper/module. A failed probe exits before any production object or executable is replaced.

The diagnostic-ON probe command is fixed as:

```sh
if ! "$FC" $FFLAGS $PREPROCESS_FLAG -c stepa_default_int_probe.F90 \
     -o stepa_default_int_probe.o; then
  rm -f stepa_default_int_probe.o
  echo "ERROR: FPSEID Step A requires default integer == c_int" >&2
  exit 1
fi
rm -f stepa_default_int_probe.o
```

`stepa_default_int_probe.F90` passes a default-integer actual to a contained procedure whose explicit dummy is `integer(c_int)`. It has no runtime role and is never linked. `PREPROCESS_FLAG` is the compiler-selected flag from the table above. Diagnostic OFF neither compiles nor references this file.

`tools/build_nvhpc.sh` passes the shell variable to `mk_ifort.sh`.

Diagnostic ON from repository root:

```sh
ENABLE_GPU_FFT=1 \
FPSEID_STEP_A_DIAGNOSTIC=1 \
BUILD_REPORT=1 \
TDDFT_FFLAGS="-O2 -mp -Msave -Mlarge_arrays -acc" \
./tools/build_nvhpc.sh
```

Diagnostic OFF / normal timing build:

```sh
ENABLE_GPU_FFT=1 \
FPSEID_STEP_A_DIAGNOSTIC=0 \
BUILD_REPORT=1 \
TDDFT_FFLAGS="-O2 -mp -Msave -Mlarge_arrays -acc" \
./tools/build_nvhpc.sh
```

- [UNVERIFIED] Exact NVHPC installation include/library discovery remains a runtime-environment check; it does not change the selected guard design.

## 13. Step A Coding Specification

Global prohibitions for A1-A6:

- no data-clause, enter/exit, update, delete, ownership, routine-interface, FFT-path, or calculation-order change;
- no `acc_wait`;
- no new allocation in a time-step/nonlocal loop;
- no every-step output;
- no direct `acc_deviceptr` call outside the C wrapper;
- no performance judgment from a diagnostic-ON or Nsight run.

### A1: guarded infrastructure only

| Field | Specification |
|---|---|
| Hypothesis | Guarded infrastructure compiles and OFF has zero runtime effect. |
| Files | `mk_ifort.sh`, `tools/build_nvhpc.sh`, new `mod_stepa_diag.F90`, new `fpseid_stepa_acc_diag.c`, new compile-only `stepa_default_int_probe.F90`, guarded no-op imports in `tmevl10_Avec_v4.f`. |
| Symbols | Shell/macro `FPSEID_STEP_A_DIAGNOSTIC`; typed query interfaces; saved rank/output state; compile-only default-integer/c_int probe. |
| Guard | Entire module reference and production-source call surface under the macro. |
| Import locations | In each affected routine, after the complete `subroutine` statement and before `implicit`: TMEVL before current line 50, S2_ before line 1705, `exnlp_only_make_acc` before line 2462, and `exnlp_gemm_body_fused` before line 2536. Each `use mod_stepa_diag` is guarded. |
| Call location | No computational diagnostic call yet. No module initializer performs I/O or runtime queries. |
| Output | None in both OFF and ON builds. A1 is compile/link scaffolding only. |
| Count | Zero runtime diagnostic calls. |
| API | Section 11 only, including the NVHPC default-integer/c_int compile probe. The Fortran module owns validation/output; the C wrapper owns OpenACC pointer queries only. |
| Forbidden | Any array query or data movement. |
| Validation | All fallback builds with macro OFF; NVHPC ON kind-probe compile and link; no A1 output; OFF check/compare and timing. The probe object is not linked and is removed immediately after a successful probe. |
| Rollback | Revert A1. |

### A2: P/J2G/coef diagnostics

| Field | Specification |
|---|---|
| Hypothesis | P1-P4 and safe active bounds can be classified. |
| Files | `tmevl10_Avec_v4.f`, `mod_stepa_diag.F90`. |
| Symbol | `fpseid_stepa_diag_p`. |
| Guard | Macro required. |
| Exact call | P/J2G record in S2_ after `nbndloc` assignment at line 1817 and before line 1818; coef record in `exnlp_gemm_body_fused` immediately before line 2543. |
| Rank/count | Once per rank; supported run rank 0 only. |
| Output | `FPSEID_STEPA_P rank= sample_np= ng2q= nxyz= ng2= ngcont= mxbnd= nbndloc= nbegin= nend= p_lb1= p_ub1= p_lb2= p_ub2= j2g_lb= j2g_ub= j2g_extent= j2g_min= j2g_max= j2g_valid= p_index_bounds_ok= j2g_value_bounds_ok= parent_status= parent_present= haddr= daddr= first_col_status= first_col_present= last_col_status= last_col_present= bounds_ok=` and one `FPSEID_STEPA_COEF rank= sample_np= ng2q= mxbnd= nbndloc= coef_lb1= coef_ub1= coef_lb2= coef_ub2= query_status= present= haddr= daddr= p_haddr= p_daddr= host_offset= device_offset=`. `sample_np` is only the first observed S2 phase; the P/coef classification is phase-independent and does not claim five-phase coverage. |
| API | Complex query for P; no aggregate NXYZ multi-column byte query. |
| Forbidden | Reading J2G outside `1:min(NXYZ,NG2Q)`; reading ngnl_; querying invalid bounds; treating J2G values as P indices; calling a pointer query after a failed present test. |
| Sentinel/output | Section 11.3 status/sentinel rules; rank 0 `error_unit` only. Invalid bounds produce no OpenACC query. |
| Validation | OFF and ON check/compare PASS; one P and one coef record classify the P case. |
| Rollback | Revert A2 only. |

### A3: YLM1-5 phase diagnostics

| Field | Specification |
|---|---|
| Hypothesis | All five actual families and section offsets match explicit-shape dummy storage. |
| Files | `tmevl10_Avec_v4.f`, `mod_stepa_diag.F90`. |
| Symbol/state | `fpseid_stepa_diag_ylm_parent`, `fpseid_stepa_diag_ylm_section`; independent `diagnosed_ylm_parent(5)` and `diagnosed_ylm_section(5)`. |
| Guard | Macro required. |
| Exact calls | Parent record immediately before each S2 call at lines 549, 587, 614, 641, 668. It receives the complete actual `YLMk` and phase only. Section record is immediately before line 2480 on the first `exnlp_only_make_acc` invocation matching each `NP`, after `lylm` is assigned at lines 2475-2479. |
| Phase/count | Phases 1-5; exactly one parent record and at most one representative section record per phase. |
| Parent output | `FPSEID_STEPA_YLM_PARENT rank= phase= symbol=YLMk ngcont= parent_lb1= parent_ub1= parent_lb2= parent_ub2= parent_bytes= query_status= parent_present= parent_haddr= parent_daddr=`. It contains no `lylm` or section field. |
| Section output | `FPSEID_STEPA_YLM_SECTION rank= phase= symbol=YLMk ngcont= lylm= section_lb= section_ub= section_bytes= query_status= section_present= section_haddr= section_daddr= expected_offset= observed_offset= contiguous=T`. This is the first representative section for the phase, not an enumeration of every `lylm`. |
| API | Real*8 query; current `parent_present=F` accepted as Y0. |
| Forbidden | Materializing a section temporary or changing current copyin. |
| Sentinel/output | Section 11.3 rules; rank 0 `error_unit`. Invalid `lylm` skips the section query and prints `SKIPPED_INVALID_BOUNDS`. |
| Validation | Five parent and five bounded representative-section records; check/compare PASS. |
| Rollback | Revert A3. |

### A4: VPJ1-5 phase diagnostics

| Field | Specification |
|---|---|
| Hypothesis | All five VPJ families and indexed-column offsets match. |
| Files | `tmevl10_Avec_v4.f`, `mod_stepa_diag.F90`. |
| Symbol/state | `fpseid_stepa_diag_vpj_parent`, `fpseid_stepa_diag_vpj_section`; independent `diagnosed_vpj_parent(5)` and `diagnosed_vpj_section(5)`. |
| Guard | Macro required. |
| Exact calls | Parent record at the same five caller S2 sites using complete actual `VPJk` plus phase. Section record immediately before line 2480 on the first matching `NP`, where `ip`, `il`, and `ity` are available from the S2 loops. |
| Phase/count | Phases 1-5; one parent and at most one representative section record per phase. |
| Parent output | `FPSEID_STEPA_VPJ_PARENT rank= phase= symbol=VPJk ngcont= ntyq= parent_lb1= parent_ub1= parent_lb2= parent_ub2= parent_lb3= parent_ub3= parent_lb4= parent_ub4= parent_bytes= query_status= parent_present= parent_haddr= parent_daddr=`. It contains no `ip`, `il`, or `ity`. |
| Section output | `FPSEID_STEPA_VPJ_SECTION rank= phase= symbol=VPJk ngcont= ntyq= ip= il= ity= section_lb= section_ub= section_bytes= query_status= section_present= section_haddr= section_daddr= expected_offset= observed_offset= contiguous=T`. |
| API | Real*8 query; Y0 absence is normal. |
| Forbidden | Interface/data-clause changes. |
| Sentinel/output | Section 11.3 rules; rank 0 `error_unit`. Invalid indices skip the query. |
| Validation | Five parent and five bounded representative-section records and PASS. |
| Rollback | Revert A4. |

### A5: EXTAU phase diagnostics

| Field | Specification |
|---|---|
| Hypothesis | Common EXTAU parent and phase-selected planes have correct offsets. |
| Files | `tmevl10_Avec_v4.f`, `mod_stepa_diag.F90`. |
| Symbol/state | `fpseid_stepa_diag_extau_parent`, `fpseid_stepa_diag_extau_section`; independent `diagnosed_extau_parent(5)` and `diagnosed_extau_section(5)`. |
| Guard | Macro required. |
| Exact calls | Parent record before each S2 site using the complete TMEVL EXTAU parent plus phase. Section record immediately before line 2480 on the first matching `NP`, where `np` and `itseq` are available. |
| Phase/count | NP 1-5; one parent and at most one representative section record per phase. |
| Parent output | `FPSEID_STEPA_EXTAU_PARENT rank= phase= ngcont= ntauq= parent_lb1= parent_ub1= parent_lb2= parent_ub2= parent_lb3= parent_ub3= parent_bytes= query_status= parent_present= parent_haddr= parent_daddr=`. It contains no `itseq`. |
| Section output | `FPSEID_STEPA_EXTAU_SECTION rank= phase= ngcont= ntauq= np= itseq= section_lb= section_ub= section_bytes= query_status= section_present= section_haddr= section_daddr= expected_offset= observed_offset= contiguous=T`. |
| API | Complex query; Y0 absence is normal. |
| Forbidden | EXTAU update or copyin change. |
| Sentinel/output | Section 11.3 rules; rank 0 `error_unit`. Invalid `np`/`itseq` skips the query. |
| Validation | Five parent and five bounded representative-section records and PASS. |
| Rollback | Revert A5. |

### A6: nonlocal output and metadata diagnostics

| Field | Specification |
|---|---|
| Hypothesis | work2_, cfac_, and ngnl_ current ranges satisfy the consumer contract. |
| Files | `tmevl10_Avec_v4.f`, `mod_stepa_diag.F90`. |
| Symbol/state | `fpseid_stepa_diag_nonlocal`; `diagnosed_nonlocal(2)` indexed as 1=`forward`, 2=`reverse`. |
| Guard | Macro required. |
| Exact calls | Forward record after line 1921 and before line 1923. Reverse record after line 2220 and before line 2222. Both are after metadata generation/copyin and before their consumer. |
| Rank/count | Exactly one `forward` and one `reverse` record per rank. |
| Output | `FPSEID_STEPA_NONLOCAL rank= block=forward|reverse loopcnt= work2_ncol= ngcont= ng2q= ngnl_min= ngnl_max= ngnl_valid= ngnl_bounds_ok= work2_status= work2_present= cfac_status= cfac_present= ngnl_status= ngnl_present= work2_haddr= work2_daddr= cfac_haddr= cfac_daddr= ngnl_haddr= ngnl_daddr=`. |
| API | Complex and integer queries. Device pointer is zero when absent. |
| Preconditions | For each block independently: metadata generation is complete and the matching copyin at line 1921 or 2220 has completed. `loopcnt>0` is required for min/max and OpenACC queries; otherwise a skipped record is emitted. |
| Forbidden | Evaluation before ngnl_ generation; lifetime/data transfer change. |
| Sentinel/output | Section 11.3 rules; rank 0 `error_unit`. `loopcnt<=0` prints a single skipped record for that block and performs no min/max or OpenACC query. |
| Validation | Both block records present, bounds true, and check/compare PASS. |
| Rollback | Revert A6. |

All A commits use the ON/OFF commands in Section 12.

## 14. Step A Runtime Evidence Package

Save one monotonic archive label such as `nvhpc_cufft_1rank_o2_STEPA_01` containing:

For B1 and later ownership logs, the five-phase Y1 conditions for YLM can be
checked automatically with:

```sh
python3 ./tools/check_stepa_ownership.py --family ylm /path/to/tddft.err
```

The check validates parent/section `query_status=OK`, present values,
symbols, contiguity, expected/observed offsets, and matching `ngcont`. Numerical
correctness and the performance gate remain separate checks using
`check_tddft_result.py` and the archived wall time.

- source commit and build command;
- compiler version and `-Minfo` report;
- A1-A6 output;
- normal OFF run stdout/stderr and check/compare results;
- diagnostic ON run stdout/stderr and check/compare results;
- Nsight Systems report and summaries for H2D/D2H, allocations, kernels, and GPU idle gaps;
- `nvidia-smi` GPU model, driver, and peak memory sample;
- three OFF timing runs and median.

## 15. Atomic Commit Plan

| Commit | One hypothesis | Exact scope | Preconditions | Non-goals | Validation/performance gate | Rollback |
|---|---|---|---|---|---|---|
| A1 | Guarded diagnostic infrastructure has zero OFF effect | Section 13 A1 only | Source baseline matches Section 0 and final v5 is tracked in Git | No array query | OFF build paths; ON NVHPC kind probe/link; OFF median gate | Revert A1 |
| A2 | P/J2G can be classified safely | A2 only | A1 | No mapping change | PASS and P1-P4 output | Revert A2 |
| A3 | Five YLM parents and representative sections are known | A3 only | A2 | No ownership; no full section enumeration | Five parent plus five section records, PASS | Revert A3 |
| A4 | Five VPJ parents and representative sections are known | A4 only | A3 | No ownership; no full section enumeration | Five parent plus five section records, PASS | Revert A4 |
| A5 | EXTAU parent and representative phase sections are known | A5 only | A4 | No ownership; no full section enumeration | Five parent plus five section records, PASS | Revert A5 |
| A6 | Both nonlocal blocks satisfy current range/metadata contracts | A6 only | A5 | No producer change | Forward and reverse bounds true, PASS | Revert A6 |
| B1 | YLM family parent residency can replace YLM section copyin | In one commit: map YLM1..5 in caller, remove only YLM callee copyin, add YLM present, delete at owner | A3 complete; Y0 understood | No VPJ/EXTAU change | Y1 or diagnosed Y2/Y3/Y4; PASS; <=+3% | Revert B1 |
| B2 | VPJ family parent residency can replace VPJ section copyin | Atomic VPJ1..5 owner+present conversion | B1 PASS, A4 complete | No EXTAU change | same | Revert B2 |
| B3 | EXTAU residency can replace EXTAU section copyin | Atomic EXTAU owner+present conversion | B2 PASS, A5 complete | No work2 change | same | Revert B3 |
| C1 | work2_ device lifetime contract can be fixed without transfer change | Normalize exact create/delete range and assertions only | B1-B3 PASS, A6 complete | No producer algorithm change | PASS, no allocation growth | Revert C1 |
| C2 | GPU producer can feed present consumer | exnlp_only_make_acc -> work2_ -> present GEMM | C1 PASS, P gate resolved | No cfac/ngnl authority change | PASS, Step 18 gate | Revert C2 |
| C3 | cfac_ host-authoritative bulk transfer is sufficient | Exactly `cfac_(1:loopcnt)` once per block | C2 PASS | No device generation | PASS, transfer count as designed | Revert C3 |
| C4 | ngnl_ host-authoritative bulk transfer is sufficient | Exactly `ngnl_(1:loopcnt)` once per block | C3 PASS | No ia-loop/device-authority change | PASS, bounds and transfer count | Revert C4 |
| D1 | Any remaining work2_ host round trip can be removed | work2_ only | C2-C4 PASS | No metadata redesign | PASS and faster/not slower | Revert D1 |
| D2 | Metadata transfers can be reduced safely | cfac_/ngnl_ only | D1 PASS | No ia order change | strict audit plus performance gain | Revert D2 |

- [DECISION] Existing parent+index interfaces are retained unless B runtime evidence proves Y2/Y3. No unused alternate-interface commit is planned.
- [DECISION] No commit contains caller ownership while retaining the matching callee `copyin`.

## 16. Performance And Numerical Gates

### 16.1 Normal timing run

- diagnostic macro OFF;
- same node, GPU, input, compiler flags, MPI/OpenMP settings;
- three runs unless scheduler constraints are explicitly recorded;
- compare median wall time;
- formal refreshed baseline is a new three-run Step 18-equivalent median;
- accept median regression no greater than 3%;
- 168.2 seconds is only a reference ceiling derived from the historic single value 163.31 seconds.

Diagnostic ON and Nsight runs are never performance baselines.

### 16.2 Numerical gate

Every runtime commit requires:

- `check_tddft_result.py check`: PASS;
- relaxed GNU comparison: PASS;
- direct Step 18 archive comparison: PASS under approved tolerance;
- no new NaN/Inf;
- 2-step smoke test before 50/100-step runs;
- unchanged `ia` order and force/position/velocity cardinality.

## 17. Static Checklist

- [ ] Branch and source commit match Section 0.
- [ ] Final v5 file is tracked by a Git commit; its content matches the reviewed working file, while source line references still resolve against the source baseline commit.
- [ ] All phase call lines and actual symbols match source.
- [ ] Dummy/actual types, ranks, and explicit shapes match.
- [ ] P/J2G diagnostics guard every bound evaluation.
- [ ] C wrapper types match `iso_c_binding` interfaces.
- [ ] Diagnostic wrapper does not require array `TARGET` attributes.
- [ ] Macro default is OFF and all production references are preprocessed out.
- [ ] GNU/Intel cannot enable NVHPC diagnostic symbols.
- [ ] Saved host allocation and device mapping responsibilities are distinct.
- [ ] Each owner enter has one owner delete.
- [ ] Atomic B commits remove their matching callee copyin.
- [ ] Existing CPU/FFTW interfaces are unchanged.
- [ ] New symbols and timer/diagnostic labels are unique.

## 18. Runtime Checklist

- [ ] A2 actual NG2Q/NXYZ/mxbnd/nbndloc and safe J2G range.
- [ ] A3-A5 each produce five parent and five representative-section records with expected offsets.
- [ ] A6 produces exactly one forward and one reverse record.
- [ ] Current Y0 absence recorded without treating it as failure.
- [ ] A6 ngnl min/max and work2_/metadata presence.
- [ ] Compiler report contains no unexpected temporary/pack.
- [ ] Nsight current H2D/D2H, allocation/free, kernel count, and peak memory.
- [ ] Diagnostic OFF result and median timing gates.
- [ ] B1-B3 target parent/section present lookup after ownership.
- [ ] No partial-present failure or duplicate registration.
- [ ] C2-C4 transfer ranges/frequencies and producer/consumer chain.

## 19. Stage Gate Matrix

| Stage | Objective READY condition | v5 status |
|---|---|---|
| Step A coding | API fixed; preprocessing fixed; five-phase specification fixed; safe J2G range fixed; A1-A6 exact locations/guards/output fixed | READY FOR CODING |
| Ownership B1-B3 | Corresponding Step A host/shape evidence; candidate owner range selected; atomic owner+present patch; Y1-Y4 runtime gate | DESIGNED BUT RUNTIME-GATED |
| Callee present conversion | Not independent; performed atomically inside B1-B3 | INTEGRATED INTO OWNERSHIP |
| GPU producer C2 | P/J2G/ngnl bounds resolved; B1-B3 PASS; work2 lifetime fixed; fallback builds PASS; Step 18 median gate PASS | DESIGNED BUT RUNTIME-GATED |

## 20. Failure And Rollback Matrix

| Symptom | Likely cause | First evidence | Required action |
|---|---|---|---|
| A3-A5 parent absent | Current Y0 | Step A record | Expected; do not fail Step A |
| partially present in B | duplicate/subsection registration or wrong parent range | B present table and A offsets | Revert the single B commit; fix parent mapping |
| P query invalid | NXYZ/NG2Q/mxbnd gate failed | A2 | Stop before API query; classify P3/BLOCKER |
| unexpected pack/temp | compiler behavior or interface mismatch | `-Minfo`, Nsight | Revert B; design named buffer/interface |
| numerical mismatch | stale authority, missing update, order change | check and Step 18 compare | Revert current commit |
| repeated large H2D/D2H | callee copyin retained or wrong path | Nsight | Revert current commit; inspect build/source selection |
| allocation/free growth | data region placed inside repeated loop | Nsight | Revert current commit |
| performance >3% median regression | transfer, launch, synchronization, or allocation overhead | three-run median + trace | Reject and revert unless diagnostic-only |

## 21. Unresolved Runtime Questions

| Question | Confirmation method | Required log | Pass condition / branch |
|---|---|---|---|
| Actual NG2Q/NXYZ relationship | A2 | `FPSEID_STEPA_P` | P1/P2/P4 valid; P3 stops |
| J2G and ngnl bounds | A2/A6 | P and NONLOCAL records | all referenced indices in range |
| Current transfer counts | Nsight Step A | memory summary | evidence captured; no Step A computation change |
| Five family offsets | A3/A4 | five parent plus five representative-section records per family | expected=observed for representative sections in phases 1-5 |
| EXTAU offsets | A5 | five parent plus five representative-section records | expected=observed for representative sections in phases 1-5 |
| Both nonlocal blocks | A6 | one `block=forward` and one `block=reverse` record | both valid; no skipped/invalid bounds |
| Target parent lookup | B1-B3, not Step A | present table and B diagnostics | Y1; Y2-Y4 follow decision tree |
| Host updates during target lifetime | B trace/audit | update log and source path | audited bulk update or rollback |
| Peak GPU memory | Nsight/nvidia-smi | peak report | target GPU capacity with agreed margin |
| Performance reproducibility | refreshed baseline and candidate, three runs each | timing table | candidate median <= baseline*1.03 |

## 22. Stage-Specific Self Assessment

- **Step A diagnostic coding: READY FOR CODING.** API, preprocessing, phase coverage, bounds order, guards, output limits, and rollback are specified.
- **Ownership implementation: DESIGNED BUT RUNTIME-GATED.** B1-B3 await Step A host-layout evidence and validate target lookup themselves.
- **Callee present conversion: INTEGRATED INTO OWNERSHIP.** It is not an independent stage and cannot temporarily coexist with matching internal copyin.
- **GPU producer connection: DESIGNED BUT RUNTIME-GATED.** It awaits P/J2G/ngnl resolution, B1-B3 PASS, work2 lifetime confirmation, fallback PASS, and the Step 18 median performance gate.

- [DECISION] No additional architecture decision is required before A1 coding when the environment returns.
- [BLOCKER] B1 and later remain prohibited until their stated runtime gates are satisfied.
