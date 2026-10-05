# SmartTradingBot — Deep Hidden-Boundary Audit Agent Work Order
Date: 2026-10-06
Repository: aliaskari56/SmartTradingBot-Production
Branch: main

## TARGET
Existing production Expert only:
C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87\MQL5\Experts\SmartTradingBot.mq5

MetaEditor:
C:\Program Files\Orbex Global MT5\MetaEditor64.exe

## OBJECTIVE
Forward-port and validate the prepared deep hidden-boundary corrections onto the exact active SmartTradingBot source. Do not create another Expert, do not create a parallel production path, and do not overwrite the active source blindly.

## RULES APPLIED
- Existing production Expert only.
- Read before write; minimal behavioral diff.
- One owner per action.
- Scanner never creates exposure.
- Strategy never executes.
- Risk/Safety authorizes; it does not create.
- Execution alone creates new exposure.
- Management owns existing positions/orders only.
- TradeTransaction owns lifecycle synchronization and immediate safety handoff.
- Adaptive Learning does not directly authorize live execution.
- UI is controller/observability only.
- Persistence never initiates a trade.
- Diagnostics never executes.
- Foreign ownership is never inferred from management-enable flags.
- Terminal truth is required before truthful success.
- Diagnostic mode must never silently enable live auto trading.
- Compile target is 0 errors / 0 warnings.
- Runtime evidence is mandatory.
- No destructive cleanup or new production path.

## OUR-SIDE PREFLIGHT BASE
Current prepared Expert blob: 8fdb5e61f95d6bf5eb59863fb00755d198a02ee4
Version: 1.120
Git source size: 221,726 characters
Git source lines: 7,437
Raw brace balance: 0

Prepared deep-pass commits:
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

## HIDDEN-BOUNDARY REPAIRS TO FORWARD-PORT
1. Scanner -> Candidate -> Execution:
   ScanWatchlist -> candidate array -> STB_ProcessExecutionCandidates -> ExecuteSetup.
2. Adaptive -> Risk boundary:
   BuildSetup snapshots pendingMaxBars, entryBufferPips, slBufferPips and minimumRR into Setup.
   STB_RiskAuthorizePending must not reactivate/read Adaptive state.
3. Adaptive -> Execution boundary:
   ExecuteSetup must not write Adaptive order/profile/risk state.
   TradeTransaction ORDER_ADD owns EA-order Adaptive persistence.
4. Persistence -> Execution boundary:
   ExecuteSetup must not write LastSetup state.
   Immutable setup time is carried in order metadata and restored by TradeTransaction.
5. PendingTrail lifecycle:
   TradeTransaction registers managed pending orders and stops PendingTrail when a pending order produces a deal.
6. Execution exposure invariant:
   STB_HasExecutionExposure is independent of all management-enable flags and enforces one-setup-per-symbol ownership for EA/manual objects.
7. HEDGE:
   UI -> STB_ExecutionHedgeCommand -> Risk/Safety -> STB_ExecuteMarketHedge.
   EXECUTED is reported only after deal and terminal position ownership/type/volume are confirmed.
   Long-lived protection is handled by TradeTransaction, not the Execution command.
8. Manual pending:
   UI -> STB_ExecutionManualPendingCommand -> Risk/Safety -> ExecuteSetup.
9. SAVE20:
   UI -> STB_ManagementSavePlus20Command for existing positions only.
10. Scan scheduler:
   Only OnTimer calls STB_RunScanCycle; OnTick does not launch a second scan/execution cycle.
11. Pending delete:
   Successful delete retcode is followed by terminal post-state verification.
12. Diagnostic safety:
   InpDiagnosticM15Mode must never force g_autoTrading on.
13. Ownership:
   ORDER_ADD Adaptive/persistence updates are allowed only for EA-owned orders; foreign/manual comments cannot enter EA Adaptive state.

