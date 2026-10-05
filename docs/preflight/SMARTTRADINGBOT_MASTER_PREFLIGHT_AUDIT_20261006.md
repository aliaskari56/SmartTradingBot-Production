# SmartTradingBot — Master Preflight Audit
Date: 2026-10-06
Repository: aliaskari56/SmartTradingBot-Production
Branch: main
Current Git baseline: MQL5/Experts/SmartTradingBot.mq5 @ e20e36fcc8604532e0a277928690d412d71065c4

## Scope

This is the OUR-SIDE preflight audit performed before any code change is handed to the MetaTrader Agent.

The current Git source was read across the full 6,889-line Expert in bounded ranges, with function maps, call-path analysis, input/reference analysis, include inspection, Git-history comparison and official MQL5 reference checks.

No SmartTradingBot source code was changed during this audit.

## Source identity reconciliation

Git source:
- Version: 1.120
- Git blob: e20e36fcc8604532e0a277928690d412d71065c4
- Git-retrieved UTF-8 size: 201,272 bytes
- Lines: 6,889

Previously reported active MetaTrader source:
- Version: 1.120
- Size: 211,466 bytes
- Lines: 6,889
- Active path:
  C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87\MQL5\Experts\SmartTradingBot.mq5

Important:
The line count and version match, but the reported active byte size does not match the Git-retrieved source size. Therefore the active source has NOT yet been proven byte-identical to the Git source. This must be reconciled by the MetaTrader Agent before any patch is applied.

The historical report also mentions active-source UI changes that are not present in the Git main source (for example the robust UI helper layer). Treat the active MetaTrader file as authoritative for runtime repair only after exact source identity is established.

## Official MQL5 semantics consulted

The following official MQL5 references were used for the preflight:
- Event handling / OnInit, OnDeinit, OnTick, OnTimer, OnTradeTransaction, OnChartEvent
- CTrade BuyStop/SellStop request/result semantics
- Trade transaction ordering and state changes

Key constraints confirmed:
- Timer events are generated after EventSetTimer and should normally be stopped with EventKillTimer during deinitialization. 
- NewTick events are generated for the EA chart symbol and terminal event handling is sequential; additional NewTick events can be skipped while one is already queued/processing.
- OnTradeTransaction notifications can arrive in multiple transaction stages and their arrival priority is not guaranteed, so state code must not assume a fixed transaction order.
- CTrade BuyStop/SellStop returning true does not alone prove successful server execution; retcode/result verification is required.
- OnChartEvent is the correct event entry point for graphical object clicks.

## Major architecture findings

### F-01 — Scanner directly enters Execution
Current path:
ScanWatchlist -> PlaceSetup -> ExecuteSetup

Severity: HIGH
Status: VERIFIED IN GIT SOURCE
Violation: Scanner owns an execution side effect.

Required design:
Scanner emits candidate/setup data only.
A separate execution coordinator receives the candidate after strategy/risk/safety acceptance.

Do not delete the call blindly. First map state, side effects, logging, profile selection, last-setup persistence and pending-trail handoff.

### F-02 — BuildSetup is a composite of multiple owners
BuildSetup currently performs:
- Strategy qualification
- Adaptive profile selection
- H4 trend analysis
- M15 structure analysis
- FVG/OB detection
- oscillator qualification
- scoring
- adaptive floor rejection
- pending entry/SL/TP construction
- broker normalization through PreparePendingSetup

Severity: HIGH
Violation:
A single function crosses Scanner/Strategy/Learning/Setup/Broker boundaries.

Required design:
Separate:
Scanner discovery -> Strategy qualification -> Setup contract -> Risk/Broker preparation.

### F-03 — Management performs structural market scanning
ManagePositions -> CalculateNearestStructuralSL -> CollectSwings

Also:
OneClickHedge -> CalculateHedgeSL -> CollectSwings

Severity: HIGH for the requested architecture
Violation:
Management/protection code directly performs structural analysis.

Required design:
Create a dedicated protection/SL-calculation service boundary (inside the same Expert if file-creation restrictions remain) and make Management consume the result rather than run opportunity-analysis logic.

### F-04 — Management controls entry exposure through management ownership
ExecuteSetup -> HasManagedExposure -> IsManagedPosition

