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
