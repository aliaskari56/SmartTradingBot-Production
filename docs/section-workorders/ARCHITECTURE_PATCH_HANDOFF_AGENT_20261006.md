SMARTTRADINGBOT — METAEDITOR / METATRADER AGENT WORK ORDER
TARGET: SmartTradingBot
SECTION: ARCHITECTURE PATCH HANDOFF — 2026-10-06
RULES APPLIED: 01, 03, 04, 05, 06, 08, 09, 10, 11, 14, 15, 19, 20, 21, 22, 23, 24, 25, 26, 29, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 41.1, 41.2, 41.3, 41.4, 31A, 32A, 33A
TARGET PATH: discover the existing ACTIVE SmartTradingBot.mq5 from MetaEditor/MetaTrader first.

# GOVERNING DOCUMENTS

Read first:
- docs/SMARTTRADINGBOT_AUDIT_PLAN_20261006.md
- docs/SMARTTRADINGBOT_AGENT_EXECUTION_RULES_20261006.md
- docs/SMARTTRADINGBOT_ARCHITECTURE_OWNERSHIP_CONTRACT_20261006.md
- docs/preflight/SMARTTRADINGBOT_MASTER_PREFLIGHT_AUDIT_20261006.md

# OBJECTIVE

Apply the prepared architecture corrections to the SAME active SmartTradingBot Expert.

Do not blindly replace the active file with the Git file.

The Git implementation is a reference/prepared correction set. The active MetaTrader source may contain active-source-only UI or other work.

# ACTIVE SOURCE RECONCILIATION — MANDATORY FIRST

Report:
- exact active source path
- version
- bytes
- lines
- mtime
- SHA-256 if available
- git hash-object if available

Previously reported active source:
- version 1.120
- 211,466 bytes
- 6,889 lines

Current Git-prepared source:
- version 1.120
- 201,257 bytes
- 6,884 lines
- blob: 7520e31944ade35bfb09757c581da8805fbe2081

If active source differs:
DO NOT overwrite it wholesale.

Instead:
- inspect the active-source-only differences
- forward-port the logical architecture corrections below
- preserve valid active-source-only functionality
- do not delete newer functionality merely because it is absent from Git main

# PREPARED ARCHITECTURE CORRECTIONS

## A. OWNERSHIP

Positions and pending orders now have explicit owner classes:
- EA-owned
- manual-owned
- foreign-owned

Rules:
- EA-owned is managed only when InpManageEAPositions / InpManageEAPending permits it.
- manual-owned is managed only when InpManageManualPositions / InpManageManualPending permits it.
- foreign-owned is never treated as managed.

Do not restore the old ownership-agnostic IsManagedPosition behavior.

## B. DIAGNOSTIC SAFETY

Diagnostic mode MUST NOT force live auto trading ON.

Preserve:
- InpAutoTrading as the live trading authorization
- Diagnostic mode only as analysis/telemetry behavior

Do not reintroduce:
g_autoTrading=true merely because InpDiagnosticM15Mode is true.

## C. SMART ZIGZAG INPUT

Ensure InpSmartZigZagEnabled is actually connected to the ACSS ZigZag configuration/presentation path.

Do not leave it as a dead input.

## D. PROTECTION BOUNDARY

Structural/fallback SL calculation is a protection service:
- STB_ProtectionCalculateNearestStructuralSL
- STB_ProtectionCalculateFallbackSL
- STB_ProtectionCalculateInitialSL

Position Management may call this protection service for an EXISTING position.

Position Management must NOT:
- scan the watchlist
- discover opportunities
- build new entries
- call Scanner

## E. SCANNER BOUNDARY

Scanner:
- builds symbol universe
- reads market data required for scanning
- builds strategy candidates
- returns Setup candidates

Scanner MUST NOT:
- call ExecuteSetup
- call BuyStop/SellStop
- call trade.Buy/BuyStop/Sell/SellStop
- create/modify/delete trading exposure
- manage open positions
- own pending lifetime

The expected form is:
ScanWatchlist(Setup candidates[])
-> returns candidate data
-> execution is deferred

## F. EXECUTION COORDINATOR

Candidate selection belongs after scanning.

The coordinator:
STB_ProcessExecutionCandidates()

