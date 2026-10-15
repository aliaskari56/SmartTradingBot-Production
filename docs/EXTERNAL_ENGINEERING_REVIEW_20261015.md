# External engineering review — 2026-10-15

## Scope and evidence

This review uses primary vendor documentation rather than aggregating a fixed
number of websites. Fifty secondary pages would not substitute for validating
the actual EA against the compiler, Strategy Tester, and broker constraints.

Primary references consulted:

- MQL5 trade permission checks: https://www.mql5.com/en/docs/runtime/tradepermission
- MQL5 OrderSend result semantics: https://www.mql5.com/en/docs/trading/ordersend
- MQL5 OrderCheck request validation: https://www.mql5.com/en/docs/trading/ordercheck
- MetaTrader 5 Strategy Tester: https://www.metatrader5.com/en/terminal/help/algotrading/testing
- MQL5 program compilation requirements: https://www.mql5.com/en/docs/runtime

## Change made in this branch

Added a CI regression guard requiring both `InpAutoTrading` and
`InpUseRiskSizing` to remain disabled by default. Users can explicitly opt in
through EA inputs after reviewing their own configuration. This avoids silently
turning on live order placement or risk-based sizing as a side effect of merging
unverified changes.

## Required validation before any behavior-changing merge

1. Compile `SmartTradingBot_FINAL.mq5` in MetaEditor; record compiler version,
   errors, and warnings.
2. Run deterministic Strategy Tester baselines and compare trade counts,
   order lifecycle, SL/TP behavior, drawdown, and logs.
3. Verify every trade request checks `OrderCheck` where applicable and checks
   `MqlTradeResult.retcode`; a successful `OrderSend` boolean alone is not
   proof of execution.
4. Verify terminal, EA, and account trading permissions are checked before
   requests are submitted.
5. Test pending-order price/volume/stops against symbol tick size, volume step,
   stops level, freeze level, and broker-specific execution behavior.
6. Verify source-to-EX5 provenance and test on demo before any live use.

## Limits

This branch adds automated regression protection only. It does not change the
trading strategy, claim profitability, or replace compilation and Strategy
Tester evidence. No live-trading enablement change is included.

## Separate review blocker: PR #8

PR #8 (`test/backtest-integrity-diagnostics-audit`, head
`0a37d1983488f942fc85d165742c6f2babf80cec`) is still a draft targeting
`audit/expose-cleaned-source-20261009`, not `main`, and GitHub currently reports
it as not mergeable. Its changes are outside this guard-only PR and have not
been approved by these CI checks.

The currently visible PR #8 patch includes behavior changes that need their
own explicit review and tests:

1. `InpAutoTrading` changes from `false` to `true`; this would remove the
   existing opt-in safeguard if promoted to a release source.
2. `InpUseRiskSizing` changes from `false` to `true`; this changes sizing
   behavior for users who rely on fixed lots, so resulting volume/risk must be
   checked rather than assuming the change is equivalent.
3. The Strategy Tester AUTO expression changes from logical AND to logical OR
   between `InpAutoTrading` and `InpTesterForceAutoTrading`. With the tester
   force input enabled, the EA's internal AUTO state can turn on even when the
   other input is false. That override is tester-scoped in the source, but it
   must be validated separately from live-terminal gating.
4. Automatic M5 candle-follow trailing is allowed to continue for BUY STOP and
   SELL STOP orders even when the manual-override marker is set. The intended
   ownership semantics need a clear acceptance test; LIMIT and STOP-LIMIT
   orders are intended to retain the prior override pause.
5. STOP-order trailing changes from live quote extremes to completed M5-candle
   OHLC data. Test restart/recovery, unavailable or stale M5 history, bar
   processing exactly once, one-way geometry, and broker stops/freeze levels.
6. Scanner cadence is changed to allow interval-based runs without a new chart
   M15 bar. Validate duplicate-candidate suppression, load, and symbol history
   availability in the Strategy Tester.

The two successful workflows on PR #14 validate only its test/documentation
branch against its own base. They do not compile or certify PR #8, and they
must not be cited as evidence that PR #8 is ready to merge.

Before PR #8 is considered for merge: retarget/reconcile the branch cleanly,
compile the exact candidate and includes in MetaEditor, run deterministic
baseline/candidate comparisons with identical inputs and market data, exercise
the manual-override and M5 trailing cases above, and verify source-to-EX5
provenance. Keep PR #8 in Draft until these checks and independent review are
recorded.

