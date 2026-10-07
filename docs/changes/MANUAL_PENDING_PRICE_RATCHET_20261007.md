# Manual Pending Price Ratchet — 2026-10-07

## Scope

This change applies the current-price one-way ratchet to manual BUY_STOP and SELL_STOP pending orders only.

Manual ownership is the existing Magic == 0 ownership class and remains governed by InpManageManualPending.

## Behavior

- BUY_STOP: live Ask/Bid are used every processing cycle.
  - Entry moves downward only.
  - SL moves downward only after initial alignment.
  - Initial creation alignment may tighten SL once to the nearest broker-valid level below Bid.
- SELL_STOP: live Bid/Ask are used every processing cycle.
  - Entry moves upward only.
  - SL moves upward only after initial alignment.
  - Initial creation alignment may tighten SL once to the nearest broker-valid level above Ask.
- No M15 swing/structural anchor is used by the manual path.
- After activation, STB_PendingTrailOnOrderFilled() disables PendingTrail for that ticket.

## Ownership

The existing management owner remains authoritative:

STB_GetOrderOwner() -> STB_OWNER_MANUAL -> InpManageManualPending

EA-owned pending orders retain the existing structural/M15 pending trail.

## Broker safety

The manual resolver uses stops/freeze-aware TradeMinDistance, directional tick alignment, and OrderCheck/server-retcode/read-back confirmation before committing state.

## Evidence used

- Git history: pending persistence/trail handoff is owned by TradeTransaction (c950ff54...).
- Current architecture: ManagePendingOrders() is the pending-management owner.
- Official MQL5 reference confirms OnTradeTransaction() receives manual GUI trade activity and pending activation events, and transaction order is not guaranteed.
- Official MQL5 reference confirms CTrade::OrderModify() requires server retcode validation after the boolean call.
- Official MQL5 reference defines SYMBOL_TRADE_STOPS_LEVEL and SYMBOL_TRADE_FREEZE_LEVEL as trade-distance constraints.

## Validation required before production

1. Compile 0 errors / 0 warnings.
2. Manual BUY_STOP: price down -> Entry and SL down; price up -> Entry and SL do not move up; trigger -> PendingTrail stops.
3. Manual SELL_STOP: exact inverse.
4. Restart with active manual pending orders.
5. Check history/transactions for trigger, cancel, and modify provenance.