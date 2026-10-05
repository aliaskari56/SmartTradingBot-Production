# SmartTradingBot — Architecture Ownership & Responsibility Contract
Date: 2026-10-06
Repository: aliaskari56/SmartTradingBot-Production
Branch: main

## Purpose

This document defines the independent responsibility, ownership, inputs, outputs and hard boundaries of every major SmartTradingBot subsystem.

No Section audit, repair or enhancement may violate these boundaries.

The architecture rule is simple:

> A subsystem performs its own defined job, emits a well-defined result, and hands control to the next owner. It must not silently take over another subsystem's responsibilities.

## 1. SYSTEM LAYERS

The production flow is divided into these independent layers:

1. Market Data / Broker Adapters
2. Scanner
3. Strategy / Signal Qualification
4. Candidate / Setup Contract
5. Risk / Safety / Broker Validation
6. Execution
7. Position & Pending Management
8. Trade Transaction / State Synchronization
9. Adaptive Learning
10. Dashboard / UI Controller
11. Diagnostics / Observability
12. Persistence / Recovery

These are separate responsibilities even when implemented in one MQL5 file.

## 2. HARD OWNERSHIP RULE

Every action must have one owner.

Allowed:
- Scanner finds opportunities.
- Strategy qualifies opportunities.
- Risk/Safety validates.
- Execution creates the market/pending order or position.
- Management manages an already-created order/position.
- TradeTransaction synchronizes state.
- Adaptive Learning records permitted historical outcomes.
- UI sends commands and displays state.
- Diagnostics observes and reports.

Forbidden:
- Scanner opening orders.
- Strategy modifying live positions.
- Management scanning symbols for new setups.
- Management creating new entries as a side effect of trailing/protection.
- UI bypassing execution/risk gates.
- Diagnostics becoming an execution engine.
- Adaptive Learning placing trades.
- Persistence changing live trading decisions without an explicit owner contract.

## 3. SCANNER — EXCLUSIVE RESPONSIBILITY

### Scanner owns
- symbol universe construction
- symbol availability checks
- scan scheduling inputs
- market-data retrieval needed to scan
- structural pattern detection
- candidate discovery
- scan scores/metadata
- scan reject reasons
- scan summaries

### Scanner outputs
A candidate/setup request only.

Required conceptual output:
`SetupCandidate` / `Setup` / equivalent contract containing enough information for the next layer.

### Scanner MUST NOT
- call Buy/Sell/BuyStop/SellStop/PositionOpen
- call the execution engine to place an order
- modify SL/TP on an already-open position
- trail positions
- close positions
- own pending-order lifetime
- own account exposure management
- record trade outcomes as learning
- decide how an existing position is managed

### Scanner completion rule

Once a candidate has been emitted/rejected:
**scanner work for that candidate is complete.**

The scanner waits for the next scheduled scan.

## 4. STRATEGY / SIGNAL QUALIFICATION — EXCLUSIVE RESPONSIBILITY

### Strategy owns
- trend qualification
- structure qualification
- CHoCH/BOS/FVG/OB rules
- oscillator qualification
- score calculation
- strategy rule gates
- signal direction
- candidate validity
- strategy-specific reject reason

### Strategy MUST NOT
- send trade requests
- modify live positions
- trail positions
- delete pending orders
- manage account exposure after entry
- consume live trade outcomes except through explicit learning interfaces

Strategy returns a qualified candidate/setup or rejection.

## 5. CANDIDATE / SETUP CONTRACT

The Candidate/Setup object is the handoff contract.

It should carry, as applicable:
- symbol
- direction
- timestamp/decision identity
- entry
- SL
- TP
- RR
- score
- strategy/profile identity
- provenance
- setup validity

The Setup is data, not execution.

No subsystem may treat creation of a Setup as proof that an order was placed.

## 6. RISK / SAFETY / BROKER VALIDATION — EXCLUSIVE RESPONSIBILITY