IsManagedPosition is ownership-agnostic and returns true whenever either:
InpManageManualPositions OR InpManageEAPositions
is enabled.

Severity: HIGH
Problems:
- Manual and EA position management switches are not independent.
- Foreign positions can be treated as managed.
- Management configuration can indirectly block new entries.
- Execution depends on a management-layer predicate.

Required design:
Separate execution exposure eligibility from position-management ownership.

### F-05 — Position management ownership is internally inconsistent
IsManagedPosition ignores magic/comment/source ownership.
IsManagedOrder applies explicit ownership rules:
- EA pending: magic == InpMagic
- manual pending: magic == 0

Severity: HIGH
Result:
An external position may be modified/trailing-managed while an external pending order with non-zero foreign magic is not managed.

Required design:
Define explicit ownership classes:
EA-owned / manual-owned / foreign-owned
and apply them consistently.

### F-06 — Diagnostic mode overrides trading configuration
OnInit:
if(InpDiagnosticM15Mode)
{
    g_autoTrading=true;
    GlobalVariableSet(g_autoStateName,1.0);
}

BuildSetup also uses InpDiagnosticM15Mode to override:
- oscillator hard filter
- strict FVG/OB filter
- universal/H4 alignment

Severity: HIGH safety/configuration finding
Problem:
InpAutoTrading defaults false, yet DiagnosticM15Mode defaults true and forces auto trading ON.

Required design:
Separate diagnostic instrumentation from execution authorization.
A diagnostic flag must never silently force live trading ON.

### F-07 — Unused Smart ZigZag enable input
InpSmartZigZagEnabled is declared but has no reference in the Expert source.

Severity: MEDIUM
Problem:
The user-facing enable input does not control the downstream ACSS configuration.
ACSS_Config exposes ZZ parameters but no corresponding enabled boolean was found in the inspected config.

Required design:
Either wire the input to the actual owner or remove it only if the intended contract explicitly says ZZ is always on.

### F-08 — UI reports success without guaranteed operation result
The current Git main OnChartEvent calls:
- Manual BUY/SELL request
- OneClickHedge
- ManualSavePlus20

but does not itself report the returned boolean for HEDGE/SAVE20.

The supplied runtime report separately confirms a message pattern:
STB UI RESULT command=HEDGE executed.
even when no hedge position was opened.

Severity: MEDIUM/HIGH observability defect
Required design:
UI result must be derived from the actual operation result and, where applicable, a verified terminal state.

### F-09 — Scanner cadence is duplicated across Timer and M15-bar Tick path
OnTimer calls ScanWatchlist on every timer cycle.
OnTick calls ScanWatchlist again whenever a new M15 bar is detected.

Severity: MEDIUM
Problem:
Same opportunity discovery can be computed twice around a bar boundary.

This is separate from duplicate execution protection. Even if order dedup prevents double placement, scanner work itself is duplicated.

Required design:
Centralize scan scheduling/decision identity while allowing the management loop to remain independent.

### F-10 — Management and pending lifecycle read Adaptive profile state directly
ManagePendingOrders parses profile ID from order comment and then activates the Adaptive profile to determine max pending bars.

Severity: MEDIUM architecture finding
Required design:
Execution should stamp immutable lifecycle parameters into the order contract; Management should manage the resulting order without becoming dependent on the learning engine.

## Static quality findings

### F-11 — Documentation mismatch
InpUiMarginX default is 62 while its comment says 10..20.

Severity: LOW
No behavior change made.

### F-12 — Dead/placeholder UI geometry code
STB_DashComputeGeometry contains an exploratory nested block and later resets maxW=0 before calculating the actual geometry.

Severity: LOW/MEDIUM maintainability
No code change made during preflight.

### F-13 — Empty event blocks
OnTick contains empty if(chartBar){} blocks.

Severity: LOW
No code change made.

### F-14 — ChOCH/BOS semantic separation is incomplete
DetectStructure returns a breakout pivot and assigns chochShift/bosShift values, but no explicit classification state proving CHoCH vs BOS was established in the inspected implementation.

Severity: MEDIUM
Required: verify intended semantics against strategy contract before changing.

## Safety / execution positives

