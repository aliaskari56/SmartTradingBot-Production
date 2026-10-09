# Pass 18 — Event lifecycle, cycle ownership, and reconciliation trace (2026-10-09)

## Status

**DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN**

Repository branch: `audit/expose-cleaned-source-20261009`  
Primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
Source Git blob SHA observed before this pass: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`  
The source was inspected in event-handler and lifecycle ranges. This is a static trace only: no source code changed; no MetaEditor build, Strategy Tester, terminal runtime, broker/demo test, or independent review was performed.

## Event and lifecycle map

| Event / function | Observed source behavior | Risk / evidence still needed |
|---|---|---|
| `OnInit()` (around lines 7900–8100) | Configures synchronous `CTrade`, selects chart symbol, logs terminal/program/account permissions, creates dashboard buttons, starts timer, scans once, rebuilds pending-trail state, reconciles trade registry, then immediately calls the central management cycle. | Confirm exact initialization ordering under real terminal state; test missing history/quotes, trade-disabled states, restart with open positions and pending orders, and partial initialization failures. |
| `STB_RunManagementCycle()` (around line 8200) | Calls `STB_BeginCycle()`, `ManagePositions()`, `ManagePendingOrders()`, and `STB_PendingTrailProcess()` in that order. Comment states this is the only management decision path. | Static call path does not prove every write is reachable only through this cycle; verify all mutation call sites and per-cycle dedup invariants. |
| `OnTick()` | Runs central management first; when `NewM15Bar()` is true, reconciles registry, scans, executes top candidate, records bar time and updates panel. | Tick cadence may differ from timer cadence; repeated same-bar/near-simultaneous events need idempotence testing. |
| `OnTimer()` | Runs central management, reconciles registry, checks M15 bar, scans/executes when new, then updates panel/buttons. | Management cycle and reconciliation can run near a tick-driven cycle; test duplicate scanner/order attempts and state races. |
| `OnTradeTransaction()` (around lines 8290–8500) | Calls `STB_TradeIntakeFromTransaction(trans)` before deal-specific filtering. Then handles selected deal-add events, filters by magic, cleans per-ticket protection state on close-type entries, records adaptive profile/risk on eligible entries, accumulates partial-close PnL, checks whether the position remains open, and records final lifecycle outcomes. | Transaction arrival order is not guaranteed by platform documentation; verify duplicate/out-of-order events, partial closes, reversals, position identifier vs ticket mapping, and restart between events. Do not infer event-order safety from this handler's linear source order. |
| `OnChartEvent()` (around lines 8520–8665) | Dispatches button clicks to manual pending, manual limit, hedge, save/profit-protection and pending-trail commands; AUTO toggles persisted state and clears manual overrides only when explicitly enabled. | Test repeated clicks, rejected trade requests, stale chart objects, and interactions with timer/tick cycles. Button label/status changes must reflect server-confirmed state rather than only request acceptance. |
| `OnDeinit()` (around lines 8040–8100) | Kills timer, releases all symbol-management leases, removes chart objects/visuals, releases indicator handles. | Test recompile, chart close, timeframe/symbol change, terminal shutdown, and two charts managing the same symbol; verify lease cleanup and no orphaned state. |
| `OnTester()` | Reads tester statistics, writes a CSV under terminal-wide Common Files, logs metrics, and returns `STB_AdaptiveTesterCriterion()`. | File-write success and criterion semantics need tester validation; metrics output alone is not evidence of profitable or robust performance. |

Line anchors are approximate and should be rechecked against the same source blob before code changes.

## Concrete lifecycle observations

1. **Central management order is explicit:** positions → pending orders → pending-trail processor. This is a documented call order, not proof that interactions are race-free.
2. **Initialization performs active management:** after pending-trail rebuild and trade-registry reconciliation, `OnInit()` calls `STB_RunManagementCycle()` immediately. Test startup with stale leases, invalid quotes, open unprotected positions, and orders requiring rollback.
3. **Two event sources can initiate management:** both `OnTick()` and `OnTimer()` invoke the same cycle. The per-cycle dedup scope is reset at each `STB_BeginCycle()`; it therefore should not be assumed to deduplicate across two separate cycles close together.
4. **Reconciliation is not uniformly placed:** `OnTick()` calls registry reconciliation only on a new M15 bar, while `OnTimer()` calls it after the management cycle on every timer event. The ordering means the timer-triggered management cycle runs before that timer's reconciliation.
5. **Trade intake is front-loaded:** transaction intake is called before checking transaction type/deal validity in the remainder of `OnTradeTransaction()`. Validate that the intake routine is safe for all transaction types and repeated callbacks.
6. **Adaptive close accounting is event-driven:** the handler accumulates partial-close PnL and waits for the position identifier to no longer be open before final recording, with a separate reversal (`DEAL_ENTRY_INOUT`) path. These branches require tester evidence for partial close, close-by, reversal, duplicate notification and netting/hedging account modes.
7. **Chart commands are direct dispatches:** the handler calls the command-specific functions rather than visibly queuing requests through a single event scheduler. The downstream trade gates and cross-event dedup must therefore be verified.

## Focused acceptance tests

| ID | Scenario | Acceptance evidence |
|---|---|---|
| EVT-01 | Attach/restart with open positions and each supported pending type | Registry and pending-trail state rebuilt before the first management write; no duplicate or unauthorized mutation. |
| EVT-02 | Same M15 bar receives many ticks and timer callbacks | At most the documented number of scanner/order attempts; no duplicate setup due to event overlap. |
| EVT-03 | Timer cycle starts while a tick cycle has just run | Lease/dedup contract is explicit; no conflicting or duplicate write. |
| EVT-04 | Trade transaction callbacks arrive in a different order or repeat | Intake and accounting remain idempotent; no duplicate lifecycle learning/cleanup. |
| EVT-05 | Partial close followed by final close | Accumulated net PnL and risk multiple match deal history, including swap, commission and fees. |
| EVT-06 | Reversal / `DEAL_ENTRY_INOUT` | Old lifecycle is closed exactly once and the new lifecycle is mapped correctly. |
| EVT-07 | HEDGE deal with the same magic | Protection cleanup occurs as intended, while strategy-profile learning is excluded. |
| EVT-08 | Disable trading permissions or reject an order from a chart button | UI status and logs distinguish request rejection from server-confirmed success. |
| EVT-09 | Deinit/reinit or two charts share a symbol | Timer and leases are released/reacquired safely; no stale ownership blocks or permits writes. |
| EVT-10 | Tester metrics CSV cannot be opened | Failure is surfaced; test result does not silently imply a complete evidence bundle. |

## Platform contract

MetaTrader 5 documents that trade transactions can be delivered in stages, their arrival order is not guaranteed, and account state can change while `OnTradeTransaction()` is processing. The relevant platform reference is the official MQL5 event-handler documentation: https://www.mql5.com/en/docs/event_handlers/ontradetransaction. This platform behavior makes EVT-04 a required runtime test; it does not, by itself, prove a defect in this EA.

## Findings / next decisions

- **EVT-F01 — cross-event idempotence:** unresolved until EVT-02/03 tests show how per-cycle dedup behaves across adjacent tick/timer cycles.
- **EVT-F02 — transaction intake idempotence:** unresolved until the implementation of `STB_TradeIntakeFromTransaction()` is tested against duplicate and reordered callbacks.
- **EVT-F03 — timer reconciliation ordering:** static ordering observed; decide whether reconciliation-before-management is required, then test before changing source.
- **EVT-F04 — adaptive lifecycle accounting:** multiple branches are present; partial close, reversal, netting and hedging results remain unverified.
- **EVT-F05 — deinit/reinit ownership recovery:** release/rebuild calls are present, but actual multi-chart and restart behavior is not proven.

No source remediation was applied in this pass. These observations should be turned into runtime tests and acceptance evidence before release decisions.

## Overall status

**DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN**

The event-handler trace increases source-level coverage only. It does not establish successful compilation, safe order execution, correct accounting under all broker event sequences, or trading profitability.
