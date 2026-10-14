# SmartTradingBot-Production

> **Validation status: review snapshot only.** This repository is not certified production-ready. Static checks are not a substitute for compiling the exact source in MetaEditor and running controlled Strategy Tester checks.

## Repository layout

- `MQL5/Experts/SmartTradingBot_FINAL.mq5` — primary readable Expert Advisor source candidate.
- `MQL5/Experts/SmartTradingBot_FINAL.ex5` — compiled binary snapshot; provenance relative to the source is not yet verified.
- `MQL5/Include/STB/` — project-specific include files.
- `MQL5/Include/Trade/` and the two root support headers — minimal vendored include dependency closure found by recursive `#include` analysis.
- `tools/audit_static_checks.py` — source-level guardrails; not a compiler or runtime test.
- `.github/workflows/mql5-static-audit.yml` — CI wrapper for the static guardrails.
- `docs/` — audit records and design notes.
- `BACKUP_MANIFEST.txt` and `SmartTradingBot_FINAL_CLEANED_BACKUP_20261009_033230.zip` — preserved provenance/backup artifacts.
- `AUDIT_PROGRESS_20261009.md` — detailed audit notes and unresolved validation items.

## Source-of-truth policy

1. Treat `main` as the canonical reviewed branch after an explicit, validated merge.
2. Keep experimental changes on topic branches and submit them through pull requests.
3. Do not merge EA or include-file changes until the diff has been reviewed and the exact resulting source has passed the required validation gates.
4. Do not treat an `.ex5` binary as verified unless its relationship to the reviewed `.mq5` source is documented and reproducible.
5. Preserve the ZIP backup and verified all-refs bundle until the final source snapshot is independently recoverable.

## Validation gates

- [ ] Review the complete source diff and classify every changed file.
- [ ] Verify source/binary provenance and version identity.
- [ ] Compile the exact candidate source in MetaEditor; record compiler version, errors, and warnings.
- [ ] Run controlled baseline-versus-candidate equivalence checks for diagnostic-only changes.
- [ ] Run Strategy Tester checks with recorded inputs and settings; inspect order/deal history as well as summary metrics.
- [ ] Keep demo/runtime checks separate from static analysis and backtest claims.
- [ ] Record results and limitations before considering a merge.

## Dependency-aware cleanup

The initial include tree contained 241 `.mqh` files plus 25 graphics/shader assets. A recursive scan of the primary EA's `#include` directives and their transitive includes found a 9-file include closure. The review branch was pruned to retain those 9 headers and remove 257 other files under `MQL5/Include/` that were not reachable from the current source include graph. The method and retained dependency list are recorded in `docs/MQL5_DEPENDENCY_AUDIT.md`.

This is a source-graph cleanup, not proof of successful compilation. If MetaEditor reveals a missing implicit or build-time dependency, restore it from the verified backup and document why it is needed. Do not delete the primary EA, required includes, audit evidence, or backups merely to reduce file count.

## Current limitations

- This README does not certify the source, binary, strategy, or trading performance.
- Static analysis cannot establish runtime correctness or profitability.
- The current source has not been confirmed by a MetaEditor compile and controlled Strategy Tester run.
- No live-trading readiness should be inferred from the presence of a compiled `.ex5` file.