### Owns
- trade permission checks
- spread checks
- account limits
- exposure limits
- volume/risk sizing
- broker stop/freeze rules
- tick-size alignment
- pending geometry
- SL validity
- OrderCheck/preflight
- final execution authorization

### MUST NOT
- scan the watchlist
- discover new setups
- run strategy detection
- trail already-open positions
- own dashboard layout

Risk says:
AUTHORIZED / REJECTED

It does not itself create the order.

## 7. EXECUTION — EXCLUSIVE RESPONSIBILITY

### Execution owns the act of entry

For a new trade request, Execution:
1. receives an approved candidate/setup/request
2. performs the required final gates
3. submits the order/position
4. inspects request result/retcode
5. verifies terminal state
6. publishes the created ticket/result
7. hands the created order/position to management/state ownership

### Execution includes
- market entry
- pending-order placement
- manual pending placement
- hedge entry
- any other actual creation of a new trading exposure

### Execution MUST NOT
- scan symbols
- discover setups
- manage long-lived trailing state after handoff
- periodically search for new opportunities
- own adaptive learning statistics
- own dashboard geometry

### Critical rule

> Once Execution has successfully created the trading exposure and published the result, its entry task is complete.

After that point, long-lived management belongs to Position/Pending Management.

## 8. POSITION & PENDING MANAGEMENT — EXCLUSIVE RESPONSIBILITY

Management owns already-existing trading objects.

### Position management owns
- initial protection after creation where required by the safety contract
- SL/TP modifications
- trailing
- profit protection
- managed position state
- position lifecycle actions such as protective modification/closure when explicitly designed

### Pending management owns
- pending lifetime
- pending expiration
- pending cancellation when explicitly required by its contract
- pending initial-SL protection
- pending-trail lifecycle
- synchronization of existing pending state

### MANAGEMENT MUST NOT
- scan the watchlist for fresh entries
- call Scanner
- run strategy detection
- create a fresh trade merely because it is managing an existing object
- select new symbols to trade
- own the global opportunity-discovery loop

### Critical rule

> Management starts from an already-existing order/position. It never becomes the Scanner.

## 9. TRADE TRANSACTION / STATE SYNCHRONIZATION

This layer owns event-driven synchronization.

It listens to terminal events and updates state required by the other owners.

It may:
- detect order/deal/position creation
- trigger immediate protection requirements
- synchronize tickets and lifecycle state
- notify Adaptive Learning of eligible lifecycle events
- repair state after terminal events/restart

It must NOT:
- become a second strategy engine
- discover opportunities
- create duplicate entries independently of Execution

## 10. ADAPTIVE LEARNING — EXCLUSIVE RESPONSIBILITY

Adaptive Learning owns:
- profile statistics
- decay
- closed-trade outcomes
- R-multiple aggregation
- persistence
- profile selection parameters where explicitly requested by Strategy
- deduplication of learning outcomes

Adaptive Learning MUST NOT:
- scan symbols
- open trades
- manage live positions
- directly change SL/TP
- bypass Strategy or Risk

Learning may provide parameters to Strategy, but Strategy remains the owner of signal decisions.

## 11. DASHBOARD / UI — CONTROLLER ONLY

UI owns:
- chart objects
- buttons
- layout
- user command capture
- command display
- status display
- observability

UI command flow:

UI event
-> command request
-> appropriate controller/execution service
-> actual result
-> UI result display

UI MUST NOT:
- contain duplicate trading logic
- bypass Risk/Safety
- scan symbols
- manage positions directly
- fabricate success messages

A UI "executed" message must correspond to the actual handler result.

## 12. DIAGNOSTICS / OBSERVABILITY

Diagnostics owns:
- logging
- reason codes
- OrderCheck diagnostics
- pipeline traces
- runtime evidence

Diagnostics MUST be side-effect free unless a specific diagnostic contract explicitly authorizes otherwise.

Diagnostics cannot be the execution owner.

