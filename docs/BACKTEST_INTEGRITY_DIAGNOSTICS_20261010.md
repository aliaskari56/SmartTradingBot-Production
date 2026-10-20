# Backtest Integrity Diagnostics — 2026-10-10

## Purpose

This change adds observability before a controlled Strategy Tester run. It does not attempt to improve profitability or increase trade count. It must not disable scanner filters, auto-trading checks, exposure limits, order validation, SL/TP validation, or risk controls.

## Source change

- `InpAutoTrading` remains `false` by default, so this diagnostics branch does not enable live automatic trading on installation.
- In Strategy Tester only, `InpTesterForceAutoTrading=true` forces the EA's internal AUTO gate on (`InpAutoTrading || InpTesterForceAutoTrading`). This is a tester-only override for reproducibility; it does not change the live default. Confirm the exact `.set` inputs and tester behavior before using any test result.
- This does **not** override MetaTrader terminal/program/account trade permissions, broker/tester order rules, or any strategy/risk validation. Those permissions must be enabled in the test environment, and their effective values are logged at startup.
- `InpTesterChartSymbolOnly` remains `true` by default; the tester is intentionally restricted to the chart symbol unless the test explicitly changes that universe. This is not a signal filter, but it does limit symbol coverage.
- Removed an unintended account-wide scanner gate: any open position or pending order anywhere on the account previously prevented the scanner from running. The scanner now runs on its normal M15 signal-bar schedule even when other symbols have exposure; same-symbol managed exposure and the account order limit are still enforced at candidate execution.

Source file: `MQL5/Experts/SmartTradingBot_FINAL.mq5`

Expected source behavior remains unchanged:
- Failed aggregate market-quality score still rejects the candidate; its reason is now `REJECT_QUALITY_SCORE` rather than the misleading `REJECT_SPREAD`.
- Final revalidation failure emits `STB CANDIDATE REJECT` with symbol, direction, reason, rank, and opportunity score.
- Final execution-gate failure emits a reason distinguishing `AUTO_TRADING_OFF`, `TRADE_ENVIRONMENT_REJECT`, `MANAGED_EXPOSURE_EXISTS`, and `ACCOUNT_ORDER_LIMIT`.
- Failed symbol selection emits a diagnostic rather than silently skipping the candidate.
- Startup `STB TRADE ENV` reports `accountTrade=` separately from `accountExpert=`.

The new logs are diagnostic only. They can increase log volume and slightly affect tester runtime, but they should not change candidate selection or order behavior. A compile and deterministic comparison are required to confirm that expectation.

## Required pre-backtest checks

1. Check out this branch and verify the source blob from Git matches the file compiled in MetaEditor.
2. Compile the exact source and all repository includes in MetaEditor. Save the full compiler log; target 0 errors and investigate every warning.
3. Do not use the tracked EX5 as a trusted artifact: its provenance is not established. Compile to an isolated output path and record source SHA-256, EX5 SHA-256, MetaEditor build, terminal build, and inputs hash.
4. Run one short diagnostic smoke test first. Confirm startup reports effective inputs, including `auto`, `autoInput`, `testerForceAuto`, `testerSymbolOnly`, `accountExpert`, and `accountTrade`.
5. Check that rejected candidates have a specific reason. Confirm no rejection reason has changed into acceptance and that no risk/execution control was bypassed.
6. Run the frozen baseline and candidate build on identical symbol(s), date range, tick model, spread/cost settings, initial deposit, leverage, and inputs. Compare deal history and report metrics. The only intended difference is additional diagnostics and corrected rejection labels.
7. If trade count, orders, entries, exits, or P/L differ between builds beyond logging, stop and investigate before accepting the patch.
8. Only after this equivalence check, run the full historical test with documented tick model, historical data coverage, commission, swap, spread, and slippage assumptions. Preserve the report and input file.
9. Keep a separate untouched out-of-sample window. Do not optimize parameters against that window.

## Required log checks

