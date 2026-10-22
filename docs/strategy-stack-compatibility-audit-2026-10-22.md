# SmartTradingBot strategy-stack compatibility audit — 2026-10-22

## Scope and status

This is a static source/configuration audit of `MQL5/Experts/SmartTradingBot_FINAL.mq5` at commit `985ebc67258fdcaf86266c54b0b421ec00d073b7`, combined with the operator-provided terminal log excerpts from 2026-10-22. It is not a claim that the strategy has been shown profitable or that the full Expert Advisor has passed a new compile/Strategy Tester run from this document.

**No entry/exit rule, threshold, risk parameter, or order-placement behavior is changed by this audit.** A universal “best” parameter set cannot be established from compile results or rejection logs alone. For that, repeatable backtests and independent out-of-sample/forward validation are required.

## Runtime evidence supplied for the current build

Latest supplied scanner summaries around 13:33–13:34 show approximately:

- universe: 302 symbols
- eligible: 147–148
- quality: 18–19
- regime: 17–18
- buy and sell candidates: 0
- direction-gate rejects: 14–16
- build-setup rejects: 18–20
- setup-age rejects: 0
- score rejects: 0
- minimum scanner score: 55
- confidence: `NO_CLEAR_WINNER`

The 30 most recent `STB SETUP REJECT` records in the supplied interval comprised 16 `H4_TREND_UNAVAILABLE_H4_BULLISH_LINE_INVALIDATED_BY_CLOSE`, 10 `H4_TREND_UNAVAILABLE_H4_STRUCTURE_NEUTRAL`, 2 `H4_DIRECTION_MISMATCH`, and 2 `BOS_TOO_OLD`.

This is strong evidence that the **H4 hard gate is the first observed bottleneck in that interval**. Since `scoreRejects=0`, changing the score threshold would not address the observed failure. The full-day counts (including `BROKER_STOP_NORMALIZATION_FAILED`) must not be mixed with the later interval: a setup rejected at H4 never reaches later M15/FVG/OB/geometry checks, so earlier geometry counts are not proof that geometry is the current bottleneck.

## Strategy pipeline and gate interactions

The source currently applies these checks in sequence; a setup must survive every enabled hard gate.

1. **Symbol and quote preflight / scanner eligibility** — symbol selected and synchronized, quote availability/freshness, broker trade mode and supported order flags.
2. **Market quality and regime** — spread relative to M15 ATR and volatility/activity/freshness filters; only a small subset of the 302-symbol universe survives these gates.
3. **Per-direction eligibility** — broker's symbol direction/order restrictions before building the setup.
4. **Base setup checks** — direction tradability, spread, optional oscillator hard filter, cooldown.
5. **H4 directional context** — `InpRequireH4TrendAlignment=true` rejects an invalid/neutral H4 result and rejects a direction contrary to H4. `InpAllowUniversal=true` does not bypass this earlier condition in `BuildSetup`; it is not a switch that overrides mandatory H4 alignment.
6. **M15 market structure** — confirmed swing-based CHoCH/BOS must be detected; `BOS_TOO_OLD` is rejected using the effective maximum setup age (configured default `InpMaxSetupAgeBars=4`).
7. **Local pattern conditions** — `InpRequireFVG=true` and `InpRequireOB=true` are independent hard gates. `InpStrictPatternFilters=false` does not turn these two individual requirements off.
8. **Higher-timeframe confluence** — `InpRequireHTFConfluence=true` requires HTF FVG/OB confluence; configured timeframe is H1 and configured lookback is 120 bars.
9. **Structural stop/target and pending geometry** — the code rejects invalid structural stop anchors, crossed/stale pending triggers, invalid broker distances, missing suitable structural TP targets, and inadequate reward/risk. It deliberately should not “repair” a stale breakout by chasing price after the trigger is crossed.
10. **Scoring, ranking, candidate and execution stages** — only setups surviving earlier gates reach the score/ranking stage. A zero score-reject count with zero candidates means earlier gates are more relevant than the minimum scanner score for the supplied interval.

## H4 interpretation

`GetH4Trend` requires two latest confirmed swing highs and lows to agree directionally (higher highs + higher lows for bullish, lower highs + lower lows for bearish), then checks the corresponding line and the last closed H4 bar. A neutral structure or a close invalidating a previously bullish/bearish line is therefore a deliberate hard rejection under the current setting, not by itself proof of a coding error.

Do not loosen H4 or pattern filters merely to increase the number of candidates. If H4 is considered too restrictive, that needs an explicit strategy-policy decision followed by a controlled Strategy Tester comparison; a higher candidate count by itself is not evidence of a better strategy.

## Configuration/reproducibility concerns

