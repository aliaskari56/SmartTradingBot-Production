# Dependency Header Findings — Pass 30
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`

## Scope and method

Focused inspection of the first 45 lines of six tracked files, plus full-file metadata from GitHub Contents API. This is a targeted header review, not a complete scan of the 266-file Include tree and not a legal opinion.

## Confirmed observations

| Path | Git blob SHA | Observed evidence | Interpretation / follow-up |
|---|---|---|---|
| `MQL5/Include/Math/Alglib/fasttransforms.mqh` | `d1c78869357df71aa3145352a3a4d2b8b34073fe` | Header credits Sergey Bochkanov / ALGLIB and MetaQuotes; explicitly states GPL version 2 or any later version. | **High-priority distribution review.** Determine whether this header and related ALGLIB files are distributed, modified, linked/used by the EA or only bundled as unused library content. Establish applicable license obligations and compatibility for the intended package before release. |
| `MQL5/Include/Math/Alglib/alglibinternal.mqh` | `b26bbbc29e08380da47bdf730e0cda03e6aa9bc8` | Same ALGLIB and MetaQuotes copyright lines; explicitly states GPL v2 or later. | Treat as same ALGLIB dependency family; inspect the full family and retain license notices. |
| `MQL5/Include/Math/Alglib/ap.mqh` | `6d235bb318bcd7844d715f26cc69ce6e6aba0227` | Same copyright credits and GPL v2-or-later statement. | Confirms this is not an isolated header string. Inventory the complete family and assess distribution/use model. |
| `MQL5/Include/Trade/Trade.mqh` | `37cfd4c3fc15c6de9aec7390287c95530d3d31cb` | Header credits MetaQuotes Ltd. (2000–2026); includes Object, OrderInfo, HistoryOrderInfo, PositionInfo and DealInfo headers. | Preserve notices and verify the applicable MetaQuotes distribution terms from authoritative documentation/package provenance. Copyright text alone does not state all terms. |
| `MQL5/Include/Controls/Button.mqh` | `4c7e8c107c4f56c6f1a82e87960556fd59405257` | Header credits MetaQuotes Ltd. (2000–2026). | Same standard-library provenance/terms review; do not assume this file is part of the EA's compiled dependency closure solely because it is bundled. |
| `MQL5/Include/Canvas/DX/Shaders/DefaultShaderPixel.hlsl` | `e3c25dcf8d8dcaaf14e18702ce53607ff94a30dc` | Header credits MetaQuotes Ltd. (2000–2026). | Record shader asset in inventory and verify applicable terms and whether it is included in the distributed package. |
| `MQL5/Include/STB/STB_PendingDistanceResolver.mqh` | `2ed3aaefb3a83b7690409f87a3c7e428c35a8956` | Inspected header documents project-specific purpose but contains no explicit license statement in the inspected opening section. | Origin, authorship and permission remain unresolved; this is not proof of absent permission. |
| `MQL5/Include/STB/STB_PendingTrail.mqh` | `bdb827e7871960f88f5bf9593f1e4efcc7797367` | Opening content documents project-specific purpose but contains no explicit license statement in the inspected opening section. | Origin, authorship and permission remain unresolved; inspect full history and obtain owner confirmation as needed. |

## Critical distinction

The repository contains ALGLIB headers that explicitly declare GPL v2-or-later terms. This establishes a concrete license-review requirement; it does **not** by itself establish that the EA calls ALGLIB, that an EX5 contains ALGLIB code, or that a particular release is compliant or noncompliant. The primary source's actual include/dependency closure and the intended distribution model must be checked separately. Do not remove or rewrite notices merely to make the package appear clear.

## Next evidence needed

1. Enumerate every file under `MQL5/Include/Math/Alglib/` and preserve its header, path, and raw SHA-256.
2. Search the full EA and all transitively included headers for ALGLIB includes, class names, and references; distinguish direct use, transitive use, and unused bundled files.
3. Inspect the source archive and release package contents; determine whether unused headers/assets are distributed.
4. Identify the exact upstream release/version and applicable license text for ALGLIB and the MetaQuotes standard library.
5. Have a qualified reviewer evaluate obligations for the intended source/binary distribution model before release.
6. Identify authorship and licensing evidence for the two STB-specific modules.

## Gate update

BL-06 remains **OPEN** and is now supported by a concrete ALGLIB GPL notice finding plus unresolved project-specific module provenance. No executable source changed. This pass did not perform a full-tree license scan, establish the compiled dependency closure, provide legal advice, compile the EA, or run Strategy Tester/demo tests. Release remains **BLOCKED / NOT VERIFIED**.
