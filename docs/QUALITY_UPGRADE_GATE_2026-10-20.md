# SmartTradingBot quality-upgrade gate — 2026-10-20

## Repository control

- Production baseline: main at 578621216f2f62ade33ab8e341a506e253b22bbf.
- Development branch: fix/structure-first-fvg-trailing-20261020.
- Latest branch commit at this checkpoint: 91669e55f3516247f07d2d3f8e633af66c613fe5.
- Source blob: 0b80607d25e313313f19d0761a2cb6f0b7c29604c.
- Pending-trail include blob: b45952dcb34f854dadfa4059473402ea74b96e41.
- Static-audit tool blob: e52a25f7f642c0be84a15a35a172614a4d6dc94f.
- main has not been edited or merged into. No source or EX5 has been copied to the active MetaTrader terminal.

## CI evidence for this revision

| Check | Result | Evidence |
|---|---|---|
| MetaEditor Windows compile | **0 errors, 0 warnings** | [Run 39391437094](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39391437094) |
| Static source/invariant audit | **Passed** | [Run 39391436796](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39391436796) |
| Trading safety defaults | **Passed** | [Run 39391436842](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39391436842) |

The compile workflow archived a fresh EX5, compiler log and provenance manifest as artifact [metaeditor-build-91669e55f3516247f07d2d3f8e633af66c613fe5](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39391437094/artifacts/12249861519). This is a CI build artifact only; it has **not** been deployed to the user's terminal.

**Important:** compile/static CI success verifies syntax and listed invariants, not trading edge, full broker behavior, or profitability. No Strategy Tester backtest, out-of-sample run, or demo soak has been recorded for this upgraded build yet. The branch is therefore **not release-ready**.

## Changes now present on the working branch

1. **Entry quality gates**
   - H4 directional alignment is a hard gate by default.
   - Required local M15 FVG and Order Block are hard rejection gates; they cannot be replaced by score bonuses.
   - New H1-or-higher FVG + Order Block confluence checks the zones against the closed M15 decision time, rejects stale/fully mitigated FVGs and structurally invalidated blocks, requires a confirmed pre-impulse swing break for the OB, and verifies proximity to the M15 origin zone.
   - Setup age defaults to at most four M15 bars rather than being unlimited.

2. **Scanner**
   - Excessive spread as a share of M15 ATR is a hard market-quality rejection (InpMaxRelativeSpreadPct=10.0 by default); the threshold is configurable and logged at startup.
   - Data freshness, activity, relative volatility, market quality, direction and regime checks remain active. Hard eligibility gates are separate from ranking.

3. **Position SL/TP management**
   - Position trailing defaults to confirmed swing structure on the configured trailing timeframe, with ATR activation and ATR-based padding. It remains monotonic and preserves existing profit-lock rules.
   - Initial structural TP can be added to managed positions/pending orders only when TP is absent. Explicit user-set TPs are preserved.
   - A selected SL improvement can attach an absent structural TP in the same verified position-modify request, avoiding TP starvation when trailing improves frequently.
   - SL and TP updates use one direct broker-facing PositionModify writer, snapshot/ownership checks, server retcode checks and post-write verification. Pending TP uses the central pending geometry writer.

4. **Pending STOP trail**
   - Actionable closed-M5 bars remain retryable after a resolver/server failure instead of being marked processed before the modify succeeds.
   - Bounded retry delays are used; order existence/ownership is rechecked before honoring backoff so triggered/cancelled orders are not hidden by a stale retry timer.
   - Manual/mobile-origin pending orders are not permanently opted out of automatic protective SL/trailing solely by override metadata.

5. **Adaptive learning**
   - Learning state namespace advanced from AP2 to AP3 so old profile statistics do not mix with the new signal definition.
   - R expectancy has a separate risk-valid sample denominator; trades with unknown initial risk cannot corrupt the R mean.
   - Break-even is represented as a neutral half-win/half-loss observation.
   - Where available, actual filled-position entry/volume/SL is used to recalculate initial monetary risk; planned risk is only a fallback.

## Required next gates

1. Re-run exact-source compile and all CI checks after every source change; retain artifact provenance.
2. Run deterministic component/regression tests for BUY/SELL, both pending STOP trail directions, LIMIT and STOP-LIMIT handling, TP-missing/TP-present paths, broker stop/freeze rejection, retries, ticket disappearance/trigger, terminal restart, and multiple chart instances.
3. Run baseline vs upgraded Strategy Tester builds on the same symbol, date range, tick model, account/deposit/leverage, spread, commission, swap and input parameters. Use real ticks when reliable history exists. Reconcile order/deal history with report statistics.
4. Run a later, held-out out-of-sample window that was not used to set parameters. Report sample size, expectancy in R, profit factor, maximum equity drawdown, total costs, and exposure. Do not promote the build on win rate alone.
5. Run a demo soak test for manual/mobile/EA positions and pending orders, including missing SL/TP, transient rejections, reconnection and restart. Confirm each broker modify through resulting terminal state.
6. Only after all gates pass, copy the exact reviewed source to MetaTrader for the **final local compile**. Do not overwrite the active EA as a development step.

## Official references used

- MQL5 CTrade::PositionModify: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify
- MQL5 CTrade::OrderModify: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradeordermodify
- Broker stop/freeze levels: https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
- Strategy Tester: https://www.mql5.com/en/docs/runtime/testing
- Trade transactions: https://www.mql5.com/en/docs/event_handlers/ontradetransaction
