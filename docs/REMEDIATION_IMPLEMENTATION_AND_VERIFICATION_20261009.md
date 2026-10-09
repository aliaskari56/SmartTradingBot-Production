# Remediation Implementation and Verification Report — 2026-10-09

## Status

- **Static remediation:** implemented on the audit branch, including same-cycle SL proposal collection and arbitration.
- **Latest static structural checks:** PASS (26 checks) on GitHub Actions run [37949430269](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37949430269).
- **MetaEditor compilation:** NOT RUN; MetaEditor and Wine are not available in the current execution environment.
- **Strategy Tester / demo / live runtime tests:** NOT RUN.
- **Release approval:** **BLOCKED / NOT VERIFIED**.

This report records source changes and static evidence only. It does not claim broker-tested correctness, profitability, or release readiness. The `main` branch has not been modified.

## Source under review

- File: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
- Current Git blob SHA (not a raw-file SHA-256): `6bca33bc8e0c961f317b0828e46faf7a6b9929b4`
- Branch: `audit/expose-cleaned-source-20261009`
- Latest source-changing commit: `30d683029158bc4a1cab64e8d3d190af04b07479`
- Latest static-checker commit: `7f5092f1663f8a899449a16f3b6588df80c19bef`

## Implemented changes

### 1. Shared aggregate directional-volume preflight

Added `STB_DirectionVolumeWithinLimit()` and wired it into all four order-creation families:

- `PlaceSetup` — automatic pending orders.
- `PlaceManualPendingDirection` — manual stop orders.
- `PlaceManualLimitDirection` — manual limit orders.
- `OneClickHedge` — hedge pending orders.

The guard uses `DirectionExposureVolume()`, which includes same-symbol directional positions and active pending orders. It rejects a request when current same-direction exposure plus requested volume exceeds a positive `SYMBOL_VOLUME_LIMIT`.

**Boundary:** this is a point-in-time check, not an atomic account reservation. Another EA, terminal, or server-side state change can race the check. Broker validation and server retcodes remain authoritative; runtime concurrency testing is required.

### 2. Central pending-delete authorization

The single `trade.OrderDelete()` writer now:

- rejects non-pending order types;
- allows rollback only when the creator source matches the order's tag family (`STB|B|` / `STB|S|` for `PlaceSetup`, `STB|M|` for manual stop/limit, `STB|HEDGE|` for `OneClickHedge`) and the ticket is fresh (within the 120-second rollback window);
- independently revalidates server expiration or the configured/profile-derived local-age expiration at the delete boundary;
- blocks deletion requests that do not satisfy the reason/source policy and logs the block;
- retains the existing server-retcode and post-delete disappearance checks.

The rollback check intentionally does not rely on magic number alone because UI-created STB pending orders may use magic `0`. Manual-order rollback remains allowed only for the known creator source and fresh STB-tagged order. Server-expiry deletion additionally rechecks `source==ManagePendingOrders`, managed-symbol scope, and a verified symbol lease at the final writer boundary.

**Boundary:** only currently observed callers were reviewed. Any future delete reason or creator path must be explicitly added to the authorization policy and tested; do not bypass the central writer.

### 3. Stale TP snapshot conflict mitigation

Before `trade.PositionModify(ticket,newSL,tp)`, the writer reselects the position and compares the live TP against the earlier snapshot. If the position side or TP changed, it aborts rather than knowingly submitting the stale TP value. It also rechecks the current SL monotonicity and SL validity immediately before submission.

**Boundary:** MQL5's combined SL/TP modification is not a compare-and-swap operation. A race can still occur between this final read and the server request. The change reduces the stale-snapshot window; it does not prove that concurrent manual/EA TP changes are impossible.

### 4. Same-cycle SL arbitration

The former one-proposal call pattern has been replaced on this branch:

