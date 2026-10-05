# SmartTradingBot — Execution Authorization Unification Agent Work Order

Date: 2026-10-06

## Prepared source patch

Repository: `aliaskari56/SmartTradingBot-Production`
Branch: `main`
Prepared source commit: `2d421ea5869637c8a8fbcd4b927c2859aad5caaf`
Prepared source blob: `eb87776af3a1d52548edf0a111f602ca1d9b4e75`

## Objective

Unify the permission-to-create-new-exposure logic without weakening Risk/Safety or changing ownership boundaries.

A single mode/permission helper is now the source of truth for:

- Automatic pending execution
- Manual pending execution
- HEDGE command/execution

Specific risk checks remain specific to each operation.

## New central helpers

`STB_EXECUTION_SOURCE`

- `STB_EXECUTION_AUTO`
- `STB_EXECUTION_MANUAL`
- `STB_EXECUTION_HEDGE`

`STB_ExecutionModeAllowed(source, reason)`

Owns source-level authorization:

- AUTO: requires `InpAutoTrading && !InpDiagnosticM15Mode && g_autoTrading`
- HEDGE: requires `InpAllowOneClickHedge`
- MANUAL: does not depend on automatic-trading state

`STB_ExecutionPermissionAllowed(symbol, source, reason)`

Adds common execution-environment permission:

- non-empty symbol
- source mode permission
- terminal/program/account trading permission via `STB_TradeEnvironmentAllowed()`

## Required architecture

Automatic pending:

`Scanner -> Candidate -> Risk/Safety -> STB_ExecutionPermissionAllowed(AUTO) -> ExecuteSetup`

Manual pending:

`UI -> STB_ExecutionManualPendingCommand -> Risk/Safety -> STB_ExecutionPermissionAllowed(MANUAL) -> ExecuteSetup`

HEDGE:

`UI -> STB_ExecutionHedgeCommand -> Risk/Safety -> STB_ExecutionPermissionAllowed(HEDGE) -> STB_ExecuteMarketHedge`

## Important rule

The central helper is the source of truth for mode authorization.

Do not reintroduce independent copies of:

`!InpAutoTrading || InpDiagnosticM15Mode || !g_autoTrading`

or direct HEDGE feature-flag authorization elsewhere.

The Scanner may use `STB_ExecutionModeAllowed(AUTO)` as an early filter for efficiency, but Risk/Safety remains the final authorization owner.

## Patch details

The prepared source changes:

1. Adds the central source enum and two authorization helpers.
2. Makes `STB_RiskAuthorizePending()` use the centralized permission gate.
3. Makes `STB_RiskAuthorizeMarketHedge()` use the centralized permission gate.
4. Makes `STB_ExecutionHedgeCommand()` use the centralized HEDGE mode gate.
5. Makes `STB_ProcessExecutionCandidates()` use the same AUTO mode source-of-truth.
6. Leaves direction, spread, exposure, broker geometry, SL/TP, volume, OrderCheck and other Risk/Safety checks in their existing owners.

## MT5 Agent requirements

This Git commit is PREPARED CODE, not runtime acceptance.

Before applying to the active Expert:

1. Reconcile active source again.
2. Preserve active-only changes.
3. Forward-port this exact logical patch.
4. Compile after the corrective unit.
5. Require `0 errors / 0 warnings`.
6. Rebuild the same `SmartTradingBot.ex5`.
7. Reload the same Expert.
8. Run authorization tests.

## Mandatory authorization tests

### AUTO locked

- Diagnostic ON -> automatic execution rejected.
- InpAutoTrading OFF -> automatic execution rejected.
- g_autoTrading OFF -> automatic execution rejected.

### AUTO enabled

All three required and environment allowed -> Risk/Safety may continue.

### MANUAL

Automatic state may be OFF, but manual pending still must pass:

- central execution permission
- trade environment
- direction
- spread
- exposure
- broker geometry
- SL/TP
- OrderCheck
- execution verification

### HEDGE

Must pass:

- central HEDGE permission
- hedging account
- symbol tradability
- market-order permission
- SL permission/geometry
- spread
- volume
- OrderCheck
- deal verification
- position verification

### No bypass

No UI/Scanner/Adaptive/Persistence/Diagnostics path may create exposure directly.

## Acceptance

Do not report COMPLETE from Git preparation alone.

Required final state:

`PREPARED` + `0 errors` + `0 warnings` + `EX5 rebuilt` + `Expert reloaded` + `runtime authorization tests passed`.

