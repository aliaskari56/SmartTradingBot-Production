# Dependency Provenance and License Review Register — Pass 29
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`

## Purpose

This register defines the evidence required before distributing or releasing the EA with its bundled dependencies. It is a review tracker, not legal advice and not a claim that every dependency is unlicensed or noncompliant.

## Scope snapshot from static tree inspection

Previously observed tree summary for the reviewed branch:
- `MQL5/Include`: 266 files, including 241 `.mqh`, 23 `.bmp`, and 2 `.hlsl`.
- Primary source directly includes `Trade/Trade.mqh`, `STB\\STB_PendingDistanceResolver.mqh`, and `STB\\STB_PendingTrail.mqh`.
- `Trade.mqh` contains MetaQuotes copyright text and includes other standard trade-library headers.
- No explicit license notice was observed in the inspected portions of the two STB modules; that limited observation is not proof of missing permission or a licensing defect.
- The tree snapshot reportedly had no root `LICENSE`/ `NOTICE` and no `.github/workflows/`; re-check the exact frozen commit before release.

## Dependency register

| ID | Component / class | Evidence to collect | Current disposition |
|---|---|---|---|
| DP-01 | `Trade/Trade.mqh` and transitive standard library headers | Upstream repository/package, terminal distribution version, license/copyright terms, redistribution conditions | PARTIAL: copyright observed; provenance/redistribution review open |
| DP-02 | `STB_PendingDistanceResolver.mqh` | Author/owner, origin commit, source history, license or written permission, version/hash | OPEN |
| DP-03 | `STB_PendingTrail.mqh` | Author/owner, origin commit, source history, license or written permission, version/hash | OPEN |
| DP-04 | Remaining 238 `.mqh` files | Inventory all headers, identify upstream/custom code, license and version for each | OPEN |
| DP-05 | 23 bitmap assets | Source/creator, permitted use, modification/redistribution terms | OPEN |
| DP-06 | 2 HLSL files | Origin, license, compiler/runtime requirements, redistribution terms | OPEN |
| DP-07 | Embedded snippets and copied algorithms | Identify copied/derived portions and retain attribution/permission evidence | OPEN |
| DP-08 | Bundled archives and historical EX5 artifacts | Determine whether they contain additional dependencies or generated third-party material; hash and inventory contents | OPEN |
| DP-09 | Notices and distribution package | Prepare required copyright/license notices and a machine-readable inventory where appropriate | OPEN |

## Required review procedure

1. Freeze the exact commit and record its full SHA.
2. Generate a file inventory with path, size, raw SHA-256, detected license/copyright headers, and likely upstream origin.
3. Inspect the full contents of each dependency, not only the primary include lines.
4. Trace repository history and upstream origin; do not infer provenance solely from file names or matching file counts.
5. For each component, record license identifier or written permission, applicable version, required attribution, notice obligations, modification obligations, and redistribution constraints.
6. Review bundled binary/archive contents separately; do not assume a checked-in EX5 has the same dependency composition as current source.
7. Have a qualified reviewer resolve ambiguous or conflicting terms before distribution.
8. Add the applicable notices to the release package only after the rights and obligations are understood; do not invent or assign a license to code without authority.

## Acceptance criteria

The dependency gate can close only when every distributed file is classified as one of:
- project-owned with ownership evidence;
- third-party with verified license and satisfied conditions;
- used under documented permission;
- excluded from the release package.

Unknown-origin files remain OPEN. “No license found in the inspected portion” is an uncertainty, not a conclusion of infringement. Likewise, a public repository alone does not imply permission to redistribute.

## Gate decision

**BL-06 remains OPEN.** This pass creates the review register only. No legal conclusion, full dependency inventory, compile, runtime test, Strategy Tester, or demo test was performed. No executable source changed. Release remains **BLOCKED / NOT VERIFIED** pending evidence and review.
