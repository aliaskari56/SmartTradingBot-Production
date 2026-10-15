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
