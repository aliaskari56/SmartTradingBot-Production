# Strategy-to-Manager Static Audit — 2026-10-20

## Scope and evidence

- Repository: `aliaskari56/SmartTradingBot-Production`
- Working branch: `fix/structure-first-fvg-trailing-20261020`
- Audited source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
- Source blob SHA observed during this audit: `c8a09e3a05f7ac8aea37ccd421a7aa1012191ffd`
- Audit type: static source review only. No MetaTrader runtime, Strategy Tester, broker, or demo execution was performed as part of this audit.
- No changes to `main`, no merge, and no deployment are part of this checkpoint.

## End-to-end flow found in source

1. Scanner validates quote/data eligibility, market quality, and regime.
2. For each permitted direction, `BuildSetup()` applies tradeability, spread, oscillator policy, cooldown, H4 trend policy, M15 structure, setup-age, local FVG/OB, optional HTF confluence, structural geometry, broker-normalized pending geometry, minimum RR, and the strategy score floor.
3. A candidate stores the setup and ranking inputs. The scanner sorts, revalidates, recalculates market quality/regime, reranks the watchlist, and computes its top-candidate confidence gap.
4. `STB_ExecuteTopCandidate()` obtains a per-symbol entry lock, calls `STB_FinalCandidateRevalidation()`, applies the final auto/exposure gate, and then calls `PlaceSetup()`.
5. `PlaceSetup()` checks writer/entry-lock ownership, trading permission, exposure, setup cooldown, pending geometry, sizing, volume limits, pending lifetime, and `OrderCheck()`. It submits the pending order synchronously, verifies the server result and initial SL, records setup/profile/risk state, and invokes `STB_AfterExposureCreated()`.
6. On fill, the transaction handler calls `STB_PendingTrailOnOrderFilled()`, initializes protection state for eligible positions, and calls `STB_ManagePositionImmediately()`. Ongoing position management is centralized in `STB_RunManagementCycle()`.

## Findings

### STR-AUD-01 — CHoCH/BOS output semantics are not independently represented

**Evidence:** `DetectStructure()` finds a fresh close crossing a confirmed swing level. It assigns `chochShift=pivotShift` and `bosShift=s`. The first value is the swing pivot's shift, not the shift of a separately detected CHoCH event. `BuildSetup()` rejects when this single-break detector returns false using the reason `NO_VALID_CHOCH_BOS`.

**Impact:** The implementation currently represents one fresh structural break and its broken pivot; the names/rejection label can be read as proof of a two-event CHoCH-then-BOS sequence, which this detector does not establish.

**Disposition:** Specification decision required before behavior changes. Either explicitly define the detector as a single fresh structure break and name/log it accordingly, or define separate event criteria and add independent event state plus ordering tests. Do not silently treat the current pivot shift as a CHoCH event timestamp.

### STR-AUD-02 — Score clipping can collapse distinct raw scores

**Evidence:** `BuildSetup()` adds trend, BOS-age, RR, FVG, OB, and oscillator components, then clips the aggregate to 100.

**Impact:** Different raw component totals can become the same stored score. This is a score-resolution concern, not proof that ranking outcomes are wrong.

**Disposition:** Before changing weights or thresholds, add diagnostic/test coverage for raw component totals, clipped-score frequency, score ties, and downstream candidate ordering. No scoring weights were changed in this audit.

### STR-AUD-03 — H4-required and Universal-mode precedence must be an explicit contract

**Evidence:** `BuildSetup()` first rejects missing or misaligned H4 trend when `InpRequireH4TrendAlignment` is true. The later `InpAllowUniversal` check cannot override that earlier rejection.

**Impact:** This is deterministic precedence in the current code. Whether it is correct depends on the intended configuration contract.

**Disposition:** Keep behavior unchanged until the configuration matrix is approved and tests verify all combinations of required H4 alignment, valid/missing H4 trend, aligned/misaligned direction, and Universal mode.

### STR-AUD-04 — Revalidation protects setup identity, but needs regression coverage across the full handoff

**Evidence:** `STB_FinalCandidateRevalidation()` rebuilds the setup and rejects when the refreshed `setupTime` differs from the candidate's original `setupTime`. The execution path then rechecks geometry and the final auto/exposure gate before `PlaceSetup()`.