- The automatic management cycle collects initial-protection, profit-protection, and trailing candidates before broker submission.
- Each queued candidate records ticket and cycle, as well as source, reason, and SL.
- The flush resolves the full candidate set per ticket. BUY chooses the highest valid improving SL; SELL chooses the lowest valid improving SL. Equal-price ties use stable source priority.
- Candidate prices are normalized and revalidated with `IsValidSLForPosition()`; the selected request is revalidated again by the existing modify bridge.
- Candidate geometries are evaluated against one shared tick/stops/freeze snapshot, then the selected candidate is rechecked with the live validator. If the tick moves enough to invalidate the selected candidate, the cycle fails closed rather than selecting a fallback against a different snapshot.
- Non-initial automatic proposals are rejected outside collection rather than silently falling back to direct synchronous writes.
- Explicit user SAVE remains synchronous. Initial protective SL for a newly-created position also retains a deliberate synchronous lifecycle fallback before the next scheduled management cycle.
- If queue allocation fails, the automatic batch aborts instead of resolving an incomplete set. If the temporary per-ticket candidate array cannot hold the complete set, that ticket is skipped.
- When net profit reaches the +50-pip trigger, the resolver enforces the normalized +20-pip target as a floor for automatic candidates while an SL is already installed. A weaker trail candidate cannot replace the existing SL merely because the queued profit-lock target fails validation at the shared snapshot. If no SL exists and broker geometry blocks the lock, the strongest valid non-profit-lock candidate may serve as an emergency protective stop; it is not credited as a successful +20-pip lock. Post-flush lock state is committed only when the verified actual SL satisfies the normalized target.
- Automatic lock bookkeeping is deferred during collection. Already-satisfied lock targets are credited only after re-reading live position state. Arbitration confirmation rejects a missing actual SL before lock-pips bookkeeping.
- Current resolver revision enforces the active normalized profit-lock target as a minimum SL floor once the configured trigger is reached, and uses the strongest valid non-lock stop only as a fail-safe when a position has no installed SL and the requested lock is not currently placeable. The flush persists locked-pips only after the actual terminal SL confirms the normalized target.
- Final pending-delete expiry authorization requires the correct caller source, a managed order, and a verified symbol-management lease at the writer boundary.
- Partial-exit lifecycle: position lock/failure state is now cleaned before filtering by deal magic, so manual/foreign-magic closing deals are considered too. `DEAL_ENTRY_OUT`/`OUT_BY` preserves the state while the position ticket still exists and clears it only after a full close; `DEAL_ENTRY_INOUT` clears it on direction reversal. Runtime partial-close and netting/hedging scenarios are still required.

The static checks validate the encoded source structure, but do not execute the MQL resolver or prove permutation-independent runtime behavior. The active lock-floor contention case is tracked as SL-12 and remains NOT RUN.

## Static verification performed

The latest GitHub Actions run, [37949430269](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37949430269), completed with **success** on checker commit `7f5092f1663f8a899449a16f3b6588df80c19bef`. Its job log reports 26 passing checks, including:

- one direct `trade.OrderDelete()` writer and one direct `trade.PositionModify()` writer;
- four order-creation paths using the shared directional-volume guard;
- delete authorization and expiration checks;
- TP snapshot conflict mitigation;
- same-cycle proposal collection, full candidate-set resolution, deterministic tie-break, and allocation-failure handling;
- prevention of non-initial automatic SL writes outside arbitration cycles;
- candidate-producer write boundaries, shared-snapshot candidate validation, and confirmation of a nonzero actual SL before profit-lock bookkeeping;
- lexical balance of delimiters, comments, and literals.

These are static structural checks only. They do not prove compiler validity, MQL runtime behavior, broker compatibility, profitability, or release readiness.

## Verification blockers still open

1. **Functional SL arbitration tests:** candidate permutations, BUY/SELL monotonicity, pre-existing stops, and initial/profit/trailing contention have not been exercised in the MQL runtime.
2. **Cross-event/cross-instance behavior:** per-cycle write deduplication does not by itself prove behavior across `OnTick`, `OnTimer`, transaction bursts, restarts, or multiple EA instances.
3. **Build provenance:** the exact source has not been compiled into a newly hashed EX5 with a recorded MetaEditor/toolchain version and complete compiler log.
4. **Dependency/package provenance:** the distributable ZIP has not been extracted and independently inventoried; ALGLIB presence in the repository alone does not establish whether the package uses or ships it. License and attribution review remains open.
5. **Runtime behavior:** no Strategy Tester, demo, reconnect/restart, partial-fill, multi-EA, netting/hedging, or broker-specific validation has been run.
6. **Independent review:** no independent qualified code review has signed off on the trading-safety changes.
7. **Other product guardrails:** account-wide daily-loss/max-drawdown protection and the default risk-sizing behavior still require their own evidence and disposition.

## Required acceptance before release

- Compile the exact source blob in the intended MetaEditor/compiler version; preserve the full log, exit code, warnings, and build settings.
- Run candidate-order permutations and SL-01 through SL-12 from `docs/RELEASE_ACCEPTANCE_TEST_MATRIX_20261009.md`, including BUY/SELL, stops/freeze levels, TP changes, broker rejections, manual override, and lock-state reconciliation.
- Run the order-creation matrix for all four paths, including volume limits, pending plus open exposure, foreign/manual orders, and concurrent exposure changes.
- Run delete-policy tests for fresh rollback, stale ticket, wrong source, foreign ticket, manual override, server expiry, and local-age expiry.
- Run restart/reconnect, partial-fill, netting/hedging, and multiple-instance scenarios on a demo account.
- Freeze raw source SHA-256 and EX5 SHA-256; record toolchain, settings, compiler log, and source-to-binary provenance.
- Inventory the complete distributable package and include closure; review dependency origins and licenses/attribution.
- Obtain an independent review and document the final release decision.

## Final decision

The source has been updated in the bounded order-safety areas above, and the latest encoded static checks pass. **Overall release remains BLOCKED / NOT VERIFIED** until the exact-source build, runtime acceptance suite, artifact provenance, package/license review, and independent review are complete.
