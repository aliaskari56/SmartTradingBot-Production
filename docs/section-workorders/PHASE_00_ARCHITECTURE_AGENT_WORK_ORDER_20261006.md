SMARTTRADINGBOT — AGENT WORK ORDER
TARGET: SmartTradingBot
SECTION: PHASE 00 — Architecture Ownership Verification
RULES APPLIED: 01, 03, 04, 05, 19, 22, 23, 24, 25, 26, 29, 31, 32, 33, 35, 36, 37, 39, 40, 41, 41.1, 41.2, 41.3, 41.4
TARGET PATH: Discover and verify the active MetaTrader/MetaEditor SmartTradingBot.mq5 before inspection.

# GOVERNING CONTRACT

Read and obey:
docs/SMARTTRADINGBOT_ARCHITECTURE_OWNERSHIP_CONTRACT_20261006.md

This is a READ-ONLY architecture verification task.

NO CODE CHANGE IS AUTHORIZED IN PHASE 00.

Do not:
- edit source
- create files in the MT5 Expert path
- create backup
- create alternate Expert
- create alternate EX5
- move code
- rename functions
- refactor

# OBJECTIVE

Verify the real implementation against the ownership architecture before any Section-level repair begins.

# OWNERSHIP TO VERIFY

## Scanner
Must own:
- scan universe
- market-data scan
- candidate discovery
- scan scoring/metadata
- scan rejection/reporting

Must NOT own:
- order creation
- position creation
- trailing
- position management
- pending lifetime

## Strategy / Signal
Must own:
- trend/structure/oscillator qualification
- direction
- setup score
- setup/candidate validity

Must NOT execute trades.

## Candidate / Setup
Must be the handoff data contract.
Creating a Setup is NOT equivalent to placing an order.

## Risk / Safety
Must own:
- trading permissions
- spread
- exposure/limits
- risk sizing
- broker geometry
- SL/TP validity
- OrderCheck
- final authorization

Must NOT scan or independently create new trades.

## Execution
Must be the only owner of NEW exposure creation:
- market entry
- pending placement
- manual pending entry
- hedge entry

After successful creation and verification, execution hands the created ticket/result to management/state ownership and completes its entry task.

## Position / Pending Management
Must manage ONLY already-existing orders/positions:
- protection
- SL/TP modification
- trailing
- profit protection
- pending lifetime
- pending cancellation under explicit contract

Management must NOT call Scanner or discover new opportunities.

## TradeTransaction / State Sync
May synchronize:
- order/deal/position lifecycle
- immediate protection
- state updates
- learning lifecycle events

Must not become a second execution engine.

## Adaptive Learning
May own:
- profile stats
- decay
- historical outcomes
- persistence
- learning dedup

Must not execute or manage live trades.

## UI
Must:
- capture commands
- route requests
- display real results

Must not duplicate trading logic or bypass safety.

## Diagnostics
Must be observational/read-only unless a specific diagnostic contract explicitly allows a side effect.

# CURRENT SOURCE CHECK

Specifically map these functions and call paths:
- ScanWatchlist
- STB_BuildScannerUniverse
- BuildSetup
- PlaceSetup
- ExecuteSetup
- STB_ManualPendingCommand
- ManagePositions
- ManagePendingOrders
- STB_PendingTrailProcess
- OnTick
- OnTimer
- OnTradeTransaction
- OnChartEvent

Known suspected coupling:
ScanWatchlist -> PlaceSetup -> ExecuteSetup

Determine:
1. exact line ranges
2. every caller
3. every callee
4. side effects
5. whether Scanner can directly cause an order
6. whether Management can indirectly trigger new entries
7. whether there are duplicate execution paths
8. whether UI has an independent entry path
9. whether TradeTransaction has an independent entry path

# OUTPUT

Return:

PHASE 00
STATUS: PASS / FAIL / NOT VERIFIED

ACTIVE SOURCE:
VERSION:
PATH:
SIZE:
MTIME:

ARCHITECTURE MAP:
Scanner:
Strategy:
Setup:
Risk/Safety:
Execution:
Position Management:
Pending Management:
TradeTransaction:
Adaptive:
UI:
Diagnostics:
Persistence:

CROSS-BOUNDARY FINDINGS:
1. ...
2. ...

KNOWN COUPLINGS:
1. ...
2. ...

DUPLICATE EXECUTION PATHS:
1. ...
2. ...

RECOMMENDED SEPARATION:
1. ...
2. ...

