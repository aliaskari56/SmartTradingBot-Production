#!/usr/bin/env python3
"""Static guardrail checks for SmartTradingBot_FINAL.mq5.

This is intentionally not a compiler, Strategy Tester, or release approval.
Run: python tools/audit_static_checks.py MQL5/Experts/SmartTradingBot_FINAL.mq5
"""
from __future__ import annotations
import pathlib
import re
import sys

PAIRS = {")": "(", "]": "[", "}": "{"}


def lexical_errors(source: str) -> list[str]:
    state = "code"
    stack: list[tuple[str, int]] = []
    errors: list[str] = []
    line = 1
    i = 0
    while i < len(source):
        c = source[i]
        n = source[i + 1] if i + 1 < len(source) else ""
        if c == "\n":
            line += 1
            if state == "line_comment":
                state = "code"
            i += 1
            continue
        if state == "line_comment":
            i += 1
            continue
        if state == "block_comment":
            if c == "*" and n == "/":
                state = "code"
                i += 2
            else:
                i += 1
            continue
        if state in ("string", "char"):
            if c == "\\":
                i += 2
                continue
            if (state == "string" and c == '"') or (state == "char" and c == "'"):
                state = "code"
            i += 1
            continue
        if c == "/" and n == "/":
            state = "line_comment"
            i += 2
            continue
        if c == "/" and n == "*":
            state = "block_comment"
            i += 2
            continue
        if c == '"':
            state = "string"
            i += 1
            continue
        if c == "'":
            state = "char"
            i += 1
            continue
        if c in "([{":
            stack.append((c, line))
        elif c in ")]}":
            opening = PAIRS[c]
            if not stack or stack[-1][0] != opening:
                errors.append(f"unmatched {c!r} at line {line}")
            else:
                stack.pop()
        i += 1
    errors.extend(f"unclosed {ch!r} from line {ln}" for ch, ln in stack[-10:])
    if state in ("block_comment", "string", "char"):
        errors.append(f"unterminated lexical state: {state}")
    return errors


def source_region(source: str, start: str, end: str) -> str:
    begin = source.find(start)
    if begin < 0:
        return ""
    finish = source.find(end, begin + len(start))
    if finish <= begin:
        return ""
    return source[begin:finish]


def include_dependency_errors(source_path: pathlib.Path) -> list[str]:
    """Recursively verify every quoted/angle-bracket include is present."""
    include_root = pathlib.Path("MQL5/Include").resolve()
    pending = [source_path.resolve()]
    seen: set[pathlib.Path] = set()
    errors: list[str] = []
    pattern = re.compile(r'^\s*#include\s*([<"])([^>"]+)[>"]', re.MULTILINE)

    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        try:
            content = current.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errors.append(f"{current}: unable to read include: {exc}")
            continue
        for match in pattern.finditer(content):
            delimiter, raw_path = match.groups()
            relative = pathlib.Path(raw_path.replace("\\", "/"))
            candidate = (current.parent / relative) if delimiter == '"' else (include_root / relative)
            candidate = candidate.resolve()
            if not candidate.is_file():
                errors.append(f"{current}: missing include {raw_path}")
            elif candidate not in seen:
                pending.append(candidate)
    return errors