## STATIC ACCEPTANCE REQUIRED
- [ ] No OrderSend or PositionOpen.
- [ ] Direct new-entry CTrade APIs only in ExecuteSetup and STB_ExecuteMarketHedge.
- [ ] No direct entry API in Scanner, Strategy, Risk, UI or Adaptive.
- [ ] STB_RiskAuthorizePending has no STB_AP_* or STB_Effective* calls.
- [ ] ExecuteSetup has no Adaptive state writes/read and no SetLastSetupTime.
- [ ] ExecuteSetup does not register PendingTrail.
- [ ] STB_HasExecutionExposure does not read management-enable flags.
- [ ] Exactly one STB_RunScanCycle scheduler call exists and it is OnTimer.
- [ ] OnChartEvent has no direct CTrade API.
- [ ] TradeTransaction owns PendingTrail registration, fill handoff, order lifecycle persistence.
- [ ] PendingTrail remains modification-only.
- [ ] Brace/structure scan is balanced.

## ACTIVE SOURCE RECONCILIATION
Before editing:
1. Read the exact active file.
2. Record version, size, line count, mtime and content hash.
3. Compare against the prepared Git source.
4. Identify active-only changes.
5. Forward-port the corrections without blind replacement.

Previously reported active state was 1.120 / 211,466 bytes / 6,889 lines; re-measure before use.

## METAEDITOR GATE
- Open the SAME SmartTradingBot.mq5 in the SAME MetaEditor.
- Compile.
- Require 0 errors / 0 warnings.
- Rebuild the SAME SmartTradingBot.ex5.
- Record EX5 path, timestamp, size and hash.
- Reload the SAME Expert on the SAME active chart.
- Any compiler error/warning is a hard stop until corrected.

## RUNTIME TESTS
- AUTO OFF + Diagnostic ON: no automatic new exposure.
- Automatic scan: candidate discovery and single Timer-owned scan path.
- Manual BUY STOP and SELL STOP: UI result equals terminal state.
- HEDGE: EXECUTED only after confirmed new position.
- SAVE20: result count equals confirmed SL modifications.
- Pending ORDER_ADD -> protection -> PendingTrail registration.
- Pending new extreme -> validated modify -> terminal read-back confirmation.
- Pending fill -> PendingTrail stopped -> management owns resulting position.
- Restart rebuilds state from terminal truth.
- Foreign positions/orders are untouched.
- Management disabled does not bypass the execution exposure lock.

## OFFICIAL MQL5 REFERENCES USED
- OnTradeTransaction: transaction order is not guaranteed and terminal state can change while the handler runs.
- CTrade: ResultRetcode, ResultOrder and ResultDeal are required result data for verifying trade requests.

## HARD STOPS
- Active-source identity ambiguous.
- Forward-port would overwrite unknown active-only work.
- Any compile error or warning.
- Any second new-exposure path.
- UI bypasses Risk/Safety.
- Foreign ownership modified.
- Protection becomes optional.
- Success logged without terminal evidence.
- Adaptive directly authorizes execution.
- Execution begins owning long-lived management.
- New Expert or parallel production path appears.

## FINAL ACCEPTANCE
PRE-FLIGHT OUR SIDE:
- [x] Deep hidden-boundary audit completed.
- [x] Risk/Adaptive/Execution boundary repaired.
- [x] Persistence/Execution boundary repaired.
- [x] Execution exposure invariant separated from Management flags.
- [x] UI command routing audited.
- [x] Timer-only scan scheduling verified.
- [x] Git source structurally balanced.
- [x] Active MT5 source NOT claimed installed or compiled.

MT5 EXECUTION AGENT:
- [ ] Active source reconciled.
- [ ] Corrections forward-ported.
- [ ] Compile 0/0.
- [ ] Same EX5 rebuilt and verified.
- [ ] Same Expert reloaded.
- [ ] Runtime tests passed.
- [ ] Logs/evidence returned.

Status: DEEP HIDDEN-BOUNDARY PREFLIGHT — COMPLETE; ACTIVE MT5 EXECUTION — PENDING