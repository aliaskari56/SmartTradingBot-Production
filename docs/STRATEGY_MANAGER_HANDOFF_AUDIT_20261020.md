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

### STR-AUD-07 — Status after source correction: setup age now uses observed M15 bar shifts

**Correction:** Commit `e7f596bc05e68d31d595da2d32e9b94634c2873b` replaces both discovery and watchlist wall-clock calculations `(TimeCurrent()-setupTime)/900` with `iBarShift(symbol,PERIOD_M15,setupTime,true)-1`. If the exact setup bar cannot be located, the candidate is rejected with an explicit diagnostic rather than silently treated as age zero.

**Expected behavior:** A setup on the most recently closed M15 bar has age 0; elapsed weekends/session closures do not increment age as if M15 bars had traded.

**Verification status:** The updated source was fetched back from GitHub; both old wall-clock formulas are absent and both new stage-specific checks are present. Compile, sparse-history behavior, and Strategy Tester coverage remain NOT RUN.

### STR-AUD-08 — Fallback candidates can inherit a confidence decision made for a different winner

**Evidence:** `STB_ExecuteTopCandidate()` checks `g_scannerConfidence` once before iterating through `g_scannerTop10`. If the top-ranked candidate later fails symbol selection, entry-lock acquisition, final revalidation, the final auto gate, or placement, the loop can continue to the next candidate. The confidence label was calculated earlier from the top two candidates in the revalidated watchlist, not from a fresh comparison of the fallback candidate against its current runner-up.

**Impact:** The candidate eventually attempted for placement may not itself satisfy the configured top-score gap as the leading eligible candidate. This is a ranking/eligibility consistency risk. The static path shows the missing recalculation; runtime frequency and consequences have not been measured.

**Status update — source correction present on branch:** `STB_ExecuteTopCandidate()` now checks each fallback candidate against the revalidated watchlist, locates its current rank by symbol/direction/setup time, and recomputes the score floor and gap to the next watchlist candidate. It stops fallback consideration when the candidate is missing from the revalidated watchlist or fails the configured confidence rule. This prevents the original winner's `CLEAR` label from automatically authorizing every fallback.

**Evidence:** Verified in `MQL5/Experts/SmartTradingBot_FINAL.mq5` at revision `ab9ed32d5277c4a9ff4442d02b88da46df041924`; that exact revision compiled with 0 errors and 0 warnings in workflow run `39534333105`.

**Remaining verification:** The targeted regression described above is still **NOT RUN**. Static inspection confirms the guard is present but does not establish runtime ranking behavior.

### STR-AUD-09 — Local FVG and OB are not proven to belong to one common displacement/BOS event

**Evidence:** `FindFVG()` restricts its impulse candle to within two shifts of `bosShift`. `FindOriginCandle()` searches backward from `bosShift` across the configured pattern window and accepts an opposite candle when the immediately following displacement candle closes beyond that opposite candle. The shown OB predicate does not explicitly require that the displacement candle break the same `breakSwing.price` that `DetectStructure()` identified, nor does it return a shared impulse/event identifier that can be compared with the FVG.

**Impact:** A setup can potentially combine an FVG near the BOS with an OB that passes its local displacement predicate but is not explicitly proven to originate from the same structure-break sequence. Whether that is unacceptable depends on the intended pattern definition; static inspection alone does not establish how often such combinations occur.

**Disposition:** Make the confluence contract explicit: if FVG and OB must belong to the same impulse, record the impulse/event identity and test that relationship; if independent but nearby zones are allowed, document the permitted temporal/spatial relationship and test its boundaries. Do not tighten the pattern rule without an approved definition.

### STR-AUD-29 — FVG and origin-candle checks do not share an explicit displacement identity

**Evidence:** `FindFVG()` limits its displacement candle to within two shifts of `bosShift`. `FindOriginCandle()` accepts `bosShift` but not the detected `breakSwing.price` or `fvgShift`; it scans older candles beginning at `bosShift+1`, tests an opposite candle followed immediately by a directional displacement, and checks that the displacement close exceeds that origin candle's high/low. It does not explicitly prove that the displacement used for the origin candle is the same displacement used for the FVG, or that the origin/displacement pair itself crosses the detected break-swing level.

**Impact:** A setup may combine individually valid structure, FVG, and origin-candle findings without an explicit shared-event identity. The current source does not prove this is a runtime defect for every setup; the missing invariant is the issue.

**Disposition:** Do not add a hard rejection or change strategy semantics until the intended contract is agreed. Define whether the OB displacement must be the BOS candle, precede the BOS within a bounded sequence, and/or be the same displacement candle as the FVG. Then pass the relevant event identity/price into the pattern functions and add positive/negative fixtures.

