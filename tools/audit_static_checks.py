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
    market_quality = source_region(
        source, "bool STB_CalcMarketQuality(", "bool STB_EvaluateRegime(")
    scanner_run = source_region(
        source, "void STB_ScannerRun()", "void STB_DashDeleteAll()")
    final_revalidation = source_region(
        source, "bool STB_FinalCandidateRevalidation(",
        "// Serialize final scanner revalidation/submission")
    initial_pending_sl = source_region(
        source, "bool CalculateInitialPendingProtectionSL(",
        "bool VerifyPendingInitialSL(")
    checks: list[tuple[str, bool]] = [
        ("live automatic trading remains opt-in by default",
         "input bool    InpAutoTrading            = false;" in source),
        ("risk-based sizing remains opt-in by default",
         "input bool    InpUseRiskSizing         = false;" in source),
        ("tester AUTO override is confined to tester initialization; live input-off remains authoritative",
         "MQL_TESTER" in on_init and
         "g_autoTrading=(InpAutoTrading ||" in on_init and
         "if(!InpAutoTrading)" in on_init),
        ("BUY STOP/SELL STOP initial SL anchors to closed M5 structure and validates broker geometry",
         "if(orderType==ORDER_TYPE_BUY_STOP || orderType==ORDER_TYPE_SELL_STOP)" in initial_pending_sl and
         "iLow(symbol,PERIOD_M5,1)" in initial_pending_sl and
         "iHigh(symbol,PERIOD_M5,1)" in initial_pending_sl and
         "IsValidSLForPendingOrder(symbol,orderType,entryPrice,candleSL)" in initial_pending_sl),
        ("pending STOP trailing reads a closed M5 bar once and validates OHLC before consuming it",
         bool(trail_source) and
         "datetime lastProcessedM5Bar;" in trail_source and
         "datetime closedBar=iTime(symbol,PERIOD_M5,1);" in trail_source and
         "closedBar==g_stbPendingTrail[idx].lastProcessedM5Bar" in trail_source and
         "double barOpen=iOpen(symbol,PERIOD_M5,1);" in trail_source and
         "g_stbPendingTrail[idx].lastProcessedM5Bar=closedBar;" in trail_source),
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
        ("final scanner-to-execution handoff rechecks effective setup age",
          "iBarShift(c.symbol,PERIOD_M15,refreshed.setupTime,true)" in final_revalidation and
          "STB_EffectiveMaxSetupAgeBars()" in final_revalidation and
          'c.rejectReason="REJECT_SETUP_TOO_OLD";' in final_revalidation and
          final_revalidation.index("if(effectiveMaxAge>0 && c.setupAgeBars>effectiveMaxAge)") <
          final_revalidation.index("if(!ValidatePendingSetup(refreshed))")),
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
        ("arbitration confirmation rejects missing SL before profit-lock bookkeeping",
         (lambda body: bool(body) and "if(actualSL<=0.0)" in body and
          body.index("if(actualSL<=0.0)") < body.index("if(hasProfitCandidate)") and
          "STB SL arbitration verification failed: position has no SL" in body)
          (source_region(source, "void STB_FlushPositionSLProposals()", "// APPLY PROFIT LOCK"))),
        ("partial exits preserve SL-lock state; full close and reversal clear it before magic filtering",
         (lambda body: bool(body) and
          body.find("if(entryType==DEAL_ENTRY_OUT") >= 0 and
          body.find("if(entryType==DEAL_ENTRY_OUT") < body.find("if(magic!=(long)InpMagic)") and
          "bool positionRemains=PositionSelectByTicket(closedTicket);" in body and
          "bool exposureReversed=(entryType==DEAL_ENTRY_INOUT);" in body and
          "if(exposureReversed || !positionRemains)" in body and
          body.find("if(exposureReversed || !positionRemains)") <
              body.find("GlobalVariableDel(TicketLockName(closedTicket));") <
              body.find("if(magic!=(long)InpMagic)"))
          (source_region(source, "void OnTradeTransaction(", "if(entryType==DEAL_ENTRY_IN && !isHedge"))),
        ("resolver enforces price-move profit-lock floor and deterministic no-SL fallback",
         all(token in source for token in (
             "decisionPriceMovePips=STB_PositionPriceMovePips(ticket);",
             "decisionPriceMovePips>=STB_ProfitLockTriggerPips()",
             "bool enforceProfitLockFloor=",
             "profitLockTarget=NormalizePrice(symbol,",
             "bool meetsProfitLockFloor=!enforceProfitLockFloor ||",
             "currentSL<=0.0 && props[i].source!=STB_SL_SRC_PROFIT_PROTECTION",
             "if(!found && unprotectedFallbackFound)",
             "props[i].source<unprotectedFallbackSource")) and
         source.find("bool meetsProfitLockFloor=!enforceProfitLockFloor ||") <
             source.find("if(!meetsProfitLockFloor)") and
         source.find("if(!found && unprotectedFallbackFound)") <
             source.find("if(!found || !IsValidSLForPosition(symbol,side,finalSL))")),
        ("profit-lock state is committed only when the actual SL satisfies the lock target",
         (lambda body: bool(body) and
          "double lockTargetSL=" in body and
          "bool lockTargetConfirmed=" in body and
          "if(lockTargetConfirmed)" in body and
          body.find("if(lockTargetConfirmed)") < body.find("SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));"))
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
        ("HTF and structural trail floating inputs are finite-checked",
         all(token in source for token in (
             "!MathIsValidNumber(InpHTFZoneMaxGapATR)",
             "!MathIsValidNumber(InpHTFMinFVGWidthATR)",
             "!MathIsValidNumber(InpStructuralTrailStartATR)",
             "!MathIsValidNumber(InpStructuralTrailBufferATR)"))),
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
