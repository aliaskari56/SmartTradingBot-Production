#!/usr/bin/env python3
"""Static regression guards for conservative EA defaults and trade gates.

These checks are deliberately source-level tripwires. They do not compile MQL5,
exercise the Strategy Tester, or certify the EA as safe or profitable.
"""
from pathlib import Path
import re
import sys

SOURCE = Path("MQL5/Experts/SmartTradingBot_FINAL.mq5")


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
    source_code = strip_strings(strip_comments(source))
    permission_gate = region(
        source, "bool STB_TradeEnvironmentAllowed()", "bool IsSpreadAcceptable("
    )
    auto_gate = region(source, "bool STB_FinalAutoGate(", "//+------------------------------------------------------------------+")
    pending_check = region(
        source, "bool CheckPendingOrder(", "bool GetPendingLifetime("
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
        ("risk-based sizing is opt-in by default",
         input_default("InpUseRiskSizing", source_code) == "false"),
        ("live initialization forces AUTO off when input is false",
         "if(!InpAutoTrading){g_autoTrading=false;GlobalVariableSet(g_autoStateName,0.0);}"
         in live_auto_branch_compact),
        ("tester AUTO branch is located inside OnInit",
         bool(on_init) and bool(tester_auto_branch)),
        ("tester AUTO override is isolated from live initialization",
         "g_autoTrading=(InpAutoTrading&&InpTesterForceAutoTrading);" in tester_auto_branch_compact
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
             "!STB_ExposureAllowsExecution(s)"))),
        ("pending-order preflight checks OrderCheck boolean and retcode",
         bool(pending_check_code) and "if(!OrderCheck(request,check))" in pending_check_code
         and "check.retcode!=0" in pending_check_code),
        ("pending-order modification preflight is scoped to geometry writer",
         bool(pending_modify_code)
         and "if(!OrderCheck(req,check))" in pending_modify_code
         and "check.retcode!=0" in pending_modify_code),
        ("pending-order modification checks server retcode and verified final geometry",
         bool(pending_modify_code)
         and "if(!TradeRetcodeModifySucceeded())" in pending_modify_code
         and "if(!OrderSelect(ticket))" in pending_modify_code
         and "MathAbs(ve-newEntry)>tolerance" in pending_modify_code
         and "STB_GeomStore(ticket,false,ve,vs,vt)" in pending_modify_code),
        ("modify success helper restricts accepted server retcodes",
         bool(modify_retcode_code)
         and all(token in modify_retcode_code for token in (
             "TRADE_RETCODE_DONE", "TRADE_RETCODE_DONE_PARTIAL",
             "TRADE_RETCODE_NO_CHANGES", "TRADE_RETCODE_ORDER_CHANGED"))),
        ("central pending delete requires authorization, server success and ticket disappearance",
         bool(controlled_delete_code)
         and "if(!authorized)" in controlled_delete_code
         and "bool requestOK=trade.OrderDelete(ticket);" in controlled_delete_code
         and "TRADE_RETCODE_DONE" in controlled_delete_code
         and "TRADE_RETCODE_DONE_PARTIAL" in controlled_delete_code
         and "if(OrderSelect(ticket))" in controlled_delete_code
         and "STB DELETE CONFIRMED" in controlled_delete),
        ("all broker pending-order deletion goes through the central writer",
         source_code.count("trade.OrderDelete(") == 1
         and "bool requestOK=trade.OrderDelete(ticket);" in controlled_delete),
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
         and "if(!TradeRetcodePlacementSucceeded())" in auto_placement_code
         and "trade.ResultRetcode()" in auto_placement_code
         and "VerifyPendingInitialSL(" in auto_placement_code),
        ("automatic placement requests rollback if initial SL cannot be verified",
         "if(placedOrder>0 && OrderSelect(placedOrder))" in auto_placement
         and "STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK,\"PlaceSetup\");"
         in auto_placement
         and auto_placement.find("VerifyPendingInitialSL(placedOrder)")
         < auto_placement.find("STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK,\"PlaceSetup\");")),
        ("placement success helper enumerates accepted server retcodes",
         bool(placement_retcode_code)
         and all(token in placement_retcode_code for token in (
             "TRADE_RETCODE_DONE", "TRADE_RETCODE_DONE_PARTIAL",
             "TRADE_RETCODE_PLACED"))),
        ("directional symbol permissions are checked before auto placement",
         bool(auto_placement_code)
         and "if(!IsDirectionTradable(s.symbol,s.direction))" in auto_placement_code),
        ("one-click hedge validates server result and initial SL with rollback",
         bool(hedge_placement_code)
         and "trade.BuyStop(" in hedge_placement_code
         and "trade.SellStop(" in hedge_placement_code
         and "if(!ok || !TradeRetcodePlacementSucceeded())" in hedge_placement_code
         and "VerifyPendingInitialSL(hedgeOrder)" in hedge_placement_code
         and "STB_RequestOrderDelete(hedgeOrder,STB_DEL_AUTO_ROLLBACK,\"OneClickHedge\");"
         in hedge_placement),
        ("manual stop placement validates server result and initial SL with rollback",
         bool(manual_stop_placement_code)
         and "trade.BuyStop(" in manual_stop_placement_code
         and "trade.SellStop(" in manual_stop_placement_code
         and "if(!ok || !TradeRetcodePlacementSucceeded())" in manual_stop_placement_code
         and "VerifyPendingInitialSL(ticket)" in manual_stop_placement_code
         and "STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK,\"PlaceManual\");"
         in manual_stop_placement),
        ("manual limit placement validates server result and initial SL with rollback",
         bool(manual_limit_placement_code)
         and "trade.BuyLimit(" in manual_limit_placement_code
         and "trade.SellLimit(" in manual_limit_placement_code
         and "if(!ok || !TradeRetcodePlacementSucceeded())" in manual_limit_placement_code
         and "VerifyPendingInitialSL(ticket)" in manual_limit_placement_code
         and "STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK,\"PlaceManual\");"
         in manual_limit_placement),
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