### STR-AUD-10 — Protection eligibility is broader than strategy-managed eligibility

**Evidence:** `STB_IsProtectionPosition(ticket)` accepts every live account position outside the explicit tester chart-only isolation case. In contrast, `IsManagedPosition()` checks `STB_IsSymbolAllowed()`, which permits the chart symbol plus the configured scanner universe (or all symbols when that list is empty). `ManagePositions()`, `AutoProfitProtection()`, and transaction intake use the broad protection predicate; manual command `ManualSavePlus20()` uses the narrower managed predicate.

**Impact:** The same position can be eligible for automatic SL/TP/trailing/profit-protection management but excluded from a user-invoked manual management command. Positions with foreign magic numbers and symbols outside the configured scanner universe can still enter the broad automatic management path. The code comment describes broad live-account protection as intentional, so this is a policy-contract mismatch to resolve—not a confirmed defect that should be silently narrowed.

**Disposition:** Explicitly approve one of these contracts: (A) all live account positions receive automatic protection while manual commands are symbol-scoped; or (B) automatic management is also constrained by the managed-symbol predicate. Then test manual, foreign-magic, disallowed-symbol, tester chart-only, netting, and hedging cases. Do not change the predicate until the contract is approved.

### STR-AUD-11 — Symbol-management lease expiry clock

**Evidence:** The symbol writer lease previously used `TimeCurrent()` with a 90-second TTL while the entry lock used `TimeLocal()`. Commit `d9a30c437c2579d7dabd0bb6776c697b52edee2b` changes the symbol-management lease timestamp to `TimeLocal()`, matching the entry-lock clock choice and avoiding dependence on quote-driven server-time advancement.

**Impact:** The clock-source inconsistency is corrected in source. This does not prove race-free lease takeover: the global-variable CAS owner transition and the later lease timestamp write are separate operations, and the lease check plus broker request are not atomic.

**Verification status:** Updated source was fetched back from GitHub and the new clock expression was confirmed. Quiet-market, two-instance contention, clock-change, and restart tests remain NOT RUN.

**Disposition:** Test two EA instances with active quotes, quiet markets, stale quotes, restart, and lease-owner disappearance. Document whether expiry is intended to follow server time or wall-clock time.

### STR-AUD-12 — Partial-fill pending-trail handoff guard added

**Evidence:** Commit `a4db8b5c5069e3b739191acaca9ca068cb991c8c` updates `STB_PendingTrailOnOrderFilled()`: on `DEAL_ADD`, if the same ticket still exists as a managed supported pending order, it logs the remaining volume and leaves the pending-trail state active. It deactivates the state only when the active pending ticket is no longer present at that check.

**Impact:** This avoids prematurely disabling trailing for a remainder when the partial-fill order is still visible at transaction intake. Transaction arrival order can still race with terminal state updates, so the subsequent manager pass and stale-state cleanup must be tested.

**Verification status:** Source fetched back from GitHub; the active-order guard and early return before the handoff were confirmed. Partial-fill, delayed transaction, and restart tests remain NOT RUN.

**Disposition:** Test partial fills where the remainder is present, delayed order removal, full fill, immediate disappearance, and restart. Verify filled-volume position protection independently from remainder trailing.

### STR-AUD-13 — Transaction intake does not explicitly branch on every transaction type

**Evidence:** The inspected `STB_TradeIntakeFromTransaction()` excerpt has explicit `TRADE_TRANSACTION_ORDER_ADD` and `TRADE_TRANSACTION_DEAL_ADD` paths; it does not show equivalent explicit branches for order deletion or deal update.

**Impact:** Correctness may depend on reconciliation and terminal scans rather than direct event handling. The excerpt alone does not prove missing cleanup.

**Disposition:** Test order delete/cancel/expiry, deal add/update, delayed event ordering, and restart reconciliation. Confirm that stale registry and pending-trail entries are removed deterministically.

### STR-AUD-14 — Pending-order write quota now consumed before broker request

**Evidence:** Commit `0b3230d6bcf9cc26a2be115db0030332a38346db` adds `STB_CycleMarkWritten(ticket)` immediately before `trade.OrderModify()`, after the final snapshot, ownership, geometry, and risk-floor checks. The existing post-verification mark remains as an idempotent confirmation of the same cycle budget.

**Impact:** A failed, timed-out, or ambiguous modification attempt no longer leaves the ticket eligible for another geometry write in the same cycle. A no-change failure is deferred to a later management cycle; this favors avoiding duplicate writes over immediate same-cycle retry.

