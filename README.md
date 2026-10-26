# SmartTradingBot-Production

> **Validation status: CI compile and static checks passed for the merged source snapshot; trading validation is incomplete.** The repository is not certified profitable or production-ready. Strategy Tester regression/OOS, all-button runtime checks, and demo-forward validation remain mandatory.

## Repository layout

- `MQL5/Experts/SmartTradingBot_FINAL.mq5` — primary readable Expert Advisor source candidate.
- `MQL5/Experts/SmartTradingBot_FINAL.ex5` — intentionally not stored on this branch while binary provenance is unverified. Build the EX5 locally from the exact checked-out source and reviewed dependency set using MetaEditor.
- `MQL5/Include/STB/` — project-specific include files.
- `MQL5/Include/Trade/` and the two root support headers — minimal vendored include dependency closure found by recursive `#include` analysis.
- `tools/audit_static_checks.py` — source-level guardrails; not a compiler or runtime test.
- `.github/workflows/mql5-static-audit.yml` — CI wrapper for the static guardrails.
- `docs/` — audit records and design notes, including `LINE_BY_LINE_AUDIT_2026-10-26.md` and `RELEASE_PACKAGE_GUIDE.md`.
- `tools/Package-CleanSource.ps1` — deterministic source-only package builder with include-closure checks and SHA-256 manifest.
- `BACKUP_MANIFEST.txt` and `SmartTradingBot_FINAL_CLEANED_BACKUP_20261009_033230.zip` — preserved provenance/backup artifacts.
- `AUDIT_PROGRESS_20261009.md` — detailed audit notes and unresolved validation items.

## Source-of-truth policy

1. Treat `main` as the canonical repository branch for the source currently stored here; the current EA property version is `1.135`. This repository snapshot does **not** establish identity with any separate local `v1.141` build; do not overwrite or deploy that local build based on version labels alone.
2. Keep experimental changes on topic branches and submit them through pull requests.
3. Do not merge EA or include-file changes until the diff has been reviewed and the exact resulting source has passed the required validation gates.
4. Do not distribute an `.ex5` as verified unless its relationship to the reviewed `.mq5` source, exact include dependency set, MetaEditor build, compile log, and artifact SHA-256 is documented and reproducible.
5. Preserve the ZIP backup and verified all-refs bundle until the final source snapshot is independently recoverable.

## Validation gates

- [x] Review the changes in PR #41: broker volume-step normalization, pending-trail writer ownership, realized-deal cost diagnostics, tester optimization ranking, source-only packaging, and audit documentation.
- [x] Compile the exact merged source in the Windows MetaEditor CI workflow; workflow reported success.
- [x] Run repository static audit, trading-safety-default checks, journal contract tests, and source-package verification; workflows reported success.
- [ ] Review the complete source diff and classify every changed file.
- [ ] Verify source/binary provenance and version identity.
- [ ] Re-run the exact merged source compile locally if preparing a deployment package; retain compiler version, errors, warnings, source hash, include hashes, and EX5 hash.
- [ ] Run controlled baseline-versus-candidate equivalence checks for diagnostic-only changes.
- [ ] Run Strategy Tester checks with recorded inputs and settings; inspect order/deal history as well as summary metrics.
- [ ] Keep demo/runtime checks separate from static analysis and backtest claims.
- [ ] Record results and limitations before considering a merge.

## Dependency-aware cleanup

The initial include tree contained 241 `.mqh` files plus 25 graphics/shader assets. A recursive scan of the primary EA's `#include` directives and their transitive includes found a 9-file include closure. The review branch was pruned to retain those 9 headers and remove 257 other files under `MQL5/Include/` that were not reachable from the current source include graph. The method and retained dependency list are recorded in `docs/MQL5_DEPENDENCY_AUDIT.md`.

This is a source-graph cleanup, not proof of successful compilation. If MetaEditor reveals a missing implicit or build-time dependency, restore it from the verified backup and document why it is needed. Do not delete the primary EA, required includes, audit evidence, or backups merely to reduce file count.

## Cleanup policy

The source dependency tree has already been pruned by include-graph analysis. Do not delete functions solely because a text search finds few references: event handlers, callbacks, chart controls, persistence, and indirect execution paths may appear rarely. Remove code only after reference analysis, a reviewed diff, a fresh compile, and regression checks. Keep the historical backup ZIP and its manifest until the current source snapshot and dependencies are independently recoverable; the manifest describes an older 2026-10-09 build and is not proof of provenance for the current source.

## Current limitations

- This README does not certify the source, binary, strategy, or trading performance.
- Static analysis cannot establish runtime correctness or profitability.
- A passing GitHub static audit does not prove that MetaEditor compiled the same source or that a terminal chart loaded the resulting EX5.
- Any locally compiled EX5 must be accompanied by an artifact provenance record before it should be considered a release binary.
- No live-trading readiness should be inferred from the presence of source files or a locally compiled `.ex5` file.
