SMARTTRADINGBOT — AGENT WORK ORDER
TARGET: SmartTradingBot
SECTION: 01 — Header / Properties / Inputs / Globals / Constants
RULES APPLIED: 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 19, 22, 23, 24, 25, 26, 27, 29, 31, 32, 33, 34, 35, 36, 37, 39, 40
TARGET PATH: Discover and verify the active MetaTrader/MetaEditor SmartTradingBot.mq5 path before any edit.

# OBJECTIVE

Audit and, only where a real defect exists, professionally harden SECTION 01 of the EXISTING SmartTradingBot Expert.

Do not create:
- another Expert
- another source
- a backup
- a snapshot
- a temporary duplicate
- an alternate EX5
- a parallel production path

Do not move to SECTION 02 until SECTION 01 has passed every acceptance gate below.

# CURRENT VERSION CONTEXT

Previously reported active source:
- Version: 1.120
- Reported size: 211,466 bytes
- Reported line count: 6,889
- Reported active path:
  C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87\MQL5\Experts\SmartTradingBot.mq5

Previously reported historical 1.127-only identifiers:
- InpForensicOrderCheck
- InpStructuralPending
- InpStructuralCancelWhenInvalid

Do NOT add these identifiers merely to make the current source appear newer.
First verify the real active source and version from MetaEditor.

# EXECUTION ORDER

## STEP 1 — SOURCE IDENTITY

From MetaEditor/MetaTrader, read the active SmartTradingBot.mq5 and record:
- exact path
- file size
- modification time
- #property version
- total line count
- source hash if the environment supports hashing

Do not edit during this identity check.

## STEP 2 — DEFINE SECTION 01 RANGE

Read from line 1 forward and identify the exact end of:
- #property declarations
- include declarations
- constants
- enums/types that are genuinely part of the header contract
- input declarations
- global objects/state declarations

Stop before the first function/engine section that belongs to SECTION 02 or a later section.

Record the exact line range.

## STEP 3 — READ COMPLETELY

Read the complete Section 01, not snippets.

For every item, determine:
- type
- initial value
- scope
- owner
- dependencies
- whether it is read-only or mutable
- whether initialization order matters
- whether it is referenced before initialization
- whether it conflicts with another input/global
- whether it is dead/duplicate
- whether changing it would alter trading behavior

## STEP 4 — PROPERTIES / VERSION

Audit:
- #property strict
- #property version
- descriptions
- compiler-relevant properties

Rules:
- do not invent or relabel the version
- do not change version only for cosmetic reasons
- do not alter compiler behavior unless a verified defect requires it

## STEP 5 — INCLUDE CONTRACT

Audit every include declared in the header.

For each include:
- confirm it exists
- confirm it is actually required
- identify its role
- identify any possible duplicate include ownership
- identify compile-order/state-order implications
- do not remove or reorder an include unless a real compile/behavior/ownership defect exists

Do not audit the full internal implementation of each include here unless required to establish a Section 01 dependency. Deeper include audits belong to their dedicated Sections.

## STEP 6 — INPUT AUDIT

Inspect every input.

Classify inputs into:
- trading mode
- risk
- execution
- pending
- hedge
- management
- scanner
- adaptive learning
- UI
- diagnostics
- timing
- broker constraints

For every input check:
- valid type
- valid default
- sensible bounds where the existing design requires bounds
- dependency consistency
- contradictory combinations
- unused inputs
- duplicate semantic controls
- legacy inputs that conflict with current controls
- accidental coupling between unrelated subsystems

Do not redesign the strategy in this Section.

## STEP 7 — VERSION-SENSITIVE INPUT CHECK

Explicitly search for:
- InpForensicOrderCheck
- InpStructuralPending
- InpStructuralCancelWhenInvalid

Report each as:
- PRESENT
- ABSENT
- HISTORICAL ONLY

Never add missing version-1.127 fields just because they existed historically.

## STEP 8 — GLOBAL OBJECT / STATE AUDIT

Inspect every global variable/object/state holder in this Section.

For each determine:
- owner
- lifecycle
- initialization
- mutation sites
- reset/deinit behavior
- whether it can create duplicate state
- whether it is safe across restart
- whether it is accessed from both OnTick and OnTimer
- whether it participates in UI/chart events
- whether it participates in learning or execution

Pay special attention to:
- trade object
- magic identifiers
- trading flags
- adaptive state
- timing state
- pending/position state
- UI prefix/object names
- counters
- deduplication state
- decision identity/state

## STEP 9 — CONSTANTS / ENUMS / DEFAULTS

Check:
- constants with conflicting values
- duplicated literals controlling the same contract
- invalid enum assumptions
- unsafe zero/default values
- units mismatches (points vs pips vs price vs seconds)
- default values that can silently disable safety
- default values that can silently enable trading

