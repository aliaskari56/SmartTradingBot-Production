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

The connected repository currently exposes a canonical backup ZIP in its latest commit; the MQL5 source was not available as a directly readable repository file during this task. Therefore this change is documentation-only. No MQL5 source was modified, no build/test/backtest was run, and no live or demo order was sent.
