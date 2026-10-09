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
Current source blob SHA (Git blob identifier, not a raw-file SHA-256): `e06de0463d7dbeb26b50d7c1490e2b69d5d63aaf`  
Latest source-changing commit: `9b91af646a0362bbf38b184cdc2d3effebd28239`  
Static-checker update: `6c7213801bf5b405e88b00e34f0d4e3f74134831`

The source implementation includes these controls:

1. **Cycle-scoped collection.** `EnsureInitialSL()`, `ApplyProfitLock()`, and `TrailPositionByLivePrice()` submit proposals while automatic management is collecting. Candidates carry ticket, cycle, source, reason, and price.
2. **Complete per-ticket resolution.** The flush builds the full candidate set for each ticket and passes its actual count to `STB_ResolvePositionSL()`. It does not silently submit a subset if the per-ticket candidate array cannot be allocated.
3. **Deterministic selection.** BUY positions select the highest valid SL that improves on the installed stop; SELL positions select the lowest valid improving SL. Equal-price candidates use the source-order tie-break: initial protection, profit protection, then trailing. Candidate prices are normalized and revalidated against live broker constraints.
4. **Single central write.** The automatic batch flushes once after initial protection, profit protection, and trailing have generated their proposals. The selected change still passes through the existing modify bridge, which rechecks live position/TP state, ownership, manual override, current SL, broker constraints, retcodes, and terminal state.
5. **No silent partial batch on allocation failure.** If the queue itself cannot grow, the cycle aborts the automatic batch rather than arbitrating incomplete input. If the temporary per-ticket proposal array cannot hold the full set, that ticket is skipped and the failure is logged.
6. **No automatic bypass outside the cycle.** Non-initial automatic requests are rejected when collection is inactive. Two deliberate synchronous paths remain: explicit user SAVE, and initial protective SL for a newly-created position before the next scheduled management cycle. The latter is a lifecycle exception; it is not evidence of same-cycle arbitration for that pre-cycle event.
7. **Confirmed lock state.** Automatic profit-lock bookkeeping is deferred while candidates are collected. Existing SL that already satisfies a lock is re-read before state is credited. The flush rejects a missing terminal SL before it can commit profit-lock bookkeeping or log arbitration as confirmed.

## 3. Static verification evidence

GitHub Actions run [37931964375](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37931964375) completed with **success** on checker commit `6c7213801bf5b405e88b00e34f0d4e3f74134831`. Its log reports 22 static checks passing, including collection/flush structure, candidate-set allocation failure handling, producer write boundaries, deterministic source tie-break, lock-state checks, and lexical balance.

This is source-level structural evidence only. It does not execute the MQL resolver or prove permutation-independent runtime behavior.

## 4. Required validation still outstanding

- Multiple candidate permutations with identical expected price/source results.
- BUY and SELL monotonicity with and without an existing SL.
- Initial protection plus trailing, and profit protection plus trailing, during one management cycle.
- Equal-price ties, invalid candidates, changing ticks, stop/freeze levels, and tick-size boundaries.
- TP changes between collection and submission; broker rejection, no-changes, timeout, and delayed transaction results.
- Manual override, user SAVE, restart/reconnect, netting/hedging, and multi-instance ownership.
- Exact-source MetaEditor compilation with complete compiler log and reviewed warnings.
- Strategy Tester and demo results, EX5 provenance, full package/include inventory, dependency license review, and independent code review.

The current environment does not have MetaEditor or Wine available, so exact-source compilation was not run here. Strategy Tester and broker/demo scenarios were also not run.

## 5. Release decision

**BLOCKED / NOT VERIFIED.** The source now has an implemented same-cycle arbitration path and the encoded static checks pass. Do not interpret this as compiler, broker, runtime, profitability, or release approval. Keep the release blocked until the exact source is compiled and the acceptance scenarios above have evidence.
