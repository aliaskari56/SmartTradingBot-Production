# SMARTTRADINGBOT — METAEDITOR / METATRADER AGENT EXECUTION RULES
Date: 2026-10-06
Repository: aliaskari56/SmartTradingBot-Production
Branch: main

## TARGET
Target Expert: SmartTradingBot
Target source: MQL5/Experts/SmartTradingBot.mq5
Work only on the existing active Expert path discovered from MetaTrader/MetaEditor.

## RULES APPLIED
This document is the mandatory Agent contract. It supplements:
docs/SMARTTRADINGBOT_AUDIT_PLAN_20261006.md

## 1. SINGLE EXPERT
Use only the existing SmartTradingBot Expert.
Never create another EA, test EA, parallel Expert, alternate production path, replacement project, or new temporary Expert.

## 2. NO NEW BACKUPS
Do not create new backup copies, snapshots, temporary duplicate sources, or alternate EX5 artifacts as part of the audit/repair job.
Existing historical artifacts may be inspected when required.

## 3. ACTIVE PATH ONLY
Discover and verify the active source path from MetaTrader/MetaEditor before editing.
Never silently edit an unrelated copy.

## 4. READ BEFORE WRITE
Read the complete current Section and all directly connected functions/includes before modifying it.
Do not patch from an isolated snippet when context is required.

## 5. SECTION GATE
Work strictly Section-by-Section.
Do not advance until the current Section is fully reviewed, corrected where required, and compiled with:
Result: 0 errors, 0 warnings

## 6. CHECKLIST IS MANDATORY
At completion of every Section, tick every verified item:

- [ ] Full Section read
- [ ] Connected functions/includes reviewed
- [ ] Static logic audit complete
- [ ] Defects classified
- [ ] Required fixes applied
- [ ] Behavioral impact reviewed
- [ ] Compile executed
- [ ] 0 errors verified
- [ ] 0 warnings verified
- [ ] Runtime evidence collected where applicable
- [ ] Acceptance criteria passed
- [ ] Section COMPLETE

A checkbox may only be ticked when evidence exists.

## 7. PERSIST SECTION STATUS
After a Section is complete, record:
SECTION XX — COMPLETE ✅

Also record:
- line range
- defects
- fixes
- compile result
- runtime result when applicable
- residual issues
- date/time

## 8. EVERY FILE MUST DECLARE ITS RULES
Every Agent-facing file, task, patch instruction, or work order must begin with:

SMARTTRADINGBOT — AGENT WORK ORDER
TARGET: SmartTradingBot
SECTION: <section>
RULES APPLIED: <rule numbers>
TARGET PATH: <exact path>

It must end with:
ACCEPTANCE: 0 errors, 0 warnings + required runtime evidence

## 9. AGENT-READY LANGUAGE
All Agent-facing files must contain exact:
- objective
- scope
- constraints
- inspection steps
- repair steps
- compile requirement
- runtime tests
- evidence requirements
- completion checklist

Do not use vague commands such as "fix this" without acceptance criteria.

## 10. PROFESSIONAL / ADVANCED QUALITY
Every Section must be reviewed to production engineering standards:
- correctness
- safety
- determinism
- state integrity
- ownership
- event ordering
- failure handling
- broker compatibility
- restart behavior
- observability
- performance
- maintainability
- edge cases
- regression risk

## 11. VERIFIED UPGRADE ONLY
"Upgrade" means a justified engineering improvement.
Allowed improvements include:
- stronger validation
- clearer state transitions
- better diagnostics
- better observability
- safer edge-case handling
- cleaner maintainable structure when code is already being changed

Do not perform cosmetic rewrites or risky refactors without demonstrated benefit.

## 12. ZERO BYPASS
No UI, manual command, diagnostic path, emergency path, or test hook may bypass:
- risk controls
- safety controls
- broker validation
- SL validation
- execution verification

## 13. SL MANDATORY
No supported order/pending path may intentionally send without valid initial SL.

