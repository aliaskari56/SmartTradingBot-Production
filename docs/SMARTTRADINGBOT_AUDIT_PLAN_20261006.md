# SmartTradingBot — Complete Audit / Repair / Validation Plan
Date: 2026-10-06
Repository: aliaskari56/SmartTradingBot-Production
Target branch: main

## Scope and non-negotiable rules

Work only on the existing SmartTradingBot Expert and its established repository history. Do not create a parallel Expert, alternate production path, or backup copy as part of the MetaTrader repair work. Do not change healthy behavior for cosmetic cleanup or unnecessary refactoring.

The active MetaTrader target must be identified from MetaEditor/MetaTrader before changes:
`MQL5/Experts/SmartTradingBot.mq5`

Current repository main source was verified as version 1.120 at:
`e20e36fcc8604532e0a277928690d412d71065c4`

## Version gate

First determine the real active source version, size, line count, and presence/absence of:
- InpForensicOrderCheck
- InpStructuralPending
- InpStructuralCancelWhenInvalid

A complete 1.127 source may be inspected only if it already exists in the permitted repository/filesystem history. Do not fabricate or manually relabel 1.120 as 1.127. If a complete 1.127 source is unavailable, continue auditing the active 1.120 source.

## Section-by-section audit order

Do not advance until the current section is fully reviewed, repaired if required, and compiled with 0 errors and 0 warnings.

01. Header, properties, inputs, globals, constants
02. Structs, identity, state containers, IDs
03. Adaptive learning core
04. Persistence, Global Variables, restart recovery
05. Utility, symbol, broker, price, pip and tick helpers
06. Swing detection and closed-bar logic
07. Pending setup, entry, SL, TP and RR
08. H4 trend, structure, FVG, OB and setup construction
09. Signal qualification, strategy and rule gates
10. Exposure, state and position management
11. Hedge, emergency SL and initial SL protection
12. Trailing, pending lifetime and pending state
13. Order validation, OrderCheck and execution
14. Scanner
15. Dashboard and UI
16. OnInit and OnDeinit
17. OnTick and OnTimer
18. OnTradeTransaction
19. OnChartEvent
20. Final integration, runtime and full pipeline

## Per-section acceptance contract

For each section record:
- exact line range
- defects found
- fixes applied
- behavioral impact
- compile result
- errors
- warnings

Only proceed when the section compiles with:
`Result: 0 errors, 0 warnings`

## Safety and execution invariants

The final system must preserve:
1. No order/pending without a valid SL.
2. Valid broker minimum-distance and freeze/stops rules.
3. Tick-size alignment.
4. OrderCheck before applicable order submission.
5. Retcode inspection and post-submit verification.
6. Restart recovery without duplicate execution/state.
7. Adaptive learning restricted to valid closed-trade outcomes with no look-ahead.
8. Outcome deduplication and correct state cleanup.
9. Manual/foreign/hedge separation from learning according to the existing contract.
10. Tick/Timer deduplication for one logical closed-bar decision.
11. UI commands cannot bypass risk/safety gates.
12. BUY/SELL direction correctness.
13. Pending trail does not conflict with execution/state ownership.

## Adaptive learning audit

Verify:
- profile selection and decay
- closed-trade-only learning
- persistence across restart
- decision identity and outcome deduplication
- PnL lifecycle
- manual/foreign/hedge exclusion rules
- absence of future-data reads or look-ahead

## Pending and broker audit

Verify the complete chain:
BuildSetup
-> PreparePendingSetup
-> ValidatePendingSetup
-> broker distance validation
-> tick alignment
-> OrderCheck
-> send
-> retcode
-> verification
-> pending-trail registration

Audit:
- SYMBOL_POINT
- SYMBOL_DIGITS
- SYMBOL_TRADE_TICK_SIZE
- SYMBOL_TRADE_STOPS_LEVEL
- SYMBOL_TRADE_FREEZE_LEVEL
- Bid/Ask
- spread
- entry/SL/TP geometry