def candidate_producers_safe(source: str) -> bool:
    """Ensure automatic candidate producers cannot write around the resolver."""
    regions = (
        ("bool EnsureInitialSL(", "void STB_RecordPendingInitialSLFailure(", True),
        ("bool ApplyProfitLock(", "void AutoProfitProtection(", True),
        ("bool TrailPositionByLivePrice(", "void ManagePositions(", True),
        ("void STB_ProfitProtectionOne(", "bool ModifyPositionSL(", False),
    )
    for start, end, needs_submit in regions:
        body = source_region(source, start, end)
        if not body or "ModifyPositionSL(" in body:
            return False
        if needs_submit and "STB_SubmitPositionSL(" not in body:
            return False
    return True


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                        "MQL5/Experts/SmartTradingBot_FINAL.mq5")
    if not path.is_file():
        print(f"FAIL: source file not found: {path}")
        return 2
    source = path.read_text(encoding="utf-8")
    trail_path = pathlib.Path("MQL5/Include/STB/STB_PendingTrail.mqh")
    resolver_path = pathlib.Path("MQL5/Include/STB/STB_PendingDistanceResolver.mqh")
    resolver_source = (resolver_path.read_text(encoding="utf-8")
                       if resolver_path.is_file() else "")
    trail_source = (trail_path.read_text(encoding="utf-8")
                    if trail_path.is_file() else "")
    on_init = source_region(source, "int OnInit()", "// DEINIT")
    on_tick = source_region(source, "void OnTick()", "// TIMER")
    on_timer = source_region(source, "void OnTimer()", "// CHART EVENTS")
    detect_structure = source_region(
        source, "bool DetectStructure(", "// FVG / DISPLACEMENT ENGINE")
    quote_validator = source_region(
        source, "bool STB_ScannerQuoteValid(", "bool STB_ScannerDataEligible(")
    scanner_data = source_region(
        source, "bool STB_ScannerDataEligible(", "bool STB_ScannerDirectionAllowed(")
    scanner_session = source_region(
        source, "bool STB_ScannerSessionOpen(", "// Reject invalid market quotes")
    market_quality = source_region(
        source, "bool STB_CalcMarketQuality(", "bool STB_EvaluateRegime(")
    scanner_run = source_region(
        source, "void STB_ScannerRun()", "void STB_DashDeleteAll()")
    final_revalidation = source_region(
        source, "bool STB_FinalCandidateRevalidation(",
        "// Serialize final scanner revalidation/submission")
    execute_top_candidate = source_region(
        source, "void STB_ExecuteTopCandidate()", "// MANUAL PENDING COMMANDS")
    place_setup = source_region(
        source, "bool PlaceSetup(", "// MANUAL PENDING COMMANDS")
    on_trade_transaction = source_region(
        source, "void OnTradeTransaction(", "if(entryType==DEAL_ENTRY_IN && positionId>0)")
    on_trade_transaction_full = source_region(
        source, "void OnTradeTransaction(", "void STB_ToggleDashboard()")
    trade_intake = source_region(
        source, "void STB_TradeIntakeFromTransaction(", "// EXPOSURE MANAGEMENT")
    management_cycle = source_region(
        source, "void STB_RunManagementCycle()", "void OnTick()")
    reconcile_registry = source_region(
        source, "void STB_ReconcileTradeRegistry()", "void STB_ManagePositionImmediately")
    collect_swings = source_region(
        source, "int CollectSwings(", "// H4 TREND")
    indicator_cache = source_region(
        source, "bool EnsureIndicatorHandles(", "// SWING ENGINE")
    diagnostic_reject = source_region(
        source, "void STB_LogBuildReject(", "void STB_LogSetupReady(")
    diagnostic_ready = source_region(
        source, "void STB_LogSetupReady(", "//+------------------------------------------------------------------+")
    initial_pending_sl = source_region(
        source, "bool CalculateInitialPendingProtectionSL(",
        "bool VerifyPendingInitialSL(")
    adaptive_be = source_region(
        source, "bool STB_AdaptiveBreakEvenProtection(",
        "// The next stage upgrades break-even")
    adaptive_lock = source_region(
        source, "bool STB_AdaptiveProfitLockProtection(",
        "// ATR trailing complements confirmed swing trailing")
    adaptive_trail = source_region(
        source, "bool STB_AdaptiveATRTrail(",
        "bool TrailPositionByLivePrice(")
    position_manager = source_region(
        source, "void ManagePositions()", "// PENDING ORDER MANAGEMENT")
    position_sl_resolver = source_region(
        source, "bool STB_ResolvePositionSL(",
        "bool STB_SubmitPositionSL(")
    checks: list[tuple[str, bool]] = [
        ("live automatic trading remains opt-in by default",
         "input bool    InpAutoTrading            = false;" in source),
        ("scanner session gate falls back to a valid clock and includes previous-weekday overnight sessions",
         bool(scanner_session) and
         "datetime serverNow=TimeTradeServer();" in scanner_session and
         "serverNow=TimeCurrent();" in scanner_session and
         "if(serverNow<=0)" in scanner_session and
         "for(int dayOffset=0;dayOffset<=1;dayOffset++)" in scanner_session and
         "(dt.day_of_week-dayOffset+7)%7" in scanner_session and
         "dayOffset==1 && nowSec<=toSec" in scanner_session and
         "if(!TimeToStruct(from,fd) || !TimeToStruct(to,td))" in scanner_session),
        ("scanner requests M15/H4 history before rejecting newly selected unsynchronized symbols",
         "Do not block the history request on the symbol-wide synchronization flag." in source and
         "return copied>=count;" in source and
         "MqlRates warmM15[];" in scanner_data and
         "MqlRates warmH4[];" in scanner_data and
         "GetRates(symbol,PERIOD_M15,needM15,warmM15)" in scanner_data and
         "GetRates(symbol,PERIOD_H4,needH4,warmH4)" in scanner_data and
         scanner_data.index("GetRates(symbol,PERIOD_M15,needM15,warmM15)") <
         scanner_data.index("MqlTick tick;")),
        ("bounded equity-risk sizing is enabled by default while live AUTO remains off",
         "input bool    InpUseRiskSizing         = true;" in source and
         "input bool    InpAutoTrading            = false;" in source),
        ("tester adaptive and daily-risk state are namespaced per initialization",
         "bool STB_InitRunNamespace()" in source and
         "g_stbRunNamespace=" in source and
         '"|TESTER|RUN|"+g_stbRunNamespace' in source and
         "if(!STB_InitRunNamespace())" in on_init),
        ("tester AUTO override is confined to tester initialization; live input-off remains authoritative",
         "MQL_TESTER" in on_init and
         "g_autoTrading=(InpAutoTrading ||" in on_init and
         "if(!InpAutoTrading)" in on_init),
        ("BUY STOP/SELL STOP initial SL anchors to closed M5 structure and validates broker geometry",
         "if(orderType==ORDER_TYPE_BUY_STOP || orderType==ORDER_TYPE_SELL_STOP)" in initial_pending_sl and
         "iLow(symbol,PERIOD_M5,1)" in initial_pending_sl and
         "iHigh(symbol,PERIOD_M5,1)" in initial_pending_sl and
         "IsValidSLForPendingOrder(symbol,orderType,entryPrice,candleSL)" in initial_pending_sl),
        ("pending STOP trailing validates finite/positive/ordered closed-M5 OHLC and preserves retryability",
         bool(trail_source) and
         "datetime actionableClosedBar=0;" in trail_source and
         "MathIsValidNumber(barOpen)" in trail_source and
         "barLow<=barHigh" in trail_source and
         "barLow<=MathMin(barOpen,barClose)" in trail_source and
         "barHigh>=MathMax(barOpen,barClose)" in trail_source and
         "g_stbPendingTrail[idx].lastProcessedM5Bar=actionableClosedBar;" in trail_source and
         "STB_PEND_BACKOFF_1_SEC" in trail_source),
        ("pending-distance resolver uses directional tick alignment and validates all six pending types",
         bool(resolver_source) and
         all(token in resolver_source for token in (
             "ORDER_TYPE_BUY_STOP", "ORDER_TYPE_SELL_STOP",
             "ORDER_TYPE_BUY_LIMIT", "ORDER_TYPE_SELL_LIMIT",
             "ORDER_TYPE_BUY_STOP_LIMIT", "ORDER_TYPE_SELL_STOP_LIMIT",
             "STB_TickAlignPriceDirectional(symbol,rawEntry,entryRoundUp)",
             "STB_TickAlignPriceDirectional(symbol,rawSL,isSell)",
             "BUY_ENTRY_INSIDE_BROKER_ZONE", "SELL_ENTRY_INSIDE_BROKER_ZONE",
             "BUY_SL_INSIDE_BROKER_ZONE", "SELL_SL_INSIDE_BROKER_ZONE",
             "r.valid=true;", "r.reason=\"OK\";")) and
         "STB_ResolvePendingDistance(" in trail_source),
        ("pending trail does not classify partial execution as successful modification",
         "int STB_PendingClassifyResult(const bool ok)" in trail_source and
         "case TRADE_RETCODE_DONE_PARTIAL:" not in source_region(
             trail_source, "int STB_PendingClassifyResult(const bool ok)",
             "//--- Register a real terminal pending order") and
         "case TRADE_RETCODE_DONE:" in source_region(
             trail_source, "int STB_PendingClassifyResult(const bool ok)",
             "//--- Register a real terminal pending order")),
        ("pending trail retires disappeared orders before exposure-allocation checks",
         (lambda body: bool(body) and
          "if(!OrderSelect(g_stbPendingTrail[idx].ticket))" in body and
          "if(STB_ExposureEnsure(ticket,false)<0)" in body and
          body.index("if(!OrderSelect(g_stbPendingTrail[idx].ticket))") <
              body.index("if(STB_ExposureEnsure(ticket,false)<0)") and
          "g_stbPendingTrail[idx].active=false;" in body)
         (source_region(trail_source,
                        "bool STB_PendingTrailManageOne(",
                        "int STB_PendingTrailProcess("))),
        ("partial pending fills retain trailing only while a managed remainder remains",
         bool(trail_source) and
         "DEAL_ADD can represent a partial fill" in trail_source and
         "if(OrderSelect(ticket) &&" in
             source_region(trail_source,
                           "void STB_PendingTrailOnOrderFilled(",
                           "//--- Restart recovery") and
         "action=KEEP_TRAIL_ACTIVE" in
             source_region(trail_source,
                           "void STB_PendingTrailOnOrderFilled(",
                           "//--- Restart recovery") and
         "g_stbPendingTrail[idx].active=false;" in
             source_region(trail_source,
                           "void STB_PendingTrailOnOrderFilled(",
                           "//--- Restart recovery")),
        ("manual/mobile pending override metadata does not disable automatic SL protection or trailing",
         "Do not impose protection on an order explicitly assigned to the user." not in source and
         "if(!isUserAction && STB_ManualOverrideIs(ticket) && !stbCandleStop)" not in source and
         "!manual && STB_ManualOverrideIs(ticket) && !candleStop" not in trail_source and
         "Every supported pending type remains under automatic management" in trail_source),
        ("actionable M5 candle remains retryable after resolver/server failure and commits only after a confirmed write or deliberate skip",
         "actionableClosedBar=closedBar;" in trail_source and
         "Retry with the same bounded 5/15/60s policy." in trail_source and
         "if(candleStop && step>0.0 &&" in trail_source and
         "if(committed)\n   {\n      if(candleStop && actionableClosedBar>0)" in trail_source),
        ("empty managed-symbol list means universal exposure management",
         "if(StringLen(InpScannerSymbols)==0)\n      return true;" in source),
        ("scanner is interval-throttled independently of chart M15 bar",
         "bool intervalElapsed=(g_scannerLastRun<=0 ||" in source and
         "if(!newChartBar && !intervalElapsed)" in source and
         "if(cycleBar>0)" in source),
         ("scanner quote validator rejects non-finite/crossed, future-dated, and stale quotes",
          bool(quote_validator) and all(token in quote_validator for token in (
              "MathIsValidNumber(tick.bid)", "MathIsValidNumber(tick.ask)",
              "tick.ask<tick.bid", "TimeTradeServer()", "ageSeconds < -2",
              "REJECT_FUTURE_QUOTE", "REJECT_STALE_DATA"))),
         ("scanner quote age input is bounded and enforced consistently in eligibility and freshness scoring",
          "InpScannerMaxQuoteAgeSec<1" in source and
          "InpScannerMaxQuoteAgeSec>3600" in source and
          "ageSeconds>(long)InpScannerMaxQuoteAgeSec" in quote_validator and
          "age>(long)InpScannerMaxQuoteAgeSec" in market_quality and
          "(double)age/(double)InpScannerMaxQuoteAgeSec" in market_quality and
          "MathMax(30,InpScannerMaxQuoteAgeSec)" not in source),
         ("scanner eligibility and market-quality gates both use shared quote validation",
          "STB_ScannerQuoteValid(tick,reason)" in scanner_data and
          "STB_ScannerQuoteValid(tick,quoteReason)" in market_quality),
         ("market quality rejects non-finite ATR and derived metrics before scoring",
          all(token in market_quality for token in (
              "MathIsValidNumber(atrNow)", "MathIsValidNumber(atrBase)",
              "MathIsValidNumber(q.relativeSpread)",
              'q.reason="REJECT_INVALID_MARKET_METRICS"'))),
         ("scanner top-gap uses the full revalidated watchlist before Top-N truncation",
          "if(clear && g_scannerWatchlistCount>1)" in scanner_run and
          "g_scannerWatchlist[1].opportunityScore" in scanner_run and
          "if(clear && g_scannerTop10Count>1)" not in scanner_run),
        ("scanner dashboard ready counts reflect final revalidated watchlist, not discovery candidates",
          "int finalBuyReady=0;" in scanner_run and
          "int finalSellReady=0;" in scanner_run and
          "g_panelScanBuyReady=finalBuyReady;" in scanner_run and
          "g_panelScanSellReady=finalSellReady;" in scanner_run and
          "g_panelScanBuyReady=g_scannerBuyCount;" not in scanner_run and
          "g_panelScanSellReady=g_scannerSellCount;" not in scanner_run),
        ("fallback candidate independently satisfies revalidated-watchlist confidence before submission",
          bool(execute_top_candidate) and
          "if(i>0)" in execute_top_candidate and
          "CANDIDATE_NOT_IN_REVALIDATED_WATCHLIST" in execute_top_candidate and
          "FALLBACK_CONFIDENCE_NOT_CLEAR" in execute_top_candidate and
          "g_scannerWatchlist[watchRank+1].opportunityScore" in execute_top_candidate and
          "fallbackScore>=InpScannerMinScore" in execute_top_candidate and
          execute_top_candidate.index("CANDIDATE_NOT_IN_REVALIDATED_WATCHLIST") <
              execute_top_candidate.index("FALLBACK_CONFIDENCE_NOT_CLEAR") <
              execute_top_candidate.index("bool placed=false;")),
        ("final scanner-to-execution handoff rechecks effective setup age",
          "iBarShift(c.symbol,PERIOD_M15,refreshed.setupTime,true)" in final_revalidation and
          "STB_EffectiveMaxSetupAgeBars()" in final_revalidation and
          'c.rejectReason="REJECT_SETUP_TOO_OLD";' in final_revalidation and
          final_revalidation.index("if(effectiveMaxAge>0 && c.setupAgeBars>effectiveMaxAge)") <
          final_revalidation.index("if(!ValidatePendingSetup(refreshed))")),
        ("diagnostic state arrays check allocation before indexing",
          "if(ArrayResize(g_diagnosticStates,idx+1)!=idx+1)" in diagnostic_reject and
          "if(ArrayResize(g_diagnosticStates,idx+1)!=idx+1)" in diagnostic_ready and
          "diagnostic state allocation failed" in diagnostic_reject and
          "ready-state diagnostic allocation failed" in diagnostic_ready),
        ("indicator cache allocation releases newly created handles on failure",
          "if(ArrayResize(g_indicatorCache,n+1)!=n+1)" in indicator_cache and
          'Print("STB indicator cache allocation failed symbol=",symbol,' in indicator_cache and
          indicator_cache.index("IndicatorRelease(hRsi);") <
          indicator_cache.index('Print("STB indicator cache allocation failed') and
          indicator_cache.index("IndicatorRelease(hCci);") <
          indicator_cache.index('Print("STB indicator cache allocation failed') and
          indicator_cache.index('Print("STB indicator cache allocation failed') <
          indicator_cache.index("return false;", indicator_cache.index('Print("STB indicator cache allocation failed'))),
        ("swing collection fails closed on reset or append allocation failure",
          "if(ArrayResize(highs,0)<0 || ArrayResize(lows,0)<0)" in collect_swings and
          "if(ArrayResize(highs,n+1)!=n+1)" in collect_swings and
          "if(ArrayResize(lows,n+1)!=n+1)" in collect_swings and
          collect_swings.count("ArrayFree(highs);") >= 2 and
          collect_swings.count("ArrayFree(lows);") >= 2),
        ("management lease tracking allocation failure releases the untrackable writer lease",
          "bool STB_LeaseTrackSymbol(const string symbol)" in source and
          "if(ArrayResize(g_stbLeaseSymbols,n+1)==n+1)" in source and
          "STB management lease tracking allocation failed" in source and
          source.count("if(!STB_LeaseTrackSymbol(symbol))") == 3 and
          source.count("GlobalVariableSetOnCondition(ownerKey,0.0,me);") >= 4),
        ("pending deletion requires full DONE retcode and rejects DONE_PARTIAL",
         "bool STB_ExecuteOrderDelete(" in source and
         "if(!requestOK || ret!=TRADE_RETCODE_DONE)" in source_region(
             source, "bool STB_ExecuteOrderDelete(",
             "// Single controlled entry used by every permitted pending delete.") and
         "ret!=TRADE_RETCODE_DONE_PARTIAL" not in source_region(
             source, "bool STB_ExecuteOrderDelete(",
             "// Single controlled entry used by every permitted pending delete.")),
        ("modify retcodes never treat partial execution as successful geometry change",
         "bool TradeRetcodeModifySucceeded()" in source and
         "TRADE_RETCODE_DONE_PARTIAL" not in source_region(
             source, "bool TradeRetcodeModifySucceeded()",
             "bool TradeRetcodePlacementSucceeded()") and
         "TRADE_RETCODE_DONE" in source_region(
             source, "bool TradeRetcodeModifySucceeded()",
             "bool TradeRetcodePlacementSucceeded()")),
        ("pending placement accepts only DONE or PLACED, not partial execution or NO_CHANGES",
         "bool TradeRetcodePlacementSucceeded()" in source and
         "TRADE_RETCODE_NO_CHANGES" not in source_region(
             source, "bool TradeRetcodePlacementSucceeded()",
             "double TradeMinDistance(") and
         "TRADE_RETCODE_DONE_PARTIAL" not in source_region(
             source, "bool TradeRetcodePlacementSucceeded()",
             "double TradeMinDistance(") and
         "TRADE_RETCODE_DONE" in source_region(
             source, "bool TradeRetcodePlacementSucceeded()",
             "double TradeMinDistance(") and
         "TRADE_RETCODE_PLACED" in source_region(
             source, "bool TradeRetcodePlacementSucceeded()",
             "double TradeMinDistance(")),
        ("all pending-order placement paths preflight exact request geometry with OrderCheck",
         bool(source_region(source, "bool STB_CheckPendingOrderRequest(",
                            "bool CheckPendingOrder(")) and
         "if(!OrderCheck(request,check))" in source_region(
             source, "bool STB_CheckPendingOrderRequest(", "bool CheckPendingOrder(") and
         "check.retcode!=0" in source_region(
             source, "bool STB_CheckPendingOrderRequest(", "bool CheckPendingOrder(") and
         "STB_CheckPendingOrderRequest(symbol,hedgeOrderType,volume,entry,sl,0.0" in source and
         "STB_CheckPendingOrderRequest(_Symbol,manualStopType,volume,entry,sl,0.0" in source and
         "STB_CheckPendingOrderRequest(_Symbol,manualLimitType,volume,entry,sl,0.0" in source),
        ("order submission rechecks volatile market, geometry, volume, permissions, and ownership",
          all(token in place_setup for token in (
              "TRADE_PERMISSION_CHANGED_BEFORE_SUBMIT",
              "DIRECTION_CHANGED_BEFORE_SUBMIT",
              "SPREAD_CHANGED_BEFORE_SUBMIT",
              "PENDING_GEOMETRY_CHANGED_BEFORE_SUBMIT",
              'STB_DirectionVolumeWithinLimit(s.symbol,s.direction,volume,"PlaceSetupFinal")',
              "ENTRY_LOCK_LOST_BEFORE_SUBMIT",
              "SYMBOL_WRITER_LEASE_LOST",
              "MANAGED_EXPOSURE_CHANGED_BEFORE_SUBMIT")) and
          place_setup.index("PENDING_GEOMETRY_CHANGED_BEFORE_SUBMIT") <
          place_setup.index("bool ok=false;") <
          place_setup.index("trade.BuyStop(volume,s.entry")),
        ("scanner allocation failures fail closed, clear candidates, and restore temporary symbol selection",
          "void STB_ScannerAllocationAbort(" in source and
          'g_scannerStatus="ALLOCATION_FAILED";' in source and
          'STB_ScannerAllocationAbort("PREVIOUS_SNAPSHOT"' in source and
          'STB_ScannerAllocationAbort("UNIVERSE_LIST"' in source and
          'STB_ScannerAllocationAbort("CANDIDATE_LIST"' in source and
          'STB_ScannerAllocationAbort("INITIAL_WATCHLIST"' in source and
          'STB_ScannerAllocationAbort("FINAL_WATCHLIST"' in source and
          'STB_ScannerAllocationAbort("EXECUTION_TOPN"' in source and
          scanner_run.index("ArrayFree(wasSelected);") <
          scanner_run.index('STB_ScannerAllocationAbort("SYMBOL_SELECTION_SNAPSHOT"') and
          "ArrayFree(g_scannerTop10);" in source and
          "ArrayFree(g_scannerWatchlist);" in source and
          "ArrayFree(g_scannerCurrent);" in source and
          "no candidate may be executed" in source),
        ("M15 structure trigger requires a fresh close-crossing of a confirmed swing",
          "r[s].close>highs[i].price && r[s+1].close<=highs[i].price" in detect_structure and
          "r[s].close<lows[i].price && r[s+1].close>=lows[i].price" in detect_structure and
          detect_structure.count("s+1<ArraySize(r)") == 2),
         ("OnTick and OnTimer execute only after a new completed scanner cycle",
         "ulong cycleBefore=g_scannerCycle;" in on_tick and
         "if(g_scannerCycle!=cycleBefore)" in on_tick and
         "ulong cycleBefore=g_scannerCycle;" in on_timer and
         "if(g_scannerCycle!=cycleBefore)" in on_timer),
        ("timer startup failure aborts initialization",
         "if(!EventSetTimer(MathMax(1,InpScanSeconds)))" in on_init and
         "return INIT_FAILED;" in on_init),
        ("startup logs distinguish expert and account trade permissions",
         "accountExpert=" in source and "accountTrade=" in source),
        ("one direct OrderDelete writer",
         len(re.findall(r"\btrade\s*\.\s*OrderDelete\s*\(", source)) == 1),
        ("one direct PositionModify writer",
         len(re.findall(r"\btrade\s*\.\s*PositionModify\s*\(", source)) == 1),
        ("shared directional-volume guard defined once",
         len(re.findall(r"\bbool\s+STB_DirectionVolumeWithinLimit\s*\(", source)) == 1),
        ("four order-creation paths use shared volume guard",
         all(token in source for token in (
             'STB_DirectionVolumeWithinLimit(s.symbol,s.direction,volume,"PlaceSetup")',
             'STB_DirectionVolumeWithinLimit(_Symbol,direction,volume,"PlaceManualPendingDirection")',
             'STB_DirectionVolumeWithinLimit(_Symbol,direction,volume,"PlaceManualLimitDirection")',
             'STB_DirectionVolumeWithinLimit(symbol,hedgeDirection,volume,"OneClickHedge")'))),
        ("delete writer rejects unauthorized requests",
         "reason=UNAUTHORIZED_OR_UNVERIFIED" in source),
        ("rollback authorization matches creator comment families",
         all(token in source for token in (
             '(source=="OneClickHedge" && hedgeCreated)',
             '(source=="PlaceSetup" && autoCreated)',
             '(source=="PlaceManual" &&',
             'StringFind(orderComment,"STB|M|")==0'))),
        ("expiry delete rechecks source, managed scope, and symbol lease at the writer boundary",
         all(token in source for token in (
             'bool expiryAuthority=(source=="ManagePendingOrders" &&',
             "IsManagedOrder(ticket)",
             "STB_SymbolManagementOwnedVerified(symbol)",
             "if(expiryAuthority)",
             "authorized=serverExpired || localAgeExpired"))),
        ("daily-loss guard closes only EA-magic positions and verifies the result",
         "PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic" in source and
         "trade.PositionClose(ticket)" in source and
         "closeRetcode!=TRADE_RETCODE_DONE" in source and
         "STB DAILY GUARD POSITION CLOSED" in source),
        ("daily-loss guard uses dedicated authorization for aged EA and UI-manual pending orders",
          all(token in source for token in (
              "STB_DEL_DAILY_RISK_GUARD=5",
              "if(reason==STB_DEL_DAILY_RISK_GUARD)",
              'source=="DailyLossGuard"',
              'StringFind(orderComment,"STB|M|")==0',
              'STB_RequestOrderDelete(ticket,STB_DEL_DAILY_RISK_GUARD,"DailyLossGuard")',
              "STB_SymbolManagementOwnedVerified(symbol)"))),
        ("position modify rechecks TP snapshot",
         "position state changed before request" in source),
        # Fail closed on the confirmed root cause. A one-element proposal
        # array makes the resolver incapable of comparing management sources.
        ("SL submit does not force single-proposal arbitration",
         "ArrayResize(props,1)" not in source and
         "STB_ResolvePositionSL(ticket,props,1,finalSL,finalSource)" not in source),
        ("automatic SL proposals are queued with ticket and cycle",
         all(token in source for token in (
             "STBQueuedSLProposal g_stbSLQueue[]",
             "g_stbSLQueue[n].ticket=ticket",
             "g_stbSLQueue[n].cycle=g_stbCycleId",
             "STB_QueuePositionSL(ticket,candidateSL,source,reason)"))),
        ("non-initial automatic SL requests cannot bypass arbitration outside a cycle",
         all(token in source for token in (
             "if(source!=STB_SL_SRC_INITIAL)",
             "STB SL request blocked outside arbitration cycle",
             "if(g_stbCollectingSLProposals)",
             "if(isUserAction)"))),
        ("candidate producers do not call the broker modify bridge directly",
         candidate_producers_safe(source)),
        ("central SL modify bridge has only synchronous user, initial fallback, and flush call sites",
         len(re.findall(r"\bModifyPositionSL\s*\(", source)) == 4),
        ("queue allocation failure aborts the incomplete arbitration batch",
         all(token in source for token in (
             "bool g_stbSLCollectionFaulted=false;",
             "g_stbSLCollectionFaulted=true;",
             "bool collectionFault=g_stbSLCollectionFaulted;",
             "if(collectionFault)",
             "incomplete proposal queue; no automatic SL writes"))),
        ("per-ticket resolver receives the full candidate set or skips that ticket",
         all(token in source for token in (
             "if(ArrayResize(props,count)!=count)",
             "never arbitrate a silently truncated candidate set",
             "props[propIndex].reason=g_stbSLQueue[j].reason; propIndex++"))),
        ("management collects before a single central flush",
         source.count("STB_FlushPositionSLProposals();") == 1 and
         "g_stbCollectingSLProposals=true;" in source and
         source.index("g_stbCollectingSLProposals=true;") < source.index("STB_FlushPositionSLProposals();")),
        ("resolver uses one shared tick snapshot for candidate validity",
         all(token in source for token in (
             "MqlTick decisionTick;",
             "STB_IsValidSLForDecisionSnapshot(side,c,decisionTick,point,stopsLevel,freezeLevel)",
             "return sl<tick.bid && (tick.bid-sl)>=minimumDistance",
             "return sl>tick.ask && (sl-tick.ask)>=minimumDistance"))),
        ("resolver has deterministic source tie-break and revalidates selected SL",
         "props[i].source<finalSource" in source and
         "!IsValidSLForPosition(symbol,side,finalSL)" in source),
        ("automatic profit-lock state is deferred during collection",
         "if(!g_stbCollectingSLProposals || isUserAction)" in source),
        ("already-satisfied profit lock re-reads live SL before state commit",
         (lambda body: body.count("PositionSelectByTicket(ticket)") >= 3 and
          body.count("double liveSL=PositionGetDouble(POSITION_SL);") == 2 and
          body.count("SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));") == 2)
          (source[source.find("bool ApplyProfitLock("):source.find("void AutoProfitProtection()",
             source.find("bool ApplyProfitLock("))]) if "bool ApplyProfitLock(" in source and
          "void AutoProfitProtection()" in source else False),
        ("arbitration confirmation rejects missing SL before positive-lock bookkeeping",
         (lambda body: bool(body) and "if(actualSL<=0.0)" in body and
          body.index("if(actualSL<=0.0)") < body.index("double pip=PipSize(symbol);") and
          body.index("if(actualSL<=0.0)") < body.index("SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));") and
          "STB SL arbitration verification failed: position has no SL" in body)
          (source_region(source, "void STB_FlushPositionSLProposals()", "// APPLY PROFIT LOCK"))),
        ("partial exits preserve SL-lock state; full close and reversal clear it before magic filtering",
         (lambda body: bool(body) and
          body.find("if(entryType==DEAL_ENTRY_OUT") >= 0 and
          body.find("if(entryType==DEAL_ENTRY_OUT") < body.find("if(magic!=(long)InpMagic &&") and
          "bool positionRemains=PositionSelectByTicket(closedTicket);" in body and
          "bool exposureReversed=(entryType==DEAL_ENTRY_INOUT);" in body and
          "if(exposureReversed || !positionRemains)" in body and
          body.find("if(exposureReversed || !positionRemains)") <
              body.find("GlobalVariableDel(TicketLockName(closedTicket));") <
              body.find("if(magic!=(long)InpMagic &&"))
          (source_region(source, "void OnTradeTransaction(", "if(entryType==DEAL_ENTRY_IN && positionId>0)"))),
        ("closed lifecycle PnL can be reconstructed from OUT/OUT_BY broker history",
         "bool STB_SumClosedLifecyclePnlFromHistory(" in source
         and "HistorySelectByPosition(positionId)" in source
         and "entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY" in source
         and "STB_SumClosedLifecyclePnlFromHistory(positionId,historyLifecyclePnl)" in on_trade_transaction_full
         and on_trade_transaction_full.find("TakeAccumulatedPositionPnl(positionId)") <
             on_trade_transaction_full.find("STB_SumClosedLifecyclePnlFromHistory(positionId,historyLifecyclePnl)")),
        ("resolver enforces price-move profit-lock floor and deterministic no-SL fallback",
         all(token in source for token in (
             "decisionPriceMovePips=STB_PositionPriceMovePips(ticket);",
             "decisionPriceMovePips>=STB_ProfitLockTriggerPips()",
             "bool enforceProfitLockFloor=",
             "profitLockTarget=NormalizePrice(symbol,",
             "if(enforceProfitLockFloor &&",
             "!STB_IsValidSLForDecisionSnapshot(side,profitLockTarget,decisionTick,",
             "bool meetsProfitLockFloor=!enforceProfitLockFloor ||",
             "currentSL<=0.0 && props[i].source!=STB_SL_SRC_PROFIT_PROTECTION",
             "if(!found && unprotectedFallbackFound)",
             "props[i].source<unprotectedFallbackSource")) and
         source.find("bool meetsProfitLockFloor=!enforceProfitLockFloor ||") <
             source.find("if(!meetsProfitLockFloor)") and
         source.find("if(!found && unprotectedFallbackFound)") <
             source.find("if(!found || !IsValidSLForPosition(symbol,side,finalSL))")),
        ("only a broker-confirmed positive actual SL is persisted as locked pips",
         (lambda body: bool(body) and
          "if(actualSL<=0.0)" in body and
          "double achieved=(side==POSITION_TYPE_BUY" in body and
          "if(achieved>0.0)" in body and
          "SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));" in body and
          body.index("if(actualSL<=0.0)") < body.index("SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));"))
          (source_region(source, "void STB_FlushPositionSLProposals()", "// APPLY PROFIT LOCK"))),
        ("trail success log is not emitted for queued proposals",
         'if(result && !g_stbCollectingSLProposals)' in source),
        ("H4 trend alignment is a configurable hard entry gate",
         "InpRequireH4TrendAlignment = true" in source and
         "if(InpRequireH4TrendAlignment && (!ti.valid || !aligned))" in source),
        ("required local M15 FVG and Order Block are hard rejection gates",
         "if((InpRequireFVG || InpStrictPatternFilters) && !hasFVG)" in source and
         "if((InpRequireOB || InpStrictPatternFilters || InpRequireHTFConfluence) && !hasOB)" in source),
        ("HTF FVG and Order Block use only zones confirmed by the closed M15 decision time",
         "bool STB_CheckHTFConfluence(" in source and
         "datetime decisionTime=latestClosedM15+m15Seconds;" in source and
         source.count("confirmedAt>decisionTime") >= 2 and
         "r[j].time+tfSeconds>decisionTime" in source),
        ("HTF Order Block requires a confirmed pre-impulse structural break",
         "STB_HTFImpulseBrokePriorSwing" in source and
         "pivotShift-rightBars<=impulseShift" in source),
        ("structural position trailing routes candidates through shared SL arbitration",
         "bool STB_CalculateStructuralTrailSL(" in source and
         "STB_SubmitPositionSL(ticket,structuralSL," in source and
         "trade.PositionModify(ticket,structuralSL" not in source),
        ("structural trailing uses confirmed swings, ATR activation and ATR buffer",
         "CollectSwings(symbol,InpTrailTF,lookback,highs,lows)" in source and
         "movePrice<atr*InpStructuralTrailStartATR" in source and
         "atr*InpStructuralTrailBufferATR" in source),
        ("adaptive break-even, ATR profit lock and ATR trail share the central arbiter",
         all(token in source for token in (
             "bool STB_AdaptiveBreakEvenProtection(",
             "bool STB_AdaptiveProfitLockProtection(",
             "bool STB_AdaptiveATRTrail(",
             'STB_SubmitPositionSL(ticket,target,STB_SL_SRC_PROFIT_PROTECTION,',
             'STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_TRAIL,"ADAPTIVE_ATR_TRAIL")',
             "STB_AdaptiveBreakEvenProtection(ticket);",
             "STB_AdaptiveProfitLockProtection(ticket);",
             "STB_AdaptiveATRTrail(ticket);"))),
        ("adaptive break-even validates cost offset and net PnL before locking",
         all(token in source for token in (
             "STB_AdaptiveBreakEvenOffsetPips(ticket,symbol,side,entry,pip)",
             "PositionNetProfitPips(ticket)<offsetPips",
             "InpBreakEvenTriggerATR",
             '"ADAPTIVE_BREAK_EVEN"'))),
        ("adaptive ATR trail retains a positive buffer beyond entry and routes through arbiter",
         all(token in source for token in (
             "candidate<=entry+minimumLockedPrice",
             "candidate>=entry-minimumLockedPrice",
             'STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_TRAIL,"ADAPTIVE_ATR_TRAIL")',
             "InpAdaptiveTrailDistanceATR"))),
        ("HTF, structural trail and adaptive protection inputs are finite-checked",
         all(token in source for token in (
             "!MathIsValidNumber(InpHTFZoneMaxGapATR)",
             "!MathIsValidNumber(InpHTFMinFVGWidthATR)",
             "!MathIsValidNumber(InpStructuralTrailStartATR)",
             "!MathIsValidNumber(InpStructuralTrailBufferATR)",
             "!MathIsValidNumber(InpBreakEvenTriggerATR)",
             "!MathIsValidNumber(InpBreakEvenMinOffsetPips)",
             "!MathIsValidNumber(InpBreakEvenCostMultiplier)",
             "!MathIsValidNumber(InpAdaptiveLockTriggerATR)",
             "!MathIsValidNumber(InpAdaptiveLockATR)",
             "!MathIsValidNumber(InpAdaptiveTrailStartATR)",
             "!MathIsValidNumber(InpAdaptiveTrailDistanceATR)",
             "!MathIsValidNumber(InpAdaptiveTrailStepATR)"))),
        ("adaptive state namespace is isolated from pre-confluence profile results",
         "AP3|" in source and "AP2" not in source),
        ("adaptive R expectancy uses its own risk-valid observation denominator",
         '"RCOUNT",profile,0.0)*decay' in source and
         '"RCOUNT",profileId,oldRCount' in source and
         "if(hasValidRiskSample && MathIsValidNumber(rMultiple))" in source),
        ("closed-trade learning reports whether initial monetary risk was captured",
         source.count("riskMoney>0.0 && MathIsValidNumber(riskMoney)") >= 2),
        ("default M15 setup age is bounded rather than unlimited",
         "InpMaxSetupAgeBars       = 4;" in source),
        ("only one direct PositionModify call exists in the shared verified broker writer",
         source.count("trade.PositionModify(") == 1 and
         "bool STB_PositionModifyBrokerVerified(" in source),
        ("SL/TP wrapper delegates to the shared verified position modification bridge",
         'gv,\n                                           (targetTP!=latestTP ? "SL+TP":"SL"))' in source and
         "STB_PositionModifyBrokerVerified(ticket," in source),
        ("structural TP manager delegates TP-only writes to the same verified bridge",
         'failKey,"TP")' in source and
         'bool STB_ModifyPositionTP(' in source and
         "trade.PositionModify(ticket,sl,newTP)" not in source),
        ("existing explicit position and pending TPs are never overwritten",
         "if(PositionGetDouble(POSITION_TP)>0.0)\n      return true;" in source and
         "if(OrderGetDouble(ORDER_TP)>0.0)\n      return true;" in source),
        ("position TP management happens after SL arbitration flush",
         source.index("STB_FlushPositionSLProposals();", source.index("void ManagePositions()")) <
         source.index("EnsureInitialTPForPosition(ticket)", source.index("void ManagePositions()"))),
        ("pending structural TP modification uses the central pending geometry writer",
         "STB_ModifyPendingOrderGeometry(ticket,entry,sl,tp,false)" in source),
        ("structural TP calculation includes RR floor, swing target, quote buffer and RR fallback",
         "bool STB_CalculatePositionTPFromStructure(" in source and
         "bool STB_CalculatePendingTPFromStructure(" in source and
         'source="STRUCTURE_SWING"' in source and
         'source="RR_FALLBACK"' in source and
         "tick.bid+marketBuffer" in source and
         "tick.ask-marketBuffer" in source),
        ("managed positions and pending orders select their symbols before market-data management",
         "SymbolSelect(symbol,true)" in source[source.index("void ManagePositions()"):source.index("void ManagePendingOrders()")] and
         "SymbolSelect(symbol,true)" in source[source.index("void ManagePendingOrders()"):source.index("double DirectionExposureVolume(")]),
        ("scanner rejects excessive spread relative to M15 ATR before score ranking",
         "InpMaxRelativeSpreadPct   = 10.0" in source and
         'q.reason="REJECT_RELATIVE_SPREAD";' in source and
         "q.relativeSpread>InpMaxRelativeSpreadPct" in source and
         "!MathIsValidNumber(InpMaxRelativeSpreadPct)" in source),
        ("scanner logs final revalidation, age and score rejection reasons instead of silently dropping candidates",
         bool(scanner_run) and
         'stage=FINAL_REVALIDATION symbol=' in scanner_run and
         'stage=WATCHLIST_AGE symbol=' in scanner_run and
         'stage=WATCHLIST_SCORE symbol=' in scanner_run and
         'c.rejectReason' in scanner_run),
        ("scanner logs entry-lock rejection and reports confidence runner-up from full watchlist",
         bool(execute_top_candidate) and
         'stage=ENTRY_LOCK' in execute_top_candidate and
         'g_scannerWatchlist[1].opportunityScore' in execute_top_candidate and
         'g_scannerWatchlistCount>1' in execute_top_candidate),
        ("watchlist age gate uses the effective adaptive setup-age limit consistently",
         'int watchlistMaxAge=STB_EffectiveMaxSetupAgeBars();' in scanner_run and
         'c.setupAgeBars>watchlistMaxAge' in scanner_run and
         'maxAgeBars=",IntegerToString(watchlistMaxAge)' in scanner_run),
        ("selected structural SL can attach a missing structural TP in the same verified broker request",
         "double tpForRequest=-1.0" in source and
         "if(STB_CalculatePositionTPFromStructure(symbol,side,entry,chosenSL" in source and
         "ModifyPositionSL(ticket,chosenSL,false,tpForRequest)" in source and
         "const double requestedTP=-1.0" in source),
        ("manager-generated position TP uses deterministic base RR, not stale active-profile state",
         "InpMinimumRR,tp,source" in source and
         "STB_EffectiveMinimumRR(),tp,source" not in source),
        ("every position modify attempt consumes this cycle's write budget before the broker call",
         "STB_CycleMarkWritten(ticket);\n\n   ResetLastError();\n   bool requestOK=trade.PositionModify(ticket,newSL,newTP);" in source and
         source.index("STB_CycleMarkWritten(ticket);\n\n   ResetLastError();\n   bool requestOK=trade.PositionModify(ticket,newSL,newTP);") <
         source.index("bool ModifyPositionSL(")),
        ("transaction intake runs before deal-magic filtering so manual and foreign-magic fills enter protection",
         "STB_TradeIntakeFromTransaction(trans);" in on_trade_transaction and
         on_trade_transaction.index("STB_TradeIntakeFromTransaction(trans);") <
         on_trade_transaction.index("if(magic!=(long)InpMagic &&")),
        ("pending-order intake records actual server geometry before registering pending trail state",
         "if(trans.type==TRADE_TRANSACTION_ORDER_ADD" in trade_intake and
         trade_intake.index("STB_GeomStore(trans.order,false,") <
         trade_intake.index("STB_PendingTrailRegister(trans.order,\"TRADE_TRANSACTION\")")),
        ("filled positions seed exposure and geometry before immediate manager handoff",
         "STB_ExposureEnsure(trans.position,true)" in trade_intake and
         "STB_GeomStore(trans.position,true," in trade_intake and
         "STB_ManagePositionImmediately(trans.position);" in trade_intake and
         trade_intake.index("STB_ExposureEnsure(trans.position,true)") <
         trade_intake.index("STB_GeomStore(trans.position,true,") <
         trade_intake.index("STB_ManagePositionImmediately(trans.position);")),
        ("deal-add handoff safely defers unavailable positions to periodic terminal reconciliation",
         "if(trans.position>0 && PositionSelectByTicket(trans.position))" in trade_intake and
         "STB_ManagePositionImmediately(trans.position);" in trade_intake and
         "STB_ReconcileTradeRegistry();" in on_timer and
         on_timer.index("STB_ReconcileTradeRegistry();") <
             on_timer.index("STB_RunManagementCycle();")),
        ("immediate fill management is reentrancy-guarded and defers nested cycles",
         "if(g_stbManagementCycleActive)" in management_cycle and
         "g_stbManagementCyclePending=true;" in management_cycle and
         "while(g_stbManagementCyclePending && pass<2);" in management_cycle),
        ("accepted pending order is initial-SL-verified before setup cooldown is committed",
         "if(placedOrder==0 || !VerifyPendingInitialSL(placedOrder))" in place_setup and
         place_setup.index("VerifyPendingInitialSL(placedOrder)") <
         place_setup.index("SetLastSetupTime(s.symbol,s.direction,s.setupTime)")),
        ("final volatile-state and ownership checks are directly before broker submission",
         place_setup.index("TRADE_PERMISSION_CHANGED_BEFORE_SUBMIT") <
         place_setup.index("bool ok=false;") <
         place_setup.index("trade.BuyStop(volume,s.entry") and
         place_setup.index("MANAGED_EXPOSURE_CHANGED_BEFORE_SUBMIT") <
         place_setup.index("bool ok=false;")),
        ("startup recovery rebuilds pending trails and reconciles exposure before management and scanner",
         all(token in on_init for token in (
             "STB_PendingTrailRebuildFromTerminal();",
             "STB_ReconcileTradeRegistry();",
             "STB_RunManagementCycle();",
             "STB_ScannerRun();")) and
         on_init.index("STB_PendingTrailRebuildFromTerminal();") <
         on_init.index("STB_ReconcileTradeRegistry();") <
         on_init.index("STB_RunManagementCycle();") <
         on_init.index("STB_ScannerRun();")),
        ("periodic timer recovery reconciles terminal positions/orders before management and scanner execution",
         "STB_ReconcileTradeRegistry();" in on_timer and
         on_timer.index("STB_ReconcileTradeRegistry();") <
             on_timer.index("STB_RunManagementCycle();") <
             on_timer.index("STB_ScannerRun();")),
        ("tick recovery reconciles a newly detected M15-bar exposure before the central management cycle",
         "STB_RunManagementCycle();" in on_tick and
         "bool m15Bar=NewM15Bar();" in on_tick and
         "if(m15Bar)" in on_tick and
         on_tick.index("STB_ReconcileTradeRegistry();") <
             on_tick.index("STB_RunManagementCycle();") <
             on_tick.index("STB_ScannerRun();")),
         ("transaction intake fails closed before registering a managed pending order",
          "STB_ExposureEnsure(trans.order,false)" in trade_intake and
          "if(exposureIdx<0)" in trade_intake and
          "STB ORDER INTAKE DEFERRED" in trade_intake and
          trade_intake.index("if(exposureIdx<0)") <
              trade_intake.index("STB_GeomStore(trans.order,false") <
              trade_intake.index('STB_PendingTrailRegister(trans.order,"TRADE_TRANSACTION")')),
         ("filled managed position handoff is guarded and defers cleanly on exposure allocation failure",
          "STB_ExposureEnsure(trans.position,true)" in trade_intake and
          "STB POSITION BASELINE DEFERRED after fill" in trade_intake and
          "STB_ManagePositionImmediately(trans.position);" in trade_intake and
          "STB POSITION HANDOFF DEFERRED" in source),
         ("partial close retains per-ticket lock state while position remains; full close or reversal clears it before magic filtering",
          "entryType==DEAL_ENTRY_OUT" in on_trade_transaction and
          "entryType==DEAL_ENTRY_OUT_BY" in on_trade_transaction and
          "entryType==DEAL_ENTRY_INOUT" in on_trade_transaction and
          "bool positionRemains=PositionSelectByTicket(closedTicket);" in on_trade_transaction and
          "if(exposureReversed || !positionRemains)" in on_trade_transaction and
          "GlobalVariableDel(TicketLockName(closedTicket));" in on_trade_transaction and
          on_trade_transaction.index("if(exposureReversed || !positionRemains)") <
              on_trade_transaction.index("if(magic!=(long)InpMagic &&")),
         ("pending trail fill transition is attempted before immediate position handoff",
          "STB_PendingTrailOnOrderFilled(trans.order);" in trade_intake and
          trade_intake.index("STB_PendingTrailOnOrderFilled(trans.order);") <
              trade_intake.index("STB_ManagePositionImmediately(trans.position);")),
        ("pending-order reconciliation fails closed on exposure allocation and preserves known geometry baselines",
         "int exposureIdx=STB_ExposureEnsure(ticket,false);" in reconcile_registry and
         "if(exposureIdx<0)" in reconcile_registry and
         "STB ORDER RECONCILE DEFERRED" in reconcile_registry and
         "STB_PendingTrailRegister(ticket,\"RECONCILE\");" in reconcile_registry and
         "if(g_stbExposure[exposureIdx].entry<=0.0)" in reconcile_registry),
        ("position reconciliation seeds only an unknown geometry baseline",
         "int exposureIdx=STB_ExposureEnsure(ticket,true);" in reconcile_registry and
         "if(exposureIdx>=0 && g_stbExposure[exposureIdx].entry<=0.0)" in reconcile_registry and
         "STB_GeomStore(ticket,true," in reconcile_registry),
        ("adaptive break-even requires confirmed initial SL, ATR movement, net cost coverage, broker-valid geometry, and queues through the shared writer",
         bool(adaptive_be) and all(token in adaptive_be for token in (
             "currentSL<=0.0", "STB_GetAdaptiveProtectionATR(symbol,atr)",
             "STB_AdaptiveBreakEvenOffsetPips(ticket,symbol,side,entry,pip)",
             "movePips*pip<triggerPrice",
             "PositionNetProfitPips(ticket)<offsetPips",
             "IsValidSLForPosition(symbol,side,target)",
             "STB_SubmitPositionSL(ticket,target,STB_SL_SRC_PROFIT_PROTECTION",
             "currentSL>=target", "currentSL<=target"))),
        ("adaptive break-even cost buffer accounts for commission, adverse swap, spread, and pip value",
         bool(adaptive_be) and
         "PositionPipValue(symbol,side,volume,entry)" in source and
         "PositionCommissionMoney(ticket)" in source and
         "PositionGetDouble(POSITION_SWAP)" in source and
         "spreadPips*0.25" in source and
         "observedCostPips*MathMax(1.0,InpBreakEvenCostMultiplier)" in source),
        ("adaptive profit lock and ATR trail are monotonic and use shared SL arbitration",
         bool(adaptive_lock) and bool(adaptive_trail) and
         "STB_SubmitPositionSL(ticket,target,STB_SL_SRC_PROFIT_PROTECTION" in adaptive_lock and
         "STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_TRAIL" in adaptive_trail and
         "currentSL>=target" in adaptive_lock and
         "currentSL<=target" in adaptive_lock and
         "candidate<=currentSL" in adaptive_trail and
         "candidate>=currentSL" in adaptive_trail),
        ("position management confirms initial SL before adaptive BE/lock, batches trailing proposals, flushes once, then considers missing TP",
         bool(position_manager) and
         position_manager.index("EnsureInitialSL(ticket);") <
             position_manager.index("STB_AdaptiveBreakEvenProtection(ticket);") <
             position_manager.index("STB_AdaptiveProfitLockProtection(ticket);") <
             position_manager.index("STB_FlushPositionSLProposals();") <
             position_manager.index("EnsureInitialTPForPosition(ticket)")),
        ("SL resolver evaluates all queued candidates against a shared quote/constraint snapshot and preserves monotonic protection",
         bool(position_sl_resolver) and
         "MqlTick decisionTick" in position_sl_resolver and
         "STB_IsValidSLForDecisionSnapshot" in position_sl_resolver and
         "currentSL>0.0 && c<=currentSL" in position_sl_resolver and
         "currentSL>0.0 && c>=currentSL" in position_sl_resolver),
    ]
    include_errors = include_dependency_errors(path)
    checks.append(("recursive #include dependencies exist", not include_errors))
    errors = lexical_errors(source)
    checks.append(("balanced delimiters/comments/literals", not errors))
    failed = False
    for name, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {name}")
        failed |= not ok
    for error in errors:
        print(f"  {error}")
    for error in include_errors:
        print(f"  INCLUDE: {error}")

    # A source-level regression tripwire complements the check above; neither
    # this nor a passing run proves runtime correctness or compiler validity.
    single_proposal = ("ArrayResize(props,1)" in source or
                       "STB_ResolvePositionSL(ticket,props,1,finalSL,finalSource)" in source)
    if single_proposal:
        print("BLOCKER: SL candidates are still resolved one at a time; same-cycle arbitration is absent.")
    print("NOT COVERED: MetaEditor compilation, Strategy Tester, demo, broker compatibility, "
          "EX5 provenance, package/license review, profitability.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