may:
- evaluate candidate choices
- check exposure
- select the candidate for each symbol
- call Risk/Safety authorization
- hand the approved candidate to ExecuteSetup

This coordinator is NOT part of Scanner.

## G. STRATEGY BOUNDARY

BuildSetup/strategy logic must produce a candidate/setup.

The following are NOT strategy ownership:
- live execution authorization
- spread gate
- direction-specific broker trade permissions
- setup cooldown
- exposure check
- OrderCheck
- actual order submission

These belong to Risk/Safety/Execution.

## H. RISK/SAFETY AUTHORIZATION

The prepared source introduces:
STB_RiskAuthorizePending()

It owns:
- live trading authorization
- direction tradability
- spread
- exposure
- trade environment
- account order limit
- broker normalization
- pending geometry validation
- setup cooldown
- volume/risk sizing
- volume limit
- pending lifetime
- OrderCheck

It returns AUTHORIZED / REJECTED.

It does not create the order.

## I. EXECUTION

ExecuteSetup() owns only the final new-order creation path after Risk authorization:
- CTrade request construction
- BuyStop/SellStop
- request-return handling
- server retcode check
- execution handoff metadata/logging

It must not discover candidates or scan symbols.

## J. RETCODE OBSERVABILITY

Preserve detailed logs for:
- request failure
- server rejection
- retcode
- retcode description
- symbol
- side
- order ticket where available

Never replace detailed broker diagnostics with a generic failure message.

# ACTIVE-SOURCE MERGE RULE

If the active source contains a more recent UI/event layer or other behavior not present in Git:
- preserve it
- apply the same ownership architecture around it
- do not remove it blindly
- do not duplicate another UI/event layer

# COMPILE / INSTALL / RUNTIME

After applying the logical corrections to the SAME active source:

1. Compile in MetaEditor.
2. Require:
Result: 0 errors, 0 warnings
3. Rebuild the SAME SmartTradingBot.ex5.
4. Reload/re-attach the SAME SmartTradingBot Expert.
5. Run runtime checks relevant to this architecture:
   - initialization
   - scan cycle
   - candidate logging
   - execution coordinator
   - pending creation path
   - management loop on existing positions/orders
   - OnTradeTransaction
   - UI command routing
6. Confirm Scanner produces candidates without direct execution.
7. Confirm Execution owns actual new pending creation.
8. Confirm Management does not invoke Scanner.

# EVIDENCE

Return:

SOURCE IDENTITY
Path:
Version:
Size:
Lines:
Mtime:
SHA/hash:
Active-vs-Git match:

ARCHITECTURE TEST
Scanner -> Candidate:
Candidate -> Risk:
Risk -> Execution:
Execution -> Created Order:
Created Order -> Management:
Management -> Scanner: MUST BE NO

COMPILE
Result:
Errors:
Warnings:
Elapsed:

EX5
Path:
Size:
Build time:

RUNTIME
Scan:
Risk:
Execution:
Management:
TradeTransaction:
UI:

CHECKLIST
- [ ] Active source verified
- [ ] Active/Git differences mapped
- [ ] Ownership model applied
- [ ] Diagnostic auto-enable removed
- [ ] SmartZigZag input wired
- [ ] Protection boundary preserved
- [ ] Scanner direct execution removed
- [ ] Execution coordinator active
- [ ] Strategy/risk boundary applied
- [ ] Risk authorization active
- [ ] Execution-only order creation verified
- [ ] Management does not scan
- [ ] Retcode diagnostics preserved
- [ ] MetaEditor compile executed
- [ ] 0 errors
- [ ] 0 warnings
- [ ] EX5 rebuilt
- [ ] Same Expert reloaded
- [ ] Runtime evidence collected
- [ ] ARCHITECTURE PATCH HANDOFF — COMPLETE ✅

# HARD STOP CONDITIONS

Stop and report without overwriting the active source if:
- active source identity cannot be established
- active source contains materially newer logic that makes the prepared patch ambiguous
- applying the patch would delete valid active functionality
- MetaEditor compile fails
- any architectural boundary remains ambiguous

ACCEPTANCE:
Same active Expert + architecture boundaries enforced + 0 errors + 0 warnings + runtime evidence.
