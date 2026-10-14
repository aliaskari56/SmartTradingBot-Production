# ALGLIB License Notice Inventory and Release Decision — Pass 33
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`

## Confirmed header notices in the bundled ALGLIB family

Six inspected files contain the same substantive notice: free software, redistribution/modification under the GNU GPL as published by the Free Software Foundation, version 2 or (at the user's option) any later version; no warranty; see the GNU GPL for details. Headers credit Sergey Bochkanov / the ALGLIB project (2003–2022) and MetaQuotes Ltd. (2012–2026).

| File | Git blob SHA | Relevant relationship |
|---|---|---|
| `fasttransforms.mqh` | `d1c78869357df71aa3145352a3a4d2b8b34073fe` | Includes `alglibinternal.mqh`; defines `CFastFourierTransform` |
| `alglibinternal.mqh` | `b26bbbc29e08380da47bdf730e0cda03e6aa9bc8` | Includes `ap.mqh` |
| `ap.mqh` | `6d235bb318bcd7844d715f26cc69ce6e6aba0227` | Includes `Object.mqh`, `matrix.mqh`, `bitconvert.mqh` |
| `matrix.mqh` | `7cfb9aa8f0267ba7a0d3e4a0839c0dfe4b096e26` | Includes `arrayresize.mqh` |
| `bitconvert.mqh` | `9321354ac1a451e6dd8f09b48ab6de6c65e2bc1d` | Includes `arrayresize.mqh` |
| `arrayresize.mqh` | `5805bc1e9c7c4615243e32ca509f49b8935a78f7` | Shared ALGLIB utility include |

The observed notice is clear evidence that these source files declare GPL v2-or-later terms. It is not a legal conclusion about the overall EA, MetaQuotes' additional copyright lines, license compatibility, or the terms governing a particular release package.

## Reconciliation with the EA include trace

The inspected direct and recursive include graph of `SmartTradingBot_FINAL.mq5` did not include these ALGLIB files, and the complete primary source text had no hits for `ALGLIB`, `CFastFourierTransform`, or `CAlglib`. This supports a bounded source-level observation that ALGLIB is not visibly referenced in the currently traced source closure.

However, the repository itself bundles these headers. If a release package includes them, redistribution review may be required even if the EA does not compile or call them. The existing ZIP was not downloaded/extracted, and the existing EX5 was not inspected or mapped to the current source. Therefore package inclusion remains unknown.

## Release gate decision

- **Source closure concern:** no ALGLIB reference observed in the traced EA closure.
- **Repository bundled-source concern:** confirmed GPL v2-or-later notice in six ALGLIB headers.
- **Release archive contents:** unknown.
- **Legal/compliance decision:** not made; requires review by a qualified reviewer based on the actual shipped files, intended distribution, applicable upstream terms, and preserved notices.
- **BL-06:** OPEN. Do not mark dependency/licensing review closed on the basis of the source-closure trace alone.

## Evidence needed to close BL-06

1. Extract and enumerate the exact release ZIP, including hashes and license/notice files.
2. Compare the release package's ALGLIB directory against the tracked files and determine whether it is included intentionally.
3. Preserve the full license and copyright notices for every distributed component and identify the upstream version/provenance.
4. Have the intended distribution model and license obligations reviewed by a qualified legal/compliance reviewer.
5. Record the decision, evidence bundle, reviewer, date, and exact release artifact hash.

No executable source changed. No ZIP extraction, compile, Strategy Tester, runtime, demo test, or legal review was performed. Release remains **BLOCKED / NOT VERIFIED**.