**Impact:** The code has an explicit stale-setup defense. Static inspection alone does not prove that all races, ranking changes, symbol-data changes, or broker rejections are handled correctly at runtime.

**Disposition:** Add deterministic tests for unchanged setup, newly formed BOS between scan and submission, changed/missing data, changed geometry, lost entry lock, lost symbol-management lease, and exposure appearing before submit. Verify every rejection reason and ensure no order is reported as accepted unless the server result and required initial protection are verified.

### STR-AUD-05 — Manager handoff is split across order creation and transaction events

**Evidence:** After the server confirms the pending order and initial SL is verified, `PlaceSetup()` calls `STB_AfterExposureCreated(placedOrder,"AUTO")`. On a fill transaction, the handler invokes the pending-fill transition and, for eligible positions, `STB_ExposureEnsure()`, `STB_GeomStore()`, and `STB_ManagePositionImmediately()`. Ongoing management is centralized in `STB_RunManagementCycle()`.

**Impact:** This is a multi-stage lifecycle rather than a single synchronous call. Correctness depends on idempotence and recovery when transaction events are delayed, repeated, or interrupted by restart.

**Disposition:** Test pending accepted → registered → filled → position protection active → managed-cycle discovery. Also test repeated fill/transaction notifications, partial fills where supported, immediate position disappearance, restart recovery, and manual/foreign positions. No runtime result is claimed here.

### STR-AUD-06 — Setup eligibility and ranking should remain separate concepts

**Evidence:** Hard conditions in `BuildSetup()` reject setups before the score is calculated; scanner ranking then combines strategy, market-quality, regime, and stability scores. Final revalidation rebuilds the setup before submission.

**Impact:** The architecture distinguishes hard eligibility from ranking, but test coverage must ensure that a high aggregate scanner score cannot bypass a failed strategy gate and that final rejection cannot be bypassed by an earlier rank.

**Disposition:** Add negative tests for each mandatory gate and a positive control for a candidate that passes all required gates. Confirm that every final rejection leaves no unintended pending order and records a stage-specific reason.

### STR-AUD-07 — Scanner setup age is inferred from wall-clock seconds, not observed M15 bars

**Evidence:** In scanner candidate creation and watchlist revalidation, `setupAgeBars` is calculated as `(TimeCurrent()-setupTime)/900`. This converts elapsed wall-clock time to nominal 15-minute bars. Separately, `BuildSetup()` has the actual `bosShift` available and applies a structure-age check based on bar shift.

**Impact:** Wall-clock duration is not equivalent to the number of M15 bars that have formed. Market closures, weekends, missing history, and symbol-specific session gaps can make the scanner's `InpMaxSetupAgeBars` filter disagree with the structure detector's bar-shift age. This can cause inconsistent eligibility decisions; static inspection does not quantify how often it occurs.

**Disposition:** Treat bar-count age and elapsed-time age as separate concepts. Specify which one `InpMaxSetupAgeBars` means, then add tests around weekends/session gaps, missing bars, and a newly closed M15 candle. Do not silently replace one with the other without confirming intended behavior.

### STR-AUD-08 — Fallback candidates can inherit a confidence decision made for a different winner

**Evidence:** `STB_ExecuteTopCandidate()` checks `g_scannerConfidence` once before iterating through `g_scannerTop10`. If the top-ranked candidate later fails symbol selection, entry-lock acquisition, final revalidation, the final auto gate, or placement, the loop can continue to the next candidate. The confidence label was calculated earlier from the top two candidates in the revalidated watchlist, not from a fresh comparison of the fallback candidate against its current runner-up.

**Impact:** The candidate eventually attempted for placement may not itself satisfy the configured top-score gap as the leading eligible candidate. This is a ranking/eligibility consistency risk. The static path shows the missing recalculation; runtime frequency and consequences have not been measured.

**Disposition:** Add a regression test where candidate 1 initially clears the gap but fails final revalidation, while candidates 2 and 3 are closer than the required gap. The approved policy should either stop after the winner fails, or recompute eligibility/confidence from the remaining freshly validated candidates before considering a fallback. Do not treat the original `CLEAR` value as proof that every fallback is clear.

