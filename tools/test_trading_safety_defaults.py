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


def region(source: str, start: str, end: str) -> str:
    begin = source.find(start)
    finish = source.find(end, begin + len(start)) if begin >= 0 else -1
    return source[begin:finish] if begin >= 0 and finish > begin else ""


def main() -> int:
    if not SOURCE.is_file():
        print(f"FAIL: missing source: {SOURCE}")
        return 2

    source = SOURCE.read_text(encoding="utf-8")
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
    tester_auto_branch_code = re.sub(
        r"/\*.*?\*/|//[^\n]*", "", tester_auto_branch, flags=re.DOTALL
    )
    live_auto_branch_code = re.sub(
        r"/\*.*?\*/|//[^\n]*", "", live_auto_branch, flags=re.DOTALL
    )
    tester_auto_branch_compact = re.sub(r"\s+", "", tester_auto_branch_code)
    live_auto_branch_compact = re.sub(r"\s+", "", live_auto_branch_code)
    on_init_compact = re.sub(
        r"/\*.*?\*/|//[^\n]*|\s+", "", on_init, flags=re.DOTALL
    )

    checks = (
        ("live auto-trading is opt-in by default",
         input_default("InpAutoTrading", source) == "false"),
        ("risk-based sizing is opt-in by default",
         input_default("InpUseRiskSizing", source) == "false"),
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
         bool(permission_gate) and all(token in permission_gate for token in (
             "TERMINAL_TRADE_ALLOWED", "MQL_TRADE_ALLOWED",
             "ACCOUNT_TRADE_EXPERT", "ACCOUNT_TRADE_ALLOWED"))),
        ("automatic execution gate checks AUTO state, permissions and exposure",
         bool(auto_gate) and all(token in auto_gate for token in (
             "!g_autoTrading", "!STB_TradeEnvironmentAllowed()",
             "!STB_ExposureAllowsExecution(s)"))),
        ("pending-order preflight checks OrderCheck boolean and retcode",
         bool(pending_check) and "if(!OrderCheck(request,check))" in pending_check
         and "check.retcode!=0" in pending_check),
        ("pending-order modification preflight is scoped to geometry writer",
         bool(pending_modify)
         and "if(!OrderCheck(req,check))" in pending_modify
         and "check.retcode!=0" in pending_modify),
        ("pending-order modification checks server retcode and verified final geometry",
         bool(pending_modify)
         and "if(!TradeRetcodeModifySucceeded())" in pending_modify
         and "if(!OrderSelect(ticket))" in pending_modify
         and "MathAbs(ve-newEntry)>tolerance" in pending_modify
         and "STB_GeomStore(ticket,false,ve,vs,vt)" in pending_modify),
        ("modify success helper restricts accepted server retcodes",
         bool(modify_retcode)
         and all(token in modify_retcode for token in (
             "TRADE_RETCODE_DONE", "TRADE_RETCODE_DONE_PARTIAL",
             "TRADE_RETCODE_NO_CHANGES", "TRADE_RETCODE_ORDER_CHANGED"))),
        ("central pending delete requires authorization, server success and ticket disappearance",
         bool(controlled_delete)
         and "if(!authorized)" in controlled_delete
         and "bool requestOK=trade.OrderDelete(ticket);" in controlled_delete
         and "TRADE_RETCODE_DONE" in controlled_delete
         and "TRADE_RETCODE_DONE_PARTIAL" in controlled_delete
         and "if(OrderSelect(ticket))" in controlled_delete
         and "STB DELETE CONFIRMED" in controlled_delete),
        ("all broker pending-order deletion goes through the central writer",
         source.count("trade.OrderDelete(") == 1
         and "bool requestOK=trade.OrderDelete(ticket);" in controlled_delete),
        ("no raw TRADE_ACTION_REMOVE request bypasses the central delete writer",
         "TRADE_ACTION_REMOVE" not in re.sub(
             r"/\*.*?\*/|//[^\n]*", "", source, flags=re.DOTALL
         )),
        ("rollback deletion requires known creator, matching comment and a fresh order",
         bool(controlled_delete)
         and "bool knownCreator=" in controlled_delete
         and "bool creatorCommentMatches=" in controlled_delete
         and "authorized=knownCreator && stbComment && creatorCommentMatches &&" in controlled_delete
         and "setupTime>0 && setupTime<=TimeCurrent()+5" in controlled_delete
         and "TimeCurrent()-setupTime<=120" in controlled_delete),
        ("automatic pending placement checks server result and initial SL",
         bool(auto_placement)
         and "trade.BuyStop(" in auto_placement
         and "trade.SellStop(" in auto_placement
         and "if(!TradeRetcodePlacementSucceeded())" in auto_placement
         and "trade.ResultRetcode()" in auto_placement
         and "VerifyPendingInitialSL(" in auto_placement),
        ("automatic placement requests rollback if initial SL cannot be verified",
         "if(placedOrder>0 && OrderSelect(placedOrder))" in auto_placement
         and "STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK,\"PlaceSetup\");"
         in auto_placement
         and auto_placement.find("VerifyPendingInitialSL(placedOrder)")
         < auto_placement.find("STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK,\"PlaceSetup\");")),
        ("placement success helper enumerates accepted server retcodes",
         bool(placement_retcode)
         and all(token in placement_retcode for token in (
             "TRADE_RETCODE_DONE", "TRADE_RETCODE_DONE_PARTIAL",
             "TRADE_RETCODE_PLACED"))),
        ("directional symbol permissions are checked before auto placement",
         bool(auto_placement)
         and "if(!IsDirectionTradable(s.symbol,s.direction))" in auto_placement),
        ("one-click hedge validates server result and initial SL with rollback",
         bool(hedge_placement)
         and "trade.BuyStop(" in hedge_placement
         and "trade.SellStop(" in hedge_placement
         and "if(!ok || !TradeRetcodePlacementSucceeded())" in hedge_placement
         and "VerifyPendingInitialSL(hedgeOrder)" in hedge_placement
         and "STB_RequestOrderDelete(hedgeOrder,STB_DEL_AUTO_ROLLBACK,\"OneClickHedge\");"
         in hedge_placement),
        ("manual stop placement validates server result and initial SL with rollback",
         bool(manual_stop_placement)
         and "trade.BuyStop(" in manual_stop_placement
         and "trade.SellStop(" in manual_stop_placement
         and "if(!ok || !TradeRetcodePlacementSucceeded())" in manual_stop_placement
         and "VerifyPendingInitialSL(ticket)" in manual_stop_placement
         and "STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK,\"PlaceManual\");"
         in manual_stop_placement),
        ("manual limit placement validates server result and initial SL with rollback",
         bool(manual_limit_placement)
         and "trade.BuyLimit(" in manual_limit_placement
         and "trade.SellLimit(" in manual_limit_placement
         and "if(!ok || !TradeRetcodePlacementSucceeded())" in manual_limit_placement
         and "VerifyPendingInitialSL(ticket)" in manual_limit_placement
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
