# Pass 19 — Consolidated Finding Register (2026-10-09)

## Purpose and status

This register consolidates open audit findings documented through Pass 18. It is a triage and evidence-tracking artifact, not a claim that all possible defects have been discovered.

**Overall status: DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN**  
**Source scope:** `MQL5/Experts/SmartTradingBot_FINAL.mq5` and the dependencies traced in prior passes.  
**Source changes in this pass:** none. **Build/runtime tests:** not performed. **Independent review:** not performed.

### Severity interpretation

- **Critical / High / Medium / Unknown** here are provisional audit-priority labels, not a quantified probability of harm. Findings affecting order authorization, stop-loss/take-profit writes, or live trading remain release blockers until verified.
- **Open** means required evidence is missing; it does not necessarily mean the behavior is defective.
- **Static finding** means source inspection supports the observation, but runtime consequences remain unproven.

## Consolidated findings

| ID | Priority | Finding / evidence | Required disposition | Acceptance evidence | Status |
|---|---|---|---|---|---|
| BL-01 | High | Exact-source build provenance is missing. A backup manifest claims a compile result, but raw compiler output, exact source hash, and toolchain linkage have not been independently verified. | Compile the exact reviewed source with a recorded MetaEditor/toolchain version and command/settings. | Raw complete build log; source SHA-256; toolchain/version; build command/settings; explicit error/warning count. | OPEN |
| BL-02 | High | Checked-in EX5 exists, but source-to-binary provenance is not established. | Produce the EX5 from the exact reviewed source and retain hashes and build evidence. | Input source hash and output EX5 SHA-256 tied to the same build record. | OPEN |
| BL-03 | High | Dependency provenance/licensing is unresolved for the full include tree; two STB modules need explicit ownership/license evidence. | Inventory upstream versions, local modifications, notices, and redistribution terms; resolve ambiguous files before packaging. | Per-file provenance/license inventory and approval for redistribution. | OPEN |
| BL-04 | Critical | `STB_ExecuteOrderDelete()` validates server response/ticket disappearance, but verified lease/scoped authorization is not visibly enforced at the writer boundary. Rollback cleanup paths make a blanket lease guard unsafe without a defined exception contract. | Define normal-delete authorization and bounded rollback proof; do not let a reason enum alone bypass ownership proof. | DEL-01..DEL-08 pass; call-site inventory; tests for owned, foreign, missing, rejected, rollback and lease-race cases. | OPEN |
| BL-05 | High | `ModifyPositionSL()` calls `trade.PositionModify(ticket,newSL,tp)`; TP is supplied from a local snapshot and may be stale if another writer changes it. This is a potential lost-update risk, not proof an overwrite occurred. | Define serialization/fresh-read/merge behavior for SL and TP writes. | SL-03..SL-05 plus evidence that concurrent/stale TP cannot be unintentionally overwritten. | OPEN |
| BL-06 | High | `STB_SubmitPositionSL()` passes a single proposal to `STB_ResolvePositionSL()`; simultaneous arbitration among initial SL, profit-lock and trailing proposals is not demonstrated. | Define deterministic candidate priority, monotonicity, validation, and one-write-per-cycle behavior. | SL-01..SL-02 and SL-05 pass with BUY/SELL and competing-candidate cases. | OPEN |
| BL-07 | High | Pending-trail state/rebuild/retry components are present, but end-to-end activation, handoff, restart and recovery are not runtime-proven. | Exercise lifecycle and reconcile expected state after restart, missing tickets, rejected modifications and broker constraints. | Relevant release gate RG-07 and documented tester/demo results. | OPEN |
| BL-08 | High | Trade events may be reordered or delivered in stages; handler intake/accounting idempotence is not proven. Tick and timer both invoke management; timer reconciliation is observed after that timer's management cycle. | Decide reconciliation ordering and prove idempotence across callbacks, repeated transactions and adjacent cycles. | EVT-02..EVT-06 pass with event logs and expected-vs-actual ledger. | OPEN |
| BL-09 | Critical | No current-source Strategy Tester, demo-account or broker-behavior evidence has been supplied/verified. | Execute a documented risk-focused test matrix on the exact build; review outcomes, not just summary metrics. | RG-09, T-01..T-14 and event-focused cases with settings, data range, logs and results. | OPEN |
| BL-10 | High | No independent technical review or named release-owner decision is recorded. | Independent reviewer assesses code and evidence; release owner records explicit GO/NO-GO with residual risks. | Review record and signed/attributed decision tied to source/artifact hashes. | OPEN |
| EVT-F01 | High | Per-cycle dedup may not deduplicate across a tick-triggered cycle and a separate timer-triggered cycle. | Test adjacent and overlapping tick/timer cycles; clarify the deduplication contract. | EVT-02 and EVT-03 pass. | OPEN |
| EVT-F02 | High | `STB_TradeIntakeFromTransaction()` is invoked before later transaction/deal filtering; safety and idempotence for every transaction type are not established. | Test repeated/out-of-order transaction callbacks and inspect intake invariants. | EVT-04 passes without duplicate state mutation/accounting. | OPEN |
| EVT-F03 | Medium | Timer path runs management before registry reconciliation in the same timer callback. Whether this ordering is acceptable is not yet decided. | Decide desired invariant; change only if required and then test. | Written ordering decision plus EVT-01/03 evidence. | OPEN |
| EVT-F04 | High | Partial-close and reversal accounting branches exist, but netting/hedging behavior and cost attribution are unverified. | Reconcile lifecycle records against deal history including commission, fees and swap as applicable. | EVT-05..EVT-07 pass with a reproducible ledger. | OPEN |
| EVT-F05 | High | Deinitialization releases leases and initialization rebuilds state, but multi-chart and restart recovery are unproven. | Test recompile, chart closure, terminal restart and two charts managing the same symbol. | EVT-01 and EVT-09 pass; logs show correct lease ownership. | OPEN |
| ARCH-01 | High | Four order-creation families are present; a single structurally enforced creation gateway has not been established. | Map all create-order call sites and decide whether a central gateway is required. | Complete call-site inventory and tests proving every creation path enforces shared authorization, risk and result validation. | OPEN |
| ARCH-02 | Medium | Logical module boundaries share one translation unit. This limits structural isolation but is not by itself proof of incorrect behavior. | Decide whether modularization is needed for maintainability/testability; avoid broad refactoring before behavior is captured. | Approved architecture decision and regression evidence if changed. | OPEN |
| ARCH-03 | Medium | A separate break-even manager and independently verified live-position TP manager/resolver have not been established by the reviewed static trace. Profit-lock must not be relabeled as break-even without proof. | Confirm intended product behavior and map each advertised management feature to implementation and tests. | Feature-to-code map and tests; unsupported feature claims removed or corrected. | OPEN |
| EVID-01 | Medium | Historical CI logs refer to older commits/source paths; current branch has no verified current-source build status. | Establish fresh, exact-commit build evidence; do not treat historical workflows as current proof. | New run linked to exact branch commit and source hash with complete logs. | OPEN |

## Cross-reference to existing evidence

- [Release evidence checklist](RELEASE_EVIDENCE_CHECKLIST_20261009.md): RG-01..RG-10 and T-01..T-14.
- [Mutation boundary trace, Pass 17](MUTATION_BOUNDARY_TRACE_PASS17_20261009.md): delete authorization, rollback semantics, SL/TP write boundary, DEL-01..DEL-08 and SL-01..SL-06.
- [Event lifecycle trace, Pass 18](EVENT_LIFECYCLE_TRACE_PASS18_20261009.md): event ordering, restart/reconciliation and EVT-01..EVT-10.
- [Root audit blueprint](ROOT_AUDIT_BLUEPRINT.md): scope, static findings and prior-pass records.

## Closure protocol

For each finding, record: owner; decision; remediation commit (if any); exact source hash; test case and environment; raw evidence location; result; residual risk; reviewer; closure date. A finding must not be marked closed based solely on a code change or an assertion. For build/test-dependent findings, attach reproducible output tied to the exact source/artifact hash.

### Release rule

No GO recommendation is supported by the evidence currently recorded. Do not deploy to a live account based only on this documentation pass. The current status is **DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN**.