### STR-AUD-09 — Local FVG and OB are not proven to belong to one common displacement/BOS event

**Evidence:** `FindFVG()` restricts its impulse candle to within two shifts of `bosShift`. `FindOriginCandle()` searches backward from `bosShift` across the configured pattern window and accepts an opposite candle when the immediately following displacement candle closes beyond that opposite candle. The shown OB predicate does not explicitly require that the displacement candle break the same `breakSwing.price` that `DetectStructure()` identified, nor does it return a shared impulse/event identifier that can be compared with the FVG.

**Impact:** A setup can potentially combine an FVG near the BOS with an OB that passes its local displacement predicate but is not explicitly proven to originate from the same structure-break sequence. Whether that is unacceptable depends on the intended pattern definition; static inspection alone does not establish how often such combinations occur.

**Disposition:** Make the confluence contract explicit: if FVG and OB must belong to the same impulse, record the impulse/event identity and test that relationship; if independent but nearby zones are allowed, document the permitted temporal/spatial relationship and test its boundaries. Do not tighten the pattern rule without an approved definition.

### STR-AUD-10 — Protection eligibility is broader than strategy-managed eligibility

**Evidence:** `STB_IsProtectionPosition(ticket)` accepts a broader set of live account positions than `IsManagedPosition()`, which applies the symbol allow-list. Transaction intake can call immediate management after the protection-scope check.

**Impact:** Manual or foreign-symbol positions may enter the protection/management path even when they are not eligible for strategy entry management. This may be intentional account-protection policy, but the ownership boundary is not self-evident.

**Disposition:** Define separate contracts for protection scope and strategy-management scope. Test manual, foreign-magic, disallowed-symbol, tester chart-only, netting, and hedging cases before narrowing either predicate.

### STR-AUD-11 — Symbol-management lease expiry depends on server time

**Evidence:** The symbol writer lease uses `TimeCurrent()` with a 90-second TTL, while the entry lock uses `TimeLocal()`.

**Impact:** When server time is not advancing because quotes are absent/stale, lease expiry and reclaim timing may differ from elapsed wall-clock time. Two-instance ownership behavior is not established by static inspection.

**Disposition:** Test two EA instances with active quotes, quiet markets, stale quotes, restart, and lease-owner disappearance. Document whether expiry is intended to follow server time or wall-clock time.

### STR-AUD-12 — Partial fills need explicit pending-trail lifecycle coverage

**Evidence:** Pending trail handling is deactivated on the first `DEAL_ADD`; the periodic pending-trail processor may discover and register a still-existing remainder through terminal order enumeration.

**Impact:** Correctness depends on transaction ordering and subsequent reconciliation when a pending order partially fills and leaves a remainder.

**Disposition:** Add partial-fill tests that verify remainder tracking, protection initialization for the filled volume, and cleanup only when the remainder is gone. This is a conditional lifecycle risk, not a confirmed defect.

### STR-AUD-13 — Transaction intake does not explicitly branch on every transaction type

**Evidence:** The inspected `STB_TradeIntakeFromTransaction()` excerpt has explicit `TRADE_TRANSACTION_ORDER_ADD` and `TRADE_TRANSACTION_DEAL_ADD` paths; it does not show equivalent explicit branches for order deletion or deal update.

**Impact:** Correctness may depend on reconciliation and terminal scans rather than direct event handling. The excerpt alone does not prove missing cleanup.

**Disposition:** Test order delete/cancel/expiry, deal add/update, delayed event ordering, and restart reconciliation. Confirm that stale registry and pending-trail entries are removed deterministically.

### STR-AUD-14 — Pending-order write quota is consumed after verification

**Evidence:** The central pending-order writer records its write quota after a successful result and geometry verification, unlike the position bridge path that consumes quota before sending.

**Impact:** If a request has an ambiguous outcome, another write may be attempted in the same cycle because the first write was not recorded as consuming the quota. Whether this is possible depends on the trade API outcome path.

**Disposition:** Test success, explicit rejection, timeout/ambiguous result, geometry mismatch, and order disappearance. Do not change quota semantics until ambiguous outcomes are specified.

