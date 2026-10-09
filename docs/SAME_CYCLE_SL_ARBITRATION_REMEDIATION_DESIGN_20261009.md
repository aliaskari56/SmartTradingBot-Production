# Same-Cycle Stop-Loss Arbitration — Remediation and Verification Status

Date: 2026-10-09  
Branch: `audit/expose-cleaned-source-20261009`  
Status: **IMPLEMENTED ON AUDIT BRANCH; STATIC CHECKS PASS; COMPILE/RUNTIME NOT VERIFIED**  
Related blocker: [Issue #5](https://github.com/aliaskari56/SmartTradingBot-Production/issues/5)

## 1. Historical root cause

The reviewed baseline had `STB_SubmitPositionSL()` pass one proposal at a time to `STB_ResolvePositionSL(ticket, props, 1, ...)`. Because initial protection, profit protection, and trailing were called sequentially and a ticket could receive only one broker modification per cycle, source ordering could determine which stop proposal reached the broker.

The audit branch now collects the automatic candidates generated in `ManagePositions()` before resolving them. The original one-proposal call pattern is no longer present in the current source.

## 2. Current implementation

Source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
Current source blob SHA (Git blob identifier, not a raw-file SHA-256): `6bca33bc8e0c961f317b0828e46faf7a6b9929b4`  
Latest source-changing commit: `30d683029158bc4a1cab64e8d3d190af04b07479`  
Static-checker update: `7f5092f1663f8a899449a16f3b6588df80c19bef`

The source implementation includes these controls:

1. **Cycle-scoped collection.** `EnsureInitialSL()`, `ApplyProfitLock()`, and `TrailPositionByLivePrice()` submit proposals while automatic management is collecting. Candidates carry ticket, cycle, source, reason, and price.
2. **Complete per-ticket resolution.** The flush builds the full candidate set for each ticket and passes its actual count to `STB_ResolvePositionSL()`. It does not silently submit a subset if the per-ticket candidate array cannot be allocated.
3. **Deterministic selection.** BUY positions select the highest valid SL that improves on the installed stop; SELL positions select the lowest valid improving SL. Equal-price candidates use the source-order tie-break: initial protection, profit protection, then trailing. Candidate prices are normalized and evaluated against one shared tick/stops/freeze snapshot for the candidate set; the chosen SL must still pass `IsValidSLForPosition()` at resolution and is revalidated again at the write boundary. This avoids candidate-order-dependent validation caused by reading a moving tick separately for each proposal. If the tick moves enough to invalidate the chosen candidate after resolution, the cycle fails closed rather than trying another candidate against a different snapshot.
4. **Single central write.** The automatic batch flushes once after initial protection, profit protection, and trailing have generated their proposals. The selected change still passes through the existing modify bridge, which rechecks live position/TP state, ownership, manual override, current SL, broker constraints, retcodes, and terminal state.
5. **No silent partial batch on allocation failure.** If the queue itself cannot grow, the cycle aborts the automatic batch rather than arbitrating incomplete input. If the temporary per-ticket proposal array cannot hold the full set, that ticket is skipped and the failure is logged.
6. **No automatic bypass outside the cycle.** Non-initial automatic requests are rejected when collection is inactive. Two deliberate synchronous paths remain: explicit user SAVE, and initial protective SL for a newly-created position before the next scheduled management cycle. The latter is a lifecycle exception; it is not evidence of same-cycle arbitration for that pre-cycle event.
7. **Confirmed lock state and active target floor.** Automatic profit-lock bookkeeping is deferred while candidates are collected. Once the universal trigger is reached, the resolver enforces the normalized lock target as a floor; a weaker trail cannot displace it. If there is no SL and the requested lock is temporarily unplaceable, the strongest valid non-lock candidate may be used as an emergency protective fallback. The flush persists lock-pips only after the actual terminal SL is verified to meet the normalized lock target, and rejects a missing SL. Partial exit handling preserves lock state while the position remains and clears it on full close/reversal. Server-expiry deletion additionally rechecks caller source, managed-symbol scope and the verified symbol lease at the central writer boundary. Close-deal cleanup also preserves locked-pips state during partial exits and clears it only on a full close or reversal, including close deals whose magic differs from this EA. The resolver also enforces the normalized +20-pip lock target after net profit reaches +50 pips: weaker candidates cannot replace an existing SL. If an unprotected position has no compliant candidate because broker geometry prevents the lock, the strongest valid non-profit-lock proposal may be used only as an emergency stop, and is not credited as a completed +20-pip lock.

## 3. Static verification evidence

GitHub Actions run [37950552410](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37950552410) completed with **success** on checker commit `7f5092f1663f8a899449a16f3b6588df80c19bef`. Its log reports 26 static checks passing, including collection/flush structure, candidate-set allocation failure handling, producer write boundaries, deterministic source tie-break, lock-state checks, and lexical balance.

This is source-level structural evidence only. It does not execute the MQL resolver or prove permutation-independent runtime behavior.

## 4. Required validation still outstanding

- Multiple candidate permutations with identical expected price/source results.
- BUY and SELL monotonicity with and without an existing SL.
- Initial protection plus trailing, and profit protection plus trailing, during one management cycle.
- Equal-price ties, invalid candidates, changing ticks, stop/freeze levels, and tick-size boundaries.
- SL-12: active +50/+20 lock-floor contention where stop/freeze constraints invalidate the target; verify no weaker replacement for an existing SL and no false lock-state credit.
- Active +50/+20 lock-floor contention when stop/freeze constraints invalidate the lock target; verify existing SL is not weakened and state is not credited unless the actual SL meets the target, including the no-SL emergency-stop case.
- TP changes between collection and submission; broker rejection, no-changes, timeout, and delayed transaction results.
- Manual override, user SAVE, restart/reconnect, netting/hedging, and multi-instance ownership.
- Exact-source MetaEditor compilation with complete compiler log and reviewed warnings.
- Strategy Tester and demo results, EX5 provenance, full package/include inventory, dependency license review, and independent code review.

The current environment does not have MetaEditor or Wine available, so exact-source compilation was not run here. Strategy Tester and broker/demo scenarios were also not run.

## 5. Release decision

**BLOCKED / NOT VERIFIED.** The source now has an implemented same-cycle arbitration path and the encoded static checks pass. Do not interpret this as compiler, broker, runtime, profitability, or release approval. Keep the release blocked until the exact source is compiled and the acceptance scenarios above have evidence.
