# Pending STOP trailing direction remediation — 2026-10-23

## Finding

The previous implementation used LIMIT-style favorable-extreme semantics for STOP orders in three independent places: closed-M5 anchor selection, the pending-distance resolver's aligned-entry check, and the central order writer's monotonic-entry gate. A proposed correction in only one layer could therefore either calculate the wrong direction or be rejected before reaching the broker.

## Direction contract

| Pending type | Anchor | Favorable entry movement |
| --- | --- | --- |
| BUY STOP | closed M5 high | Up |
| SELL STOP | closed M5 low | Down |
| BUY STOP-LIMIT | closed M5 high | Up |
| SELL STOP-LIMIT | closed M5 low | Down |
| BUY LIMIT | live Bid / pullback low | Down |
| SELL LIMIT | live Ask / pullback high | Up |

STOP-kind orders are evaluated once per newly closed M5 candle, not on every tick. Existing tick alignment, current quote boundaries, broker stop/freeze constraints, structural SL validation, the central writer, and retry backoff remain in place. The change does not promise a modification will be accepted by a broker; every modification remains subject to the terminal/server result.

## Code changes

- `STB_PendingTrail.mqh`: correct STOP/STOP-LIMIT anchor side, monotonic extreme detection and committed watermark advancement.
- `STB_PendingDistanceResolver.mqh`: reject non-improving BUY STOP entries that fail to move upward and SELL STOP entries that fail to move downward, after tick alignment.
- `SmartTradingBot_FINAL.mq5`: align the central writer's last monotonic gate with STOP-vs-LIMIT semantics.
- `tools/test_pending_trail_direction.py`: add regression checks for all six pending-order types and the agreement between the trail, resolver and writer.
- `.github/workflows/mql5-static-audit.yml`: run the new regression checks during pushes and pull requests.

## External implementation references

- MetaQuotes MQL5 reference — [Order Properties](https://www.mql5.com/en/docs/constants/tradingconstants/orderproperties), which defines the six pending-order types and their terminal properties.
- MetaQuotes MQL5 reference — [CTrade::OrderModify](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradeordermodify), which confirms that pending-order activation price and protection levels are modifiable, and that a successful client-side method call is not proof of successful server execution.
- MetaQuotes MQL5 Algo Book — [Modifying a pending order](https://www.mql5.com/en/book/automation/experts/experts_modify_order), which describes pending-order modification limits.

These references establish the platform contract; they do not endorse any trading strategy or imply profitability.

## Verification required

GitHub Actions must pass the MetaEditor compile, MQL5 static audit, pending-trailing direction regression, trading-safety defaults, and LRN-04 contract tests. After merge, deployment must update all three modified source files (the EA and both STB include modules) before compiling. Run behavior checks in Strategy Tester or a demo account before considering any real-account use.
