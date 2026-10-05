# SmartTradingBot — Complete Audit / Repair / Validation Plan
Date: 2026-10-06
Repository: aliaskari56/SmartTradingBot-Production
Target branch: main

## Scope and non-negotiable rules

Work only on the existing SmartTradingBot Expert and its established repository history. Do not create a parallel Expert, alternate production path, or backup copy as part of the MetaTrader repair work. Do not change healthy behavior for cosmetic cleanup or unnecessary refactoring.

The active MetaTrader target must be identified from MetaEditor/MetaTrader before changes:
`MQL5/Experts/SmartTradingBot.mq5`

Current repository main source was verified as version 1.120 at:
`e20e36fcc8604532e0a277928690d412d71065c4`

## Version gate

First determine the real active source version, size, line count, and presence/absence of:
- InpForensicOrderCheck
- InpStructuralPending
- InpStructuralCancelWhenInvalid

A complete 1.127 source may be inspected only if it already exists in the permitted repository/filesystem history. Do not fabricate or manually relabel 1.120 as 1.127. If a complete 1.127 source is unavailable, continue auditing the active 1.120 source.

## Section-by-section audit order

Do not advance until the current section is fully reviewed, repaired if required, and compiled with 0 errors and 0 warnings.

01. Header, properties, inputs, globals, constants
02. Structs, identity, state containers, IDs
03. Adaptive learning core
04. Persistence, Global Variables, restart recovery
05. Utility, symbol, broker, price, pip and tick helpers
06. Swing detection and closed-bar logic
07. Pending setup, entry, SL, TP and RR
08. H4 trend, structure, FVG, OB and setup construction
09. Signal qualification, strategy and rule gates
10. Exposure, state and position management
11. Hedge, emergency SL and initial SL protection
12. Trailing, pending lifetime and pending state
13. Order validation, OrderCheck and execution
14. Scanner
15. Dashboard and UI
16. OnInit and OnDeinit
17. OnTick and OnTimer
18. OnTradeTransaction
19. OnChartEvent
20. Final integration, runtime and full pipeline

## Per-section acceptance contract

For each section record:
- exact line range
- defects found
- fixes applied
- behavioral impact
- compile result
- errors
- warnings

Only proceed when the section compiles with:
`Result: 0 errors, 0 warnings`

## Safety and execution invariants

The final system must preserve:
1. No order/pending without a valid SL.
2. Valid broker minimum-distance and freeze/stops rules.
3. Tick-size alignment.
4. OrderCheck before applicable order submission.
5. Retcode inspection and post-submit verification.
6. Restart recovery without duplicate execution/state.
7. Adaptive learning restricted to valid closed-trade outcomes with no look-ahead.
8. Outcome deduplication and correct state cleanup.
9. Manual/foreign/hedge separation from learning according to the existing contract.
10. Tick/Timer deduplication for one logical closed-bar decision.
11. UI commands cannot bypass risk/safety gates.
12. BUY/SELL direction correctness.
13. Pending trail does not conflict with execution/state ownership.

## Adaptive learning audit

Verify:
- profile selection and decay
- closed-trade-only learning
- persistence across restart
- decision identity and outcome deduplication
- PnL lifecycle
- manual/foreign/hedge exclusion rules
- absence of future-data reads or look-ahead

## Pending and broker audit

Verify the complete chain:
BuildSetup
-> PreparePendingSetup
-> ValidatePendingSetup
-> broker distance validation
-> tick alignment
-> OrderCheck
-> send
-> retcode
-> verification
-> pending-trail registration

Audit:
- SYMBOL_POINT
- SYMBOL_DIGITS
- SYMBOL_TRADE_TICK_SIZE
- SYMBOL_TRADE_STOPS_LEVEL
- SYMBOL_TRADE_FREEZE_LEVEL
- Bid/Ask
- spread
- entry/SL/TP geometry

## Include audit

Fully review active includes, with priority on:
- STB_OrderCheckDiagnose.mqh
- STB_PendingDistanceResolver.mqh
- STB_PendingTrail.mqh
- every other include actually reached by SmartTradingBot.mq5

OrderCheck diagnostics must not accidentally become an independent execution owner.

## Scanner and ownership

Scanner must produce setup/candidate data rather than bypassing the execution pipeline. Audit:
- swing strength
- displacement bars
- lookback
- minimum score
- symbol scan cadence
- repeated work
- ownership between scanner, strategy and execution

## UI priority audit

Current dashboard commands:
- AUTO
- CANDLE_TIME
- BUY
- SELL
- HEDGE
- SAVE+20
- TRAIL

Audit:
- STB_DashCreate
- CreateButton / CreateButtonCorner
- layout/sync/redraw
- object names and prefix
- OBJ_BUTTON properties
- Z-order
- CHARTEVENT_OBJECT_CLICK
- CHARTEVENT_CHART_CHANGE
- CHARTEVENT_OBJECT_DRAG
- CHARTEVENT_CLICK fallback/hit-testing
- command recognition
- duplicate click prevention
- command result logging

Required event chain:
Mouse click
-> OBJECT_CLICK or HIT_TEST
-> command recognition
-> handler
-> result
-> pipeline/reject reason

Test each command in MetaTrader after successful compilation. For BUY/SELL/HEDGE, validate the full risk/safety/broker path; do not bypass gates merely to demonstrate the UI.

## Runtime audit

After final compile, test on the same MetaTrader Expert:
- initialization
- dashboard creation
- timer
- tick processing
- chart events
- trade transactions
- pending management
- position management
- restart/recovery behavior
- runtime logs and retcodes

## Performance review

Inspect, without changing semantics:
- ScanWatchlist cadence
- CopyRates / CollectSwings frequency
- redundant broker calls
- repeated state lookup
- unnecessary redraw/object operations

Dead code/cosmetic issues should be reported unless they create real functional or safety defects.

## Final build requirements

Final MetaEditor build must be:
`Result: 0 errors, 0 warnings`

Record:
- active source path
- source version
- source size
- line count
- compiler/build
- EX5 path
- EX5 size
- EX5 build timestamp
- runtime/UI test results
- remaining verified issues

## Git history requirement

This plan is intentionally stored on the repository's main branch so the audit/repair process has a durable, dated reference in Git history. Future implementation commits should reference this plan and preserve a traceable sequence of source changes, compile validation, and runtime validation.