**Verification status:** Updated source was fetched back from GitHub and ordering of the quota mark before `trade.OrderModify()` was confirmed. Compile and failure-injection tests remain NOT RUN.

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

### STR-AUD-27 — Status after source correction: stability is recomputed after watchlist refresh

**Correction:** Commit `bf550687cab3c94313f0d2720531b905b6e5afea` recalculates the preliminary score using the refreshed setup score, market-quality score, and regime score, then calls `STB_CandidateStability()` again before final watchlist opportunity ranking. It also updates `c.strategyScore` from the revalidated setup score before recomputing the opportunity score.

**Expected behavior:** The final watchlist score uses stability derived from the refreshed candidate state, while persistence comparison remains keyed to the previous scan's matching symbol/direction/setup identity. Score weights are unchanged.

**Verification status:** Updated source was fetched back from GitHub and the new block was confirmed. Compile, ranking fixtures, and Strategy Tester coverage remain NOT RUN.

### STR-AUD-28 — Fallback candidate could inherit confidence clearance from the original winner

**Evidence:** Before the source correction, `STB_ExecuteTopCandidate()` checked `g_scannerConfidence` once against the first two candidates, then iterated through Top-N and could continue to a lower-ranked candidate after an earlier candidate failed final revalidation or the final gate. The fallback's own score gap against the next revalidated watchlist candidate was not checked at that point.

**Impact:** The fallback could be submitted even though it did not independently satisfy the configured top-gap confidence rule. This is a confirmed control-flow inconsistency in the inspected source, not a claim about trade outcomes.

**Correction:** Commit `e2b9bffc3eeb3dbf6682ce42f3fb9556e065c28a` adds a per-fallback check against the revalidated watchlist. If the candidate is missing from that list or does not independently satisfy the score/gap rule, execution stops rather than continuing to a lower candidate. The original top candidate continues to rely on the existing global confidence gate.

**Verification status:** Source change was fetched back from GitHub and its presence confirmed. Compile and runtime tests have not yet been run; this is not a claim of compile or behavioral validation.

### STR-AUD-27 — Watchlist reranking refreshes market/regime inputs but carries forward the initial stability score

**Evidence:** During initial candidate discovery, `STB_CandidateStability()` computes `stabilityScore` using the preliminary score and previous score/rank. During watchlist revalidation, the code refreshes setup, market-quality score, and regime score, then recalculates `opportunityScore`; it does not recompute `stabilityScore` using the refreshed inputs before sorting the watchlist again.

**Impact:** The final ranking combines refreshed setup/quality/regime components with a stability component calculated during the earlier scan pass. If the setup or market/regime values materially change between passes, the stability contribution can be stale relative to the candidate's current state. This is a ranking-consistency concern, not evidence that the chosen candidate is intrinsically invalid.

**Disposition:** Decide whether stability is intended to represent scan-to-scan persistence or a score component recalculated from current inputs. If it is current-state dependent, recompute it after revalidation and before final reranking; if it is historical persistence, document the contract and test deterministic ranking under changed market quality/regime. Do not change scoring weights as part of this correction.

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
| STR-A30 | Watchlist revalidation changes market-quality/regime scores after initial stability calculation | Final ranking follows the documented stability-score contract | NOT RUN |
| STR-A31 | Top candidate fails final validation while fallback has insufficient gap to next candidate | Fallback is blocked; no candidate with uncleared confidence is submitted | SOURCE PATCHED; TEST NOT RUN |
| STR-A32 | Structure, FVG, and origin-candle patterns occur in nearby but different impulses | Candidate is accepted/rejected according to an explicit shared BOS/displacement contract; unrelated pattern combination is rejected if contract requires event identity | CONTRACT/TEST NOT DEFINED |
| STR-A33 | BOS occurs before a weekend/session gap; wall-clock age would exceed observed bar age | Discovery and watchlist age agree with M15 bar shifts; missing exact setup bar is explicitly rejected | SOURCE PATCHED; TEST NOT RUN |
| STR-A34 | Watchlist refresh changes setup, market-quality, or regime score after discovery stability was calculated | Final stability and opportunity score use refreshed values while retaining the documented previous-scan identity contract | SOURCE PATCHED; TEST NOT RUN |
| STR-A35 | Automatic protection and manual commands process the same foreign-magic or disallowed-symbol position | Observed scope matches the explicitly approved broad-protection vs symbol-managed contract; verify SL/TP/trailing and manual SAVE behavior separately | CONTRACT/TEST NOT DEFINED |
| STR-A36 | Two chart instances contend for the symbol lease during quiet quotes, restart, or local-clock adjustment | Only the CAS owner writes; stale reclaim follows the 90-second local-clock TTL without duplicate writers | SOURCE PATCHED; TEST NOT RUN |
| STR-A37 | Pending OrderModify returns failure/timeout after server-side state may have changed | The ticket consumes its write quota before the request and receives no second geometry write in the same cycle | SOURCE PATCHED; TEST NOT RUN |
| STR-A38 | Pending order emits DEAL_ADD while an unfilled remainder may still be active | Existing managed pending ticket keeps trail state active; state is handed off only after the pending ticket is absent | SOURCE PATCHED; TEST NOT RUN |

