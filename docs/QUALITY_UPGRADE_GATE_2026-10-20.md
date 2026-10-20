# SmartTradingBot quality-upgrade gate (2026-10-20)

## Scope and repository safety
- Working branch: `feature/structure-first-fvg-trailing-20261020`
- Branch base: `main` at `578621216f2f62ade33ab8e341a506e253b22bbf`
- Production `main` is not edited by this work.
- MetaTrader terminal files and the active `.ex5` are not touched during development.
- The feature branch is not release-ready until the gates below pass; a clean compile alone is not evidence of trading edge.

## Source audit findings
1. `BuildSetup()` only enforces FVG/OB when `InpStrictPatternFilters` is true, even though `InpRequireFVG` and `InpRequireOB` default true. With strict mode false, absent patterns can still reach scoring.
2. Pattern discovery is primarily on M15. The strategy uses H4 trend context, but the setup does not yet require an independently confirmed H1 FVG + H1 order block related to the M15 origin zone.
3. Position trailing in `TrailPositionByLivePrice()` is distance-from-live-price based. It is monotonic and broker-validated, but not governed by confirmed structural swing invalidation; the default start threshold is 150 pips and the separate profit-lock threshold is 50 pips.
4. The SL arbitration/writer is a shared risk-critical path. Changes must preserve monotonic SL behavior, broker stop/freeze checks, retcode checks, post-write verification, and single-writer ownership.
5. Adaptive state currently uses closed trade outcomes for profile statistics, but evaluation must separately verify outcome attribution, initial risk/R calculations, sample sufficiency, and out-of-sample generalization.

## Target design
- H4: direction/regime context; no look-ahead.
- H1: confirmed, closed-bar FVG and order-block detection. A zone must exist by the M15 setup timestamp, be directionally compatible and not already structurally invalidated. Require a configurable, explicit relation between the M15 origin and the H1 zones; log the zone bounds and every rejection reason.
- M15: confirmed BOS/CHoCH and local entry geometry. A scoring bonus cannot override a failed hard filter.
- Position management: structural SL candidate based on a confirmed pivot on the configured trailing timeframe, plus buffer and current broker constraints. Keep existing SL one-way (never widen risk), preserve profit-lock floors, and send writes only through the shared SL arbitration writer.
- Pending orders: audit separately from live-position trailing. Retry only transient failures; do not mask invalid geometry as transient.
- Scanner: separate hard eligibility gates from ranking; do not make a low-quality candidate valid by adding soft points.
- Adaptive learning: outcomes must be attributable to a profile and initial risk. Compare fixed baseline versus adaptive branch on the same held-out data; do not infer an edge from a small number of trades.

## Release gates (all required)
1. Source/static checks: no accidental changes to `main`; no duplicate/unused conflicting ownership paths; no future-bar reads in pattern detection; every reject has a useful reason.
2. Compile: MetaEditor reports 0 errors and 0 warnings on the exact source commit to be released. Preserve the compiler log and SHA-256 of both `.mq5` and generated `.ex5`.
3. Regression: test buy/sell, all supported pending types, manual/mobile-origin positions, missing SL/TP, broker stop/freeze rejects, retries, terminal restart recovery, and EA-internal AUTO disabled versus terminal Algo Trading disabled.
4. Historical test: use broker data, realistic spread/commission/swap, and real ticks where the available history supports it. Compare against the same-commit baseline.
5. Out-of-sample/forward: set parameters on an in-sample period, then evaluate on a distinct later period; report number of trades, expectancy in R, profit factor, maximum equity drawdown, costs, exposure, and confidence limitations.
6. Demo soak: verify that every attempted position/pending SL change is confirmed by server state and that management survives terminal restart and manual/mobile entry.
7. Release: only after all gates pass, move the exact tagged source to MetaTrader for final compile. Never overwrite the live EA as part of development.

## Platform facts used in implementation
- MQL5 `CTrade::PositionModify` and `CTrade::OrderModify` returning true only confirms local/basic request checks; the server retcode and resulting order/position geometry must be checked.
- `SYMBOL_TRADE_STOPS_LEVEL` and `SYMBOL_TRADE_FREEZE_LEVEL` are broker symbol constraints and need live validation.
- Strategy Tester real-tick tests are more realistic when reliable real tick history is available, but still do not prove future performance.

Official references:
- https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify
- https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradeordermodify
- https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
- https://www.mql5.com/en/docs/runtime/testing
- https://www.mql5.com/en/docs/event_handlers/ontradetransaction
