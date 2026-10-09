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


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                        "MQL5/Experts/SmartTradingBot_FINAL.mq5")
    if not path.is_file():
        print(f"FAIL: source file not found: {path}")
        return 2
    source = path.read_text(encoding="utf-8")
    checks: list[tuple[str, bool]] = [
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
        ("delete writer revalidates expiry",
         "authorized=serverExpired || localAgeExpired" in source),
        ("position modify rechecks TP snapshot",
         "position state changed before request" in source),
    ]
    errors = lexical_errors(source)
    checks.append(("balanced delimiters/comments/literals", not errors))
    failed = False
    for name, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {name}")
        failed |= not ok
    for error in errors:
        print(f"  {error}")

    # Known unresolved root cause: SL proposals are still submitted one at a
    # time. Report this separately so a structural PASS is never mistaken for
    # full trading validation.
    single_proposal = "STB_ResolvePositionSL(ticket,props,1,finalSL,finalSource)" in source
    if single_proposal:
        print("OPEN: SL proposal arbitration across initial/profit/trailing sources is not proven.")
    print("NOT COVERED: MetaEditor compilation, Strategy Tester, demo, broker compatibility, "
          "EX5 provenance, package/license review, profitability.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