### STR-AUD-15 — Pending writer postcondition needs ambiguous-result tests

**Evidence:** The pending writer performs post-send selection/geometry checks, but the inspected path does not establish a tested outcome for every ambiguous server response.

**Impact:** A send result and the terminal's eventual order state can diverge. Incorrect assumptions could cause duplicate modification attempts or stale state.

**Disposition:** Add deterministic checks for accepted-and-present, rejected, accepted-but-not-yet-visible, disappeared-before-postcheck, and mismatched geometry outcomes.

### STR-AUD-16 — Initial-SL repair and pending trailing share a cycle write budget

**Evidence:** The management cycle orders work as `ManagePositions()`, `ManagePendingOrders()`, then `STB_PendingTrailProcess()`. Pending-order management repairs SL before TP, and the trailing processor uses the same per-cycle write quota.

**Impact:** A successful initial-SL repair can prevent trailing from writing during that cycle, which appears consistent with a one-write budget. Failure and retry interactions still require validation.

**Disposition:** Test successful SL repair, failed SL repair, TP-only repair, and simultaneous trail eligibility; assert at most the intended number of writes per symbol/order/cycle.

### STR-AUD-17 — Pending initial-SL retry backoff is not persisted across restart

**Evidence:** `STB_RecordPendingInitialSLFailure()` uses a 5s, 15s, then 60s backoff sequence. `STB_PendingTrailRebuildFromTerminal()` clears in-memory state and registers existing orders with `failureCount=0` and `nextRetryTime=0`.

**Impact:** Restart resets retry history and can cause an immediate retry that would otherwise be delayed. This is confirmed behavior; whether it is a defect depends on the intended restart contract.

**Disposition:** Decide whether retry backoff must survive restart. Test restart after each failure count and ensure the chosen policy is observable and bounded.

### STR-AUD-18 — Pending-trail reconstruction resets retry scheduling

**Evidence:** Rebuild-from-terminal reconstructs pending trail state from live terminal orders rather than restoring prior retry counters and retry deadlines.

**Impact:** This is the same underlying mechanism as STR-AUD-17, not a separate defect: retries restart from the initial state after reconstruction.

**Disposition:** Track this as the restart-specific test dimension for STR-AUD-17; do not double-count it as an independent defect.

### STR-AUD-19 — Manual-override authority transfer from order to position is not explicit

**Evidence:** On `DEAL_ADD`, intake invokes `STB_PendingTrailOnOrderFilled(trans.order)`, then stores exposure/geometry for the selected position and invokes immediate management. The inspected path does not show a generic explicit transfer of manual-override state from the order ticket to the position identifier.

**Impact:** Whether a user override survives a pending-order fill depends on the called helper implementations, identifier mapping, and account mode. Static evidence does not establish a confirmed loss of override.

**Disposition:** Trace helper internals and test pending-order manual modification followed by fill, delayed events, restart, netting, and hedging. Assert the intended authority is retained or intentionally reset.

### STR-AUD-20 — Orphan-state grace uses server time

**Evidence:** `STB_ExposureOrphanGraceActive()` compares `TimeCurrent()` with the last-seen timestamp and retains absent-ticket state for a 120-second grace period.

**Impact:** Cleanup may be delayed if server time is stale because no quote arrives. The grace protects delayed event recovery, so removing it without a replacement could create a different lifecycle risk.

**Disposition:** Test elapsed wall time versus server time during quiet markets and restart. Specify whether delayed cleanup is acceptable and ensure stale state cannot persist indefinitely.

### STR-AUD-21 — INOUT reversal closes the old adaptive lifecycle without explicit new-lifecycle initialization in that branch

**Evidence:** For `DEAL_ENTRY_INOUT`, `OnTradeTransaction()` calculates the old direction, consumes accumulated PnL, records the old lifecycle, deletes the position profile/risk, and returns. That branch does not explicitly initialize a new profile/risk lifecycle for any reversed residual exposure.

**Impact:** If the account mode and transaction semantics leave a new reversed position open, it may lack adaptive profile/risk state until another supported initialization path runs. This is a conditional lifecycle gap, not yet a confirmed defect.