- The log confirms `universal=ON` and `requireH4Align=ON` at the same time. Under the current gate order, the latter remains mandatory even when universal mode is on. The input names alone can mislead an operator about this interaction.
- FVG, OB, and H1 confluence are all individually enabled, so the combined confluence filter is strict even though `InpStrictPatternFilters=false`.
- Adaptive learning and adaptive parameter learning are enabled in the supplied initialization log. That can make the effective profile important when comparing runs. A reproducibility run should record the selected profile and effective parameters and separate fixed-parameter diagnostics from adaptive behavior.
- The 302-symbol universe contains instruments with different tick sizes, contract modes, session schedules, stop/freeze distances, volume limits and quote behavior. A single hard-coded pip assumption cannot be presumed valid across every symbol. The source should continue to derive geometry and constraints from each symbol's broker properties and fail closed when those values are unavailable.
- Current logs show `auto=ON` and `testerForceAuto=ON`. The tester-specific option must remain tester-specific in its implementation, and the EA should not be attached or activated for trading as part of a static audit.

## Validation protocol (no parameter “winner” inferred in advance)

1. Freeze and identify the exact source commit and input set; record build hash and initialization log.
2. Run a baseline test with complete tick data appropriate to the strategy. Save the complete tester report and the Expert/Journal logs.
3. Compare one hypothesis at a time in the Strategy Tester, without changing multiple gates together. First verify whether the H4 gate alone accounts for the zero-candidate behavior; next inspect the newly exposed downstream reject categories. Keep the same symbol, date window, timeframe, spread/commission assumptions and modeling mode across comparisons.
4. Use separate in-sample and out-of-sample date ranges, then forward validation on data not used to choose parameters. Do not select a single isolated optimization peak as “best”; look for stability across periods and instruments and report trade count, drawdown, expectancy, profit factor, rejected setup counts, and sensitivity to costs.
5. Check broker-specific order geometry and symbol capabilities separately from signal quality; technical validity is not evidence of profitability.

## Authoritative references

- MetaQuotes, `CopyRates`: https://www.mql5.com/en/docs/series/copyrates
- MetaQuotes, Strategy Tester and testing modes: https://www.mql5.com/en/docs/runtime/testing
- MetaQuotes, symbol properties including tick size, stops/freeze levels, volume limits and allowed order modes: https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
- MetaQuotes, `OrderCheck` and its limitations: https://www.mql5.com/en/docs/trading/ordercheck
- MetaQuotes, optimization and out-of-sample/forward-validation workflow (Pardo method): https://www.mql5.com/en/articles/19520


## Follow-up from the 13:34 terminal logs

The operator later supplied five initialization records. The active M5 instance at 13:19 reports `universal=ON`, `requireFVG=ON`, `requireOB=ON`, `requireH4Align=ON`, and `requireHTFConfluence=ON`. Other chart instances were also initialized on D1, M1, and W1, so logs from a given date are not automatically attributable to one chart/instance unless the symbol, timeframe, initialization time, and instance are matched.

For the interval selected from 13:20 onward, the operator's PowerShell extraction returned 30 `STB SETUP REJECT` messages:
- 16 `H4_TREND_UNAVAILABLE_H4_BULLISH_LINE_INVALIDATED_BY_CLOSE`
- 10 `H4_TREND_UNAVAILABLE_H4_STRUCTURE_NEUTRAL`
- 2 `H4_DIRECTION_MISMATCH`
- 2 `BOS_TOO_OLD`

The last reported M5 summaries at 13:33:44, 13:33:54, and 13:34:04 showed 302-symbol universe, 147–148 eligible, 18–19 quality-passing, 17–18 regime-passing, zero buy/sell candidates, 14–16 direction-gate rejects, 18–20 setup-build rejects, zero setup-age rejects, and zero score rejects. That further confirms that the score floor is not the current first-order obstacle.

Importantly, `BuildSetup` tests the hard H4 condition before `DetectStructure`, FVG/OB detection, HTF confluence, and pending-order geometry. Thus these 30 recent records are censored by an upstream gate: they do **not** establish that downstream checks would pass. The broader full-day count of `BROKER_STOP_NORMALIZATION_FAILED` is from a different interval and must not be interpreted as the active interval's dominant cause.

## Next diagnostic split to make (tester only)

Do not silently change production defaults based on rejection counts. Use a controlled Strategy Tester comparison with an otherwise identical parameter set:

- **Baseline:** keep all current filters unchanged; save the report, exact inputs, log, build hash, date window, tick model, spread/commission and symbol.
- **Single-gate diagnostic:** toggle only `InpRequireH4TrendAlignment` for that tester run to reveal the downstream CHoCH/BOS, FVG, OB, HTF and geometry rejection distribution. Treat the result as a diagnostic branch, not as a recommended or proven better strategy.
- **Downstream audit:** determine which subsequent hard gates reject the newly visible setups. Keep counts separated by symbol/timeframe and by run; do not combine old terminal logs with the comparison interval.
- **Do not infer quality from volume:** more candidates or trades alone does not mean higher expectancy or lower drawdown. Compare the complete tester report, and preserve a separate out-of-sample period that was not used to choose inputs.

