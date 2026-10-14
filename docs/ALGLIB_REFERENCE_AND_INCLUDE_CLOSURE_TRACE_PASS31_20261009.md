# ALGLIB Reference and Include-Closure Trace — Pass 31
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`
Reviewed source blob: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8` (`MQL5/Experts/SmartTradingBot_FINAL.mq5`, 8,665 lines)

## Findings from exact-branch inspection

### Primary EA source

The checked-in EA source has three direct `#include` directives:
- line 9: `<Trade/Trade.mqh>`
- line 8115: `<STB\\STB_PendingDistanceResolver.mqh>`
- line 8116: `<STB\\STB_PendingTrail.mqh>`

A case-insensitive text scan of the complete primary source found zero references to `ALGLIB`, `CFastFourierTransform`, or `CAlglib` (the broader token scan used `alglib|CFastFourierTransform|CAlglib`). The two directly included STB modules also contain no `#include` directives in their current contents.

### Meaning and limits

This is evidence that the primary source does not visibly reference ALGLIB by those terms and that ALGLIB is not directly included by the primary EA or either of the two directly included STB modules. It is **not** a complete transitive dependency-closure proof:
- `Trade.mqh` includes `Object.mqh`, `OrderInfo.mqh`, `HistoryOrderInfo.mqh`, `PositionInfo.mqh`, and `DealInfo.mqh`; those and their transitive includes have not all been recursively traced here.
- Other source/build files or packaging scripts may bring files into the distributed package.
- A source-level text scan cannot establish what code is present in the historical EX5 binary.
- GitHub's file-content endpoint did not return the binary archive bytes in this pass, so the ZIP was not extracted or inventoried.

## Provisional disposition

- **Direct ALGLIB reference in the primary EA:** NOT OBSERVED.
- **ALGLIB in complete transitive compiled dependency closure:** NOT ESTABLISHED.
- **ALGLIB files in the repository's bundled Include tree:** CONFIRMED by prior header inspection.
- **ALGLIB files in a release archive / compiled EX5:** NOT ESTABLISHED.
- **Distribution license gate:** OPEN pending full dependency and package inventory plus qualified review.

## Next concrete evidence

1. Recursively trace all include directives from the three direct includes, including conditional compilation paths.
2. Inspect the ZIP using a binary-capable checkout/download path, list archive members, and hash the extracted files.
3. Record the exact build command and compiler output for the frozen source commit; do not infer EX5 contents from a source-only scan.
4. Determine whether ALGLIB headers are shipped as unused bundled files. If so, assess distribution obligations for those files independently of whether the EA calls them.
5. Obtain authoritative licensing/provenance records for the MetaQuotes standard library and project-specific STB modules.

No executable source changed. No archive extraction, complete recursive include analysis, legal review, compile, Strategy Tester, runtime or demo test was performed. BL-06 remains OPEN. Release remains **BLOCKED / NOT VERIFIED**.