**Disposition:** Test full reversal, partial reversal/residual exposure, netting and hedging semantics, delayed events, and subsequent close. Define whether a residual reversed position is managed as a new strategy lifecycle or excluded from adaptive learning.

### STR-AUD-22 — Duplicate of the INOUT lifecycle concern

This is the same source path as STR-AUD-21 and is retained here only to preserve the audit trail from the working discussion. It is not a separate finding and must not be counted twice.

### STR-AUD-23 — Adaptive order-to-position state transfer has multiple prerequisites

**Evidence:** On `DEAL_ENTRY_IN`, the code reads the profile from order state and falls back to parsing the deal comment, remembers the position profile, reads planned order risk, and prefers recalculated risk from actual fill volume/price and active SL when available; then it deletes order state.

**Impact:** Delayed events, absent/invalid profile metadata, or unavailable initial SL can change which state is transferred. The code explicitly skips lifecycle learning when no valid profile can be recovered and may leave risk unavailable.

**Disposition:** Test normal and delayed fills, missing order state, valid/invalid comments, missing SL, partial fills, and restart. Verify that deleting order state cannot erase the only recoverable profile/risk before position state is safely recorded.

### STR-AUD-24 — Missing initial-risk state correctly prevents an invalid R sample, but restart and delayed-SL paths need tests

**Evidence:** Position risk is stored only when positive and finite. Closed-deal recording adds an R observation only when `hasValidRiskSample` is true and the R multiple is finite.

**Impact:** This avoids fabricating an R sample when the denominator is unknown. It also means a lifecycle whose risk state was lost or never captured is excluded from R expectancy.

**Disposition:** Preserve this guard. Test restart, delayed fill/exit events, missing initial SL, and risk recalculation failure to verify that unavailable R is logged as unavailable rather than treated as zero.

### STR-AUD-25 — Accumulated position PnL is a consume-on-read global state, not a complete idempotency guarantee

**Evidence:** `TakeAccumulatedPositionPnl()` reads the accumulated value and deletes its global-variable key. The OUT path adds the current deal PnL before checking whether the position identifier remains open; a fully closed lifecycle then consumes the sum and records an outcome.

**Impact:** Consume-on-read supports one-time aggregation in the normal event sequence, but does not by itself prove duplicate-event safety, crash consistency, or concurrency safety. Setup-decision deduplication is separate and does not establish closed-trade deduplication.

**Disposition:** Add tests for multiple partial exits, duplicate/replayed close processing, delayed deal events, restart between accumulation and consumption, and repeated history reconciliation. If duplicate processing is in scope, persist a per-deal/per-lifecycle idempotency marker before updating learner statistics.

### STR-AUD-26 — Closed-lifecycle adaptive-stat updates have no visible per-deal idempotency marker

**Evidence:** `STB_AdaptiveRecordClosedDeal()` increments profile win/loss observations and updates R sum/count, then flushes global variables. In the inspected `OnTradeTransaction()` close paths, the lifecycle is recorded after consuming accumulated PnL, but no explicit processed-deal or processed-lifecycle key is checked in the shown path before the statistics increment.

**Impact:** If the same close lifecycle is processed twice through a replay/recovery path, learner counts can be incremented twice. Normal terminal delivery may not trigger this, so this is a recovery/idempotency risk requiring validation rather than a claim that ordinary event delivery duplicates callbacks.

**Disposition:** Test duplicate transaction handling and crash/restart boundaries. If replay/reconciliation is supported, add a stable lifecycle/deal idempotency key and make statistics update plus marker semantics robust to partial failure. Do not introduce a marker that could suppress legitimate partial-exit aggregation.

## Required test cases