Do not change a default merely because another value appears "better".
Change only if there is a demonstrated defect and the intended contract is clear.

## STEP 10 — CROSS-EVENT REVIEW

Without auditing later sections in full, determine whether any Section 01 global/input creates obvious risk across:
- OnTick
- OnTimer
- OnTradeTransaction
- OnChartEvent

Examples:
- duplicated logical gates
- shared mutable flags with unsafe lifecycle
- stale state
- event re-entry risk
- initialization-order risk

Record issues for the later Section if they cannot be resolved safely here.

## STEP 11 — QUALITY UPGRADE STANDARD

Where a real defect is found, apply an advanced production-quality correction:
- precise
- minimal
- deterministic
- maintainable
- observable
- safe
- compatible with the current architecture

Do NOT perform cosmetic rewrites.

"Professional and advanced" means stronger engineering and clarity, not unnecessary refactoring.

## STEP 12 — COMPILE GATE

If any change was made:
- compile the SAME active SmartTradingBot Expert
- compile after the corrective change
- verify exact result

Mandatory:
Result: 0 errors, 0 warnings

If no code change was required, still perform the required Section acceptance verification and record the most recent valid compile evidence.

If MetaEditor MCP transport is unavailable:
- do not claim a new compile was executed
- distinguish prior byte-identical build evidence from a fresh compile
- report NOT VERIFIED for the fresh compile
- do not proceed to Section 02

## STEP 13 — CHECKLIST

At completion, fill this exact checklist based only on evidence:

- [ ] Active source path verified
- [ ] Version verified
- [ ] Size / mtime recorded
- [ ] Section 01 exact line range recorded
- [ ] Header/properties audited
- [ ] Includes audited at contract level
- [ ] All inputs audited
- [ ] Version-sensitive inputs checked
- [ ] Globals/state audited
- [ ] Constants/enums/defaults audited
- [ ] Cross-event risks reviewed
- [ ] Real defects classified
- [ ] Required fixes applied
- [ ] Behavioral impact reviewed
- [ ] Compile executed
- [ ] 0 errors verified
- [ ] 0 warnings verified
- [ ] Runtime evidence collected where applicable
- [ ] Residual issues recorded
- [ ] SECTION 01 — COMPLETE ✅

Never tick an item without evidence.

## STEP 14 — SECTION REPORT

Return a compact but complete report containing:

SECTION: 01
STATUS: PASS / FAIL / NOT VERIFIED
LINE RANGE:
SOURCE PATH:
VERSION:
SIZE:
MTIME:

DEFECTS FOUND:
1. ...

FIXES APPLIED:
1. ...

BEHAVIORAL IMPACT:
...

COMPILE:
Result:
Errors:
Warnings:
Elapsed:

RUNTIME EVIDENCE:
...

UNVERIFIED ITEMS:
...

CHECKLIST:
[actual completed checklist]

SECTION 01 ACCEPTANCE:
PASS only when every mandatory gate is evidenced.

# HARD STOP

Do NOT begin SECTION 02.

Only after SECTION 01 is independently accepted may the next Agent work order be executed.

ACCEPTANCE: 0 errors, 0 warnings + required runtime evidence


# PRE-FLIGHT GATE — REQUIRED BEFORE THIS WORK ORDER IS EXECUTED

This Section may be sent to the MetaTrader Agent only after the following has been completed on our side:

- [ ] Current Section scope mapped from the real source
- [ ] Relevant Git history/baseline reviewed
- [ ] Relevant MQL5/MetaEditor semantics checked where required
- [ ] Intended change or NO-CODE-CHANGE decision prepared
- [ ] Affected identifiers/call paths/includes checked
- [ ] Diff reviewed for unintended changes
- [ ] Preflight compile performed when an authorized compiler is actually available

PRE-FLIGHT STATUS:
NOT COMPLETE until evidenced.

MetaTrader Agent is responsible only for the environment-specific final stage after handoff:
- apply the approved change to the same active Expert
- MetaEditor compile
- EX5 rebuild
- install/reload the same Expert
- runtime validation
- Experts/Journal evidence

Do not claim this Section is complete from Git/static/preflight evidence alone.

SECTION 01 must finish with these three statuses:

PRE-FLIGHT — OUR SIDE: PASS / FAIL / NOT VERIFIED
MT5 EXECUTION — META TRADER AGENT: PASS / FAIL / NOT VERIFIED
FINAL ACCEPTANCE — COMBINED: PASS / FAIL / NOT VERIFIED

Only FINAL ACCEPTANCE = PASS permits SECTION 02.