- `STB INIT`: effective strategy inputs and auto state.
- `STB TRADE ENV`: terminal, program, account-expert, account-trade, and tester state.
- `STB SCANNER SUMMARY`: scanner funnel counts and confidence.
- `STB CANDIDATE REJECT stage=FINAL_REVALIDATION`: refreshed candidate rejection.
- `STB CANDIDATE REJECT stage=FINAL_AUTO_GATE`: final gate rejection.
- Existing `STB PLACE REJECT`, `STB ORDERCHECK REJECT`, server-retcode, and successful pending-order logs: execution result.

## Acceptance criteria

- Exact source compiles with 0 errors; warnings are reviewed and dispositioned.
- No strategy or risk gate was disabled.
- Diagnostic smoke test shows the expected reason for each deliberately induced final gate.
- Same-input baseline-vs-diagnostic comparison produces the same trade/order decisions and same financial results, apart from timing/log differences that are fully explained.
- Report totals reconcile to order/deal history and include trading costs.
- Source-to-EX5 provenance is recorded.

## Historical status and integration checkpoint — 2026-10-15

The original audit status above reflects the October 10 checkpoint; it is not a statement about later CI runs.

The corresponding source bytes (`MQL5/Experts/SmartTradingBot_FINAL.mq5`, blob `a5cab7fa950571626c8261e14d40890189aa34e5`) passed the repository's Windows MetaEditor workflow on October 15: **0 errors, 0 warnings**, MetaEditor `5.0.0.6266`, run [38801737418](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/38801737418). The workflow uploaded a fresh EX5, compiler log, and provenance manifest as artifact `metaeditor-build-ebb9f0bbc9cd70ccbae40efd1b07d10ff4a92941`. The live AUTO and risk-sizing defaults remain `false`.

This document remains a test plan, not evidence of a completed MT5 Strategy Tester or broker-equivalence run. Do not treat the EA as runtime-validated until deterministic baseline/candidate comparison and M5/manual-override tests are recorded.


## Follow-up scanner correction — 2026-10-20

A targeted source review on the development branch identified two scanner-integrity gaps and corrected them without changing the strategy weights or disabling any existing filter:

- Quote integrity is now checked by the same validator in both symbol eligibility and market-quality scoring. It rejects non-finite/non-positive Bid/Ask, crossed quotes, missing timestamps, quotes more than two seconds into the future relative to the server-time estimate, unavailable clock, and quotes older than the configured maximum age. A sub-two-second timestamp skew is treated as age zero; materially future-dated quotes are not silently clamped to fresh.
- ATR and derived market-quality metrics are checked for finite, valid values before they influence a score.
- Scanner confidence now compares the top candidate against the runner-up in the fully revalidated and reranked watchlist before the execution list is truncated to InpScannerTopN. With InpScannerTopN=1, a second valid candidate can no longer be hidden to bypass InpScannerMinTopGap. A single surviving candidate still uses the existing score-floor policy.

The source change is on `fix/structure-first-fvg-trailing-20261020` only; `main` is not modified. The source commit `ea67c43b92cb5b9c65ee7d170de7795561f37672` passed MetaEditor compile with **0 errors, 0 warnings** ([run 39455177457](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457)), passed the static source/invariant audit ([run 39455177088](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177088)), and passed the trading-safety-default guard ([run 39455177310](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177310)). Provenance and the fresh EX5 are archived in [artifact 12280695788](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457/artifacts/12280695788); the build is not deployed to the active terminal.

No scanner strategy weights were changed. Functional scanner cases SCN-01–SCN-08 and the baseline-equivalence Strategy Tester gate remain **NOT RUN** until real execution evidence is recorded.


## Follow-up strategy correction — M15 break event freshness

The source-level M15 structure detector now requires a fresh closed-bar crossing of the selected confirmed swing: BUY requires the older close at or below the swing high and the current close above it; SELL requires the older close at or above the swing low and the current close below it. Scan bounds also reserve the immediately older closed bar.

Reason: merely remaining above/below a broken swing could previously be mistaken for a newly formed structure break, refreshing setup age and allowing late/duplicate setups to be rebuilt from the same level. The targeted correction does not change H4 alignment, FVG/OB gates, score weights or risk controls.

Validation requirements: STR-07 through STR-09 in the acceptance matrix. STR-09 remains an open strategy-definition issue because current source does not independently require a separate CHoCH event followed by a distinct BOS event. No profitability conclusion is implied.