| ID | Scenario | Expected result | Status |
|---|---|---|---|
| STR-A01 | One fresh break with confirmed pivot | Break event and pivot are reported distinctly; no false claim of two independent events | NOT RUN |
| STR-A02 | Pivot unconfirmed / insufficient right-side bars | No structure event is accepted | NOT RUN |
| STR-A03 | Break candle is not a fresh cross | Persistent beyond-level state alone is rejected | NOT RUN |
| STR-A04 | Raw strategy score exceeds 100 | Raw total and clipped score are both inspectable; ranking behavior is deterministic | NOT RUN |
| STR-A05 | H4 required × Universal enabled, H4 missing or misaligned | Behavior matches the approved precedence matrix | NOT RUN |
| STR-A06 | Candidate setup time changes after initial scan | Final revalidation rejects as stale; no order is submitted | NOT RUN |
| STR-A07 | Candidate geometry becomes invalid before submission | Final revalidation or placement rejects; no unverified order is reported | NOT RUN |
| STR-A08 | Entry lock or symbol writer lease is lost before submit | Submission is refused | NOT RUN |
| STR-A09 | Exposure appears between ranking and submission | Final gate refuses the duplicate/conflicting setup | NOT RUN |
| STR-A10 | Pending accepted but initial SL cannot be verified | Rollback/explicit failure path is observed; cooldown is not falsely committed | NOT RUN |
| STR-A11 | Pending order fills | Protection state is initialized and the position reaches the manager path | NOT RUN |
| STR-A12 | Duplicate/delayed transaction events and restart | Management state remains consistent and idempotent | NOT RUN |
| STR-A13 | High scanner score but a required strategy gate fails | Candidate is excluded; score cannot override the hard gate | NOT RUN |
| STR-A14 | Final revalidation rejects a previously ranked candidate | Rejected candidate is not submitted; rejection stage/reason is logged | NOT RUN |
| STR-A15 | Wall-clock time crosses a session gap while few/no M15 bars form | Setup-age behavior matches the documented age definition | NOT RUN |
| STR-A16 | Top candidate fails final validation; fallback is close to runner-up | Fallback is attempted only if it independently satisfies the approved confidence policy | NOT RUN |
| STR-A17 | FVG and OB pass individually but derive from different impulses | Acceptance follows the approved shared-event or independent-zone contract | NOT RUN |
| STR-A18 | Protection scope vs managed scope across manual/foreign/disallowed-symbol positions | Behavior matches the approved ownership contract | NOT RUN |
| STR-A19 | Two EA instances contend for symbol lease during quiet/stale quotes | Lease ownership and reclaim follow the documented clock/TTL policy | NOT RUN |
| STR-A20 | Pending order partially fills and remainder remains active | Filled position is protected and remaining pending order stays correctly tracked | NOT RUN |
| STR-A21 | Order cancellation/expiry and delayed transaction ordering | Registry, trail, exposure, and geometry state reconcile without stale entries | NOT RUN |
| STR-A22 | Pending writer receives ambiguous send/postcheck outcome | No duplicate write; final order state and write quota are reconciled | NOT RUN |
| STR-A23 | Initial-SL repair and pending trailing are eligible in the same cycle | Write quota and retry behavior match the documented policy | NOT RUN |
| STR-A24 | Restart after pending initial-SL failures | Retry backoff follows the explicitly chosen persistence policy | NOT RUN |
| STR-A25 | Pending order is manually modified and then filled | Manual-override authority follows the approved order-to-position transfer policy | NOT RUN |
| STR-A26 | Quiet market delays server time during orphan-state grace | Cleanup timing is bounded and matches the documented clock policy | NOT RUN |
| STR-A27 | DEAL_ENTRY_INOUT reversal with residual exposure | Old lifecycle closes exactly once and new residual state follows contract | NOT RUN |
| STR-A28 | Missing profile/risk state during delayed fill or after restart | Invalid profile is excluded and unavailable R is never fabricated | NOT RUN |
| STR-A29 | Partial exits, duplicate close processing, and restart between PnL accumulation/consume | Closed-lifecycle PnL and adaptive observations are idempotent | NOT RUN |

## Exit criteria

- Decide and document CHoCH/BOS semantics before changing structure behavior.
- Approve the H4/Universal configuration precedence.
- Add deterministic tests for score diagnostics, stale candidates, final gates, and manager lifecycle.
- Re-run exact-source compile and static checks after source changes.
- Run the relevant Strategy Tester and demo-lifecycle checks before any release decision. Compilation or static audit alone is not evidence of runtime correctness or profitability.

## Current status

**Static audit in progress; release status remains NOT VERIFIED.** This document records code paths and test obligations; it does not certify runtime behavior or trading performance.
