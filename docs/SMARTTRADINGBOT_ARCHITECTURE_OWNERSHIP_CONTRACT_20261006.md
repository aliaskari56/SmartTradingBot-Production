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

## 17. CURRENT SOURCE AUDIT TARGET,,The original Scanner -> Execution coupling has been repaired in Git main.,,Current verified flow:,`ScanWatchlist()`,-> candidate array,-> `STB_ProcessExecutionCandidates()`,-> `ExecuteSetup()`,,Additional hidden-boundary repairs now verified:,- Manual Pending UI -> `STB_ExecutionManualPendingCommand()` -> Risk -> Execution,- HEDGE UI -> `STB_ExecutionHedgeCommand()` -> Risk -> `STB_ExecuteMarketHedge()`,- HEDGE creation verifies deal, position ownership/type/volume before reporting creation.,- HEDGE protection failure is represented separately from rejection.,- Pending deletion verifies the ticket is no longer visible after a successful server retcode.,- TradeTransaction explicitly hands a filled pending ticket to PendingTrail.,- TradeTransaction registers new managed pending tickets for PendingTrail.,- Scan scheduling has one owner: OnTimer. OnTick no longer starts a second scan/execution cycle.,,The active MetaTrader source still requires forward-port + compile/runtime validation because its previously reported byte identity differs from Git main.,
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

## 21. HIDDEN-BOUNDARY AUDIT ADDENDUM — 2026-10-06

### RULES APPLIED
- Every new-exposure creation path has one Execution owner.
- UI captures commands only; it does not construct or submit trades.
- Risk/Safety remains the final authorization boundary.
- Existing-object modification remains in Management/Protection.
- TradeTransaction performs lifecycle synchronization/handoff only.
- Scanner scheduling has one event owner.
- Terminal truth is required before an operation is reported as successful.
- Foreign ownership is never inferred from a management input alone.
- No fallback path silently re-enables live auto trading.
- Git changes do not imply active-terminal installation or compilation.

### STATIC PREFLIGHT EVIDENCE
- Direct new-exposure APIs are isolated to `STB_ExecuteMarketHedge()` and `ExecuteSetup()`.
- `OrderSend()` and `PositionOpen()` are absent.
- Scanner, Strategy, Adaptive and UI sections contain no direct new-exposure CTrade call.
- `STB_RunScanCycle()` has one scheduler call: OnTimer.
- Legacy `OneClickHedge` and `STB_ManualPendingCommand` identifiers are gone.
- Management bodies contain no Scanner/Strategy discovery call.
- Raw brace balance is zero.
- Current Git Expert blob: `76d99969a20c5828bb948db41c3d2ecf217edb1b`.
- Current Git Expert: version 1.120, 7,408 lines, 219,385 characters.

### REMAINING NON-BOUNDARY SECTION ITEMS
- BuildSetup function cohesion.
- CHoCH/BOS semantic classification quality.
- UI geometry/dead-code cleanup.
- Documentation/input-comment inconsistencies.
- Compiler/runtime/broker validation.

### TWO-SIDED ACCEPTANCE
PRE-FLIGHT OUR SIDE:
- [x] Hidden boundary scan completed.
- [x] Direct new-exposure creation paths centralized.
- [x] UI manual-entry construction moved under Execution request coordination.
- [x] HEDGE false-result paths hardened.
- [x] Pending deletion post-state confirmation added.
- [x] PendingTrail transaction handoffs added.
- [x] Scan scheduler ownership centralized.
- [x] Active source is NOT claimed installed or compiled.

MT5 EXECUTION:
- [ ] Reconcile active source identity.
- [ ] Forward-port corrections without overwriting active-only changes.
- [ ] MetaEditor compile: 0 errors / 0 warnings.
- [ ] Same SmartTradingBot.ex5 rebuilt and verified.
- [ ] Attach/reload same Expert.
- [ ] Runtime UI HEDGE / BUY STOP / SELL STOP / SAVE20.
- [ ] Pending fill -> PendingTrail stop -> management handoff.
- [ ] Timer-only scan and no duplicate OnTick scan.
- [ ] Truthful UI RESULT logs.

Status:
ARCHITECTURE CONTRACT — DEFINED
GIT HIDDEN-BOUNDARY PREFLIGHT — COMPLETE
ACTIVE MT5 EXECUTION — PENDING

## 22. DEEP HIDDEN-BOUNDARY UPDATE — 2026-10-06

### RULES APPLIED
- Execution creation is isolated from Strategy, Risk, Adaptive, Persistence and Management state mutation.
- Adaptive parameters cross into Risk only as immutable Setup snapshots.
- Execution exposure gating is independent of Management enable switches.
- TradeTransaction is the lifecycle owner after terminal creation events.
- UI routes only to explicit execution/management command handlers.
- Foreign objects cannot populate EA lifecycle state.
- Terminal state verification is required before truthful success.

### CURRENT GIT SOURCE
- SmartTradingBot.mq5 blob: 8fdb5e61f95d6bf5eb59863fb00755d198a02ee4
- Version: 1.120
- Lines: 7,437
- Characters: 221,726
- Raw brace balance: 0

### DEEP BOUNDARY FINDINGS NOW CLOSED
- Risk authorization no longer activates or reads Adaptive state.
- ExecuteSetup no longer writes Adaptive order/profile/risk state.
- ExecuteSetup no longer writes LastSetup persistence.
- ExecuteSetup no longer registers PendingTrail.
- TradeTransaction owns EA order lifecycle persistence and PendingTrail registration.
- Execution one-symbol exposure protection is independent of Management toggles.
- HEDGE creation is isolated in STB_ExecuteMarketHedge and is terminal-verified.
- HEDGE Execution ends at confirmed creation; TradeTransaction owns immediate protection/management handoff.
- UI Save20 is routed through an explicit Management command.
- Scanner execution scheduling is Timer-owned only.
- ORDER_ADD lifecycle state writes are restricted to EA-owned orders.

### ACCEPTANCE
- [x] Git/source hidden-boundary preflight complete.
- [x] Direct new-exposure paths statically isolated.
- [x] Risk/Adaptive boundary isolated.
- [x] Execution/Persistence boundary isolated.
- [x] Execution/Management handoff isolated.
- [x] UI routing audited.
- [x] Execution exposure invariant audited.
- [ ] Active MetaTrader source reconciled.
- [ ] MetaEditor compile 0/0.
- [ ] Same EX5 rebuilt.
- [ ] Runtime validation complete.

Status:
ARCHITECTURE CONTRACT — DEFINED
GIT HIDDEN-BOUNDARY PREFLIGHT — COMPLETE
ACTIVE MT5 EXECUTION — PENDING