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
        ("resolver has deterministic source tie-break and revalidates SL",
         "props[i].source<finalSource" in source and
         "IsValidSLForPosition(symbol,side,c)" in source),
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
        ("trail success log is not emitted for queued proposals",
         'if(result && !g_stbCollectingSLProposals)' in source),
    ]
    errors = lexical_errors(source)
    checks.append(("balanced delimiters/comments/literals", not errors))
    failed = False
    for name, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {name}")
        failed |= not ok
    for error in errors:
        print(f"  {error}")

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
