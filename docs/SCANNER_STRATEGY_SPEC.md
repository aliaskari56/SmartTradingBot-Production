# SmartTradingBot Scanner Strategy — Five-Part Specification

## Status

**Design-only proposal. Not implemented, compiled, backtested, or approved for live trading.**

This specification defines the intended scanner and decision pipeline before any MQL5 changes. The production EA and its current inputs must remain unchanged until a reviewed implementation is tested separately.

## Objectives

- Rank candidate symbols by measurable opportunity quality, not score alone.
- Separate market eligibility, setup quality, risk approval, and execution.
- Make each decision explainable and auditable.
- Evaluate BUY and SELL independently; prior reported tests show a persistent BUY/SELL performance asymmetry, but do not prove its cause.
- Avoid claiming profitability until a reproducible, cost-aware, out-of-sample evaluation supports it.

## Part 1 — Symbol scanner and opportunity ranking

For each configured/eligible symbol, collect only data that is available and sufficiently fresh. Normalize metrics by symbol characteristics rather than comparing raw points across instruments.

Candidate score components (initial design weights; hypotheses, not optimized values):

| Component | Weight | Intended evidence |
|---|---:|---|
| Trend quality | 25% | Directional persistence and separation from chop |
| Price structure / setup quality | 25% | Valid pullback, structure, and confirmation |
| Multi-timeframe alignment | 20% | Higher-timeframe context agrees with candidate direction |
| Execution quality | 15% | Spread and estimated trading costs relative to stop distance / expected move |
| Volatility suitability and stability | 15% | Tradable volatility, sufficient data, and stable behavior |

The weights apply only after hard eligibility gates pass. They must not compensate for a failed risk or execution gate. Compare this proposed score with the current scanner score before changing code; do not silently replace existing scoring.

Required hard gates:
- symbol is explicitly eligible under the scanner allow-list and management policy;
- price/indicator data are valid and fresh;
- spread/cost is within a documented symbol-aware limit;
- market regime is compatible with the selected setup;
- no duplicate or prohibited exposure would be created;
- risk and broker constraints pass.

Rank eligible candidates by score, but select a trade only after Parts 2–4 approve it. If no candidate passes, do not trade.

## Part 2 — Market-regime classifier

Classify the current environment into one of these states:
1. Uptrend
2. Downtrend
3. Range / low directional quality
4. Abnormal volatility
5. Unacceptable execution conditions (for example, excessive spread or stale data)
6. Unknown / insufficient data

Use H4 for higher-timeframe context and M15 for setup evaluation as an initial hypothesis. Use closed bars for signals where possible to reduce unstable intrabar decisions. Define explicit, testable thresholds in code only after inspecting the current implementation and available historical data.

Initial routing:
- Uptrend: evaluate BUY trend-pullback setups.
- Downtrend: evaluate SELL trend-pullback setups.
- Range: reject trend-following entries unless a separately tested range strategy is explicitly enabled.
- Abnormal volatility, unacceptable costs, or unknown data: reject new entries.

Do not infer that H4 alignment causes improved outcomes merely because BUY trades have underperformed in aggregate. Record alignment state and evaluate it by direction and regime.

## Part 3 — Entry strategy: trend + pullback + confirmation

This is a candidate strategy to validate, not a claim of proven edge.

### BUY candidate
1. H4 context indicates an eligible uptrend.
2. Price forms a measurable pullback without invalidating the trend structure.
3. M15 provides a predefined, closed-bar confirmation.
4. Entry, initial stop-loss, and target are valid under symbol tick size, stop-distance, and broker constraints.
5. Estimated reward/risk after material costs meets the predeclared threshold.
6. Parts 1, 2, and 4 all approve the candidate.

### SELL candidate
Apply the mirrored rules for a downtrend, pullback, and bearish confirmation. Do not assume symmetry implies equal performance; report BUY and SELL separately.

### Rejection behavior
Reject a setup if confirmation is absent, structure is invalid, data are stale, the expected move is too small relative to costs, or the required reward/risk is not available. Do not relax filters automatically to force a minimum trade count.

The proposed minimum planned reward/risk of 1.5 is an experiment setting only. Validate it against realized outcomes and costs; a higher planned ratio does not guarantee a positive expectancy.

## Part 4 — Risk and execution engine

