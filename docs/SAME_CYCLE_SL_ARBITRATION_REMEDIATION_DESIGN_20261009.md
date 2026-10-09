# Same-Cycle Stop-Loss Arbitration — Remediation Design

Date: 2026-10-09  
Branch: `audit/expose-cleaned-source-20261009`  
Status: **DESIGN ONLY — implementation and runtime verification are still required**  
Related blocker: [Issue #5](https://github.com/aliaskari56/SmartTradingBot-Production/issues/5)

## 1. Confirmed root cause

In `MQL5/Experts/SmartTradingBot_FINAL.mq5`, `STB_SubmitPositionSL()` currently creates an array with exactly one proposal and calls `STB_ResolvePositionSL(ticket, props, 1, ...)`. The resolver's geometry selection can compare multiple entries, but callers never supply multiple source candidates in that path.

`ManagePositions()` calls initial protection, profit protection, and trailing in sequence. The single-write-per-ticket-per-cycle guard can make this call order affect which source gets to request a modification. This is not a proven same-cycle arbitration mechanism.

## 2. Required design invariants

1. **Collect, then commit:** candidate-generation functions must not write SL/TP to the broker.
2. **One candidate set per ticket and cycle:** include source, reason, cycle id, candidate price, and validation status.
3. **Re-read live state:** immediately before resolution, reselect the position and read side, SL, TP, symbol specification, and current tick.
4. **Monotonicity:** for BUY, only consider candidates strictly above current SL; for SELL, only candidates strictly below current SL. A missing current SL permits any otherwise-valid candidate.
5. **Deterministic geometry:** BUY chooses the highest valid improving candidate; SELL chooses the lowest valid improving candidate. Equal-price ties use a stable source priority (initial protection, profit protection, trailing) and never arrival order.
6. **Broker constraints:** validate tick-size normalization, stops level, freeze level, and current bid/ask immediately before submission. Candidate selection must not bypass existing `IsValidSLForPosition`.
7. **Single writer:** only the existing centralized modify bridge may submit the selected SL, retaining ownership, manual override, retry/backoff, retcode, and terminal-state verification checks.
8. **No speculative state:** profit-lock bookkeeping, success logs, and manual override must reflect confirmed terminal state, not merely a queued proposal.
9. **Cycle boundaries:** explicitly begin and flush a management cycle in the relevant event paths. Manual SAVE must remain synchronous from the user's perspective and must not accidentally join the automatic proposal batch.
10. **Failure recovery:** after rejected, timed-out, or ambiguous requests, reselect the live position and reconcile cached geometry and lock state before another decision.

## 3. Implementation sequence

1. Introduce a bounded proposal store keyed by ticket and cycle id; clear it on cycle start and after flush.
2. Refactor `EnsureInitialSL`, `ApplyProfitLock`, and `TrailPositionByLivePrice` to calculate/submit proposals without direct broker writes during automatic management.
3. Add one flush pass after all three candidate producers have run. Resolve the complete set per ticket, validate the selected candidate again, and invoke the centralized writer once.
4. Move profit-lock state updates and “updated” logs to the post-write confirmation path. If a stronger existing SL already satisfies the lock target, record that only after re-reading it.
5. Keep manual SAVE as a separate explicit synchronous path, with its own confirmation semantics and no automatic queue leakage.
6. Add static checks for proposal collection, exactly one automatic flush point, no direct writer calls in candidate producers, and no premature lock-state commit.
7. Compile with MetaEditor, fix every error/warning, and run SL-01 through SL-10 from the acceptance matrix on both BUY/SELL and supported account modes.

## 4. Required tests

- Multiple proposals supplied in every permutation resolve to the same price/source.
- BUY and SELL choose the strongest valid improving SL and never loosen an existing SL.
- Initial protection plus trailing in one cycle.
- Profit protection plus trailing in one cycle.
- Equal-price candidates and invalid/expired candidates.
- Stop/freeze-level and tick-size boundary cases.
- TP update between collection and flush.
- Broker rejection, timeout, no-changes, and delayed transaction events.
- Manual override, manual SAVE, restart recovery, and two instances competing for the same symbol.
- A failed modification does not persist a lock value or success log.

## 5. Why source implementation is not marked complete here

This is a stateful trading path, and the refactor changes when the broker write occurs relative to the current synchronous return values. Without an available MetaEditor compiler and Strategy Tester in this environment, making a speculative source rewrite and calling it “fixed” would not be responsible. This design records the exact root cause and the acceptance criteria; the code-level fix remains open until it can be implemented and verified against the compiler and tests.

## 6. Release decision

**BLOCKED / NOT VERIFIED.** Static CI is not a substitute for exact-source compilation, tester evidence, demo verification, EX5 provenance, and dependency/license review.
