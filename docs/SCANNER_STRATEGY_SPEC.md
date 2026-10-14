# Five-Part Scanner Strategy Specification

**Status: design proposal only. Not implemented, compiled, backtested, or approved for live use.**

This document records a testable design direction for the scanner. It does not authorize changing the current EA behavior, and it does not establish a profitable trading strategy.

## 1. Symbol eligibility and ranking

Evaluate only symbols with valid, sufficiently fresh price/indicator data and acceptable trading conditions. Normalize metrics by symbol characteristics rather than comparing raw points. Rank eligible opportunities using documented components such as trend quality, price structure, multi-timeframe context, execution cost, and volatility suitability.

Hard eligibility, exposure, risk, and broker constraints must run before ranking can lead to an order. A high score must never override a failed hard gate. If no candidate passes, do not trade.

## 2. Market regime

Classify conditions into uptrend, downtrend, range/low directional quality, abnormal volatility, unacceptable execution conditions, or unknown/insufficient data. H4 context and M15 setup evaluation are initial hypotheses, not validated requirements. Prefer closed-bar signals where appropriate. Reject new entries when data or execution conditions are unacceptable.

## 3. Entry hypothesis

A BUY candidate may require eligible higher-timeframe uptrend context, a measurable pullback, predefined M15 confirmation, valid entry/SL/TP geometry, and an acceptable planned reward/risk after estimated costs. SELL rules should be mirrored but measured independently. Do not relax filters to force trade count, and do not assume directional symmetry guarantees equal outcomes.

Any score weights, thresholds, and planned reward/risk values are experimental settings only. They must be compared with the existing implementation and evaluated on reproducible data before any code change.

## 4. Risk and execution

Risk controls are independent of scanner score. Before order submission, verify volume sizing and broker limits, margin and trading permissions, spread/costs, symbol/directional/aggregate exposure, duplicate-order rules, tick size, stops level, and freeze level. Reject safely when a mandatory check fails. Never silently widen stops, increase volume, or disable a gate merely to get an order accepted.

## 5. Measurement and controlled adaptation

For each opportunity or trade, make available the timestamp, symbol, direction, regime, scores, setup/profile, entry/SL/TP, planned reward/risk, estimated cost, rejection reason, realized net result, exit reason, and execution costs where feasible.

Evaluate net expectancy after costs, profit factor, win/loss distribution, drawdown, sample size, BUY/SELL, symbol, regime, score bucket, and in-sample versus untouched out-of-sample results. Adaptive profile selection must not be promoted on recent outcomes alone; require predefined sample sizes and out-of-sample confirmation.

## Evaluation protocol

1. Map the existing EA's scanner, regime, entry, risk, and reporting behavior before proposing code changes.
2. Preserve an exact baseline source, inputs, reports, and persistent-state snapshot.
3. Change one variable per experiment.
4. Keep symbol, dates, data model, costs, deposit, leverage, and inputs identical for baseline/candidate comparisons.
5. Reconcile tester summary totals with order/deal history and report BUY and SELL separately.
6. Freeze a candidate before using an untouched out-of-sample period.
7. Compile the exact source in MetaEditor and record compiler/terminal versions and all warnings/errors.
8. Keep demo/runtime checks separate from static analysis and backtest claims.

## Known evidence and limits

Previously reported baseline figures (473 trades, net loss around 278.29, profit factor 0.8017) were not independently recalculated here. They may justify further investigation but do not identify a cause or establish that this proposal will improve results.

## Current repository status

A readable source candidate is proposed for review in PR #9, which remains unmerged and draft. The exact candidate has not been verified by MetaEditor compilation or controlled Strategy Tester. The compiled `.ex5` provenance also remains unverified. No profitability or live-readiness claim is made.