## 13. PERSISTENCE / RECOVERY

Persistence owns:
- GlobalVariables
- restart state
- recovery metadata
- state reconstruction
- dedup persistence

Persistence must not independently initiate new trades.

## 14. EVENT OWNERSHIP

### OnTimer
Scheduling/orchestration only.
It must not create a second independent strategy/execution engine.

### OnTick
Market-event orchestration and calls to the appropriate owners.
It must not duplicate OnTimer decisions.

### OnTradeTransaction
State/lifecycle synchronization and immediate safety hooks.
It must not become a parallel entry engine.

### OnChartEvent
UI event routing only.
It must not contain a second trade strategy.

## 15. FORBIDDEN CROSS-BOUNDARIES

The following are architecture violations:

SCANNER -> EXECUTION
STRATEGY -> EXECUTION_DIRECT
MANAGEMENT -> SCANNER
MANAGEMENT -> NEW_ENTRY
UI -> BYPASS_RISK
DIAGNOSTICS -> EXECUTION
LEARNING -> EXECUTION
PERSISTENCE -> NEW_ENTRY

A call is allowed only if it respects the owner chain.

## 16. APPROVED CONTROL FLOW

### Automatic opportunity flow

Market Data
-> Scanner
-> Strategy
-> Candidate/Setup
-> Risk/Safety
-> Execution
-> Created Order/Position
-> Management
-> TradeTransaction synchronization
-> Adaptive Learning after eligible closed outcome

### Manual entry flow

UI
-> Manual Entry Request
-> Risk/Safety
-> Execution
-> Created Order/Position
-> Management

Manual entry does NOT need to pass through opportunity Scanner discovery.

### Management flow

Existing Position/Order
-> Management
-> Broker modification/action
-> State synchronization

Management does NOT call Scanner.

## 17. CURRENT SOURCE AUDIT TARGET

The current Git source must be checked specifically for this known architectural coupling:

`ScanWatchlist()`
currently calls:
`PlaceSetup()`
which calls:
`ExecuteSetup()`

This means the current implementation combines Scanner orchestration and Execution.

This is a **known architecture finding**, not yet a permission to patch.

Required action:
- record the violation
- map all dependent paths
- design the separation first
- then repair in the dedicated Section where Execution/Scanner ownership is audited
- compile and runtime-test after repair

Do not blindly remove the call; the replacement handoff must be designed first.

## 18. ARCHITECTURE ACCEPTANCE TEST

The architecture is accepted only when these statements are true:

- [ ] Scanner can discover and emit a candidate without creating a trade.
- [ ] Strategy can qualify/reject without creating a trade.
- [ ] Risk/Safety can authorize/reject without creating a trade.
- [ ] Execution alone owns creation of new exposure.
- [ ] Management can manage an existing position/order without invoking Scanner.
- [ ] Management cannot create a new opportunity merely because it is running.
- [ ] UI cannot bypass Risk/Safety.
- [ ] Diagnostics cannot execute trades.
- [ ] Learning cannot execute trades.
- [ ] Persistence cannot execute trades.
- [ ] TradeTransaction does not become a duplicate execution engine.
- [ ] Each handoff has one owner and one result contract.
- [ ] Duplicate execution paths are identified and eliminated.

## 19. ARCHITECTURE CHANGE RULE

Do not refactor this architecture casually.

Before changing a boundary:
1. map current callers/callees
2. identify all side effects
3. define the replacement handoff
4. define ownership of state
5. define failure/rejection behavior
6. define logs/reason codes
7. compile
8. runtime test
9. verify no duplicate path remains

## 20. REQUIRED ORDER OF FUTURE AUDIT

The architecture contract must be accepted BEFORE the detailed Section gates.

Detailed Section work may then proceed with this ownership model as the governing architecture.

Status:
ARCHITECTURE CONTRACT — DEFINED
CURRENT IMPLEMENTATION COMPLIANCE — REQUIRES REPAIR/AUDIT