## Include audit

Fully review active includes, with priority on:
- STB_OrderCheckDiagnose.mqh
- STB_PendingDistanceResolver.mqh
- STB_PendingTrail.mqh
- every other include actually reached by SmartTradingBot.mq5

OrderCheck diagnostics must not accidentally become an independent execution owner.

## Scanner and ownership

Scanner must produce setup/candidate data rather than bypassing the execution pipeline. Audit:
- swing strength
- displacement bars
- lookback
- minimum score
- symbol scan cadence
- repeated work
- ownership between scanner, strategy and execution

## UI priority audit

Current dashboard commands:
- AUTO
- CANDLE_TIME
- BUY
- SELL
- HEDGE
- SAVE+20
- TRAIL

Audit:
- STB_DashCreate
- CreateButton / CreateButtonCorner
- layout/sync/redraw
- object names and prefix
- OBJ_BUTTON properties
- Z-order
- CHARTEVENT_OBJECT_CLICK
- CHARTEVENT_CHART_CHANGE
- CHARTEVENT_OBJECT_DRAG
- CHARTEVENT_CLICK fallback/hit-testing
- command recognition
- duplicate click prevention
- command result logging

Required event chain:
Mouse click
-> OBJECT_CLICK or HIT_TEST
-> command recognition
-> handler
-> result
-> pipeline/reject reason

Test each command in MetaTrader after successful compilation. For BUY/SELL/HEDGE, validate the full risk/safety/broker path; do not bypass gates merely to demonstrate the UI.

## Runtime audit

After final compile, test on the same MetaTrader Expert:
- initialization
- dashboard creation
- timer
- tick processing
- chart events
- trade transactions
- pending management
- position management
- restart/recovery behavior
- runtime logs and retcodes

## Performance review

Inspect, without changing semantics:
- ScanWatchlist cadence
- CopyRates / CollectSwings frequency
- redundant broker calls
- repeated state lookup
- unnecessary redraw/object operations

Dead code/cosmetic issues should be reported unless they create real functional or safety defects.

## Final build requirements

Final MetaEditor build must be:
`Result: 0 errors, 0 warnings`

Record:
- active source path
- source version
- source size
- line count
- compiler/build
- EX5 path
- EX5 size
- EX5 build timestamp
- runtime/UI test results
- remaining verified issues

## Git history requirement

This plan is intentionally stored on the repository's main branch so the audit/repair process has a durable, dated reference in Git history. Future implementation commits should reference this plan and preserve a traceable sequence of source changes, compile validation, and runtime validation.


## Operational rules — mandatory execution contract

These rules apply to every MetaTrader/Agent audit, repair, compile and runtime-validation step associated with this plan.

### Rule 01 — One production Expert only
Work only on the existing `SmartTradingBot` Expert. Never create a second Expert, alternate EA, test EA, parallel production path or replacement project.

### Rule 02 — No new backups
Do not create a new backup, snapshot copy, temporary duplicate source or alternate EX5 as part of the work. Existing historical files may be inspected when needed for recovery or comparison.

### Rule 03 — Same active path
The MetaTrader/MetaEditor active source path must be discovered and verified before editing. Changes must be made to that active Expert, not to an unrelated copy.

### Rule 04 — Read before write
Before modifying any section, read the entire relevant section and its directly connected functions/includes. Never patch from an isolated snippet when the surrounding contract is required.

### Rule 05 — Section gate
Do not move to the next audit section until the current section is:
1. fully reviewed,
2. real defects identified,
3. required fixes applied,
4. compiled,
5. verified at 0 errors and 0 warnings.

### Rule 06 — Minimal behavioral diff
Do not refactor, rename, reorder or cosmetically clean code unless there is a demonstrated functional, safety, correctness, maintainability or compile reason.

### Rule 07 — No invented version
Never change the version label merely to claim a newer release. Version identity must come from the real source contents/history.

### Rule 08 — Existing history is authoritative
When versions conflict, compare the actual source, Git history and available file history. Do not assume that the latest filename or EX5 timestamp proves the source version.