| STR-A39 | Restart occurs during pending-trail retry backoff | Recovered ticket is re-registered with failureCount=0 and nextRetryTime=0; confirm this reset is an intentional policy or persist retry state, and verify no immediate retry storm after repeated restarts | CONTRACT/TEST NOT DEFINED |

| STR-A40 | Pending order has no initial SL; initial-protection repair and trailing are both eligible, including OrderCheck rejection or ambiguous broker response | Central writer allows at most one broker geometry write per ticket per cycle; retry backoff and next-cycle reconciliation remain consistent with actual terminal geometry | SOURCE PATH REVIEWED; TEST NOT RUN |

| STR-A41 | Pending OrderModify reports success but the order disappears before postcheck, or postcheck geometry differs | Writer returns false and caches only observed geometry when selectable; confirm next-cycle reconciliation, retry/backoff, and trail-state cleanup for vanished tickets and broker-normalized geometry | SOURCE PATH REVIEWED; TEST NOT RUN |



| STR-A44 | Periodic Reconcile overwrites an existing geometry baseline before delayed POSITION/ORDER_UPDATE intake | Patched `STB_ReconcileTradeRegistry()` to seed geometry only when registry entry is unknown (`entry<=0`), preserving a known baseline for later event comparison; verify startup recovery, own writes, manual edits, zero-SL/TP, delayed callbacks, and restart | SOURCE PATCHED/FETCH-BACK VERIFIED; MetaEditor compile 0 errors/0 warnings on commit `6e1a0700eed08515a785430ff57ed9353254dc47` (includes source patch); runtime behavior tests NOT RUN |
| STR-A43 | Manual pending-order geometry changes while Reconcile runs before delayed `TRADE_TRANSACTION_ORDER_UPDATE` intake | Original race hypothesis is addressed by STR-A44: Reconcile now seeds geometry only when the exposure registry has no known entry baseline. Verify delayed ORDER_UPDATE still detects the change and sets override under actual event ordering | SUPERSEDED BY STR-A44 PATCH; RUNTIME TEST NOT RUN |
| STR-A42 | Pending trail lifecycle after fill/cancel/delete or ownership loss | ManageOne deactivates state when OrderSelect fails, order is no longer managed, type changes, or symbol differs; process prunes inactive records; verify transaction ordering, position handoff, and repeated restart/reconciliation with functional tests | SOURCE PATH REVIEWED; TEST NOT RUN |

| STR-A46 | Exposure registry allocation fails under memory/resource pressure | `STB_ExposureEnsure()` now checks `ArrayResize()` and returns `-1` with a diagnostic instead of indexing a potentially unallocated slot; source call-site review found most state writes re-enter through guarded `STB_GeomStore()`, but immediate management still proceeds after a failed ensure and requires fault-injection/runtime validation | SOURCE PATCHED/FETCH-BACK VERIFIED; METAEDITOR COMPILE 0 ERRORS/0 WARNINGS; STATIC AUDIT PASS; RUNTIME/ALLOCATION-FAILURE TEST NOT RUN |

