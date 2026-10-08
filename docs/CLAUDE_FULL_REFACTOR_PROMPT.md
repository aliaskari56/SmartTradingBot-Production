# Claude Master Prompt — SmartTradingBot Full Engine Architecture Refactor

Repository: aliaskari56/SmartTradingBot-Production
Canonical EA: MQL5/Experts/SmartTradingBot.mq5
Working branch: refactor/full-engine-architecture
Base branch: main

## Mission

Refactor the complete SmartTradingBot Expert Advisor into a clean, responsibility-separated engine architecture without changing trading behavior.

You have permission to perform real multiline/range edits to the source file. Do not simulate edits, truncate code, or leave pseudo-refactors.

## Branch safety

- Work ONLY on refactor/full-engine-architecture.
- NEVER modify or merge main.
- NEVER force-push.
- Preserve the current main branch exactly.
- Make logical commits after each major phase.
- Keep the final branch buildable.

## Target architecture

SmartTradingBot
├── ENTRY ENGINE       → entry decisions and entry construction only
├── SL ENGINE          → all stop-loss calculation/validation/application
├── TP ENGINE          → all take-profit calculation/validation
├── TRAILING ENGINE    → trailing eligibility and trailing candidate calculation
├── RISK ENGINE        → risk and lot calculation
├── HEDGE ENGINE       → hedge policy/calculation only
├── PENDING ENGINE     → pending-order lifecycle
├── MANUAL ENGINE      → manual commands/priorities
├── SCANNER ENGINE     → scanner discovery/validation/scoring/ranking/selection
├── VISUAL ENGINE      → chart/UI visualization only
└── EXECUTION ENGINE   → broker/MT5 trade execution only

Each engine must have one responsibility. Calculation and execution must remain separate.

## Immutable trading behavior

Do NOT alter these behaviors:

1. Initial SL uses M5 structure.
2. M15 remains the setup/context timeframe for setup logic, BOS age, origin candle, FVG/OB, TP context, scoring, scanner and visualization where currently used.
3. Automatic protection trigger remains +50 pips.
4. Automatic lock floor remains +30 pips.
5. Live trailing distance remains 30 pips.
6. Automatic SL movement is forward-only.
7. Manual Priority remains intact.
8. Manual SAVE20 behavior remains intact.
9. Pending-order behavior remains intact.
10. Risk/lot calculation behavior remains intact.
11. Hedge behavior remains intact.
12. Scanner behavior remains intact.
13. Visual behavior remains intact.
14. Preserve existing magic number, filling mode, async mode, symbol/price normalization and broker retcode validation behavior.
15. Do not change inputs unless required for architecture and behavior remains identical.
16. Do not introduce new trading rules, thresholds, signals, filters or state machines.

Important current parameters:
- InpAutoTriggerPips = 50
- InpAutoLockPips = 30
- InpTrailDistancePips = 30
- InpTrailStartPips = 150 is legacy/non-operational for automatic protection.

## Current known good refactors — preserve them

The source already contains these architectural improvements:

- SL_ApplyPosition() is the single active Position SL writer.
- CalculateTrailingSL() performs trailing candidate calculation/validation.
- TrailPositionLive() is trailing orchestration.
- STB_ShouldAutoProtectPosition() separates manual/origin policy from SL calculation.
- Manual SAVE20 remains separate.
- EnsureInitialSL() uses SL_ApplyPosition().
- Initial SL remains M5 based.
- Automatic protection has no dead +50→+150 zone.
- Execution wrappers already exist for:
  - STB_ExecBuyStop()
  - STB_ExecSellStop()
  - STB_ExecOrderModify()
  - STB_ExecOrderDelete()
- Existing safe execution wrapper call sites must remain behaviorally identical.

Do not regress these changes.

## Required refactors

### Phase 1 — ENTRY / TP separation

Refactor BuildSetup() so TP calculation is no longer embedded as a large responsibility inside the setup builder.

Create a dedicated TP calculation path, for example:
- CalculateTakeProfit(...)
- ValidateTakeProfit(...), if useful

BuildSetup() should orchestrate and consume the TP result rather than own the full TP algorithm.

