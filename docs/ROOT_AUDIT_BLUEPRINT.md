# SmartTradingBot_FINAL — Root Audit Blueprint

Status: work in progress. This is the working checklist for the review branch; it is not a claim that the EA is compiled or runtime-validated.

## Reference
- User-supplied product/reference page: https://www.mql5.com/en/market/product/171441
- Treat this as a conceptual reference only. No proprietary marketplace source is copied into this repository. The page could not be retrieved by the current web connector, so product-specific claims are intentionally not made.

## Safety and release boundaries
- All edits stay on `audit/expose-cleaned-source-20261009`.
- Do not sync this branch to the live MetaTrader `Experts` folder.
- Do not compile the terminal copy until the static audit and refactor are complete.
- Keep `main` and its backup archive untouched until one consolidated final release is ready.
- Compilation, visual inspection in MT5, Strategy Tester results, and demo-forward behavior are separate release gates. None may be marked passed from static analysis alone.

## System invariants
1. One central position-SL writer and one central pending-geometry writer.
2. Verify ticket ownership, symbol permissions, broker stop/freeze distance, tick-size alignment, monotonic SL/entry movement, and server-confirmed geometry.
3. Manual geometry edits grant per-ticket manual authority; automatic trail/profit-protection must not overwrite it until the explicit AUTO action clears that authority.
4. New/recovered exposures must seed ticket geometry and pending-trail recovery state before automated writes.
5. Protect every managed position/pending with a valid initial SL where the user has not explicitly taken manual control.
6. A pending trail may only update its own pending ticket. Once filled, the position manager owns the position.
7. Never increase the accepted structural risk through pending trailing; do not loosen a position SL.
8. Risk sizing must fail closed when a valid cash-risk calculation or legal volume cannot be obtained.
9. Strategy signals must use closed/confirmed bars and must not use future data.
10. Adaptive learning must count genuine discovery/outcome events, not repeated revalidation passes.

## Audit workstreams

### A. Strategy and Buy Stop / Sell Stop geometry
- Confirm H4 bias uses confirmed swings and matches the timestamp of the closed candle being evaluated.
- Confirm M15 structure break uses only pivots that were confirmed before the breakout candle.
- Confirm FVG/OB must be tied to the setup's BOS/displacement, not an unrelated pattern.
- Confirm Buy Stop entry is above the live Ask by a broker-valid distance; Sell Stop entry is below the live Bid.
- Build SL beyond the actual OB risk-side extreme, or the nearest confirmed pre-BOS opposite swing when OB is optional and absent.
- Compute TP/RR after final tick/broker normalization, and reject stale triggers that have already crossed.

### B. Position manager and trailing
- Single-cycle priority: establish missing initial SL first, then profit-lock, then live trailing.
- Profit calculations must be net-of-known opening commission and swap; fail closed if pip cash value cannot be computed.
- Only submit SL changes that improve protection and pass current broker distances.
- Verify the broker's final SL after a successful retcode; refresh geometry from actual terminal values on failures.
- Avoid repeated high-volume debug logging inside tick-level paths.

### C. Pending order manager
- Cover BUY/SELL STOP, BUY/SELL LIMIT, and STOP-LIMIT order types consistently.
- Use per-ticket state, restart reconstruction, bounded retries/backoff, cooldown/step gates, and single central writer.
- Preserve the trigger-to-limit offset on STOP-LIMIT modifications and verify the child limit price after modification.
- Prune inactive/completed ticket state so lifetime memory does not grow with all historical pending orders.
- Confirm manual order edits reset the trail baseline and retain manual authority.

### D. Exposure ownership, restart, and manual authority
- Seed exposure geometry before the first management cycle on attach/restart.
- Seed a new pending order's initial terminal geometry at first transaction intake.
- Transfer per-ticket manual authority from a pending ticket to the filled position where applicable.
- Reconcile closed tickets and stale persistence without affecting unrelated accounts/magics.
- Confirm symbol lease ownership is verified immediately before all broker writes.

### E. Scanner, adaptive engine, and risk
- Distinguish scanner discovery from final candidate revalidation so repeated rebuilds do not inflate adaptive attempts.
- Keep final candidate revalidation on current market data and require the same closed setup timestamp.
- Check symbol-specific trading mode, order permissions, spread, quote age, session, volume limits, pending lifetime, and account trade permissions before placement.
- Verify trade outcomes are aggregated across partial exits and adaptive statistics update only once when a position lifecycle closes.

### F. Source quality and release verification
- Remove only symbols proven to be dead; keep all active strategy logic.
- Run static checks for malformed comments/strings, brace balance, duplicate definitions, unresolved references, and writer counts.
- Then perform one clean MetaEditor compile of the consolidated source and record the exact source hash, compiler output, and resulting EX5 hash.
- Only after compile review: run Strategy Tester on representative symbols/regimes and inspect logs for rejected geometry, modification failures, trailing behavior, and manual-override protection.
- Only after those gates pass: create one consolidated ZIP/commit, update `main`, and perform a single transfer to the canonical terminal.

## Incremental fixes saved on this review branch
- AUTO clears manual overrides only when enabling AUTO, not when disabling it.
- Pending-trail state is rebuilt before the first management cycle and inactive trail records are pruned during processing.
- Exposure geometry is reconciled before the first management write; new managed pending orders seed their initial geometry on intake.
- Revalidation rebuilds no longer increment adaptive attempt counts.
- Net pip-profit conversion returns zero when a valid pip cash value cannot be obtained instead of falling back to gross price movement.
- Per-tick P5A diagnostic spam was removed from the central position-SL writer.
- Setup cooldown timestamps are committed only after a pending order's initial SL is verified.
- H4 trendline validation evaluates the closed candle at its corresponding close time.
- Initial setup SL now anchors beyond the actual OB extreme or a confirmed pre-BOS opposite swing instead of using the already-broken trigger pivot as a near-entry stop.
- Manual pending/hedge commands are being guarded against terminal/account and symbol-direction permissions.

## Known limitation
The changes above are static-review changes only. No compile or runtime pass is claimed for this review branch. Continue auditing, update this document as each workstream is proven, and do not release until every gate has evidence.