| STR-A53 | Stale Pending Trail records gated behind Exposure Registry allocation | `STB_PendingTrailManageOne()` now checks whether the order still exists and retires missing tickets before calling `STB_ExposureEnsure()`. This keeps lifecycle cleanup independent of a transient registry allocation failure; live orders still fail closed before trail processing if exposure state cannot be ensured | SOURCE PATCHED/FETCH-BACK VERIFIED at `18042cdedfe314cd2e04d59970d275b5b92147d6`; MetaEditor compile SUCCESS (0 errors, 0 warnings; run `39489741763`); static audit and safety-default checks SUCCESS; runtime fault-injection not run |
| STR-A52 | Pending Trail state-array allocation failure after geometry inference | `STB_PendingTrailRegister()` now checks the return value of `ArrayResize(g_stbPendingTrail, n+1)` before writing the new state; on failure it logs and returns false, avoiding an out-of-range write and allowing later terminal scans to retry | SOURCE PATCHED/FETCH-BACK VERIFIED at `2b07bc61434d23b2e1f018552a0ef8d6e25820db`; included in exact-tree MetaEditor compile SUCCESS (0 errors/0 warnings, run `39490351228`), static audit and safety-default checks SUCCESS; RUNTIME/ALLOCATION-FAILURE TEST NOT RUN |
| STR-A51 | Pending Trail registration and processing without Exposure Registry | `STB_PendingTrailRegister()` and `STB_PendingTrailManageOne()` now require `STB_ExposureEnsure()` to succeed before creating state or processing an actionable bar. Allocation failure logs a deferred diagnostic and leaves the terminal order available for a later scan/cycle retry | SOURCE PATCHED/FETCH-BACK VERIFIED at `324e7cabf082c69b5ff77ba6b319c5a15dc5781e`; included in exact-tree MetaEditor compile SUCCESS (0 errors/0 warnings, run `39490351228`), static audit and safety-default checks SUCCESS; RUNTIME/FAULT-INJECTION TEST NOT RUN |
| STR-A49 | Pending-order reconcile ordering under exposure allocation failure | `STB_ReconcileTradeRegistry()` now ensures the Exposure Registry before registering Pending Trail state; on allocation failure it logs and skips that order's reconciliation pass, allowing a later timer pass to retry. This prevents trail registration from preceding a failed baseline allocation in this path | SOURCE PATCHED/FETCH-BACK VERIFIED at `f93c0e20dd584fe17804e762202dc0235d0e0426`; included in exact-tree MetaEditor compile SUCCESS (0 errors/0 warnings, run `39490351228`), static audit and safety-default checks SUCCESS; RUNTIME/FAULT-INJECTION TEST NOT RUN |
| STR-A48 | Allocation failure in transaction ORDER_ADD / DEAL_ADD baseline intake | `ORDER_ADD` now exits before geometry/trail registration when exposure registry allocation fails; `DEAL_ADD` avoids claiming a seeded geometry baseline on failure and still reaches the guarded immediate-handoff retry path. `OnTimer()` runs management and reconciliation repeatedly; `OnTick()` also runs management and reconciles on a new M15 bar. Verify recovery under injected allocation failure and delayed transaction ordering | SOURCE PATCHED/FETCH-BACK VERIFIED at `f781d9328fb4ff31fe638da6c3dab8c7bed86126`; exact-source MetaEditor compile SUCCESS, 0 errors/0 warnings (run `39488615530`, MetaEditor `5.0.0.6274`); RUNTIME/FAULT-INJECTION TEST NOT RUN |

| STR-A47 | Exposure allocation failure during geometry intake / immediate position handoff | Patched `STB_GeomIsKnown()` to seed a baseline only after successful `STB_ExposureEnsure()`; manual intake defers on ensure failure and immediate position management stops before its cycle. Verify recovery/retry and inject allocation failure; fail-closed guard is not runtime proof | SOURCE PATCHED/FETCH-BACK VERIFIED at `d425ed31cc32a227e0dd16e22d2728e6fbba1fa0`; MetaEditor workflow succeeded on that exact commit; later intake guards tracked in STR-A48; RUNTIME/FAULT-INJECTION TEST NOT RUN |

## Exit criteria

- Decide and document CHoCH/BOS semantics before changing structure behavior.
- Approve the H4/Universal configuration precedence.
- Add deterministic tests for score diagnostics, stale candidates, final gates, and manager lifecycle.
- Re-run exact-source compile and static checks after source changes.
- Run the relevant Strategy Tester and demo-lifecycle checks before any release decision. Compilation or static audit alone is not evidence of runtime correctness or profitability.

## Current status

**The latest integrated source compiled successfully** at validation commit `2e5cf06c8a318f5343cf9b50f495c1a07e5ea036`: MetaEditor `5.0.0.6274`, **0 errors, 0 warnings** (workflow `39492814185`, artifact `12295809473`); static audit (run `39492814244`) and safety-default checks (run `39492814033`) passed. The compiled source blob fetched back from the branch is `3d0d67850fa9444f06da27dea7aa7e62c78cfa80`. Provenance records source SHA-256 `EC162131A48E93527125F275BCEBF822B0650E29361E4780ED0C89AD00B3B4F5` and EX5 SHA-256 `83F4206E18A867462E277F65F4050C7E0AF74ECAA66CFF0CD6491A8CB7C36BCF`. **Release status remains NOT VERIFIED** because runtime/fault-injection and integrated scanner-to-manager tests have not been run. Compile/static success does not certify runtime behavior or trading performance.

