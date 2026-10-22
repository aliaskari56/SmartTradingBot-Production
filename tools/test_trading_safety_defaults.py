#!/usr/bin/env python3
"""Static regression guards for conservative EA defaults and trade gates.

These checks are deliberately source-level tripwires. They do not compile MQL5,
exercise the Strategy Tester, or certify the EA as safe or profitable.
"""
from pathlib import Path
import re
import sys

SOURCE = Path("MQL5/Experts/SmartTradingBot_FINAL.mq5")
PENDING_TRAIL_SOURCE = Path("MQL5/Include/STB/STB_PendingTrail.mqh")
WORKFLOW = Path(".github/workflows/mql5-compile.yml")


def input_default(name: str, source: str) -> str | None:
    match = re.search(
        rf"^\s*input\s+\w+\s+{re.escape(name)}\s*=\s*([^;]+);",
        source,
        re.MULTILINE,
    )
    return match.group(1).strip() if match else None


def strip_comments(source: str) -> str:
    """Remove MQL5 comments while preserving strings and line structure."""
    out = list(source)
    state = "code"
    quote = ""
    i = 0

    while i < len(source):
        char = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if state == "code":
            if char in ('"', "'"):
                state = "string"
                quote = char
            elif char == "/" and nxt == "/":
                out[i] = out[i + 1] = " "
                state = "line_comment"
                i += 1
            elif char == "/" and nxt == "*":
                out[i] = out[i + 1] = " "
                state = "block_comment"
                i += 1
        elif state == "string":
            if char == "\\":
                i += 1
            elif char == quote:
                state = "code"
        elif state == "line_comment":
            if char == "\n":
                state = "code"
            else:
                out[i] = " "
        elif state == "block_comment":
            if char == "*" and nxt == "/":
                out[i] = out[i + 1] = " "
                state = "code"
                i += 1
            elif char != "\n":
                out[i] = " "

        i += 1

    return "".join(out)


def strip_strings(source: str) -> str:
    """Blank string literals while preserving code and line structure."""
    out = list(source)
    state = "code"
    quote = ""
    i = 0

    while i < len(source):
        char = source[i]

        if state == "code":
            if char in ('"', "'"):
                state = "string"
                quote = char
                out[i] = " "
        elif state == "string":
            if char == "\\" and i + 1 < len(source):
                out[i] = " "
                if source[i + 1] != "\n":
                    out[i + 1] = " "
                i += 1
            elif char == quote:
                out[i] = " "
                state = "code"
            elif char != "\n":
                out[i] = " "

        i += 1

    return "".join(out)
def find_line_comment_marker(source: str, marker: str, start_offset: int) -> int:
    """Find a marker at a real // comment boundary, not inside strings or /* */."""
    state = "code"
    quote = ""
    i = 0

    while i < len(source):
        char = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if state == "code":
            if char in ('"', "'"):
                state = "string"
                quote = char
            elif char == "/" and nxt == "/":
                if i >= start_offset and source.startswith(marker, i):
                    return i
                state = "line_comment"
                i += 1
            elif char == "/" and nxt == "*":
                state = "block_comment"
                i += 1
        elif state == "string":
            if char == "\\":
                i += 1
            elif char == quote:
                state = "code"
        elif state == "line_comment":
            if char == "\n":
                state = "code"
        elif state == "block_comment":
            if char == "*" and nxt == "/":
                state = "code"
                i += 1

        i += 1

    return -1


def region(source: str, start: str, end: str) -> str:
    # Find the start in executable code so comments and strings cannot shadow
    # the function/branch signature. Legacy end markers can be comment banners,
    # so find those only when they begin a genuine // comment.
    code_view = strip_strings(strip_comments(source))
    begin = code_view.find(start)
    if begin < 0:
        return ""

    if end.lstrip().startswith("//"):
        finish = find_line_comment_marker(source, end, begin + len(start))
    else:
        finish = code_view.find(end, begin + len(start))

    if finish <= begin:
        return ""
    return strip_comments(source[begin:finish])