# PRE-FLIGHT RESULT — OUR SIDE — 2026-10-06

## Source/Git review
- Git source reviewed: `MQL5/Experts/SmartTradingBot.mq5`
- Git baseline blob SHA: `e20e36fcc8604532e0a277928690d412d71065c4`
- Declared version: `1.120`
- SECTION 01 exact range: lines `1–188`
- First STRUCTURES boundary: line `191`
- Input declarations inspected: `88`
- Duplicate input identifiers detected: `0`
- Historical 1.127 identifiers in Section 01:
  - `InpForensicOrderCheck`: ABSENT
  - `InpStructuralPending`: ABSENT
  - `InpStructuralCancelWhenInvalid`: ABSENT

## Technical reference review
MQL5 documentation confirms:
- `#property` belongs in the main source module and controls compiled program properties.
- `input` variables are external/read-only program parameters initialized before `OnInit`.
- Global-scope variables/objects are initialized before event handling.
- `input group` is valid for organizing EA parameters.

References reviewed:
- MQL5 Program Properties
- MQL5 Input Variables
- MQL5 Global Variables / scope

## Static findings

### Finding 01 — documentation drift
Location:
`InpUiMarginX` line 180

Observed:
- Default value: `62`
- Inline comment says the margin range is `10..20`

Classification:
DOCUMENTATION / CONTRACT CLARITY
Behavioral impact: NONE demonstrated.

Decision:
NO CODE CHANGE during preflight.
Reason: changing a comment is not required to make the Expert compile or change runtime behavior, and the audit contract requires minimal behavioral diff.

### Finding 02 — ownership statement requiring downstream verification
Location:
`InpManageEAPositions = true` line 91
Comment:
`ownership is not filtered`

Classification:
DESIGN RISK / DOWNSTREAM AUDIT ITEM
Behavioral impact: NOT YET VERIFIED.

Decision:
NO CHANGE in Section 01.
Carry to Section 10 (Exposure / Position State) for full ownership-path verification.

## Preflight assessment

Header/properties: PASS
Include declarations: PASS
Inputs: PASS
Input identifier uniqueness: PASS
Version-sensitive input check: PASS
Global object declaration at header level: PASS
Static Section 01 correctness: PASS WITH FINDINGS RECORDED
Code patch required in Section 01: NO

## Preflight compile

Fresh compile on our side:
NOT VERIFIED — no authorized MetaEditor compiler/runtime is available through this preflight environment.

Important:
- Do NOT describe Git/static validation as a fresh MetaEditor compile.
- Existing historical 0/0 compile evidence remains historical evidence only.
- MetaTrader Agent must perform the actual MetaEditor compile after handoff.

## Section 01 preflight checklist

- [x] Active Git source identified
- [x] Version identified
- [x] Exact Section 01 line range identified
- [x] Header/properties reviewed
- [x] Includes reviewed at contract level
- [x] All 88 inputs reviewed for identifier duplication
- [x] Version-sensitive inputs checked
- [x] Global header object reviewed
- [x] Static MQL5 semantics checked against official documentation
- [x] Real findings classified
- [x] Unnecessary code changes avoided
- [x] Relevant downstream risk recorded
- [ ] Preflight compile executed
- [ ] 0 errors verified by a fresh preflight compiler
- [ ] 0 warnings verified by a fresh preflight compiler

PRE-FLIGHT STATUS:
`PASS FOR HANDOFF WITH COMPILE PENDING IN METATRADER AGENT`

FINAL ACCEPTANCE:
`NOT COMPLETE`

HARD STOP:
Do not mark SECTION 01 complete until MetaTrader Agent performs the actual compile and returns fresh 0 errors / 0 warnings plus required runtime evidence.


# UPDATED MASTER PREFLIGHT DEPENDENCY

SECTION 01 may NOT be handed to the MetaTrader Agent for code modification until these Phase-00 conditions are satisfied:

- exact active MetaTrader source identity is reconciled against the Git baseline
- architecture ownership contract is accepted
- Scanner/Strategy/Setup/Risk/Execution/Management boundaries are mapped
- current cross-boundary side effects are recorded

Current known architecture findings that affect Section 01:
- ScanWatchlist -> PlaceSetup -> ExecuteSetup
- BuildSetup mixes Strategy + Adaptive + broker normalization
- HasManagedExposure -> IsManagedPosition couples Management to Execution eligibility
- IsManagedPosition is ownership-agnostic while IsManagedOrder is ownership-specific
- InpDiagnosticM15Mode can force auto trading ON
- InpSmartZigZagEnabled is currently unused in the Git baseline

SECTION 01 remains an analysis gate first. Do not patch these architecture issues from inside Section 01 unless the master architecture design explicitly assigns the repair there.