The scanner score must never override risk controls. Before order submission:
- calculate volume from the approved risk budget and stop distance, subject to broker volume steps/minimums/maximums;
- verify margin availability and trading permissions;
- check spread and estimated costs;
- enforce symbol, direction, and aggregate exposure limits;
- prevent duplicate entries and excess orders;
- validate SL/TP against tick size, stops level, and freeze level;
- enforce daily/strategy drawdown or loss-stop policies if those controls are already specified and supported;
- reject safely when any mandatory check fails.

Never silently widen the stop, increase volume, or remove a filter to make an order pass. Any rejected order should have a concise reason code in the existing diagnostic path where possible.

## Part 5 — Measurement, attribution, and controlled adaptation

Record or make available the following fields for each evaluated opportunity/trade, preferably through the existing reporting path rather than generating many new files:
- timestamp, symbol, direction, regime, and timeframe;
- scanner score and component scores;
- H4 alignment state;
- setup/profile identifier and entry confirmation;
- planned entry, initial SL/TP, planned reward/risk, and estimated cost;
- eligibility/rejection reason;
- realized net outcome, exit reason, and relevant execution costs.

Measure at minimum:
- net expectancy after costs, profit factor, win/loss distribution, and drawdown;
- trade count and uncertainty/sample size;
- BUY versus SELL;
- symbol and market regime;
- score bucket and H4-aligned versus unaligned candidates;
- in-sample versus untouched out-of-sample results.

Do not use adaptive bandit/profile selection to repeatedly promote profiles based only on recent outcomes. Require minimum sample sizes, fixed evaluation windows, and out-of-sample confirmation before any score or profile changes. Preserve a reproducible baseline and prevent test runs from overwriting baseline data.

## Evaluation protocol before any code change

1. Inspect the production source and current inputs to map existing scanner, regime, entry, risk, and reporting behavior to this specification.
2. Confirm symbol allow-list consistency, especially the interaction between scanner eligibility, management eligibility, and tester chart-symbol-only behavior.
3. Preserve the current baseline configuration and source; do not edit the active chart EA.
4. Define a single-variable experiment before running it. For the H4 BUY hypothesis, record alignment status for eligible BUY candidates and compare aligned versus unaligned results; a BUY-only gate should not be accepted based on aggregate results alone.
5. Use the same symbol, dates, tick model, costs, inputs, and initial balance for baseline and candidate. Keep an untouched out-of-sample window.
6. Compare net expectancy, profit factor, drawdown, trade count, and BUY/SELL attribution. Reject changes that only reduce trade count without improving validated quality.
7. Do not run parameter optimization until a candidate shows evidence in a fixed test and a separate out-of-sample period.
8. Do not deploy based solely on a backtest. Any later validation should remain in a demo/test environment first.

## Decision gates

A proposed change is **not accepted** merely because it improves one metric. Before testing, specify minimum sample size, cost assumptions, primary metric, drawdown guardrail, and out-of-sample rule. If these are not available or the baseline cannot be reproduced, stop and report the blocker instead of guessing.

## Known evidence and limits

Previously reported results show the six-month baseline had 473 trades, net loss of about 278.29, and PF 0.8017; BUY accounted for about 237.61 of net losses and SELL about 40.68 of net losses. These are user-provided report figures and have not been independently recalculated in this document. They justify investigating directional asymmetry, not concluding that H4 alignment is the cause or that this specification will be profitable.

The production repository still does not expose a readable `SmartTradingBot_FINAL.mq5` path; the readable candidate is named `SmartTradingBot.mq5` in the separate repair repository. Therefore this change remains documentation-only. No MQL5 source was modified, no build/test/backtest was run, and no order was sent.


## Source audit — available MQL5 snapshot

A readable MQL5 file was found in `aliaskari56/AstraCore-Cloud-Repair` at commit `1f33cecc255da58a29da8674af28dd458cec580b` (`MQL5/Experts/SmartTradingBot.mq5`, EA version 1.126). Follow-up inspection of the `smarttradingbot-architecture-complete-v1.126-20261006`, `recovery-smarttradingbot-v126-20261006`, and `repair/smarttradingbot-boundary-hardening-20261007` branches confirmed that their `OnInit` code emits the exact `STB TRADE ENV terminal=... program=... account=... tester=...` log signature supplied by the user. This strongly links the runtime log to the v1.126 source family, although it does not prove that the compiled file named `SmartTradingBot_FINAL` is byte-for-byte identical to any repository snapshot. Treat the v1.126 repair branch as the best current source candidate; verify the compiled/source identity before porting strategy changes.