| STR-A45 | Manual-override persistence across re-init/restart, lazy migration, AUTO clear, and ticket disappearance | Existing code restores scoped override keys in `STB_ExposureEnsure`, migrates legacy keys lazily, and prunes absent tickets after a bounded orphan grace; verify no stale key or unintended override loss across order fill/cancel/restart | SOURCE PATH REVIEWED; RUNTIME TEST NOT RUN |


### STR-A54 — An allocated but unseeded geometry row could be misread as a manual edit

**Evidence:** `STB_ManualOverrideIntake()` ensures an Exposure Registry row before calling `STB_GeomIsKnown()`. When that row already exists but still has the zero-entry sentinel, the old implementation compared the real terminal entry against zero and could report a geometry change. In the pending-order branch that can reach `STB_ManualOverrideSet()` even though the snapshot was only being observed for the first time.

**Correction:** `STB_GeomIsKnown()` now detects an existing row with `entry<=0.0` and a valid observed `entry>0.0`, seeds entry/SL/TP from the current terminal snapshot, logs `FIRST_VALID_SNAPSHOT`, and returns true. Later snapshots continue through the normal tolerance comparison, preserving detection of subsequent geometry changes. Allocation failure remains a separate false/deferred path.

**Verification status:** Source patch commit `9be5577f6541e46173612995f46596c25fa1fa2f`; fetch-back verified with blob `5491c308fd06241362afc391b1664e779dfb5b4f`. The source file was compiled unchanged in validation commit `994b9d462bd5d953e65ec2edbcee88dd1e010e14`: MetaEditor 5.0.0.6274 reports 0 errors and 0 warnings (workflow `39490351228`); static audit and safety-default checks succeeded. Runtime/manual-edit/restart tests have not been run.


### STR-A55 — Scanner pipeline array-allocation failures could leave an incomplete candidate set

**Evidence:** `STB_ScannerRun()` resized several dynamic arrays without checking the result: prior-scan snapshot, explicit/Market-Watch universe accumulation, candidate append, initial/final watchlist, and execution Top-N. A resource-allocation failure could leave the pipeline incomplete or permit an invalid index write instead of producing an explicit fail-closed scan result.

**Correction:** `STB_ScannerAllocationAbort()` now releases temporary symbol selections where safe, clears current/watchlist/Top-N candidates and dashboard readiness, sets scanner status to `ALLOCATION_FAILED`, records a diagnostic, and returns without leaving a candidate available for execution. The scanner checks resize results at each listed stage and invokes the abort path on failure. If the symbol-selection snapshot itself cannot be allocated, the partial snapshot is freed before abort cleanup so default-false entries cannot cause user-selected symbols to be deselected. Added a static-audit regression assertion for the fail-closed behavior.

**Verification status:** Initial scanner fail-closed source commit `00eb7d0d706d64144d902e962f96c9f15a806b65` was fetch-back verified at blob `6559da7d692260b01cd10e3cf966fac590603c76`. The symbol-selection rollback guard is source commit `d5bac947f9d545f74d16dc1031be973c637cdf5f`; the resulting source blob `21b834d0c33302e59dcbdd4c5ddf511de7c6c295` was fetched back and verified. Regression assertions are included in the validation tree at `6a27377536e1f5cc7220a0ceb10bc6310f38fa70`. Exact-source compile succeeded with 0 errors/0 warnings; static audit and safety-default checks passed. Runtime allocation-fault injection and end-to-end scanner/manager tests NOT RUN. Runtime allocation-fault injection and end-to-end scanner/manager tests NOT RUN.

### STR-A56 — Scanner dashboard readiness counters included candidates rejected during final revalidation

**Evidence:** The scanner increments `g_scannerBuyCount` / `g_scannerSellCount` during discovery, before final setup revalidation, refreshed market-quality/regime evaluation, and final setup-age checks. The dashboard previously copied these discovery counts into fields named `g_panelScanBuyReady` and `g_panelScanSellReady`, which could overstate final ready candidates.

**Correction:** Dashboard ready counts are now derived from the final revalidated `g_scannerWatchlist`. Discovery counters remain available for diagnostic candidate totals. A static-audit regression assertion verifies that the dashboard fields no longer consume the pre-validation counters.

