#!/usr/bin/env python3
"""Source-contract checks for SmartTradingBot chart-control wiring."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
EA = ROOT / "MQL5/Experts/SmartTradingBot_FINAL.mq5"


def region(source: str, start: str, end: str) -> str:
    a = source.find(start)
    if a < 0:
        return ""
    b = source.find(end, a + len(start))
    return source[a:b] if b > a else ""


def main() -> int:
    if not EA.is_file():
        print(f"FAIL: missing EA source: {EA}")
        return 2

    source = EA.read_text(encoding="utf-8")
    checks = []

    def check(label: str, result: bool) -> None:
        checks.append((label, bool(result)))

    button = region(source, "void CreateButton(", "// Repair stale control objects")
    ensure = region(source, "void STB_EnsureControlButtons()", "void STB_RenderControlStatus()")
    status = region(source, "void STB_RenderControlStatus()", "void STB_SetControlStatus(")
    handler_start = source.find("void OnChartEvent(")
    handler = source[handler_start:] if handler_start >= 0 else ""
    init = region(source, "int OnInit()", "//==================================================================\n// DEINIT")

    check(
        "buttons are interactive OBJ_BUTTON objects with a released state",
        bool(button) and all(token in button for token in (
            "ObjectCreate(0,name,OBJ_BUTTON,0,0,0)",
            "OBJPROP_SELECTABLE,false",
            "OBJPROP_SELECTED,false",
            "OBJPROP_STATE,false",
            "OBJPROP_HIDDEN,false",
            "OBJPROP_BACK,false",
        )),
    )
    check(
        "button click priority is above the status panel",
        "OBJPROP_ZORDER,200000" in button and "OBJPROP_ZORDER,1" in status,
    )
    repair = region(source, "bool STB_ControlButtonNeedsRepair(", "void STB_LogControlButtonHealth()")
    health = region(source, "void STB_LogControlButtonHealth()", "void STB_EnsureControlButtons()")
    check(
        "same-type controls normalize flags in place and rebuild only for wrong type or invalid geometry",
        bool(repair) and all(token in repair for token in (
            "OBJPROP_SELECTABLE,false", "OBJPROP_SELECTED,false",
            "OBJPROP_STATE,false", "OBJPROP_HIDDEN,false",
            "width<=0 || height<=0", "reason=UNRECOVERABLE_GEOMETRY",
        )),
    )
    check(
        "health report treats selectability as movement state, not click readiness",
        bool(health) and
        "type==(long)OBJ_BUTTON && !selected && !pressed && !hidden" in health and
        "selectable &&" not in health,
    )
    check(
        "stale same-named non-button chart objects are detected and rebuilt",
        "STB_ControlButtonNeedsRepair" in ensure
        and "ObjectGetInteger(0,name,OBJPROP_TYPE)" in source
        and "type!=(long)OBJ_BUTTON" in source,
    )
    check(
        "startup emits a health report for the eight control buttons",
        "STB_LogControlButtonHealth();" in init
        and "STB UI BUTTONS SUMMARY" in source
        and 'expected=",IntegerToString(ArraySize(names))' in source,
    )
    check(
        "raw object-click diagnostics run before exact-name routing filters",
        bool(handler)
        and "STB UI OBJECT_CLICK event received name=" in handler
        and handler.index("STB UI OBJECT_CLICK event received name=")
            < handler.index("if(sparam!=buyName"),
    )
    check(
        "unknown prefixed controls are reported instead of silently ignored",
        "STB UI CLICK NOT ROUTED name=" in handler
        and "reason=UNRECOGNIZED_CONTROL_NAME" in handler,
    )
    check(
        "recognized UI controls reset pressed state and report dispatch",
        "ObjectSetInteger(0,sparam,OBJPROP_STATE,false);" in handler
        and 'Print("STB UI CLICK RECEIVED object=",sparam' in handler
        and 'STB_SetControlStatus("PROCESSING "+sparam' in handler,
    )
    check(
        "keyboard events are logged and D remains the only built-in hotkey",
        "STB UI KEY EVENT keyCode=" in handler
        and "if(lparam==68 || lparam==100)" in handler,
    )

    check(
        "click-router chart ID is logged without 32-bit truncation",
        "IntegerToString(ChartID())" in handler
        and "IntegerToString((int)ChartID())" not in handler,
    )
    check(
        "daily-loss guard rejection is shown on the chart without re-running or weakening the guard",
        "string STB_ControlRejectSuffix()" in source
        and "if(g_stbDailyLossThresholdReached)" in source
        and "DAILY_LOSS_LIMIT_ACTIVE" in source
        and '"BUY STOP REJECTED"+STB_ControlRejectSuffix()' in handler
        and '"SELL STOP REJECTED"+STB_ControlRejectSuffix()' in handler,
    )

    failed = 0
    for label, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {label}")
        if not ok:
            failed += 1
    print(f"RESULT: {len(checks)-failed}/{len(checks)} UI checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
