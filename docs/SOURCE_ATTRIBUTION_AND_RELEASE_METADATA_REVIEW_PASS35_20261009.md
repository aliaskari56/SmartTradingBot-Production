# Source Attribution and Release Metadata Review — Pass 35
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`

## Scope

Inspected the opening headers of the checked-in EA and two directly included custom STB modules. This is a narrow source-attribution and release-metadata check, not a legal opinion or full repository license audit.

## Findings

### F-35-01 — EA header contains template placeholders

File: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
Git blob SHA: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`

The opening header identifies the project as `ProjectName`, gives `Copyright 2020, CompanyName`, and points to `http://www.companyname.net`. These are visibly generic placeholders inconsistent with a release-ready attribution header unless they are intentionally literal. The source also has `#property version "1.126"` and a SmartTradingBot product description.

**Impact:** release identity, maintainer attribution and source ownership are not clearly communicated by the current file header.
**Confidence:** confirmed placeholder strings in source; the actual rights holder is unknown.
**Action:** have the project owner confirm the correct copyright/author/maintainer details and replace placeholders only after confirmation. Do not invent an owner or claim ownership from repository access.

### F-35-02 — Custom STB modules have no explicit attribution/license notice in the inspected headers

Files:
- `MQL5/Include/STB/STB_PendingDistanceResolver.mqh` — Git blob SHA `2ed3aaefb3a83b7690409f87a3c7e428c35a895`
- `MQL5/Include/STB/STB_PendingTrail.mqh` — Git blob SHA `bdb827e7871960f88f5bf9593f1e4efcc7797367`

Their opening headers describe module roles and integration contracts, but the inspected headers do not state an author, copyright holder, origin, or license. The PendingTrail file begins with a function before its descriptive header, which is a minor header-layout inconsistency.

**Impact:** source provenance and intended redistribution terms cannot be determined from these headers alone.
**Confidence:** confirmed only for the inspected header region; this does not establish that permission is absent or that the files are third-party code.
**Action:** record the actual author/source and ownership basis for each custom module; add accurate license/notice text only after confirmation.

### F-35-03 — Findings must be kept separate from the ALGLIB review

The repository tree contains 18 ALGLIB-family headers with explicit GPL v2-or-later notices in previously inspected files. The current EA's traced include closure did not show an ALGLIB dependency. Neither the generic EA header nor missing notices in the two STB module headers prove a licensing violation. These are distinct attribution/provenance questions and must be resolved from source history, authorship records, package contents, and qualified review.

## Evidence and limitations

- EA source blob: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`
- Pending Distance Resolver blob: `2ed3aaefb3a83b7690409f87a3c7e428c35a895`
- Pending Trail blob: `bdb827e7871960f88f5bf9593f1e4efcc7797367`
- This pass inspected source headers only. It did not inspect contributor records, external provenance, the ZIP contents, EX5 internals, or legal agreements.
- No executable source was changed.
- No compile, tester, runtime, demo, or legal review was performed.

## Closure decision

Track as release metadata/provenance actions. BL-06 remains OPEN. Do not change the placeholder fields without the owner's confirmed attribution. Release remains **BLOCKED / NOT VERIFIED**.
