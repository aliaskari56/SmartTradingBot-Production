# Pass 20 — Technical Audit Execution Plan (2026-10-09)

## Status and scope

**Status: DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN.**  
This plan orders the open findings in Pass 19 into an evidence-gated execution sequence. It is not a test report, a remediation approval, or a release authorization. No executable source changes are included in this pass.

Reviewed primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
Expected source Git blob SHA: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`  
Previously recorded size: 8,665 lines. Re-verify the SHA before any test or patch.

## Execution principles

1. **Freeze the test subject.** Record commit, source blob SHA, SHA-256 of the exported source file, dependency inventory, terminal/MetaEditor build, and test configuration before a run.
2. **Separate observation from conclusion.** A static concern remains open until its stated acceptance evidence exists; absence of a reproduced failure is not proof of correctness.
3. **No live-account validation.** Use a controlled test environment and then a demo account for behavior verification. Do not use real-money deployment as a test.
4. **One remediation at a time.** For each code change, preserve a focused diff, compile the exact changed tree, rerun relevant regression cases, and record residual risks.
5. **No silent bypasses.** Order ownership, cleanup, SL/TP updates, and failure handling must have explicit authorization and test coverage.
6. **Keep release blocked** while any high-priority write-boundary, source/build provenance, or behavioral risk gate is unresolved.

## Ordered work packages

| Order | Work package | Findings / gates | Owner / environment | Exit evidence | Dependency |
|---|---|---|---|---|---|
| 0 | Establish immutable audit snapshot | BL-01, EVID-01 | Repository maintainer + local terminal operator | Commit ID; source blob SHA and file SHA-256; complete dependency inventory; timestamped evidence folder | Start here |
| 1 | Exact-source build and artifact provenance | BL-01, BL-02; RG-01, RG-02 | Local MetaEditor environment | Full raw compile log; MetaEditor/build version; command/settings; source hash; resulting EX5 hash; manifest tying all values together | Work package 0 |
| 2 | Dependency origin and distribution rights | BL-03 | Dependency maintainer / release owner | Per-file origin/version/local-modification/license register; official source for standard library; disposition for unclear-provenance files | Can run in parallel with 1 |
| 3 | Order-delete authorization design | BL-04, ARCH-01; DEL-01..DEL-08 | MQL5 maintainer + independent reviewer | Written authorization contract; ordinary lifecycle delete requires verified ownership/lease; rollback path proves the ticket was created by the current operation; negative tests for foreign orders and stale tickets | Snapshot; design review before code |
| 4 | Position SL/TP write semantics | BL-05, BL-06, ARCH-02; SL-01..SL-06 | MQL5 maintainer + independent reviewer | Documented snapshot freshness strategy; merged SL/TP proposal contract; deterministic arbitration rules; evidence of at most one approved write per position/cycle; regression results | Snapshot; design review before code |
| 5 | Pending-trail restart and recovery | BL-07; RG-07 | MQL5 maintainer + test operator | Reproducible restart/rebuild/retry tests; per-ticket state assertions; proof no unauthorized order mutation after lease loss | Work packages 1, 3 |
| 6 | Event lifecycle and reconciliation | BL-08, EVT-F01..EVT-F05; EVT-01..EVT-10 | Test operator + reviewer | Repeated and reordered transaction tests; tick/timer interleaving tests; partial close/reversal accounting; restart and multi-chart evidence | Work packages 1, 3, 4 |
| 7 | Strategy Tester and demo behavioral validation | BL-09; RG-09; T-01..T-14 | Test operator / release owner | Configuration, data range, symbol/account mode, spread/slippage assumptions, complete logs/reports, exposure/risk results, and reproducible case outcomes | Work packages 1–6 |
| 8 | Independent review and release decision | BL-10; RG-10 | Reviewer not authoring the remediation + release owner | Review record; all findings closed or explicitly accepted with rationale; residual-risk list; signed GO/NO-GO decision | All relevant work packages |

## Minimum design decisions before implementation

### A. Order deletion

- Define the default authorization predicate at the actual delete write boundary, not only in callers.
- Define a narrow rollback capability that is tied to a ticket returned by the current creation operation and is invalidated after use or operation termination.
- A reason enum or caller label alone must not bypass ownership proof.
- Specify behavior when the ticket disappears, the server rejects the request, the lease is lost, or a retry races with reconciliation.
- Acceptance requires both positive cases (authorized lifecycle cleanup and current-operation rollback) and negative cases (foreign order, stale proof, lost lease).

### B. Position modification

- Treat the position snapshot as potentially stale between read and server request.
- Specify whether the writer re-reads current SL/TP immediately before submission and how it handles a concurrent update.
- Collect candidates from initial protection, profit-lock, and trailing logic before arbitration; do not assume a one-item proposal array proves cross-manager arbitration.
- Define BUY/SELL monotonicity rules, stop/freeze-level validation, manual override policy, rejected-request behavior, and one-write-per-cycle semantics.
- Confirm whether a TP manager is intended to exist; do not infer one from preserving an existing TP.

These are design requirements, not assertions that a particular runtime failure has already occurred.

## Evidence bundle template

For each run, store a unique run ID and include:

- source commit, source blob SHA, exported source SHA-256, dependency manifest;
- terminal and MetaEditor versions, account mode (hedging/netting), broker/server context where relevant;
- test case ID, preconditions, exact steps, expected result, actual result;
- complete raw logs and screenshots/exported reports where applicable;
- server retcodes and before/after order/position snapshots;
- pass/fail/not-run status, anomaly link, reviewer, timestamp;
- for a code fix: focused diff, new source hash, compile log, regression evidence, and remaining limitations.

Do not store credentials, account passwords, or unnecessary personal/account identifiers in the evidence bundle.

## Gate policy

- **PASS:** every acceptance item has attached, reproducible evidence and has been reviewed.
- **FAIL:** a test violates expected behavior or produces an unexplained result.
- **BLOCKED:** prerequisite, environment, or required evidence is unavailable.
- **NOT RUN:** no execution evidence exists. Documentation alone cannot convert NOT RUN into PASS.
- **CLOSED:** the finding owner and independent reviewer record the decision, evidence references, commit/hash, residual risk, and closure date.

## Current blockers and required local actions

The repository review cannot substitute for a local MetaEditor build or Strategy Tester run. The maintainer/operator must provide the exact-source build log and environment metadata, then execute the ordered test packages. Historical workflow logs and manifest claims are not evidence that the currently reviewed source builds successfully.

No executable source was changed in Pass 20. No compile, runtime, Strategy Tester, demo-account, or independent-review activity was performed in this pass. The branch remains a documentation/audit branch; this plan does not authorize merge or deployment.