Verified in code:
- pending setup uses SL/TP values
- broker minimum distance uses stops/freeze level plus a one-point margin
- price normalization uses symbol tick size
- OrderCheck exists before pending submission
- CTrade pending result/retcode is checked
- position SL modification validates broker distance and verifies terminal SL after modification
- pending trail uses OrderModify and checks server result
- active position initial-SL protection exists
- restart pending-trail rebuild exists
- adaptive state is account/magic scoped

Official MQL5 behavior supports the need for explicit trade result/transaction verification.

## Adaptive findings

Positive:
- adaptive stats are persisted with account/magic/profile context
- decay uses TimeCurrent against stored outcome time
- profile learning records closed-trade outcomes
- magic filter prevents foreign-trade lifecycle entry into the learner
- hedge comments are excluded from adaptive outcome processing
- profile state is associated with orders/positions

Still requiring focused verification:
- exact outcome dedup across unusual transaction sequences/restarts
- lifecycle behavior for partial close + final close + INOUT
- stale GlobalVariable cleanup
- whether every rejected setup should or should not be recorded
- learning/strategy ownership boundary

## Include findings

### STB_OrderCheckDiagnose.mqh
- Read-only diagnostics
- Does not own OrderSend/OrderModify
- Delegates final gate to CheckPendingOrder
- Current execution path invokes forensic probes before the actual gate

Concern:
Each actual placement invokes replay + positive + negative OrderCheck probes. This is observability-heavy and should be measured/controlled rather than assumed harmless in live operation.

### STB_PendingDistanceResolver.mqh
- Read-only pending geometry service
- Uses broker limits and tick alignment
- No execution call found

### STB_PendingTrail.mqh
- Owns existing pending trailing modifications
- Uses OrderModify only
- No order creation call found

### AC_SmartStructure.mqh
- No trade execution APIs found
- Analysis/visualization owner appears clean at the execution boundary

## Architecture state

Architecture contract:
DEFINED

Current implementation compliance:
NOT PASS

Primary required architectural repairs:
1. Scanner -> Candidate only
2. Strategy -> Candidate qualification only
3. Risk/Safety -> authorization only
4. Execution -> new exposure creation only
5. Management -> existing position/order lifecycle only
6. Protection/SL calculation -> dedicated service boundary
7. TradeTransaction -> synchronization only
8. Learning -> historical outcome/profile state only
9. UI -> command controller/observability only
10. Diagnostics -> observation only

## Master Section checklist

- [ ] SECTION 01 — Header / Inputs / Globals
- [ ] SECTION 02 — Structs / Identity / State
- [ ] SECTION 03 — Adaptive Learning
- [ ] SECTION 04 — Persistence / Restart
- [ ] SECTION 05 — Utility / Broker Helpers
- [ ] SECTION 06 — Swing / Closed-Bar
- [ ] SECTION 07 — Pending Setup / SL / TP / RR
- [ ] SECTION 08 — Trend / Structure / FVG / OB
- [ ] SECTION 09 — Signal / Strategy / Gates
- [ ] SECTION 10 — Exposure / Position State
- [ ] SECTION 11 — Hedge / Emergency SL
- [ ] SECTION 12 — Trailing / Pending Lifetime
- [ ] SECTION 13 — OrderCheck / Execution
- [ ] SECTION 14 — Scanner
- [ ] SECTION 15 — Dashboard / UI
- [ ] SECTION 16 — OnInit / OnDeinit
- [ ] SECTION 17 — OnTick / OnTimer
- [ ] SECTION 18 — OnTradeTransaction
- [ ] SECTION 19 — OnChartEvent
- [ ] SECTION 20 — Final Integration / Runtime

## Preflight conclusion

The Expert is not yet ready for a code-change handoff.

The correct next step is NOT to patch one isolated Section blindly.

First:
1. reconcile the exact active MetaTrader source against the Git baseline,
2. finalize the ownership map,
3. design the scanner/strategy/setup/risk/execution/management handoffs,
4. then perform Section-level repairs under the established architecture,
5. compile and runtime-validate through the MetaTrader Agent,
6. feed every runtime defect back into this same audit loop.

Status:
PREFLIGHT AUDIT — FINDINGS COMPLETE FOR CURRENT GIT BASELINE
ACTIVE-SOURCE RECONCILIATION — PENDING
CODE CHANGES — NONE