### Existing behavior observed in that snapshot

| Strategy part | Existing implementation | Gap against proposed design |
|---|---|---|
| 1. Scanner | In the `repair/smarttradingbot-boundary-hardening-20261007` snapshot, `STB_ScannerRun()` evaluates BUY/SELL candidates across an allow-listed symbol universe, sorts candidates globally, revalidates the watchlist, and keeps a configurable Top-N. | This branch already has global ranking, so the older claim that the scanner does not rank across symbols is not true for this snapshot. The score uses 65% strategy, 20% market quality, 10% regime fit, and 5% stability—not the proposed 25/25/20/15/15 model. The allow-list implementation and effective candidate counts still need validation in MT5. |
| 2. Regime | `STB_EvaluateRegime()` classifies trending, ranging, transition, high volatility, low volatility, or unstable using H4 trend, M15 efficiency, and ATR ratio. | This is a heuristic classifier, not a validated edge. Ranging/high/low-volatility regimes receive nonzero fit scores rather than always being hard-rejected; their behavior should be tested explicitly. |
| 3. Entry | `BuildSetup()` checks tradability, spread, optional hard oscillator filters, cooldown, H4 alignment/universal mode, CHoCH/BOS, FVG/OB, swing structure, geometry, and RR. | `InpAllowUniversal=true` means H4 misalignment is not automatically rejected. The scanner's regime fit is a score component rather than a strict direction/regime gate. Whether that behavior is desirable is an empirical question. |
| 4. Risk/execution | The source includes pending-order geometry checks, `OrderCheck`, volume/exposure constraints, trade-environment checks, fixed-lot default with optional risk sizing, and server-retcode validation. | `InpUseRiskSizing=false` by default. Fixed lots plus `InpTrendLotMultiplier=2.0` can make aligned setups use a larger lot than universal setups; actual risk varies with stop distance unless risk sizing is enabled. All behavior must be tested in Strategy Tester/demo before deployment. |
| 5. Measurement/learning | Adaptive profile logic, setup/order logs, rejection reasons, regime/quality score fields, and scanner summary counters exist. | The scanner silently skips several eligibility/quality/regime failures, and the market-quality function maps some below-threshold scores to `REJECT_SPREAD` even when volatility/activity/freshness contributed. Candidate-level auditability is therefore incomplete; adaptive behavior should be tested separately from a fixed baseline. |

### Confirmed scanner behavior worth noting

- In the inspected repair branch, `InpTesterChartSymbolOnly=true` restricts Strategy Tester scanning to `_Symbol`; the normal scanner uses the symbols that pass `STB_ScannerIsAllowListed()` from the terminal symbol list.
- The scanner cycle is keyed to the latest closed M15 bar (`iTime(_Symbol, PERIOD_M15, 1)`), so a timer firing every 10 seconds does not mean a full universe rescan every 10 seconds.
- `STB_ScannerRun()` ranks candidates globally, then revalidates the shortlist and executes at most one successfully placed candidate per scan cycle.
- `BuildSetup()` computes H4 alignment and rejects misaligned setups only when `InpAllowUniversal` is false. Thus a proposed BUY-only H4 gate would be an additional experiment, not a correction proven by this audit.
- Scanner confidence is `CLEAR` only when the top score meets `InpScannerMinScore` and, when there is a runner-up, its lead meets `InpScannerMinTopGap`; otherwise execution is skipped.
- `InpMinimumRR` defaults to 1.0 and `InpTrailStartPips` defaults to 150.0 in this snapshot. These are existing settings, not evidence that the proposed 1.5 RR hypothesis is better.
- `InpUseRiskSizing` defaults to false. Do not infer risk-based sizing is active unless the runtime configuration explicitly enables it.

### Recommended implementation sequence

1. Confirm that the v1.126 repair-branch source is identical to the compiled `SmartTradingBot_FINAL` artifact (for example, compare source hash/version and compile the exact source in MetaEditor). Do not port changes until this is confirmed.
2. Repair candidate-level diagnostics: distinguish low-quality score causes (spread, volatility, activity, stale quote) and emit compact rejection counts/reasons without excessive log spam.
3. Validate scanner allow-list behavior, closed-M15-bar cadence, top-gap confidence, and final candidate revalidation with deterministic tests.
4. Establish a fixed baseline and test any BUY-only H4-alignment gate as one isolated, reversible experiment; preserve aligned and unaligned candidate outcomes.
5. Keep any future score/regime changes behind explicit inputs until compile checks, deterministic backtests, and out-of-sample evaluation pass.

