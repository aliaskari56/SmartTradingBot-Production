# SmartTradingBot-Production

> **Validation status: CI compile and static checks passed for the merged source snapshot; trading validation is incomplete.** The repository is not certified profitable or production-ready. Strategy Tester regression/OOS, all-button runtime checks, and demo-forward validation remain mandatory.

## Repository layout

- `MQL5/Experts/SmartTradingBot_FINAL.mq5` — primary readable Expert Advisor source candidate.
- `MQL5/Experts/SmartTradingBot_FINAL.ex5` — intentionally not stored while binary provenance is unverified. Build it locally from the exact source and reviewed dependency set using MetaEditor.
- `MQL5/Include/STB/` — project-specific include files.
- `MQL5/Include/Trade/` and the two root support headers — vendored include dependency closure identified by recursive `#include` analysis.
- `tools/audit_static_checks.py` — source-level guardrails, not a compiler or runtime test.
- `.github/workflows/` — CI workflows for compile, static audit, safety defaults, journal contracts, and source packaging.
- `tools/Package-CleanSource.ps1` — source-only package builder with include-closure checks and a SHA-256 manifest.
- `docs/` — current audit, release guidance, and design records; `docs/archive/` — historical audit notes and backup/provenance artifacts retained outside the repository root.

## Source-of-truth policy

1. Treat `main` as the canonical repository branch for the source currently stored here; the EA property version is `1.136`. This repository snapshot does **not** establish identity with any separate local `v1.141` build. Do not overwrite or deploy that local build based on version labels alone.
2. Keep experimental changes on topic branches and submit them through pull requests.
3. Review the diff and run the required validation gates for future EA or include-file changes before merging.
4. Do not distribute an `.ex5` as verified unless its relationship to the reviewed `.mq5`, exact include dependency set, MetaEditor build, compile log, and artifact SHA-256 is documented and reproducible.
5. Preserve the historical ZIP backup and manifest in `docs/archive/` until the current source snapshot is independently recoverable. The manifest describes an older 2026-10-09 build and is not provenance for the current source.

## Validation status

- [x] PR #41 merged with broker volume-step normalization, pending-trail writer ownership, realized-deal cost diagnostics, tester optimization ranking, source-only packaging, and audit documentation.
- [x] CI MetaEditor compile reported success for the merged source snapshot.
- [x] Static audit, trading-safety-default checks, journal contract tests, and source-package verification reported success.
- [ ] Verify source/binary provenance and identity against any separate local build.
- [ ] Run same-settings Strategy Tester baseline regression and inspect order/deal history.
- [ ] Run multi-period/multi-symbol out-of-sample tests with realistic commission, swap, spread, and slippage.
- [ ] Runtime-test all eight UI buttons, AUTO state, manual pending placement, SAVE +20, hedge controls, and BUY_STOP/SELL_STOP pending trailing.
- [ ] Complete demo-forward validation before considering live deployment.

## Dependency-aware cleanup

The initial include tree contained 241 `.mqh` files plus 25 graphics/shader assets. Recursive analysis of the primary EA's `#include` directives and transitive includes found a 9-file include closure. The source tree was pruned to retain those 9 headers and remove 257 other files under `MQL5/Include/` not reachable from the current include graph. The retained dependency list and method are recorded in `docs/MQL5_DEPENDENCY_AUDIT.md`.

This is a source-graph cleanup, not proof of successful runtime behavior. If MetaEditor reveals a missing implicit or build-time dependency, restore it from the preserved backup and document why it is required.

## Cleanup policy

The include tree has been pruned by include-graph analysis. Do not delete functions solely because text search finds few references: event handlers, callbacks, chart controls, persistence, and indirect execution paths may appear rarely. Remove code only after reference analysis, reviewed diff, fresh compile, and regression checks. Historical audit records and backup artifacts are retained under `docs/archive/` to keep the root focused without destroying provenance.

## Current limitations

- This repository does not certify source/binary identity, strategy profitability, or live-trading readiness.
- Static analysis cannot establish runtime correctness or positive expectancy.
- A passing CI workflow does not prove a terminal chart loaded the resulting EX5.
- Any locally compiled EX5 needs a reproducible artifact provenance record before it can be considered a release binary.
