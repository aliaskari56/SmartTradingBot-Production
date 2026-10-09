# Release Evidence & Test Traceability Checklist — 2026-10-09

## Status

**DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN**

This checklist turns the open audit findings into evidence that must be collected before any release decision. It does not certify the EA as safe, profitable, compilable, or ready for live trading. No executable source was changed for this checklist.

## Rules for evidence

- Identify the exact branch, commit SHA, source path, and SHA-256 for every test run.
- Preserve raw logs and reports; do not replace raw evidence with a summary or screenshot alone.
- Record terminal/build tool version, settings, symbol, timeframe, account mode, broker/server context, and test interval where applicable.
- Separate **PASS**, **FAIL**, **BLOCKED**, and **NOT RUN**. Missing evidence is not a pass.
- Any source change invalidates evidence tied to an earlier source hash until the relevant checks are rerun.
- Use a demo/test environment for behavioral and risk testing; do not infer safety from historical compile results.

## Release gates

| Gate | Required evidence | Acceptance condition | Current status |
|---|---|---|---|
| RG-01 Exact-source build | Raw MetaEditor log, compiler/toolchain version, build command/settings, source SHA-256, output artifact SHA-256 | Build demonstrably corresponds to the exact reviewed source; complete output retained; warnings triaged | OPEN — not independently verified |
| RG-02 EX5 provenance | Hashes of built and distributed EX5, build record, reproducible artifact mapping | Delivered EX5 is tied to the reviewed source/build record | OPEN |
| RG-03 Dependency provenance | Inventory of all 266 `MQL5/Include/` files, upstream origin/version, local modifications, license/redistribution basis | Every shipped dependency has documented provenance and permitted use | OPEN |
| RG-04 Trade-write authorization | Static call-site review plus tests for every order/position mutation route, including rollback and expiry cleanup | Authorization is enforced at the mutation boundary without preventing safe cleanup of bot-owned invalid orders | OPEN |
| RG-05 SL/TP concurrency | Tests and code review for stale snapshots, concurrent writers, partial fills, and SL modification behavior | No unintended TP overwrite or lost update; behavior documented and verified | OPEN |
| RG-06 SL proposal arbitration | Trace/log evidence for initial SL, profit lock, and trailing proposals in the same cycle | Deterministic arbitration and final server request are demonstrated | OPEN |
| RG-07 Pending-trail lifecycle | Restart/reconnect tests, pending-order changes/deletes/fills, retry/backoff, invalid stops, rejected requests | State recovery and handoff remain consistent in all tested lifecycle cases | OPEN |
| RG-08 Event ordering/idempotence | Transaction callback and tick/timer interleaving tests, duplicate/reordered event cases | Reconciliation is idempotent and does not rely on guaranteed transaction ordering | OPEN |
| RG-09 Strategy Tester/demo behavior | Saved test configuration, report, journal, trade list, and risk metrics across representative scenarios | Defined acceptance criteria pass; failures and limitations documented | OPEN — not run here |
| RG-10 Independent review | Review record tied to exact commit, unresolved findings list, release owner sign-off | Critical/high findings resolved or explicitly accepted by authorized owner | OPEN |

## Minimum behavioral test matrix

For every scenario, capture the exact source commit/hash, inputs, symbol specifications, terminal build, journal, trade/order history, and expected versus observed outcome.

| ID | Scenario | Key assertions | Status |
|---|---|---|---|
| T-01 | Fresh initialization with no positions/orders | Initialization is deterministic; no unintended trade request | NOT RUN |
| T-02 | Restart with existing bot-owned and foreign positions/orders | Ownership and reconstructed state remain correct; foreign trades are untouched | NOT RUN |
| T-03 | Place each pending-order type through each of the four creation families | Correct geometry, volume, SL/TP, ownership and error handling | NOT RUN |
| T-04 | Expiry cleanup and each rollback path | Only eligible bot-owned orders are deleted; cleanup still works after partial failure | NOT RUN |
| T-05 | Delete request denied, delayed, or order already absent | Result handling and reconciliation are idempotent; no false success | NOT RUN |
| T-06 | Simultaneous SL proposals: initial SL, profit lock, trailing | Defined priority/arbitration is observed; final SL respects broker constraints | NOT RUN |
| T-07 | SL update while TP changes or another writer acts | No stale TP overwrite or unintended modification | NOT RUN |
| T-08 | Pending-trail across restart, reconnect, rejection and partial lifecycle changes | Per-ticket state is rebuilt and reconciled correctly | NOT RUN |
| T-09 | Trade transaction events arrive in varying order or in multiple callbacks | Handler tolerates intermediate account state and repeated notifications | NOT RUN |
| T-10 | Invalid stops, freeze levels, market closed, requotes, insufficient margin, disconnect | Failures are reported, retried only when appropriate, and do not cause loops or unsafe duplicate requests | NOT RUN |
| T-11 | Multiple symbols, netting/hedging account modes where supported | Symbol/ticket ownership and isolation remain correct | NOT RUN |
| T-12 | High-volatility/spread expansion and rapid price changes in tester/demo | Risk limits and order validation remain effective under adverse conditions | NOT RUN |
| T-13 | Deinitialization, chart changes, timeframe changes, timer and tick overlap | Resources/state are cleaned up or restored without duplicate actions | NOT RUN |
| T-14 | Long-duration demo soak and restart during active trades | No unexplained order/position drift, repeated requests, or state corruption | NOT RUN |

## Finding-to-test mapping

- **BL-01 / BL-02:** RG-01, RG-02.
- **BL-03:** RG-03.
- **BL-04:** RG-04; T-04 and T-05 are mandatory.
- **BL-05:** RG-05; T-07 is mandatory.
- **BL-06:** RG-06; T-06 is mandatory.
- **BL-07:** RG-07; T-08 is mandatory.
- **BL-08:** RG-08; T-09 and T-13 are mandatory.
- **BL-09:** RG-09; the full behavioral matrix must be executed and results retained.
- **BL-10:** RG-10.

## Required evidence bundle

1. `source-manifest.txt`: branch, commit SHA, primary source path, source SHA-256, dependency inventory/version records.
2. `build/`: raw compiler log, compiler/toolchain version, settings, built EX5 hash, build timestamp and environment.
3. `tests/`: one subdirectory per test ID with configuration, expected result, actual result, journal, report, and disposition.
4. `findings.csv`: finding ID, severity, affected path/line, evidence, owner, remediation commit, retest result, residual risk.
5. `review/`: independent review record, remaining risks, release-owner approval.
6. `release-decision.md`: explicit GO/NO-GO decision and the exact source/artifact hashes covered by that decision.

## Decision rule

Do not mark the technical audit complete or authorize live deployment solely because a source file exists, a manifest claims a successful compile, a historical workflow passed, or static inspection found no additional issue. At minimum, RG-01 through RG-10 must be dispositioned with evidence, and critical/high findings must be resolved or explicitly accepted by the responsible release authority. A successful compile alone is not evidence of safe runtime behavior.