### Rule 09 — Compile after every corrective unit
Every corrective change must be compiled before proceeding. Record the compiler result and affected section.

### Rule 10 — Zero warning target
The acceptance target is:
`Result: 0 errors, 0 warnings`
Warnings must not be ignored merely because the Expert compiles.

### Rule 11 — Safety gates cannot be bypassed
UI/manual commands, diagnostics, emergency paths or test hooks must not bypass existing risk, safety, broker-distance, SL or execution validation.

### Rule 12 — SL is mandatory
No supported order/pending path may intentionally submit without a valid initial SL. Any fallback SL must remain within the existing safety contract.

### Rule 13 — Broker geometry is authoritative
Pending entry, SL and TP must respect tick size, stops level, freeze level, direction and other broker constraints actually exposed by the terminal.

### Rule 14 — Execution must be verified
Do not treat a trade request as successful merely because a function returned. Inspect the applicable result/retcode and verify the terminal state.

### Rule 15 — No duplicate decision execution
Tick, Timer, chart events and other event sources must not cause the same logical trading decision to execute twice.

### Rule 16 — Learning cannot see the future
Adaptive learning must use only permitted historical/closed outcomes. No future candle, future PnL or post-decision information may leak into the decision path.

### Rule 17 — Outcome deduplication
A closed trade/outcome must not be counted more than once because of repeated transactions, restart, retry or duplicated event delivery.

### Rule 18 — State survives restart correctly
Restart recovery must restore the required live state without creating duplicate positions, duplicate pending orders, duplicate learning outcomes or stale ownership.

### Rule 19 — Ownership must remain singular
Scanner, strategy, BPB, execution, pending trail, diagnostics and UI must have clear ownership boundaries. Adding a second execution owner is prohibited.

### Rule 20 — UI must be observable
Every supported dashboard command must have a traceable path:
click/event -> command recognition -> handler -> result -> reject reason when applicable.

### Rule 21 — UI test safety
BUY, SELL and HEDGE may be runtime-tested only through the real safety/risk/broker pipeline. Do not weaken gates merely to prove the button works.

### Rule 22 — Runtime evidence matters
0/0 compilation is necessary but not sufficient. Final acceptance also requires runtime evidence for initialization, UI events, timer/tick processing and relevant trade-transaction paths.

### Rule 23 — No false completion
Do not label a section "clean", "safe" or "fully verified" solely from compilation. Distinguish:
- compile correctness,
- static logic correctness,
- runtime verification,
- broker/execution verification.

### Rule 24 — Preserve forensic evidence
When a defect, version conflict or accidental corruption is discovered, record its exact path, relevant line/range, observed symptom, cause and resulting correction in the audit history.

### Rule 25 — Git traceability
All intentional repository changes associated with this plan must have a clear commit message and remain on the designated main branch unless an explicitly authorized project workflow requires otherwise.

### Rule 26 — Production source remains canonical
Do not silently replace the active source with a different historical version. Any recovery from Git/history must first establish which version is intended and why.

### Rule 27 — No destructive cleanup during audit
Do not delete existing source/history artifacts merely because they are old, duplicated or inconvenient. Report them unless deletion is explicitly authorized.

### Rule 28 — Final acceptance
The work is complete only when:
- the intended source version is identified,
- every planned section has passed its gate,
- final compile is 0 errors/0 warnings,
- EX5 rebuild is confirmed,
- relevant runtime/UI tests are evidenced,
- remaining issues are explicitly recorded.


## Delivery, checklist and quality-gate protocol — mandatory

### Rule 29 — Section completion checklist must be explicitly ticked
At the end of every completed Section, maintain a visible checklist and tick every item that was actually completed.

Required checklist:

- [ ] Section fully read from source
- [ ] Connected functions/includes reviewed
- [ ] Static logic audit completed
- [ ] Defects classified by severity
- [ ] Required fixes applied
- [ ] Behavioral impact reviewed
- [ ] Compile executed
- [ ] 0 errors confirmed
- [ ] 0 warnings confirmed
- [ ] Runtime evidence collected where applicable
- [ ] Section acceptance criteria passed
- [ ] Section marked COMPLETE

No checkbox may be ticked by assumption. A box is checked only when evidence exists.

### Rule 30 — Section status must be persisted
After each Section reaches COMPLETE, update the audit record/history so the completed Section remains visibly marked.

Use a status block such as:

`SECTION 01 — COMPLETE ✅`

and retain:
- exact source line range
- date/time of completion
- defects found
- fixes
- compiler result
- runtime result when applicable
- residual issues, if any

### Rule 31 — Every delivered file/instruction must state its governing rules
Whenever a file, patch, instruction block or Agent task is sent for execution, prepend a compact compliance header:

`RULES APPLIED: Rule XX, Rule YY, ...`

Also state:
- target Expert
- target file/path
- target Section
- allowed scope of change
- compile requirement
- runtime requirement when applicable

This prevents a file from being executed without its corresponding contract.

### Rule 32 — All Agent-facing files must be MetaTrader-Agent-ready
Any file intended for the MetaTrader Agent must be written as an executable, unambiguous work order for that Agent.

It must contain, where applicable:
1. objective
2. target path
3. exact scope
4. exact constraints
5. inspection requirements
6. repair requirements
7. compile command/acceptance criteria
8. runtime test requirements
9. evidence to report
10. completion checklist

No vague prose such as "fix this" without acceptance criteria is permitted.

### Rule 33 — Advanced professional quality standard
Every Section must be audited to a professional production standard, not merely compiled.

For each Section evaluate, as relevant:
- correctness
- safety
- determinism
- state integrity
- ownership boundaries
- event ordering
- failure handling
- broker compatibility
- restart behavior
- observability
- performance
- maintainability
- edge cases
- regression risk

Improvements must be technically justified and must preserve intended trading semantics.

### Rule 34 — "Upgrade" means verified engineering improvement
The instruction to make every Section "very precise, professional, advanced and beautiful" means:
- improve clarity of control flow where safe
- strengthen validation where a real gap exists
- improve diagnostics and observability
- remove ambiguity in state transitions
- harden edge-case handling
- preserve clean naming and structure when modifying code
- keep comments/contracts accurate

It does NOT authorize cosmetic rewrites, unnecessary abstraction, behavior changes without evidence, or risky refactors.

### Rule 35 — Evidence-first acceptance
A Section is COMPLETE only when the Agent can show evidence for the claims made.

Minimum evidence:
- source/version identification
- relevant line range
- compile result
- exact errors/warnings if any occurred
- fix summary
- runtime evidence for runtime-sensitive behavior

### Rule 36 — No hidden work
The Agent must not silently skip an item because it appears difficult or because the compiler is already clean.

Skipped checks must be explicitly listed as:
`NOT VERIFIED`
with the reason and required next action.

### Rule 37 — One Section, one gate
Do not batch multiple Sections into one unverified "global pass". Each Section must receive its own status and acceptance gate.

### Rule 38 — Final master checklist
At final completion, all planned Sections must appear in one master checklist:

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

Only checked items count as completed.

### Rule 39 — File delivery format
Every Agent-facing file should begin with:

`SMARTTRADINGBOT — AGENT WORK ORDER`
`TARGET: SmartTradingBot`
`SECTION: <section number and name>`
`RULES APPLIED: <rule numbers>`
`TARGET PATH: <exact active path>`

and end with:

`ACCEPTANCE: 0 errors, 0 warnings + required runtime evidence`

### Rule 40 — Visual/professional documentation standard
Audit documents, checklists and Agent work orders must be structured, readable and consistent:
- clear section numbering
- explicit acceptance gates
- compact evidence tables where useful
- no ambiguous wording
- no contradictory instructions
- no missing paths
- no unsupported completion claims

The documentation itself is part of the engineering audit trail and must remain production-quality.
