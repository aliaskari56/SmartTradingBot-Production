# SmartTradingBot quality-upgrade gate — 2026-10-20

## Repository control

- Production baseline: `main` at `578621216f2f62ade33ab8e341a506e253b22bbf`.
- Development branch: `fix/structure-first-fvg-trailing-20261020`.
- Latest source-code commit in this scanner checkpoint: `ea67c43b92cb5b9c65ee7d170de7795561f37672` (`fix: harden scanner quote integrity and top-gap ranking`).
- Exact source Git blob: `40adb7effcdb024be04dd4ecea2048a02d30f0de`; source SHA-256 from build provenance: `EC95BAE59896D1E8227F87A71D299720A8A3571045BEFD4EEEB0A4B3C7B3A259`.
- Pending-trail include blob remains `b45952dcb34f854dadfa4059473402ea74b96e41`.
- Static-audit tool blob in this checkpoint: `488a98e64d32592cd64b95217612ae52eb0eb6e7`.
- Main has not been edited or merged into. No source or EX5 was copied to the active MetaTrader terminal.

## CI evidence for this source commit

| Check | Result | Evidence |
|---|---|---|
| MetaEditor Windows compile | **0 errors, 0 warnings** | [Run 39455177457](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457) |
| Static source/invariant audit | **Passed** | [Run 39455177088](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177088) |
| Trading safety defaults | **Passed** | [Run 39455177310](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177310) |

The fresh compile artifact is [artifact 12280695788](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457/artifacts/12280695788). Its provenance records:
- Source SHA-256: `EC95BAE59896D1E8227F87A71D299720A8A3571045BEFD4EEEB0A4B3C7B3A259`.
- EX5 SHA-256: `99229960CD83699225ED6318791B4BB2929CA580AA7B0283130DF4252243B602`.
- MetaEditor: `5.0.0.6274`; compile time `2026-10-20T16:11:57.3635453Z`.
- The artifact contains a fresh `SmartTradingBot_FINAL.ex5`, compiler log and `provenance.json`; it is a CI test artifact, not a terminal deployment.

**Important:** compile/static CI success verifies syntax and the listed source invariants, not scanner runtime decisions, broker behavior, profitability, or release readiness. Scanner functional tests SCN-03–SCN-08 remain **NOT RUN**; no Strategy Tester backtest, out-of-sample run, or demo soak has been recorded for this correction. The branch remains **NOT release-ready**.

## Changes now present on the working branch

1. **Entry quality gates**
   - H4 directional alignment is a hard gate by default.
   - Required local M15 FVG and Order Block are hard rejection gates; they cannot be replaced by score bonuses.
   - New H1-or-higher FVG + Order Block confluence checks the zones against the closed M15 decision time, rejects stale/fully mitigated FVGs and structurally invalidated blocks, requires a confirmed pre-impulse swing break for the OB, and verifies proximity to the M15 origin zone.
   - Setup age defaults to at most four M15 bars rather than being unlimited.

2. **Scanner**
   - Excessive spread as a share of M15 ATR is a hard market-quality rejection (InpMaxRelativeSpreadPct=10.0 by default); the threshold is configurable and logged at startup.
   - One shared fail-closed quote validator is applied both before scanner eligibility and before market-quality ranking. It rejects non-finite/non-positive quotes, crossed markets, missing timestamps, materially future-dated quotes and stale quotes; a small two-second timestamp skew is tolerated.
   - Quality scoring rejects non-finite ATR/derived metrics instead of allowing invalid numeric values to contaminate ranking.
   - Scanner confidence compares the best candidate with the runner-up in the complete final revalidated watchlist before applying the execution Top-N cap. InpScannerTopN=1 therefore cannot bypass InpScannerMinTopGap when a second valid candidate exists; a lone candidate can still pass the score floor.
   - Data freshness, activity, relative volatility, market quality, direction and regime checks remain active. Hard eligibility gates are separate from ranking. Strategy weights and regime thresholds were not changed.

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


## Scanner correction checkpoint — 2026-10-20

The source correction is committed as `ea67c43b92cb5b9c65ee7d170de7795561f37672`. Its exact source compiled with MetaEditor `5.0.0.6274` with **0 errors, 0 warnings** ([run 39455177457](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457)); the static scanner/architecture audit passed ([run 39455177088](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177088)); trading safety defaults passed ([run 39455177310](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177310)). Build provenance and a fresh EX5 are archived in [artifact 12280695788](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457/artifacts/12280695788).

The code change adds shared quote-integrity validation, finite-market-metric rejection and full-watchlist competition-gap evaluation. It does not change the existing 65/20/10/5 ranking weights, hard-spread threshold or regime thresholds. Deterministic scanner cases SCN-03 through SCN-07 and the frozen baseline/candidate Strategy Tester comparison SCN-08 remain **NOT RUN**. Static/compile pass is not runtime or profitability evidence; the branch remains **NOT release-ready**.


## Strategy audit checkpoint — fresh M15 structure break

A source-level defect was corrected in `DetectStructure()`: prior logic accepted any closed bar still above a bullish swing high (or below a bearish swing low). That could relabel an old break as a new setup, refresh `setupTime`, and undermine `InpMaxSetupAgeBars`. The detector now requires a fresh close-crossing relative to the immediately older closed bar and bounds the loop to guarantee that older bar exists.

Exact source commit `5b14166acb84c367bb02b4616a348c0816ab4cc8` passed MetaEditor `5.0.0.6274` with **0 errors, 0 warnings** ([run 39457211695](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211695)), the static invariant audit passed ([run 39457211171](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211171)), and safety-default checks passed ([run 39457211930](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211930)). Exact-source artifact: [12280118878](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211695/artifacts/12280118878).

Provenance: source blob `c8a09e3a05f7ac8aea37ccd421a7aa1012191ffd`; source SHA-256 `E8AAA1DAD0C3914837D915718D91D4A73D230E6A52EBC1210BB42BBB8E453BC8`; EX5 SHA-256 `7B9DC581BDD9A4091147C9208F652B7E8FABFEB0B0977D6BECD65000DEFCFDAD`. This is CI evidence only, not Strategy Tester evidence or terminal deployment.

The detector still does not independently identify a distinct two-event CHoCH-then-BOS sequence: it confirms one fresh directional pivot crossing. In addition, `chochShift` currently records the broken pivot's shift while `bosShift` records the break candle's shift. Whether to require both separate events is an open strategy-definition decision, tracked as STR-09 rather than being silently assumed.

Two additional source-derived strategy items are now tracked:
- Strategy score saturation: an aligned setup with fresh BOS (`+40+30`), RR ≥ 2 (`+15`), local FVG and OB (`+10+10`), and confirmed default RSI/CCI (`+7.5`) calculates 112.5 before the score is clipped to 100. This can reduce ranking resolution for strong setups. No scoring weights were changed; evaluate saturation and compare a single-variable candidate against a frozen baseline first.
- Input-policy interaction: with `InpRequireH4TrendAlignment=true`, an H4-misaligned setup is rejected even if `InpAllowUniversal=true`; the latter only matters when the hard H4-alignment requirement is disabled. Confirm the intended meaning through STR-11 before altering defaults.

STR-07–STR-12 remain test requirements, not completed runtime results. The branch remains NOT release-ready until the applicable deterministic and Strategy Tester gates are run.