## Additional implementation observation

`STB_CalcMarketQuality` defines relative spread as `(ask-bid)/M15_ATR * 100`, rejects values above `InpMaxRelativeSpreadPct`, and applies quality-score penalties for spread, volatility, activity, and quote freshness. The summary count `eligible` includes symbols before market-quality checks; the large difference between `eligible` (about 147) and `quality` (about 18–19) means the aggregate summary alone cannot say whether spread, activity, volatility, freshness, or missing data explains that drop. The next diagnostic should collect reason counts for `STB SCANNER REJECT stage=MARKET_QUALITY` and `stage=DATA_ELIGIBILITY` separately rather than loosening thresholds blindly.

MetaQuotes documents that `CopyRates` may initially return fewer bars while data history is still downloading/building, so multi-symbol test repeatability depends on confirming series readiness and using consistent historical data. For the multi-symbol EA, a test on one symbol should not be treated as a complete reproduction of a 302-symbol live scan.


## Follow-up from the stage rejection aggregation

The operator's next aggregation (still scoped to chart label `SmartTradingBot_FINAL (XAUUSD+,M5)`, starting at 13:20 server-log time) returned these **event counts**, not unique-symbol counts:

| Rejection stage/reason | Logged events |
|---|---:|
| DATA_ELIGIBILITY / REJECT_STALE_DATA | 27,856 |
| DATA_ELIGIBILITY / REJECT_DATA_UNAVAILABLE | 2,499 |
| DATA_ELIGIBILITY / REJECT_SESSION | 395 |
| MARKET_QUALITY / REJECT_RELATIVE_SPREAD | 24,971 |
| MARKET_QUALITY / REJECT_VOLATILITY | 198 |
| MARKET_QUALITY / REJECT_ACTIVITY | 196 |
| MARKET_QUALITY / REJECT_QUALITY_SCORE | 5 |
| REGIME_FILTER / REJECT_UNSTABLE_REGIME | 248 |

The repeated per-symbol scan loop means these are repeated observations across cycles and must not be read as 27,856 distinct symbols or independent trade opportunities.

### Source-backed interpretations

- `STB_ScannerQuoteValid` rejects a symbol when the timestamp in its latest `MqlTick` exceeds `max(30, InpScannerMaxQuoteAgeSec)`; current configured max quote age is 300 seconds. Official `SymbolInfoTick` documentation describes the returned timestamp as the time of the last price update, so instruments with no new quote for several minutes will naturally fail a freshness gate. This can be prudent, but it also means a broad mixed-symbol universe can repeatedly count dormant instruments.
- In `STB_ScannerDataEligible`, freshness/quote checks currently occur before `STB_ScannerSessionOpen`. A closed-session instrument whose last quote is old is therefore labelled `REJECT_STALE_DATA` before the code can classify it as `REJECT_SESSION`. Reordering the session check before quote freshness would improve diagnosis without making a stale quote valid or loosening entry gates; it should be tested because broker session metadata can vary by symbol.
- `STB_CalcMarketQuality` defines `relativeSpread = (ask-bid)/M15_ATR*100` and rejects when the value exceeds the input `InpMaxRelativeSpreadPct=10.0`. The 24,971 event count shows this is the predominant quality-gate reason in this interval. It does **not** prove that 10.0 is an incorrect threshold: symbol classes differ materially in quote frequency, tick size, session schedules and spreads. Do not set the threshold to zero or simply raise it from this count alone.
- The initialization logs show a 302-symbol universe with mixed instruments. The correct next measurement is the number of unique symbols affected per reason, the most recent timestamp/quote age per symbol, and rejection counts per full scan cycle. These are necessary to separate repeated dormant quotes from a systemic time-basis or feed problem.
- `REJECT_UNSTABLE_REGIME` is downstream of market quality and represents 248 further events in the same interval. Since only symbols that pass market quality reach this stage, the event count is conditional on earlier gates and should not be compared as if each gate saw the same universe.

### Next audit action

Before changing any trade-selection threshold, collect unique-symbol coverage and compare it against the number of `STB SCANNER SUMMARY` rows in the same time interval. If most stale symbols are consistently outside their published trade sessions, classify sessions first for clearer telemetry. If they are supposed to be active, compare terminal/server clock, latest tick timestamp and current session metadata. Independently report relative spread as a distribution by symbol and asset class rather than loosening the shared cap blindly.
