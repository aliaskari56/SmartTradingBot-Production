# SmartTradingBot-Production

> **Validation status: review snapshot only.** The source in this repository has not been verified as production-ready. A successful static check is not a substitute for compiling the exact source in MetaEditor and running controlled Strategy Tester checks.

## Repository layout

- `MQL5/Experts/SmartTradingBot_FINAL.mq5` — readable Expert Advisor source candidate.
- `MQL5/Experts/SmartTradingBot_FINAL.ex5` — compiled binary snapshot. Its provenance must be verified against the source before release.
- `MQL5/Include/` — MQL5 include dependencies. Do not remove files merely because they are not the primary EA; confirm include references and compile dependencies first.
- `.github/workflows/mql5-static-audit.yml` — static source audit workflow.
- `BACKUP_MANIFEST.txt` — backup/source provenance notes.
- `AUDIT_PROGRESS_20261009.md` — detailed audit notes and unresolved validation items.

## Source-of-truth policy

1. Treat `main` as the canonical reviewed branch.
2. Keep experimental changes on short-lived topic branches and submit them through pull requests.
3. Do not merge an EA or include-file change until the diff has been reviewed and the exact resulting source has passed the required validation gates.
4. Do not treat an `.ex5` binary as verified unless its relationship to the reviewed `.mq5` source is documented and reproducible.
5. Preserve the original ZIP backup and the verified all-refs bundle until the repository has been reviewed and the final source snapshot is independently recoverable.

## Validation gates

- [ ] Review the complete source diff and identify every added, removed, or modified file.
- [ ] Verify source/binary provenance and version identity.
- [ ] Compile the exact candidate source in MetaEditor; record the compiler version and all warnings/errors.
- [ ] Run a controlled baseline-versus-candidate equivalence check when changes are intended to be diagnostic-only.
- [ ] Run Strategy Tester checks with recorded inputs and settings; inspect order/deal history as well as summary metrics.
- [ ] Keep any demo/runtime checks separate from static analysis and backtest claims.
- [ ] Record results and limitations in the audit report before considering a merge.

## Cleanup policy

Repository cleanup must be dependency-aware. Keep only one clearly designated primary EA in the release layout, but first search all source/include references, project settings, workflows, documentation, and provenance records. Move obsolete alternatives to a clearly labeled archive branch or remove them only after confirming they are unreferenced and covered by the verified backup. Never delete shared MQL5 standard-library headers just because they are numerous.

## Current limitations

- This README does not certify the source, compiled binary, strategy, or trading performance.
- Static analysis cannot establish runtime correctness or profitability.
- No live-trading readiness should be inferred from the presence of a compiled `.ex5` file.