def main() -> int:
    if not SOURCE.is_file():
        print(f"FAIL: missing source: {SOURCE}")
        return 2

    source = SOURCE.read_text(encoding="utf-8")
    if not PENDING_TRAIL_SOURCE.is_file():
        print(f"FAIL: missing pending trail source: {PENDING_TRAIL_SOURCE}")
        return 2
    pending_trail_source = PENDING_TRAIL_SOURCE.read_text(encoding="utf-8")
    pending_trail_code = strip_strings(strip_comments(pending_trail_source))
    workflow = WORKFLOW.read_text(encoding="utf-8") if WORKFLOW.is_file() else ""
    source_code = strip_strings(strip_comments(source))
    permission_gate = region(
        source, "bool STB_TradeEnvironmentAllowed()", "bool IsSpreadAcceptable("
    )
    auto_gate = region(source, "bool STB_FinalAutoGate(", "//+------------------------------------------------------------------+")
    pending_check = region(
        source, "bool STB_CheckPendingOrderRequest(", "bool CheckPendingOrder("
    )
    pending_modify = region(
        source, "bool STB_ModifyPendingOrderGeometry(", "bool PreparePendingSetup("
    )
    auto_placement = region(
        source, "bool PlaceSetup(", "bool PlaceManualPendingDirection("
    )
    modify_retcode = region(
        source, "bool TradeRetcodeModifySucceeded()",
        "bool TradeRetcodePlacementSucceeded()"
    )
    placement_retcode = region(
        source, "bool TradeRetcodePlacementSucceeded()",
        "// Minimum distance required by the broker"
    )
    controlled_delete = region(
        source, "bool STB_ExecuteOrderDelete(", "bool STB_RequestOrderDelete("
    )
    hedge_placement = region(
        source, "bool OneClickHedge()", "//==================================================================\n// STOP VALIDATION"
    )
    manual_stop_placement = region(
        source, "bool PlaceManualPendingDirection(", "bool PlaceManualLimitDirection("
    )
    manual_limit_placement = region(
        source, "bool PlaceManualLimitDirection(", "STBCandidate g_scannerCurrent[];"
    )
    permission_gate_code = strip_strings(permission_gate)
    auto_gate_code = strip_strings(auto_gate)
    pending_check_code = strip_strings(pending_check)
    pending_modify_code = strip_strings(pending_modify)
    auto_placement_code = strip_strings(auto_placement)
    modify_retcode_code = strip_strings(modify_retcode)
    placement_retcode_code = strip_strings(placement_retcode)
    controlled_delete_code = strip_strings(controlled_delete)
    hedge_placement_code = strip_strings(hedge_placement)
    manual_stop_placement_code = strip_strings(manual_stop_placement)
    manual_limit_placement_code = strip_strings(manual_limit_placement)
    # Scope these checks to OnInit(); there are unrelated tester-mode checks
    # elsewhere in the EA, so a file-global substring search would be too broad.
    on_init = region(
        source, "int OnInit()", "//==================================================================\n// DEINIT"
    )
    tester_auto_branch = region(
        on_init, "if(MQLInfoInteger(MQL_TESTER))", "if(!InpAutoTrading)"
    )
    live_auto_branch = region(
        on_init, "if(!InpAutoTrading)", "trade.SetExpertMagicNumber(InpMagic);"
    )
    # Use the string-aware comment stripper consistently; a regex alone can
    # mistake comment markers inside quoted source strings for real comments.
    tester_auto_branch_code = strip_strings(tester_auto_branch)
    live_auto_branch_code = strip_strings(live_auto_branch)
    tester_auto_branch_compact = re.sub(r"\s+", "", tester_auto_branch_code)
    live_auto_branch_compact = re.sub(r"\s+", "", live_auto_branch_code)
    on_init_compact = re.sub(r"\s+", "", strip_strings(on_init))
    risk_sizing = region(
        source, "double CalculateOrderVolumeByRisk(", "bool STB_LogPlaceReject("
    )
    volume_normalizer = region(
        source, "double NormalizeVolume(", "bool GetRates("
    )
    daily_risk_guard = region(
        source, "bool STB_DailyLossLimitHit()",
        "// UNIVERSAL PROFIT LOCK POLICY"
    )
    daily_risk_guard_code = strip_strings(daily_risk_guard)
    daily_risk_enforcer = region(
        source, "void STB_EnforceDailyRiskGuard()",
        "void STB_RunManagementCycle()"
    )
    daily_risk_enforcer_code = strip_strings(daily_risk_enforcer)
    trade_transaction = region(
        source, "void OnTradeTransaction(", "void STB_ToggleDashboard()"
    )
    trade_transaction_code = strip_strings(strip_comments(trade_transaction))

    # Exercise the stripper itself against comment markers inside strings,
    # both comment styles, and line preservation. Static source checks alone
    # would not catch a broken comment parser.
    comment_sample = (
        'string url="https://example.test/a/*kept*/"; // line comment\n'
        '/* block comment\ncontinued */ int value=1;\n'
    )
    stripped_sample = strip_comments(comment_sample)
    stripper_preserves_strings = '"https://example.test/a/*kept*/"' in stripped_sample
    stripper_removes_comments = (
        "line comment" not in stripped_sample
        and "block comment" not in stripped_sample
        and "continued" not in stripped_sample
    )
    stripper_preserves_lines = (
        stripped_sample.count("\n") == comment_sample.count("\n")
    )
    commented_input_sample = (
        "/* configuration example\n"
        "input bool InpAutoTrading = true;\n"
        "*/\n"
        "input bool InpAutoTrading = false;\n"
    )
    commented_input_is_ignored = (
        input_default("InpAutoTrading", strip_strings(strip_comments(commented_input_sample)))
        == "false"
    )
    code_only_sample = strip_strings(strip_comments(
        'string message="escaped \\" quote /*token*/ // text"; // comment\n'
        'trade.OrderDelete(123);\n'
    ))
    strings_do_not_trigger_code_guards = "TRADE_ACTION_REMOVE" not in code_only_sample
    code_calls_survive_string_removal = "trade.OrderDelete(123);" in code_only_sample
    region_sample = (
        "/* bool Target() { int wrong=1; } */\n"
        'string note="bool Target() { int fake=1; }";\n'
        "bool Target() { int expected=1; }\n"
        'string terminator="// END";\n'
        "/* // END */\n"
        "// END\n"
        "bool Next() { int tail=1; }\n"
    )
    selected_region = region(region_sample, "bool Target()", "// END")
    region_ignores_comment_and_string_signatures = (
        "expected=1;" in selected_region
        and "wrong=1;" not in selected_region
        and "fake=1;" not in selected_region
        and "terminator" in selected_region
        and "tail=1;" not in selected_region
    )
    region_fails_closed_when_boundary_missing = (
        region(region_sample, "bool Target()", "missing boundary") == ""
    )

    checks = (
        ("comment stripper preserves comment-like text inside strings",
         stripper_preserves_strings),
        ("comment stripper removes line/block comments",
         stripper_removes_comments),
        ("comment stripper preserves newline count",
         stripper_preserves_lines),
        ("commented-out input declarations cannot satisfy default checks",
         commented_input_is_ignored),
        ("string contents cannot trigger code-only request guards",
         strings_do_not_trigger_code_guards),
        ("actual code calls remain visible after string removal",
         code_calls_survive_string_removal),
        ("region extraction ignores commented and quoted signatures",
         region_ignores_comment_and_string_signatures),
        ("region extraction fails closed when a boundary is missing",
         region_fails_closed_when_boundary_missing),
        ("live auto-trading is opt-in by default",
         input_default("InpAutoTrading", source_code) == "false"),
        ("bounded equity-risk sizing is enabled by default",
         input_default("InpUseRiskSizing", source_code) == "true"),
        ("risk sizing derives one-lot stop loss from OrderCalcProfit and fails closed on calculation errors",
         bool(risk_sizing) and
         "AccountInfoDouble(ACCOUNT_EQUITY)" in risk_sizing and
         "equity*(InpRiskPercent/100.0)" in risk_sizing and
         "OrderCalcProfit(orderType,s.symbol,1.0,s.entry,s.sl,lossForOneLot)" in risk_sizing and
         "if(!OrderCalcProfit(" in risk_sizing and
         "return 0.0;" in risk_sizing),
        ("risk sizing rejects a broker minimum lot that exceeds the requested risk budget",
         bool(risk_sizing) and
         "if(raw+1e-9<minLot)" in risk_sizing and
         "if(InpMaxRiskVolume>0.0 && volume>InpMaxRiskVolume+1e-9)" in risk_sizing),
        ("volume normalization never upgrades zero or undersized requests to broker minimum",
         bool(volume_normalizer) and
         "volume<=0.0" in volume_normalizer and
         "if(volume+1e-9<minLot)" in volume_normalizer and
         "return 0.0;" in volume_normalizer and
         "volume=MathFloor(volume/step+1e-9)*step;" in volume_normalizer),
        ("volume precision follows arbitrary broker step and validates the final step grid",
         bool(volume_normalizer) and
         "double scaledStep=step*MathPow(10.0,d);" in volume_normalizer and
         "MathAbs(scaledStep-MathRound(scaledStep))<=1e-8" in volume_normalizer and
         "double stepUnits=normalized/step;" in volume_normalizer and
         "MathAbs(stepUnits-MathRound(stepUnits))>1e-7" in volume_normalizer and
         "int digits=2;" not in volume_normalizer),
        ("build provenance manifest matches actual AUTO and risk-sizing defaults",
         input_default("InpAutoTrading", source_code) == "false"
         and input_default("InpUseRiskSizing", source_code) == "true"
         and "liveAutoTradingDefault = $false" in workflow
         and "riskSizingDefault = $true" in workflow
         and "riskSizingDefault = $false" not in workflow),
        ("scanner rejects stale quotes after one minute by default",
         input_default("InpScannerMaxQuoteAgeSec", source_code) == "60"),
        ("scanner quote age input is bounded and used consistently by eligibility and freshness scoring",
         "InpScannerMaxQuoteAgeSec<1" in source_code
         and "InpScannerMaxQuoteAgeSec>3600" in source_code
         and "ageSeconds>(long)InpScannerMaxQuoteAgeSec" in source_code
         and "age>(long)InpScannerMaxQuoteAgeSec" in source_code
         and "(double)age/(double)InpScannerMaxQuoteAgeSec" in source_code
         and "MathMax(30,InpScannerMaxQuoteAgeSec)" not in source_code),
        ("daily and adaptive tester state are isolated by a fresh run namespace",
         "bool STB_InitRunNamespace()" in source_code
         and "g_stbRunNamespace" in source_code
         and '"|TESTER|RUN|"+g_stbRunNamespace' in source
         and "if(!STB_InitRunNamespace())" in source_code),
        ("daily loss guard attempts to close only EA-owned positions and verifies retcode",
         "PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic" in source_code
         and "trade.PositionClose(ticket)" in source_code
         and "closeRetcode!=TRADE_RETCODE_DONE" in source_code),
        ("live initialization forces AUTO off when input is false",
         "if(!InpAutoTrading){g_autoTrading=false;GlobalVariableSet(g_autoStateName,0.0);}"
         in live_auto_branch_compact),
        ("tester AUTO branch is located inside OnInit",
         bool(on_init) and bool(tester_auto_branch)),
        ("tester AUTO override is isolated from live initialization",
         "g_autoTrading=(InpAutoTrading||InpTesterForceAutoTrading);" in tester_auto_branch_compact
         and "}elseif(!InpAutoTrading){" in on_init_compact
         and bool(live_auto_branch)
         and "InpTesterForceAutoTrading" not in live_auto_branch_compact),
        ("trade gate checks terminal, program, account-expert and account permissions",
         bool(permission_gate_code) and all(token in permission_gate_code for token in (
             "TERMINAL_TRADE_ALLOWED", "MQL_TRADE_ALLOWED",
             "ACCOUNT_TRADE_EXPERT", "ACCOUNT_TRADE_ALLOWED"))),
        ("automatic execution gate checks AUTO state, permissions and exposure",
         bool(auto_gate_code) and all(token in auto_gate_code for token in (
             "!g_autoTrading", "!STB_TradeEnvironmentAllowed()",
             "!STB_ExposureAllowsExecution(s,reason)"))),
        ("shared pending-order preflight checks OrderCheck boolean and retcode for explicit order geometry",
         bool(pending_check_code) and "if(!OrderCheck(request,check))" in pending_check_code
         and "check.retcode!=0" in pending_check_code
         and "request.type=orderType;" in pending_check_code
         and "request.magic=magic;" in pending_check_code
         and "request.type_filling=ORDER_FILLING_RETURN;" in pending_check_code),
        ("pending-order modification preflight is scoped to geometry writer",
         bool(pending_modify_code)
         and "bool pendingOrderCheckOK=OrderCheck(req,check);" in pending_modify_code
         and "if(!pendingOrderCheckOK)" in pending_modify_code
         and "check.retcode!=0" in pending_modify_code
         and "pendingOrderCheckLastError=GetLastError();" in pending_modify_code),
        ("pending-trail backoff and cooldown gates precede candle consumption",
         bool(pending_trail_code)
         and "nextRetryTime>TimeCurrent()" in pending_trail_code
         and "lastModifyTime+STB_PEND_TRAIL_COOLDOWN_SEC" in pending_trail_code
         and pending_trail_code.index("if(g_stbPendingTrail[idx].nextRetryTime>TimeCurrent())")
             < pending_trail_code.index("datetime closedBar=iTime(symbol,PERIOD_M5,1)")),
        ("pending-trail only submits from the verified symbol lease owner",
         "STB_SymbolManagementOwnedVerified(managedSymbol)" in pending_trail_code
         and "if(!STB_SymbolManagementOwnedVerified(managedSymbol))" in pending_trail_code),
        ("pending-trail retry delay is bounded and increases after consecutive failures",
         all(token in pending_trail_code for token in (
             "STB_PEND_BACKOFF_1_SEC", "STB_PEND_BACKOFF_2_SEC",
             "STB_PEND_BACKOFF_3_SEC", "failureCount++",
             "nextRetryTime=TimeCurrent()+backoffSec"))),
        ("pending-trail classifies false writer outcomes without stale CTrade retcodes",
         bool(re.search(
             r"int STB_PendingClassifyResult\(const bool ok\)\s*\{[^}]*return STB_PEND_RES_OTHER_FAILURE;",
             pending_trail_code, re.DOTALL))
         and "trade.ResultRetcode()" not in region(
             pending_trail_source, "int STB_PendingClassifyResult(",
             "//--- Register a real terminal pending order")),
        ("stop-limit child price snapshot is revalidated after OrderCheck",
         bool(pending_modify_code)
         and "double stbCurStopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);" in pending_modify_code
         and "double latestStopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);" in pending_modify_code
         and "MathAbs(latestStopLimit-stbCurStopLimit)>latestTolerance" in pending_modify_code),
        ("pending modification revalidates expiration policy after OrderCheck",
         bool(pending_modify_code)
         and "ENUM_ORDER_TYPE_TIME typeTime=" in pending_modify_code
         and "datetime expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);" in pending_modify_code
         and "(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME)!=typeTime" in pending_modify_code
         and "(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION)!=expiration" in pending_modify_code),
        ("pending modification rejects prices outside the tradable tick grid",
         bool(pending_modify_code)
         and "double pendingTickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);" in pending_modify_code
         and "if(pendingTickSize<=0.0)" in pending_modify_code
         and "MathAbs(newEntry-MathRound(newEntry/pendingTickSize)*pendingTickSize)<=pendingGridTolerance" in pending_modify_code
         and "MathAbs(newSL-MathRound(newSL/pendingTickSize)*pendingTickSize)<=pendingGridTolerance" in pending_modify_code
         and "MathAbs(newTP-MathRound(newTP/pendingTickSize)*pendingTickSize)<=pendingGridTolerance" in pending_modify_code
         and "pendingPricesOnTickGrid" in pending_modify_code),
        ("pending modification rechecks type-specific entry distance against live quotes",
         "bool STB_IsPendingEntryBrokerValid(" in source_code
         and "case ORDER_TYPE_BUY_STOP:" in source_code
         and "case ORDER_TYPE_BUY_STOP_LIMIT:" in source_code
         and "case ORDER_TYPE_SELL_STOP:" in source_code
         and "case ORDER_TYPE_SELL_STOP_LIMIT:" in source_code
         and "case ORDER_TYPE_BUY_LIMIT:" in source_code
         and "case ORDER_TYPE_SELL_LIMIT:" in source_code
         and "STB_IsPendingEntryBrokerValid(symbol,(ENUM_ORDER_TYPE)stbOt,newEntry)" in pending_modify_code
         and pending_modify_code.count("STB_IsPendingEntryBrokerValid(symbol,(ENUM_ORDER_TYPE)stbOt,newEntry)") >= 2),
        ("pending modification broker guards reject stale or invalid quotes",
         "bool STB_IsPendingEntryBrokerValid(" in source_code
         and "bool IsValidSLForPendingOrder(" in source_code
         and source_code.count("!STB_ScannerQuoteValid(tick,quoteReason)") >= 2
         and "tick.ask<tick.bid" in source_code),
        ("pending limit broker-distance checks use the correct quote side",
         "case ORDER_TYPE_BUY_LIMIT:" in source_code
         and "return entry<tick.ask-minDist;" in source_code
         and "case ORDER_TYPE_SELL_LIMIT:" in source_code
         and "return entry>tick.bid+minDist;" in source_code),
        ("pending-order modification checks server retcode and verified final geometry",
         bool(pending_modify_code)
         and "if(!TradeRetcodeModifySucceeded())" in pending_modify_code
         and "if(!OrderSelect(ticket))" in pending_modify_code
         and "MathAbs(ve-newEntry)>tolerance" in pending_modify_code
         and "STB_GeomStore(ticket,false,ve,vs,vt)" in pending_modify_code),
        ("modify success helper excludes partial execution and restricts accepted server retcodes",
         bool(modify_retcode_code)
         and "TRADE_RETCODE_DONE" in modify_retcode_code
         and "TRADE_RETCODE_DONE_PARTIAL" not in modify_retcode_code
         and "TRADE_RETCODE_NO_CHANGES" in modify_retcode_code
         and "TRADE_RETCODE_ORDER_CHANGED" in modify_retcode_code),
        ("central pending delete requires authorization, server success and ticket disappearance",
         bool(controlled_delete_code)
         and "if(!authorized)" in controlled_delete_code
         and "bool requestOK=trade.OrderDelete(ticket);" in controlled_delete_code
         and "if(!requestOK || ret!=TRADE_RETCODE_DONE)" in controlled_delete_code
         and "TRADE_RETCODE_DONE_PARTIAL" not in controlled_delete_code
         and "if(OrderSelect(ticket))" in controlled_delete_code
         and "STB DELETE CONFIRMED" in controlled_delete),
        ("all broker pending-order deletion goes through the central writer",
         source_code.count("trade.OrderDelete(") == 1
         and "bool requestOK=trade.OrderDelete(ticket);" in controlled_delete_code),
        ("no raw TRADE_ACTION_REMOVE request bypasses the central delete writer",
         "TRADE_ACTION_REMOVE" not in source_code),
        ("rollback deletion requires known creator, matching comment and a fresh order",
         bool(controlled_delete)
         and "bool knownCreator=" in controlled_delete
         and "bool creatorCommentMatches=" in controlled_delete
         and "authorized=knownCreator && stbComment && creatorCommentMatches &&" in controlled_delete
         and "setupTime>0 && setupTime<=TimeCurrent()+5" in controlled_delete
         and "TimeCurrent()-setupTime<=120" in controlled_delete),
        ("automatic pending placement checks server result and initial SL",
         bool(auto_placement_code)
         and "trade.BuyStop(" in auto_placement_code
         and "trade.SellStop(" in auto_placement_code
         and "STB_ReconcilePendingSubmit(s.symbol,finalPendingType" in auto_placement_code
         and "STB_MarkPendingSubmitUnknown(s.symbol,(ulong)InpMagic,finalPendingType" in auto_placement_code
         and "trade.ResultRetcode()" in auto_placement_code
         and "VerifyPendingInitialSL(" in auto_placement_code),
        ("automatic placement requests rollback if initial SL cannot be verified",
         "if(placedOrder>0 && OrderSelect(placedOrder))" in strip_strings(auto_placement)
         and "STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK," in strip_strings(auto_placement)
         and strip_strings(auto_placement).find("VerifyPendingInitialSL(placedOrder)")
         < strip_strings(auto_placement).find("STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK,")),
        ("automatic placement repeats OrderCheck at final submit boundary using exact order type and metadata",
         bool(auto_placement_code)
         and "STB_CheckPendingOrderRequest(s.symbol,finalPendingType,volume," in auto_placement_code
         and "finalPendingType=(s.direction>0?ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP);" in re.sub(r"\s+", "", auto_placement_code)
         and auto_placement_code.rfind("STB_CheckPendingOrderRequest(s.symbol,finalPendingType,volume,")
             < auto_placement_code.rfind("trade.BuyStop(")),
        ("pending placement success helper accepts DONE and PLACED only",
         bool(placement_retcode_code)
         and all(token in placement_retcode_code for token in (
             "TRADE_RETCODE_DONE", "TRADE_RETCODE_PLACED"))
         and "TRADE_RETCODE_DONE_PARTIAL" not in placement_retcode_code
         and "TRADE_RETCODE_NO_CHANGES" not in placement_retcode_code),
        ("directional symbol permissions are checked before auto placement",
         bool(auto_placement_code)
         and "if(!IsDirectionTradable(s.symbol,s.direction))" in auto_placement_code),
        ("one-click hedge preflights its pending request before broker submission",
         bool(hedge_placement_code)
         and "STB_CheckPendingOrderRequest(symbol,hedgeOrderType,volume,entry,sl,0.0" in hedge_placement_code
         and hedge_placement_code.index("STB_CheckPendingOrderRequest(") <
             hedge_placement_code.index("trade.BuyStop(")),
        ("one-click hedge validates server result and initial SL with rollback",
         bool(hedge_placement_code)
         and "trade.BuyStop(" in hedge_placement_code
         and "trade.SellStop(" in hedge_placement_code
         and "STB_ReconcilePendingSubmit(symbol,hedgeOrderType" in hedge_placement_code
         and "STB_MarkPendingSubmitUnknown(symbol,(ulong)InpMagic,hedgeOrderType" in hedge_placement_code
         and "VerifyPendingInitialSL(hedgeOrder)" in hedge_placement_code
         and "STB_RequestOrderDelete(hedgeOrder,STB_DEL_AUTO_ROLLBACK," in hedge_placement_code),
        ("hedge rechecks directional volume after fresh-quote validation and before OrderCheck",
         bool(hedge_placement_code)
         and hedge_placement_code.count("STB_DirectionVolumeWithinLimit") >= 2
         and hedge_placement_code.rfind("STB_DirectionVolumeWithinLimit") > hedge_placement_code.find("STB_ScannerQuoteValid")
         and hedge_placement_code.rfind("STB_DirectionVolumeWithinLimit") < hedge_placement_code.find("STB_CheckPendingOrderRequest")),
        ("manual stop rechecks directional volume after fresh-quote validation and before OrderCheck",
         bool(manual_stop_placement_code)
         and manual_stop_placement_code.count("STB_DirectionVolumeWithinLimit") >= 2
         and manual_stop_placement_code.rfind("STB_DirectionVolumeWithinLimit") > manual_stop_placement_code.find("STB_ScannerQuoteValid")
         and manual_stop_placement_code.rfind("STB_DirectionVolumeWithinLimit") < manual_stop_placement_code.find("STB_CheckPendingOrderRequest")),
        ("manual limit rechecks directional volume after fresh-quote validation and before OrderCheck",
         bool(manual_limit_placement_code)
         and manual_limit_placement_code.count("STB_DirectionVolumeWithinLimit") >= 2
         and manual_limit_placement_code.rfind("STB_DirectionVolumeWithinLimit") > manual_limit_placement_code.find("STB_ScannerQuoteValid")
         and manual_limit_placement_code.rfind("STB_DirectionVolumeWithinLimit") < manual_limit_placement_code.find("STB_CheckPendingOrderRequest")),
        ("duplicate pending helper matches symbol, exact order type and owner magic",
         "bool STB_HasDuplicatePendingType(" in source
         and "OrderGetString(ORDER_SYMBOL)!=symbol" in source
         and "OrderGetInteger(ORDER_TYPE)!=orderType" in source
         and "OrderGetInteger(ORDER_MAGIC)!=magic" in source
         and "StringFind(existingComment,\"STB|M|\")!=0" in source
         and "StringFind(existingComment,\"STB|\")!=0" in source),
        ("automatic pending path blocks duplicate same-type order before final OrderCheck",
         "STB_HasDuplicatePendingType(s.symbol,finalPendingType" in auto_placement_code
         and auto_placement_code.index("STB_HasDuplicatePendingType(")
             < auto_placement_code.rfind("STB_CheckPendingOrderRequest(")),
        ("manual stop path blocks duplicate same-type order before OrderCheck",
         "STB_HasDuplicatePendingType(_Symbol,manualStopType,0)" in manual_stop_placement_code
         and manual_stop_placement_code.index("STB_HasDuplicatePendingType(")
             < manual_stop_placement_code.index("STB_CheckPendingOrderRequest(")),
        ("manual limit path blocks duplicate same-type order before OrderCheck",
         "STB_HasDuplicatePendingType(_Symbol,manualLimitType,0)" in manual_limit_placement_code
         and manual_limit_placement_code.index("STB_HasDuplicatePendingType(")
             < manual_limit_placement_code.index("STB_CheckPendingOrderRequest(")),
        ("hedge path blocks duplicate same-type order before OrderCheck",
         "STB_HasDuplicatePendingType(symbol,hedgeOrderType" in hedge_placement_code
         and hedge_placement_code.index("STB_HasDuplicatePendingType(")
             < hedge_placement_code.index("STB_CheckPendingOrderRequest(")),
        ("ambiguous pending submissions reconcile exact active order signature",
         "bool STB_ReconcilePendingSubmit(" in source
         and "ORDER_COMMENT)!=comment" in source
         and "ORDER_VOLUME_INITIAL)-volume" in source
         and "ORDER_PRICE_OPEN)-entry" in source
         and "matches==1" in source
         and "matches>1" in source),
        ("unresolved pending submission quarantines retries and expires safely",
         "void STB_MarkPendingSubmitUnknown(" in source
         and "TimeLocal()+90" in source
         and "GlobalVariableSet(key" in source
         and "prior request unresolved" in source
         and "GlobalVariableDel(unknownKey)" in source),
        ("restart recovery rebuilds pending trail state from active managed orders",
         "STB_PendingTrailRebuildFromTerminal();" in source
         and "int STB_PendingTrailRebuildFromTerminal()" in pending_trail_source
         and "STB_PendingTrailRegister(ticket,\"RESTART_RECOVERY\")" in pending_trail_source),
        ("pending setup validation rejects stale or invalid market quotes",
         "STB_ScannerQuoteValid(tick,quoteReason)" in source
         and "STB PENDING SETUP REJECT: invalid/stale quote" in source),
        ("manual stop placement preflights the exact pending type before broker submission",
         bool(manual_stop_placement_code)
         and "STB_CheckPendingOrderRequest(_Symbol,manualStopType,volume,entry,sl,0.0" in manual_stop_placement_code
         and manual_stop_placement_code.index("STB_CheckPendingOrderRequest(") <
             manual_stop_placement_code.index("trade.BuyStop(")),
        ("manual stop placement validates server result and initial SL with rollback",
         bool(manual_stop_placement_code)
         and "trade.BuyStop(" in manual_stop_placement_code
         and "trade.SellStop(" in manual_stop_placement_code
         and "STB_ReconcilePendingSubmit(_Symbol,manualStopType,0" in manual_stop_placement_code
         and "STB_MarkPendingSubmitUnknown(_Symbol,0,manualStopType" in manual_stop_placement_code
         and "VerifyPendingInitialSL(ticket)" in manual_stop_placement_code
         and "STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK," in manual_stop_placement_code),
        ("manual limit placement preflights the exact pending type before broker submission",
         bool(manual_limit_placement_code)
         and "STB_CheckPendingOrderRequest(_Symbol,manualLimitType,volume,entry,sl,0.0" in manual_limit_placement_code
         and manual_limit_placement_code.index("STB_CheckPendingOrderRequest(") <
             manual_limit_placement_code.index("trade.BuyLimit(")),
        ("manual limit placement validates server result and initial SL with rollback",
         bool(manual_limit_placement_code)
         and "trade.BuyLimit(" in manual_limit_placement_code
         and "trade.SellLimit(" in manual_limit_placement_code
         and "STB_ReconcilePendingSubmit(_Symbol,manualLimitType,0" in manual_limit_placement_code
         and "STB_MarkPendingSubmitUnknown(_Symbol,0,manualLimitType" in manual_limit_placement_code
         and "VerifyPendingInitialSL(ticket)" in manual_limit_placement_code
         and "STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK," in manual_limit_placement_code),
        ("daily equity guard fails closed on invalid clock/equity and failed persistence",
         bool(daily_risk_guard_code)
         and "if(now<=0 || !TimeToStruct(now,nowParts))" in daily_risk_guard_code
         and "if(!MathIsValidNumber(equity) || equity<=0.0)" in daily_risk_guard_code
         and "if(!STB_DailyRiskPersist(dayKey,equity,false))" in daily_risk_guard_code
         and "return true;" in daily_risk_guard_code),
        ("daily equity guard blocks a damaged same-day baseline instead of resetting it",
         bool(daily_risk_guard_code)
         and "bool anyStatePresent=" in daily_risk_guard_code
         and "if(!GlobalVariableCheck(dayName))" in daily_risk_guard_code
         and "storedDay>=(double)dayKey" in daily_risk_guard_code
         and "STB DAILY RISK STATE CORRUPT/DATE REGRESSION: entries blocked." in daily_risk_guard),
        ("daily equity enforcement fails closed and scopes forced closes to this EA magic",
         bool(daily_risk_enforcer_code)
         and "if(!STB_DailyLossLimitHit())" in daily_risk_enforcer_code
         and "POSITION_MAGIC)!=(long)InpMagic" in daily_risk_enforcer_code
         and "orderMagic==(long)InpMagic" in daily_risk_enforcer_code
         and "STB_RequestOrderDelete(ticket,STB_DEL_DAILY_RISK_GUARD" in daily_risk_enforcer_code),
        ("automatic and manual pending entry paths call the daily equity guard before submission",
         "if(STB_DailyLossLimitHit())" in auto_placement_code
         and "if(STB_DailyLossLimitHit())" in manual_stop_placement_code
         and "if(STB_DailyLossLimitHit())" in manual_limit_placement_code
         and "if(STB_DailyLossLimitHit())" in hedge_placement_code),
        ("tracked adaptive lifecycles include manual/foreign-magic close PnL but reject unrelated foreign trades",
         bool(trade_transaction)
         and "bool isLifecycleClose=" in trade_transaction_code
         and "bool hasTrackedAdaptiveLifecycle=" in trade_transaction_code
         and "!(isLifecycleClose && hasTrackedAdaptiveLifecycle)" in trade_transaction_code
         and trade_transaction_code.index("STB_AdaptiveReadPositionProfile(positionId)>=0")
             < trade_transaction_code.index("if(magic!=(long)InpMagic")
         and "if(entryType==DEAL_ENTRY_IN && positionId>0)" in trade_transaction_code
         and "if(isHedge)" in trade_transaction_code),
        ("closed adaptive lifecycle PnL is reconstructed from broker history after restart",
         "bool STB_SumClosedLifecyclePnlFromHistory(" in source
         and "HistorySelectByPosition(positionId)" in source
         and "entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY" in source
         and "lastReversalDeal" in source
         and "DEAL_TIME_MSC" in source
         and "DEAL_ENTRY_INOUT" in source
         and "STB_SumClosedLifecyclePnlFromHistory(positionId,historyLifecyclePnl)" in trade_transaction_code
         and trade_transaction_code.index("TakeAccumulatedPositionPnl(positionId)")
             < trade_transaction_code.index("STB_SumClosedLifecyclePnlFromHistory(positionId,historyLifecyclePnl)")),
        ("INOUT reversal closes old adaptive state before initializing a distinct active reverse lifecycle",
         bool(trade_transaction)
         and "if(entryType==DEAL_ENTRY_INOUT)" in trade_transaction_code
         and "STB_AdaptiveDeletePositionProfile(positionId)" in trade_transaction_code
         and "STB_AdaptiveDeletePositionRisk(positionId)" in trade_transaction_code
         and "if(PositionSelect(symbol))" in trade_transaction_code
         and "POSITION_IDENTIFIER" in trade_transaction_code
         and "STB_AdaptiveRememberPositionProfile(newPositionId,newProfileId)" in trade_transaction_code
         and "STB_AdaptiveRememberPositionRisk(newPositionId,newRiskMoney)" in trade_transaction_code
         and trade_transaction_code.index("STB_AdaptiveDeletePositionProfile(positionId)")
             < trade_transaction_code.index("STB_AdaptiveRememberPositionProfile(newPositionId,newProfileId)")),
        ("INOUT reversal validates opposite exposure and preserves order state when transfer cannot be confirmed",
         "newPositionType==POSITION_TYPE_BUY" in trade_transaction_code
         and "newPositionType==POSITION_TYPE_SELL" in trade_transaction_code
         and "activeReversalPosition && newProfileId>=0" in trade_transaction_code
         and "order state retained for reconciliation" in trade_transaction
         and "STB_AdaptiveDeleteOrderState(trans.order)" in trade_transaction_code),
    )

    failed = False
    for label, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {label}")
        failed |= not ok

    print("LIMITATION: static checks cannot validate runtime behavior, broker "
          "execution, compiler compatibility, backtests, or profitability.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