Preserve the exact current TP algorithm, timeframe, pivot logic, normalization, fallback behavior and direction-specific behavior.

Do not duplicate the old TP algorithm. Move/extract it cleanly.

Commit:
REFACTOR: extract TP engine

### Phase 2 — HEDGE separation

Refactor OneClickHedge() so it does not simultaneously own:
- hedge policy
- hedge direction decision
- hedge volume/risk calculation
- hedge SL calculation
- broker order execution

Separate calculation/policy from execution.

The HEDGE ENGINE must return an explicit hedge plan/result. The EXECUTION ENGINE must execute it.

Preserve:
- direction
- volume
- SL
- TP
- symbol
- order type
- expiration
- comments
- magic number
- filling mode
- retcode handling
- all current hedge conditions

Do not change hedge behavior.

Commit:
REFACTOR: separate hedge calculation and execution

### Phase 3 — SCANNER separation

Refactor STB_ScannerRun() into clear internal stages without changing scanner output:

1. Discovery
2. Candidate construction
3. Validation
4. Scoring
5. Ranking
6. Selection
7. Output/visualization

Do not change scanner thresholds, ranking weights, candidate rules or selection semantics.

Avoid unnecessary classes/frameworks. Simple functions/structs are preferred.

Commit:
REFACTOR: split scanner engine

### Phase 4 — EXECUTION centralization

Find every remaining active broker writer:
- BuyStop
- SellStop
- BuyLimit
- SellLimit
- OrderModify
- OrderDelete
- PositionModify
- PositionOpen/Buy/Sell if present
- PositionClose/CloseBy if present
- any other CTrade/MT5 broker-writing operation

Centralize execution behind a thin EXECUTION ENGINE.

The engine responsible for calculation must not directly call broker-writing APIs.

Preserve exact:
- argument order
- symbol
- volume
- prices
- SL/TP
- order type
- time type
- expiration
- stop-limit
- comments
- magic number
- filling mode
- async mode
- retcode checks
- existing logs

Do not introduce a large framework.

Commit:
REFACTOR: centralize execution writers

### Phase 5 — cleanup

Remove only functions that are provably dead:
- zero active references
- not required by MT5 event handlers
- not required by callbacks/indirect invocation
- not required by external integration

Retired/deprecated functions may be removed only when confirmed safe.

Do not delete anything merely because it looks old.

Commit:
CLEANUP: remove confirmed dead code

## Hard constraints

- No regex-based destructive refactor.
- No broad search/replace that can alter unrelated logic.
- No truncation.
- No duplicated old algorithm left behind after extraction.
- No placeholder TODO implementation.
- No fake wrapper that simply moves responsibility without actually separating it.
- No new unnecessary files unless architecture genuinely requires them.
- Prefer keeping the EA as one .mq5 file unless there is a strong technical reason otherwise.
- Do not change strategy behavior for the sake of code style.

## Validation after every phase

After each major phase:

1. Inspect the changed functions.
2. Search for old duplicate logic.
3. Search for all callers.
4. Verify engine boundaries.
5. Compile if a MetaEditor/MQL5 compiler is available.
6. Require:
   0 errors
   0 warnings
7. Verify no accidental behavior changes.
8. Commit only after the phase is internally consistent.

If local MetaEditor is not available to you, do NOT claim compilation succeeded. State that local MetaEditor compilation must be performed separately.

## Final audit

At the end, produce a concise audit containing:

- functions before/after
- dead functions removed
- ENTRY status
- SL status
- TP status
- TRAILING status
- RISK status
- HEDGE status
- PENDING status
- MANUAL status
- SCANNER status
- VISUAL status
- EXECUTION status
- remaining direct broker writers
- duplicate logic check
- behavior invariants check
- compile status
- final commit SHA
- comparison against main

Final target:

ENTRY       PASS
SL          PASS
TP          PASS
TRAILING    PASS
RISK        PASS
HEDGE       PASS
PENDING     PASS
MANUAL      PASS
SCANNER     PASS
VISUAL      PASS
EXECUTION   PASS

The final result must remain a functional MQL5 Expert Advisor, not merely a conceptual architecture.

Do not merge into main.
