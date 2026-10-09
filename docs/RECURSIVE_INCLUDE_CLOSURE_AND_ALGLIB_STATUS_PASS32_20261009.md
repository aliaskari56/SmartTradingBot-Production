# Recursive Include Closure and Bundled ALGLIB Status — Pass 32
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`
Primary source blob: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`

## Recursive trace of the primary EA's direct includes

The primary EA directly includes:
- `Trade/Trade.mqh` (blob `37cfd4c3fc15c6de9aec7390287c95530d3d31cb`)
- `STB/STB_PendingDistanceResolver.mqh` (blob `2ed3aaefb3a83b7690409f87a3c7e428c35a895`)
- `STB/STB_PendingTrail.mqh` (blob `bdb827e7871960f88f5bf9593f1e4efcc7797367`)

The inspected recursive include graph for the standard Trade library is:
`Trade.mqh` → `Object.mqh` → `StdLibErr.mqh`
and
`Trade.mqh` → `OrderInfo.mqh`, `HistoryOrderInfo.mqh`, `PositionInfo.mqh`, `DealInfo.mqh`; each of those four also includes `Object.mqh`.

Inspected file blobs:
- `Trade/OrderInfo.mqh`: `104444612778249ff7c0abe2aa6d8f51135cc1ad`
- `Trade/HistoryOrderInfo.mqh`: `f570b65d72f35061ed45c5bce4dfa62d1093edd5`
- `Trade/PositionInfo.mqh`: `e4ee0cd008f1fca4daa9a1bcf31aa67dc9c8ed32`
- `Trade/DealInfo.mqh`: `f8d16df5e3f8a20bb344d81a296f23fd33aec9ca`
- `Object.mqh`: `2ad6ca61b3335d4947bfafd89a9fa6dcb77abc6f`
- `StdLibErr.mqh`: `5d96e6dcf235c69272555dc888532ae268c25908`

The two directly included STB modules have no `#include` directives in the inspected contents. No ALGLIB include appears in this traced graph. Combined with the zero ALGLIB token hits in the complete primary EA source, this supports a bounded finding: **ALGLIB was not observed in the current source's directly traced include closure.** This is not a compiler-generated dependency manifest and does not prove what an existing EX5 contains.

## ALGLIB family is bundled separately in the repository tree

The following ALGLIB headers are present and internally include one another:
- `fasttransforms.mqh` (blob `d1c78869357df71aa3145352a3a4d2b8b34073fe`) includes `alglibinternal.mqh`.
- `alglibinternal.mqh` (blob `b26bbbc29e08380da47bdf730e0cda03e6aa9bc8`) includes `ap.mqh`.
- `ap.mqh` (blob `6d235bb318bcd7844d715f26cc69ce6e6aba0227`) includes `Object.mqh`, `matrix.mqh`, and `bitconvert.mqh`.
- `matrix.mqh` (blob `7cfb9aa8f0267ba7a0d3e4a0839c0dfe4b096e26`) includes `arrayresize.mqh`.
- `bitconvert.mqh` (blob `9321354ac1a451e6dd8f09b48ab6de6c65e2bc1d`) includes `arrayresize.mqh`.

Earlier header inspection found explicit GPL version 2-or-later wording in multiple ALGLIB headers. That warrants a distribution/licensing review if these files are included in a delivered source package. It does not, by itself, establish an infringement, identify all applicable upstream terms, or imply that ALGLIB code is compiled into this EA.

## Archive and release limitation

The repository ZIP could not be retrieved as binary content through the available repository file-content endpoint in this pass. No archive was extracted, no file list was generated from the archive, and no EX5 inspection or source-to-binary mapping was performed. Thus:
- **Repository tree contains ALGLIB files:** confirmed.
- **ALGLIB in the traced current EA include closure:** not observed.
- **ALGLIB in the ZIP distributed to users:** unknown.
- **ALGLIB in the checked-in EX5:** unknown.
- **License compliance decision:** not made; BL-06 remains OPEN.

## Required follow-up

1. Use a binary-capable checkout/download to extract the exact ZIP, enumerate files, and hash its contents.
2. Establish whether the release package ships the ALGLIB directory even if unused by the EA.
3. Preserve upstream source/version and licensing notices; obtain qualified review of distribution obligations.
4. Produce an exact-commit build with raw compiler log and a build artifact manifest before claiming source/EX5 correspondence.

No executable source changed. No compilation, runtime, Strategy Tester, demo test, archive extraction, or legal review was performed. Release remains **BLOCKED / NOT VERIFIED**.