## Implementation checkpoint — architecture corrections prepared in Git main

The following source-level architecture corrections have now been prepared and committed in the existing `MQL5/Experts/SmartTradingBot.mq5` on `main`:

1. Explicit position/order ownership classification:
   - EA-owned
   - manual-owned
   - foreign-owned
   Foreign positions/orders are no longer treated as managed merely because one management input is enabled.

2. Diagnostic mode no longer silently forces `g_autoTrading=true`.
   Diagnostic mode is treated as analysis/telemetry behavior; live trading remains governed by the trading input/state.

3. `InpSmartZigZagEnabled` is wired to the ACSS ZigZag presentation/configuration path instead of being a dead input.

4. Protection SL calculation is explicitly named as a `STB_Protection*` service boundary.
   Position Management remains the caller/owner of existing-position management, not the owner of market-opportunity scanning.

5. Scanner/Execution separation:
   - `ScanWatchlist(Setup &candidates[])` discovers and returns candidates only.
   - `STB_ProcessExecutionCandidates()` performs candidate selection/handoff.
   - `ExecuteSetup()` owns actual new pending-order creation.
   - The legacy `PlaceSetup()` wrapper was removed.

6. Strategy/Risk boundary:
   - direction tradability
   - spread filter
   - setup cooldown
   were removed from `BuildSetup()` as execution gates.
   They are now enforced by `STB_RiskAuthorizePending()`.

7. Execution boundary:
   `ExecuteSetup()` receives a candidate, calls the Risk/Safety authorization contract, then owns only request construction, submission, retcode verification and execution handoff.

8. Execution rejection diagnostics were preserved after the architecture refactor, including broker retcode and description.

### Git implementation sequence

- `9c4576a2a748f96ae8382e82f001b4f780191c35`
  `ARCH: define ownership boundaries and protect diagnostic mode`
- `e32fcc6e8ca14fe7f3d6a80b8035a4747952a1dd`
  `ARCH: isolate scanner candidates from execution ownership`
- `d95b8edc1f067e90963f7358113ef141944a9d21`
  `ARCH: isolate strategy from risk and execution gates`
- `1162c491f1eb87b5e8598e06f60a98e2780c640b`
  `ARCH: preserve execution retcode diagnostics after separation`

Current Git source blob:
`7520e31944ade35bfb09757c581da8805fbe2081`

### Current preflight status

Static architecture checks on the Git source now report:
- Scanner direct execution leak: NOT FOUND
- `PlaceSetup`: NOT FOUND
- explicit Risk authorization function: PRESENT
- explicit Execution function: PRESENT
- explicit ownership model: PRESENT
- diagnostic auto-enable: NOT FOUND
- SmartZigZag enable wiring: PRESENT
- Protection service boundary: PRESENT
- Management watchlist scanning: NOT FOUND in the Management function body

### Important limitation

These are Git/source-level corrections only.

No fresh MetaEditor compile has been performed in this environment.

The active MetaTrader file previously reported:
- version 1.120
- 211,466 bytes
- 6,889 lines

The Git source after the corrections reports:
- version 1.120
- 201,257 bytes
- 6,884 lines

Therefore the active MetaTrader source MUST NOT be blindly overwritten.

The MetaTrader Agent must first inspect the active file and forward-port the prepared architecture corrections onto the actual active source while preserving any active-source-only work.



---

## Hidden-boundary deep audit checkpoint — 2026-10-06

### RULES APPLIED
- One owner per action.
- Scanner discovery only.
- Strategy qualification only.
- Risk/Safety authorization only.
- Execution is the sole creator of new exposure.
- Management owns existing objects only.
- TradeTransaction owns lifecycle synchronization and immediate safety handoff.
- Adaptive Learning does not directly authorize or create trades.
- UI only dispatches commands and displays verified results.
- Persistence does not initiate trades.
- Foreign ownership is never inferred from management-enable flags.
- Terminal state must support every success result.
- No diagnostic mode may silently enable live auto trading.
- Active MetaTrader source must never be blindly overwritten.

