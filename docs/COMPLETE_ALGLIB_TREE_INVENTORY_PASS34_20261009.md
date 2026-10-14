# Complete Repository-Tree Inventory of Bundled ALGLIB — Pass 34
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`

## Method and scope

Fetched the Git tree recursively for the tracked `MQL5` subtree at the audit branch and filtered exact paths under `Include/Math/Alglib/`. The tree response was not truncated. This is an inventory of the Git repository tree, not the contents of the backup ZIP or EX5.

## Inventory

The repository tree contains **18 ALGLIB-family `.mqh` files**, with a combined tracked size of **10,742,550 bytes (10.24 MiB)**.

| File | Bytes | Git blob SHA |
|---|---:|---|
| `alglib.mqh` | 2,439,925 | `9617a7adb1d207d7912423e08e9cd6af16874232` |
| `alglibinternal.mqh` | 577,714 | `b26bbbc29e08380da47bdf730e0cda03e6aa9bc8` |
| `alglibmisc.mqh` | 119,708 | `a5374459caa4343cb03059321a4023e0090036e7` |
| `ap.mqh` | 89,595 | `6d235bb318bcd7844d715f26cc69ce6e6aba0227` |
| `arrayresize.mqh` | 4,001 | `5805bc1e9c7c4615243e32ca509f49b8935a78f7` |
| `bitconvert.mqh` | 13,398 | `9321354ac1a451e6dd8f09b48ab6de6c65e2bc1d` |
| `dataanalysis.mqh` | 1,125,446 | `d0365ca493126bc46f08802b343bee9e279ba33c` |
| `delegatefunctions.mqh` | 21,321 | `5c206dbdb4467afe169d3b9ff94035023fe49374` |
| `diffequations.mqh` | 32,334 | `eb4a708b209b74091dad6382a491f635ee5e95da` |
| `fasttransforms.mqh` | 91,787 | `d1c78869357df71aa3145352a3a4d2b8b34073fe` |
| `integration.mqh` | 116,433 | `0f52fc55443fddc6bd464a09a137667cdabbf692` |
| `interpolation.mqh` | 1,430,947 | `e743640ff9690f4b8a7f2c3b5dd768ca717fae14` |
| `linalg.mqh` | 1,452,400 | `cca112900bfad3b65229b5db2ef9ca3a17600b07` |
| `matrix.mqh` | 45,449 | `7cfb9aa8f0267ba7a0d3e4a0839c0dfe4b096e26` |
| `optimization.mqh` | 2,248,886 | `2a3a9fb825785909569fc36d1f8e8bcdc21014e1` |
| `solvers.mqh` | 295,005 | `cf33b72b38c425af5fead9bc841d7f6a966ed2f6` |
| `specialfunctions.mqh` | 234,674 | `cb5503d16c2675382a92fed3f318ff2aac2bda15` |
| `statistics.mqh` | 403,527 | `81596a3678ef6e52fcccde2255a2c76028d711fb` |

The repository's tracked ALGLIB directory is therefore materially larger than the six smaller/support headers sampled in prior passes. The inventory includes large algorithm modules such as `alglib.mqh`, `optimization.mqh`, `interpolation.mqh`, `linalg.mqh`, and `dataanalysis.mqh`. A request for the complete contents of the largest headers through the text file endpoint returned empty content, so their full source text was not independently scanned in this pass; file presence, sizes and blob IDs are confirmed by the recursive Git tree.

## Interpretation

- **Repository tree presence:** confirmed for all 18 listed files.
- **Combined tracked size:** 10,742,550 bytes.
- **Primary EA's traced direct/transitive include closure:** no ALGLIB include observed in prior passes.
- **Actual ZIP membership:** unknown; the binary archive endpoint returns no content through the available text connector.
- **EX5 contents/source mapping:** unknown.
- **License review:** still open. Prior inspected headers explicitly declare GPL v2-or-later. This is a release-review trigger, not a finding of infringement or noncompliance.

## Required closure evidence

1. Extract the exact release ZIP with a binary-capable checkout and compare its full member list with this repository inventory.
2. Hash every packaged file and preserve a machine-readable inventory.
3. Establish provenance, notices and applicable distribution terms for every shipped component.
4. Obtain qualified review before making a distribution compliance decision.
5. Build the frozen source commit with recorded compiler/toolchain and preserve raw logs plus the resulting EX5 hash.

No executable source changed. No archive extraction, compile, Strategy Tester, runtime, demo test, or legal review was performed. BL-06 remains OPEN. Release remains **BLOCKED / NOT VERIFIED**.
