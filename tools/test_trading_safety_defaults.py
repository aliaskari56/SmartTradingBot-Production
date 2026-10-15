#!/usr/bin/env python3
"""Regression guards for safe EA input defaults.

These checks are intentionally narrow. They do not compile MQL5, exercise the
Strategy Tester, or certify a strategy as safe or profitable.
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


def main() -> int:
    if not SOURCE.is_file():
        print(f"FAIL: missing source: {SOURCE}")
        return 2

    source = SOURCE.read_text(encoding="utf-8")
    checks = (
        ("live auto-trading is opt-in by default",
         input_default("InpAutoTrading", source) == "false"),
        ("risk-based sizing is opt-in by default",
         input_default("InpUseRiskSizing", source) == "false"),
    )

    failed = False
    for label, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {label}")
        failed |= not ok

    print("LIMITATION: these checks do not validate runtime permission gates, "
          "broker execution, compilation, backtests, or profitability.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