This audit is source inspection only. No MQL5 code was changed or compiled, and no backtest or trade was run.


## Follow-up audit — repair branch `repair/smarttradingbot-boundary-hardening-20261007`

The repair branch was inspected after finding that the runtime log signature matches its `OnInit` log. Its source SHA is `e81fd4632717928e4499cb948bd9269d68533fdd` and it declares EA version 1.126. This is the strongest current source candidate, but the compiled `SmartTradingBot_FINAL` identity is still not verified.

New findings:
- Contrary to the earlier snapshot's behavior, this repair branch has a global candidate ranker: 65% strategy score, 20% market-quality score, 10% regime-fit score, and 5% stability score.
- The regime classifier is implemented and uses H4 trend, M15 directional efficiency, and relative ATR to label trending/ranging/transition/high-volatility/low-volatility/unstable states.
- A full scanner cycle only runs when a new closed M15 bar appears. `InpScanSeconds=10` is the timer cadence, not a guarantee of a full scan every 10 seconds.
- It ranks and revalidates the shortlist, and only attempts execution when scanner confidence is `CLEAR`; this requires the top score to meet `InpScannerMinScore` and its gap over the runner-up to meet `InpScannerMinTopGap`.
- The scanner attempts to execute at most one candidate successfully per scan cycle.
- `STB_CalcMarketQuality()` can report `REJECT_SPREAD` for a below-threshold aggregate quality score even when volatility, activity, or freshness contributed to the low score. Several scanner-stage rejections are skipped without a per-symbol log, so diagnosis from summary counts alone can be difficult.
- `InpAutoTrading=false`, `InpUseRiskSizing=false`, `InpAllowUniversal=true`, `InpScannerMinScore=55`, and `InpScannerMinTopGap=3` are source defaults; the runtime `.set` inputs may differ. The `STB INIT` log should be checked for effective auto/universal settings.

No MQL5 source was changed, compiled, or backtested in this follow-up. The only repository write was this documentation update.


## Follow-up audit — initialization and order execution gates

Inspected the v1.126 repair-branch source at `MQL5/Experts/SmartTradingBot.mq5` (source SHA `e81fd4632717928e4499cb948bd9269d68533fdd`).

- `OnInit()` prints an `STB INIT` line containing the effective `auto`, `autoInput`, `universal`, strict pattern-filter and oscillator/adaptive settings. These runtime values matter more than source defaults because inputs and persisted AUTO state can affect behavior.
- The startup `STB TRADE ENV` line prints terminal, program, account-expert, and tester flags, but does **not** print `ACCOUNT_TRADE_ALLOWED`. The actual `STB_TradeEnvironmentAllowed()` gate checks that additional account-trading flag too. Therefore a startup line showing `account=ON` alone does not prove every trade permission gate is open. The runtime rejection log `STB TRADE ENV REJECT` does include `accountTrade=`.
- Scanner execution silently skips candidates when final revalidation or the final auto/exposure gate fails. Placement-level failures are more explicit through `STB PLACE REJECT`, while OrderCheck failures log `STB ORDERCHECK REJECT`; successful pending-order creation logs `STB AUTO PENDING CREATED`.
- The scanner's initial symbol loop uses `continue` for ineligible data, market-quality failures, unstable regimes, and failed `BuildSetup()` calls. Those individual failures are not logged there. As a result, a scanner summary with zero candidates may not identify the exact reason.
- In fixed-lot mode, requested volume is `InpBaseLots * (InpTrendLotMultiplier or InpUniversalLotMultiplier)`; the actual stop-distance risk can vary. This is another reason to verify effective inputs and evaluate only in Strategy Tester/demo before any deployment.

### Diagnostic conclusion

For a runtime log that shows `terminal=ON program=ON account=ON tester=NO`, the available line does not establish that `auto=ON`, that `ACCOUNT_TRADE_ALLOWED` is true, or that any scanner candidate passed. The next useful evidence is the matching `STB INIT` line and one complete `STB SCANNER SUMMARY`, followed by any `STB PLACE REJECT`, `STB ORDERCHECK REJECT`, `STB TRADE ENV REJECT`, or `STB AUTO PENDING CREATED` lines. This identifies which gate was reached without changing execution logic.

This is a source-audit/documentation update only. No MQL5 source was modified, compiled, backtested, or executed.