**Verification status:** Source commit `e16147a08a72a1a3a290daaa4987cbd1885935d1`; the final integrated source blob `3d0d67850fa9444f06da27dea7aa7e62c78cfa80` was fetched back and verified. The static-audit regression assertion is included in validation commit `2e5cf06c8a318f5343cf9b50f495c1a07e5ea036`. MetaEditor compile passed with 0 errors/0 warnings; static audit and safety-default checks passed. Runtime scanner/manager tests NOT RUN.

### STR-A57 — Final execution revalidation did not independently enforce setup age

**Evidence:** Scanner discovery and final watchlist construction checked setup age, but `STB_FinalCandidateRevalidation()`—also called immediately before execution—only checked that the setup timestamp had not changed. A setup could age between candidate construction and the final handoff without a dedicated final age rejection.

**Correction:** Final revalidation now recomputes the M15 bar shift from the refreshed setup timestamp, rejects unavailable age data, recalculates `setupAgeBars`, and applies `STB_EffectiveMaxSetupAgeBars()` before pending geometry validation. The rejection reason is `REJECT_SETUP_TOO_OLD`. A static-audit regression assertion checks that this gate precedes geometry validation.

**Verification status:** Source commit `fab942eec60775c8e1838352fc4329f11bf06835`; the final integrated source including this gate was fetched back at blob `3d0d67850fa9444f06da27dea7aa7e62c78cfa80`. Regression assertion is included in validation commit `2e5cf06c8a318f5343cf9b50f495c1a07e5ea036`. MetaEditor compile passed with 0 errors/0 warnings; static audit and safety-default checks passed. Runtime scanner-to-execution age-boundary test NOT RUN.

### STR-A58 — Remaining diagnostic, indicator-cache, and swing-buffer appends were unchecked

**Evidence:** Source review found additional dynamic-array writes outside the scanner and previously hardened Exposure/Pending Trail/SL queue paths: setup diagnostic state, indicator handle cache, and swing-high/swing-low collection. Allocation failure could lead to indexing beyond the allocated array; indicator-cache failure could also leak newly created handles.

**Correction:** Both diagnostic writers now return after a logged resize failure. Indicator-cache insertion releases newly created RSI/CCI handles and returns false when the cache cannot grow. Swing-buffer reset and append operations are checked; any append failure clears both swing arrays and returns no swing data. Lease-symbol tracking now returns failure explicitly; each lease-acquisition path releases its own owner claim through compare-and-swap if tracking allocation fails. It deliberately leaves the old timestamp untouched after releasing the owner sentinel, avoiding a race that could overwrite a concurrent new owner's lease timestamp.

**Verification status:** Core diagnostic/indicator/swing guards are in source commit `11a73aa6bc4bc5511117deb1f7db64e1e000a03f`; lease-release-on-tracking-failure is in source commit `81b493e20a9c4f7ec0585ba0971f40066956a121`; a follow-up at `92f8feaa0ec576adf4b596c4c2aa48c36844f39a` preserves the owner-CAS race invariant by leaving the old lease timestamp untouched after owner release. The final integrated source blob `3d0d67850fa9444f06da27dea7aa7e62c78cfa80` was compiled in validation commit `2e5cf06c8a318f5343cf9b50f495c1a07e5ea036` with 0 errors/0 warnings; static audit and safety-default checks passed. Regression assertions are included in that validation tree. Runtime allocation-fault injection NOT RUN.

### STR-A59 — Order geometry and market conditions were not rechecked at the final broker-submit boundary

**Evidence:** `PlaceSetup()` checked setup geometry and execution conditions before volume/expiration calculation and `OrderCheck`, then checked entry lock, symbol writer lease, and exposure immediately before submission. Market spread, trade permissions, directional tradability, pending geometry, and volume limits can change between the earlier checks and broker submission.

**Correction:** Added a final pre-submit gate for trade environment, direction, spread, `ValidatePendingSetup()`, directional volume limits, entry-lock ownership, symbol-writer lease, and managed exposure. The gates run immediately before the order request. A static-audit assertion checks presence and ordering.

**Verification status:** Source commit `661f678a83b6afee0f3f7410b21ad1f2b3fec563`; the integrated source blob `3d0d67850fa9444f06da27dea7aa7e62c78cfa80` was compiled unchanged in validation commit `2e5cf06c8a318f5343cf9b50f495c1a07e5ea036` with 0 errors/0 warnings; static audit and safety-default checks passed. Regression assertion is included in that validation tree. Runtime race/broker-rejection tests NOT RUN.

### STR-A60 — Transaction-to-manager handoff lacked dedicated static regression tripwires

**Review scope:** The integrated path from broker-accepted pending setup through transaction intake, pending-trail registration, fill detection, exposure/geometry baseline creation, and immediate position-management scheduling.