## 14. BROKER GEOMETRY
Respect:
- tick size
- digits
- stops level
- freeze level
- direction
- minimum distance
- symbol trading constraints

## 15. EXECUTION VERIFICATION
A successful function return is not enough.
Check applicable result/retcode and verify terminal state after submission.

## 16. NO DUPLICATE DECISIONS
Tick, Timer, ChartEvent and transaction paths must not execute the same logical decision twice.

## 17. NO LOOK-AHEAD
Adaptive learning may only use permitted historical/closed outcomes.
No future candle, future PnL, or post-decision information leakage.

## 18. OUTCOME DEDUPLICATION
The same closed outcome must not be counted twice because of:
- repeated trade transactions
- retries
- restarts
- duplicated event delivery

## 19. RESTART INTEGRITY
Restart recovery must not create:
- duplicate positions
- duplicate pending orders
- duplicate learning outcomes
- stale ownership
- corrupted state

## 20. SINGLE OWNERSHIP
Scanner, Strategy, BPB, Execution, PendingTrail, Diagnostics and UI must have clear ownership.
Do not add a second execution owner.

## 21. UI OBSERVABILITY
Every command must be traceable:

Click
-> Event
-> Command recognition
-> Handler
-> Result
-> Reject reason when applicable

## 22. UI SAFETY
BUY, SELL and HEDGE tests must use the real risk/safety/broker path.
Never weaken gates merely to prove the button works.

## 23. COMPILE IS NECESSARY, NOT SUFFICIENT
Separate these claims:
- compile correctness
- static logic correctness
- runtime verification
- broker/execution verification

Do not call a Section fully safe from 0/0 alone.

## 24. EVIDENCE REQUIRED
Every completed Section must have evidence:
- version/source identification
- line range
- defect/fix record
- compile result
- runtime evidence where applicable

## 25. NO HIDDEN SKIPS
If a check cannot be verified, mark:
NOT VERIFIED

and state:
- reason
- evidence unavailable
- required next action

## 26. ONE SECTION / ONE GATE
Do not batch several Sections into an unverified global pass.

## 27. FORENSIC TRACEABILITY
When a defect or source-version conflict is found, record:
- exact path
- line/range
- symptom
- root cause
- correction
- verification

## 28. GIT TRACEABILITY
Intentional repository documentation/code changes must have a clear commit message and remain on main unless an explicitly authorized workflow says otherwise.

## 29. NO DESTRUCTIVE CLEANUP
Do not delete historical source/evidence merely because it is old or duplicated.
Report it unless deletion is explicitly authorized.

## 30. FINAL ACCEPTANCE
The job is complete only when:
- intended source version is identified
- all Sections have completed checklists
- final compile is 0 errors / 0 warnings
- EX5 rebuild is confirmed
- relevant runtime/UI tests are evidenced
- remaining issues are explicitly listed

## SECTION MASTER CHECKLIST

- [ ] SECTION 01 — Header / Inputs / Globals
- [ ] SECTION 02 — Structs / Identity / State
- [ ] SECTION 03 — Adaptive Learning
- [ ] SECTION 04 — Persistence / Restart
- [ ] SECTION 05 — Utility / Broker Helpers
- [ ] SECTION 06 — Swing / Closed-Bar
- [ ] SECTION 07 — Pending Setup / SL / TP / RR
- [ ] SECTION 08 — Trend / Structure / FVG / OB
- [ ] SECTION 09 — Signal / Strategy / Gates
- [ ] SECTION 10 — Exposure / Position State
- [ ] SECTION 11 — Hedge / Emergency SL
- [ ] SECTION 12 — Trailing / Pending Lifetime
- [ ] SECTION 13 — OrderCheck / Execution
- [ ] SECTION 14 — Scanner
- [ ] SECTION 15 — Dashboard / UI
- [ ] SECTION 16 — OnInit / OnDeinit
- [ ] SECTION 17 — OnTick / OnTimer
- [ ] SECTION 18 — OnTradeTransaction
- [ ] SECTION 19 — OnChartEvent
- [ ] SECTION 20 — Final Integration / Runtime