### Prepared hidden-boundary corrections now in Git main
Latest prepared SmartTradingBot source:
- Blob: 8fdb5e61f95d6bf5eb59863fb00755d198a02ee4
- Version: 1.120
- Lines: 7,437
- Characters: 221,726
- Raw brace balance: 0

Deep-pass commits:
- 095610badcb4f3b7545e7436fe48d437b235cdbb
- 42c989a44ab65008964bb4040ca256e37e30a165
- 86195cb43b1b805c76c484130afb17d904ccbbd4
- 1ee0e71c1a7f64917fb58abebad2fa1278021fd8
- 013b6fb7f379a13c968045fbf0981d4185bd727b
- c950ff54f5ea3c9c7800cc291e11bfe4d7f73804
- 2606a28eaf8b28e58daef3749ad7e4382489096f
- dbed352e6c8b1e67c4a97573688fe5d8d49659d1
- e21f3ff8de0b169ed2a8866e10c45ad780c08c77
- c343f52abdcb0db755d29ff5894e8468cf4d5653

### Hidden boundaries now statically repaired
1. Automatic path: ScanWatchlist -> candidates -> STB_ProcessExecutionCandidates -> ExecuteSetup.
2. Adaptive -> Risk: BuildSetup snapshots pendingMaxBars, entryBufferPips, slBufferPips and minimumRR into Setup; STB_RiskAuthorizePending no longer activates or reads Adaptive state.
3. Adaptive -> Execution: ExecuteSetup no longer writes Adaptive order/profile/risk state; TradeTransaction ORDER_ADD owns EA-order Adaptive persistence.
4. Persistence -> Execution: ExecuteSetup no longer writes SetLastSetupTime; setup time is carried in lifecycle metadata and restored by TradeTransaction.
5. PendingTrail lifecycle: registration and fill handoff are owned by TradeTransaction/recovery.
6. Execution exposure: STB_HasExecutionExposure enforces one-setup-per-symbol without depending on management-enable flags.
7. HEDGE: UI -> Execution command -> centralized Risk/Safety -> STB_ExecuteMarketHedge; deal and terminal position evidence are required before EXECUTED.
8. Manual Pending: UI -> Execution request coordinator -> Risk/Safety -> ExecuteSetup.
9. SAVE20: UI routes to STB_ManagementSavePlus20Command; no new-entry API exists in this path.
10. Scheduler: STB_RunScanCycle has one scheduler call, OnTimer; OnTick does not launch a second scan/execution decision.
11. Pending delete: successful delete retcode is followed by terminal post-state verification.
12. ORDER_ADD ownership: Adaptive/persistence state writes occur only for EA-owned orders.

### Static acceptance evidence
- Direct new-entry CTrade calls: only STB_ExecuteMarketHedge and ExecuteSetup.
- OrderSend and PositionOpen absent.
- No direct CTrade entry calls in Scanner/Strategy/Risk/UI/Adaptive.
- Risk authorization has no STB_AP_* or STB_Effective* call.
- ExecuteSetup has no Adaptive state mutation, SetLastSetupTime, or PendingTrail registration.
- Exactly one STB_RunScanCycle call remains, in OnTimer.
- OnChartEvent has no direct CTrade call.
- Management bodies contain no Scanner/Strategy discovery calls.
- Legacy identifiers OneClickHedge, STB_ManualPendingCommand, ManualSavePlus20 and HasManagedExposure are absent.
- Raw brace balance: 0.

### Important limitation
These are Git/source preflight changes only.
No MetaEditor compile, EX5 rebuild, attachment/reload, or runtime validation has been performed by this environment.
Previously reported active source was version 1.120 / 211,466 bytes / 6,889 lines.
The active file must be re-measured and forward-ported by the MetaTrader Agent.
Git main must not be used as a blind replacement.

### Agent work order
docs/section-workorders/DEEP_HIDDEN_BOUNDARY_AUDIT_AGENT_WORK_ORDER_20261006.md
Agent must reconcile active source identity, forward-port all prepared corrections, compile 0 errors / 0 warnings, rebuild the same SmartTradingBot.ex5, reload the same Expert, execute runtime tests and return logs/evidence.

Status:
GIT DEEP HIDDEN-BOUNDARY PREFLIGHT — COMPLETE
ACTIVE MT5 EXECUTION — PENDING