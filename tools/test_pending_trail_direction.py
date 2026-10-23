#!/usr/bin/env python3
"""Regression guards for pending STOP/STOP-LIMIT trailing direction.

This is a source-contract test. The MetaEditor workflow separately compiles
the EA; this test prevents the same direction mismatch from being reintroduced.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TRAIL_PATH = ROOT / "MQL5/Include/STB/STB_PendingTrail.mqh"
RESOLVER_PATH = ROOT / "MQL5/Include/STB/STB_PendingDistanceResolver.mqh"
EA_PATH = ROOT / "MQL5/Experts/SmartTradingBot_FINAL.mq5"


def region(source: str, start: str, end: str) -> str:
    begin = source.find(start)
    if begin < 0:
        return ""
    finish = source.find(end, begin + len(start))
    if finish < 0:
        return ""
    return source[begin:finish]


def compact(source: str) -> str:
    return re.sub(r"\s+", "", source)


def main() -> int:
    for path in (TRAIL_PATH, RESOLVER_PATH, EA_PATH):
        if not path.is_file():
            print(f"FAIL: required source file missing: {path}")
            return 2

    trail = TRAIL_PATH.read_text(encoding="utf-8")
    resolver = RESOLVER_PATH.read_text(encoding="utf-8")
    ea = EA_PATH.read_text(encoding="utf-8")
    manage = region(trail, "bool STB_PendingTrailManageOne(", "//--- Per-cycle processing")
    writer_sign = region(ea, "int STB_PendingEntryImproveSign(", "bool STB_PendingRiskFloorOK(")
    writer_gate = region(ea, "bool STB_PendingEntryDirectionOK(", "bool STB_PendingRiskFloorOK(")
    checks = []

    def check(name: str, passed: bool) -> None:
        checks.append((name, bool(passed)))

    # The candle-based breakout engine must include both stop-limit triggers,
    # preserve closed-candle validation, and use high-for-buy / low-for-sell.
    check(
        "STOP and STOP-LIMIT orders use closed-M5 trailing",
        bool(manage)
        and all(token in manage for token in (
            "ORDER_TYPE_BUY_STOP", "ORDER_TYPE_SELL_STOP",
            "ORDER_TYPE_BUY_STOP_LIMIT", "ORDER_TYPE_SELL_STOP_LIMIT",
            "iTime(symbol,PERIOD_M5,1)",
        )),
    )
    check(
        "BUY stop-side anchors use M5 highs and SELL stop-side anchors use M5 lows",
        "extreme=(STB_PendingIsBuySide((ENUM_ORDER_TYPE)orderType)?barHigh:barLow);"
        in compact(manage),
    )
    check(
        "BUY STOP ratchets its high watermark upward",
        "extreme>g_stbPendingTrail[idx].trackedExtreme+point*0.5" in compact(manage),
    )
    check(
        "SELL STOP ratchets its low watermark downward",
        "extreme<g_stbPendingTrail[idx].trackedExtreme-point*0.5" in compact(manage),
    )
    check(
        "committed STOP extremes advance monotonically with breakout direction",
        "MathMax(g_stbPendingTrail[idx].trackedExtreme,extreme)" in compact(manage)
        and "MathMin(g_stbPendingTrail[idx].trackedExtreme,extreme)" in compact(manage),
    )

    # The resolver must reject non-improving aligned entries in the correct
    # direction, after rounding to the broker tick size.
    r = compact(resolver)
    check(
        "resolver rejects BUY STOP entries that do not move up",
        '(orderType==ORDER_TYPE_BUY_STOP||orderType==ORDER_TYPE_BUY_STOP_LIMIT)&&'
        'currentEntry>0.0&&entry<=currentEntry+entryTolerance' in r,
    )
    check(
        "resolver rejects SELL STOP entries that do not move down",
        '(orderType==ORDER_TYPE_SELL_STOP||orderType==ORDER_TYPE_SELL_STOP_LIMIT)&&'
        'currentEntry>0.0&&entry>=currentEntry-entryTolerance' in r,
    )

    # The single EA writer is the final monotonic gate; it must agree with the
    # proposal resolver instead of silently rejecting the corrected proposal.
    ws = compact(writer_sign)
    wg = compact(writer_gate)
    check(
        "central writer assigns +1 to BUY STOP and -1 to SELL STOP",
        "if(STB_PendingIsStopKind(type)){if(isBuy)return1;if(isSell)return-1;}" in ws,
    )
    check(
        "central writer retains opposite pullback direction for LIMIT orders",
        "else{if(isBuy)return-1;if(isSell)return1;}" in ws,
    )
    check(
        "central writer permits only favorable monotonic entry changes",
        "if(sign>0)return(newEntry>=curEntry-tolerance);"
        "if(sign<0)return(newEntry<=curEntry+tolerance);" in wg,
    )

    # An independent table-style contract verifies the intended movement
    # for all supported pending types. The source assertions above bind the
    # policy to the actual MQL5 implementation.
    favorable_sign = {
        "BUY_STOP": 1,
        "BUY_STOP_LIMIT": 1,
        "SELL_STOP": -1,
        "SELL_STOP_LIMIT": -1,
        "BUY_LIMIT": -1,
        "SELL_LIMIT": 1,
    }

    def favorable(order_type: str, current: float, proposed: float,
                  tolerance: float = 0.01) -> bool:
        sign = favorable_sign[order_type]
        if sign > 0:
            return proposed >= current - tolerance
        return proposed <= current + tolerance

    direction_cases = {
        "BUY_STOP": (101.0, 99.0),
        "BUY_STOP_LIMIT": (101.0, 99.0),
        "SELL_STOP": (99.0, 101.0),
        "SELL_STOP_LIMIT": (99.0, 101.0),
        "BUY_LIMIT": (99.0, 101.0),
        "SELL_LIMIT": (101.0, 99.0),
    }
    model_ok = True
    for order_type, (good, bad) in direction_cases.items():
        model_ok &= favorable(order_type, 100.0, good)
        model_ok &= not favorable(order_type, 100.0, bad)
    check("direction contract passes for all six pending types", model_ok)

    failures = 0
    for name, passed in checks:
        print(f"{'PASS' if passed else 'FAIL'}: {name}")
        if not passed:
            failures += 1
    print(f"RESULT: {len(checks)-failures}/{len(checks)} checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