**Source observations:** `OnTradeTransaction()` delegates to `STB_TradeIntakeFromTransaction()` before its adaptive-learning magic filter, allowing manual/foreign-origin positions within protection scope to enter the manager. Pending `ORDER_ADD` intake records terminal-confirmed geometry before pending-trail registration. On `DEAL_ADD`, the intake path attempts exposure allocation and records position geometry before immediate management; allocation failure is logged and the later immediate-management helper independently fails closed if allocation still cannot be obtained. The management-cycle guard defers nested cycle requests and caps the follow-up pass. `PlaceSetup()` commits the setup cooldown only after server acceptance and verification of the pending order's initial SL.

**Change:** Added static regression assertions for these ordering and handoff invariants, plus the final pre-submit gate ordering. This is test coverage hardening; it does not claim a newly discovered runtime defect or prove transaction ordering under a live terminal.

**Verification status:** Audit script update commit `ecd3016bcef2b70a45c9dcef62fdd9acb1994e92`. The updated script and its CI run must be fetched/checked before reporting the audit as passed. The EA source remains unchanged at blob `3d0d67850fa9444f06da27dea7aa7e62c78cfa80`; the earlier MetaEditor compile and safety-default results apply to that unchanged EA source. Transaction-event permutations, exposure allocation fault injection, pending-to-position handoff, and broker behavior remain **NOT RUN**. Release status remains **NOT VERIFIED**.


**Audit follow-up:** The first run of the newly extended static audit exposed an incorrect test-region boundary (the assertion searched an empty source region), not a source-code failure. The region boundary was corrected in audit-script commit `c29e5cf754fe940529e9c58b0e0f0f5c2fb837f9`. The corrected static audit passed on run `39532316384`; the later documentation-only head `5485581f02d5c1f8e3b6e1c17311c5ee09099bbc` also passed static audit on run `39532326754`. This is source-level coverage only, not runtime proof.


### STR-A61 — Startup/reattach recovery regression coverage

**Review scope:** Recovery ordering when the EA initializes or reattaches with existing positions and pending orders.

**Source observations:** `OnInit()` rebuilds pending-trail state from terminal orders, reconciles the per-ticket exposure/geometry registry, runs the management cycle, and only then starts a fresh scanner cycle. Pending-order reconciliation defers trail registration when exposure allocation fails and seeds geometry only for unknown baselines; position reconciliation similarly seeds only unknown geometry, preserving an already-known baseline against accidental overwrite.

**Change:** Added three static regression assertions for startup ordering, fail-closed pending-order reconciliation, and position baseline preservation. Audit-script commit: `fee9cc308931ee1e8f35ed09a763f4cbe72ef19a`. The updated static audit passed on run `39532544020`; the safety-default check passed on run `39532544001`. These results validate source-level guardrails only.

**Source/compile status:** Canonical EA file remains `MQL5/Experts/SmartTradingBot_FINAL.mq5`, blob `3d0d67850fa9444f06da27dea7aa7e62c78cfa80`; no EA source changes were made. A MetaEditor compile on the same EA source passed on run `39532360739` (documentation/test-script commits do not alter the EA source). A newer compile triggered by the audit-script commit was still running at the time of this note; check its final result separately. Runtime reattach/restart tests and allocation fault injection remain **NOT RUN**. Release status remains **NOT VERIFIED**.


### STR-A62 — Timer reconciliation now precedes the periodic management pass

**Source observation:** `OnTimer()` previously ran the management cycle before periodic trade-registry reconciliation. If a transaction callback was missed or delayed, a terminal-visible position/order could be absent from the in-memory registry during that timer's management pass.

**Correction:** Source commit `110bee250beaee48bf8745bf2d0a2074ee3994bc` reorders `OnTimer()` so `STB_ReconcileTradeRegistry()` runs before `STB_RunManagementCycle()`. The static audit now asserts this order, alongside the existing tick recovery ordering.

**Verification status:** Latest EA source passed MetaEditor compile (run [39533064357](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39533064357)), static audit (run [39533064361](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39533064361)), and safety-default checks (run [39533064336](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39533064336)). The latest audit-script head `589002bf868c0cfdda74b66d69a3965375d98f45` also passed compile (run [39533074448](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39533074448)), static audit (run [39533074402](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39533074402)), and safety defaults (run [39533074531](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39533074531)). These checks do not simulate missed/delayed events or prove broker/runtime behavior. Runtime recovery and lifecycle tests remain **NOT RUN**; release remains **NOT VERIFIED**.