CHECKLIST:
- [ ] Active source verified
- [ ] Scanner ownership verified
- [ ] Strategy ownership verified
- [ ] Setup handoff verified
- [ ] Risk ownership verified
- [ ] Execution ownership verified
- [ ] Position management ownership verified
- [ ] Pending management ownership verified
- [ ] TradeTransaction ownership verified
- [ ] Adaptive ownership verified
- [ ] UI ownership verified
- [ ] Diagnostics ownership verified
- [ ] All cross-boundary calls mapped
- [ ] Duplicate execution paths mapped
- [ ] No code changed
- [ ] PHASE 00 — COMPLETE ✅

# HARD STOP

Do not modify code.

Do not begin SECTION 01.

Do not begin any repair.

Return only the architecture evidence and findings.

ACCEPTANCE:
Architecture map complete + all cross-boundary calls mapped + no source modification.


# MASTER PREFLIGHT UPDATE — EXACT SOURCE RECONCILIATION REQUIRED

Before any code modification, the Agent MUST reconcile the exact active MetaTrader source with the Git baseline used by the preflight audit.

## SOURCE RECONCILIATION

Report:
- exact active source path
- #property version
- file size in bytes
- line count
- last-write timestamp
- SHA-256 hash if available

If the active file is inside a local Git working tree:
run the equivalent of:
`git hash-object <active SmartTradingBot.mq5>`

Expected Git blob SHA for the audited Git baseline:
`e20e36fcc8604532e0a277928690d412d71065c4`

IMPORTANT:
Do not assume that equal version + equal line count means equal source.

Previously reported:
- active MetaTrader source: 211,466 bytes
- Git-retrieved source: 201,272 bytes
- both report version 1.120 and 6,889 lines

Therefore source identity is NOT yet proven.

If the hashes do not match:
- DO NOT PATCH
- DO NOT RESTORE
- DO NOT COPY
- DO NOT OVERWRITE
- report the mismatch and return the active-file evidence only.

## ARCHITECTURE VERIFICATION

On the exact active source, map:
- Scanner
- Strategy
- Candidate/Setup
- Risk/Safety
- Execution
- Position Management
- Pending Management
- Protection/SL calculation
- TradeTransaction
- Adaptive Learning
- UI
- Diagnostics
- Persistence

Trace at minimum:
- ScanWatchlist
- BuildSetup
- PlaceSetup
- ExecuteSetup
- STB_ManualPendingCommand
- OneClickHedge
- ManagePositions
- ManagePendingOrders
- CalculateNearestStructuralSL
- CalculateHedgeSL
- OnTick
- OnTimer
- OnTradeTransaction
- OnChartEvent

Explicitly verify these known Git findings against the active source:
1. ScanWatchlist -> PlaceSetup -> ExecuteSetup
2. BuildSetup mixes Strategy + Adaptive + broker normalization
3. Management -> CollectSwings through protection calculation
4. HasManagedExposure -> IsManagedPosition ownership coupling
5. InpDiagnosticM15Mode can force auto trading
6. InpSmartZigZagEnabled may be unused
7. UI result reporting accuracy

## PROHIBITIONS

This Phase is read-only.

Do NOT:
- modify SmartTradingBot.mq5
- modify any Include
- create backup
- create duplicate
- create another Expert
- create another EX5
- restore Git
- overwrite the active source
- compile a changed source

Compilation is NOT required because this phase makes no code changes. Record this as:
COMPILE: NOT APPLICABLE — READ-ONLY SOURCE RECONCILIATION

## OUTPUT

Return:

PHASE 00
STATUS: PASS / MISMATCH / NOT VERIFIED

SOURCE IDENTITY
Path:
Version:
Size:
Lines:
Mtime:
SHA-256:
Git hash-object:
Matches baseline: YES / NO / UNKNOWN

ARCHITECTURE MAP
...

CROSS-BOUNDARY VIOLATIONS
...

CHECKLIST
- [ ] Exact active source identified
- [ ] Version verified
- [ ] Size verified
- [ ] Line count verified
- [ ] Hash verified
- [ ] Git baseline comparison completed where possible
- [ ] Scanner boundary verified
- [ ] Strategy boundary verified
- [ ] Setup handoff verified
- [ ] Risk boundary verified
- [ ] Execution ownership verified
- [ ] Management boundary verified
- [ ] Protection boundary verified
- [ ] TradeTransaction boundary verified
- [ ] Learning boundary verified
- [ ] UI boundary verified
- [ ] Diagnostics boundary verified
- [ ] Persistence boundary verified
- [ ] No code changed
- [ ] PHASE 00 — COMPLETE ✅

HARD STOP:
Do not proceed to SECTION 01 or any repair until source identity and architecture map are returned.

ACCEPTANCE:
Exact active-source identity + complete architecture map + zero source changes.
