# Backtest Integrity Diagnostics — 2026-10-10

## Purpose

This change adds observability before a controlled Strategy Tester run. It does not attempt to improve profitability or increase trade count. It must not disable scanner filters, auto-trading checks, exposure limits, order validation, SL/TP validation, or risk controls.

## Source change

- `InpAutoTrading` now defaults to `true`.
- In Strategy Tester, `InpTesterForceAutoTrading=true` now explicitly forces the EA's internal AUTO gate on (`InpAutoTrading || InpTesterForceAutoTrading`). This fixes the previous AND condition, which incorrectly left AUTO off when a `.set` file had `InpAutoTrading=false`.
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

## Status

This is a test plan, not a test result. The source edit is committed to a separate review branch. The account-wide scanner-gate fix passed the repository's GitHub Actions static-guardrail workflow (run 38064897055). No MetaEditor compile, terminal run, or Strategy Tester run was available in this environment. Do not treat the branch as a compiled or backtest-approved release.
