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

## Exit criteria

- Decide and document CHoCH/BOS semantics before changing structure behavior.
- Approve the H4/Universal configuration precedence.
- Add deterministic tests for score diagnostics, stale candidates, final gates, and manager lifecycle.
- Re-run exact-source compile and static checks after source changes.
- Run the relevant Strategy Tester and demo-lifecycle checks before any release decision. Compilation or static audit alone is not evidence of runtime correctness or profitability.

## Current status

**Static audit in progress; release status remains NOT VERIFIED.** This document records code paths and test obligations; it does not certify runtime behavior or trading performance.
