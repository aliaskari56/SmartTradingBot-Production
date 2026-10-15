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
    tester_auto_branch = region(
        source, "if(MQLInfoInteger(MQL_TESTER))", "if(!InpAutoTrading)"
    )
    live_auto_branch = region(
        source, "if(!InpAutoTrading)", "trade.SetExpertMagicNumber(InpMagic);"
    )
    tester_auto_branch_compact = re.sub(r"\s+", "", tester_auto_branch)

    checks = (
        ("live auto-trading is opt-in by default",
         input_default("InpAutoTrading", source) == "false"),
        ("risk-based sizing is opt-in by default",
         input_default("InpUseRiskSizing", source) == "false"),
        ("tester AUTO override is isolated from live initialization",
         bool(tester_auto_branch)
         and "g_autoTrading=(InpAutoTrading&&InpTesterForceAutoTrading);" in tester_auto_branch_compact
         and bool(live_auto_branch)
         and "InpTesterForceAutoTrading" not in live_auto_branch),
        ("trade gate checks terminal, program, account-expert and account permissions",
         bool(permission_gate) and all(token in permission_gate for token in (
             "TERMINAL_TRADE_ALLOWED", "MQL_TRADE_ALLOWED",
             "ACCOUNT_TRADE_EXPERT", "ACCOUNT_TRADE_ALLOWED"))),
        ("automatic execution gate checks AUTO state, permissions and exposure",
         bool(auto_gate) and all(token in auto_gate for token in (
             "!g_autoTrading", "!STB_TradeEnvironmentAllowed()",
             "!STB_ExposureAllowsExecution(s)"))),
        ("pending-order preflight checks OrderCheck return and retcode",
         bool(pending_check) and "OrderCheck(request,check)" in pending_check
         and "check.retcode!=0" in pending_check),
        ("pending-order modification preflight checks OrderCheck and retcode",
         "OrderCheck(req,check)" in source and "check.retcode!=0" in source),
        ("directional symbol permissions are checked before auto placement",
         "if(!IsDirectionTradable(s.symbol,s.direction))" in source),
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
