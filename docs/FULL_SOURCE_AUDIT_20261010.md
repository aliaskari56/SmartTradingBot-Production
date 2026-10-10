# Full Source Audit — 2026-10-10

## Scope and status

Target source: `MQL5/Experts/SmartTradingBot_FINAL.mq5` (9,382 lines at this checkpoint).

This is an in-progress source audit, not a release approval. Static reading and source-level checks cannot establish that MetaEditor compiles the file, that a broker accepts requests, or that strategy signals are profitable. The audit branch remains separate from the release branch.

## Review map

| Area | Static review status | Required runtime verification |
|---|---|---|
| Inputs, defaults, and validation | Initial pass | Test default and boundary input sets in MetaEditor/Tester |
| Symbol universe, synchronization, sessions, quotes | Initial pass; rejection logs improved | Verify broker suffixes, Market Watch, session calendars, and multi-symbol history |
| H4 trend and M15 structure / CHoCH / BOS | Requires deeper pass | Visual signal-by-signal replay against closed bars |
| Swing collection, FVG, order block, structural SL/TP | Initial pass | Compare generated geometry with chart bars and broker constraints |
| RSI/CCI handles and CopyBuffer indexing | Initial pass | Confirm indicator readiness and values in Tester |
| Adaptive profile selection and persistence | Requires deeper pass | Fresh-state and long-run lifecycle tests; check profile leakage/reset behavior |
| Candidate scoring, ranking, confidence gate | Initial pass; logging improved | Exercise one-candidate, close-score, stale-candidate and no-candidate cases |
| Pending geometry, expiry, OrderCheck, retcodes | Initial pass | Compile and test each broker execution/expiration mode |
| Fixed-lot and risk-based sizing | Initial pass | Compare calculated risk with actual tick value, commission, and gaps |
| Position SL arbitration, profit lock, trailing | Existing static guardrails reviewed | Multi-proposal, no-SL, freeze/stops-level, netting/hedging tests |
| Manual controls, hedge, delete authorization | Initial pass | Button/event and unauthorized-order regression tests |
| Startup, timer/tick scheduling, restart recovery | Initial pass | Attach/re-attach, timeframe switch, terminal restart, no-tick conditions |
| Trade transaction and adaptive outcome accounting | Initial pass | Partial close, reversal, netting/hedging and commission/swap history tests |
| Dashboard and visual objects | Not yet exhaustively reviewed | Chart interaction and object cleanup |
| Compiler, warnings, Strategy Tester, demo terminal | NOT RUN | Mandatory before release |

## Confirmed changes on this branch

1. Removed the account-wide `PositionsTotal()==0 && OrdersTotal()==0` scanner gate from initialization and M15 scan paths. An unrelated open position/order no longer suppresses the signal scanner globally. Same-symbol managed exposure and account order limits remain enforced at candidate execution.
2. Added stage-specific logs for scanner data eligibility, market-quality, regime, watchlist-refresh, and unclear-confidence rejection paths.
3. Changed watchlist refresh to reject a candidate if its current market-quality or regime snapshot cannot be refreshed, instead of retaining stale values from an earlier pass.
4. Kept the tester-only AUTO override and existing terminal/program/account permission checks intact.
5. Kept broker geometry checks, SL verification, order retcode checks, and risk-volume limits intact.

## Static checks at this checkpoint

- Delimiters, comments and string/character literals: no lexical imbalance detected by the local source-level scan.
- One direct `trade.OrderDelete(` call site remains.
- One direct `trade.PositionModify(` call site remains.
- No account-wide positions/orders condition remains as a scanner gate.
- Stage-specific scanner diagnostics are present.
- The repository's static workflow passed earlier for commit `11e3b134f6303e611360e49eced8e35bf2644d3e`, before the latest diagnostics changes. The latest source revision has not yet been confirmed by that workflow.
- The official Python static-check script has not been executed locally against this exact source revision.

## Open blockers / questions to resolve

- No MetaEditor compiler or MT5 terminal is available in this environment; compile errors and warnings remain unverified.
- No Strategy Tester or demo-broker run has been performed.
- Multi-symbol Strategy Tester coverage is restricted by default through `InpTesterChartSymbolOnly=true`; this is intentional test isolation, but must be explicitly changed for multi-symbol tests.
- Empty `InpScannerSymbols` means selected Market Watch symbols, not every broker symbol.
- The live AUTO state can persist as OFF after a deliberate chart-button toggle even when `InpAutoTrading=true`; the startup log reports both values. This is a persisted runtime override, not an unexplained terminal permission failure.
- The complete structural signal algorithm, adaptive-learning state lifecycle, management behavior under partial fills/reversals, and all broker-specific order modes still require deeper section-by-section review and runtime fixtures.
- No source change in this audit should be treated as proof of profitability or permission to deploy on a live account.

## Release gate

Do not merge or mark ready until:
1. the full static checker passes on the exact candidate commit;
2. MetaEditor compile completes with no errors and warnings are triaged;
3. Strategy Tester logs show signal generation, rejection reasons, accepted pending orders, and SL confirmation;
4. baseline and candidate are tested with identical symbol, timeframe, dates, modelling, spread, commission, and inputs;
5. order/deal history reconciles with the EA's logs;
6. demo-terminal restart, permissions-off, no-quotes, and broker rejection cases are tested.


## Deeper review pass — 2026-10-10

### Source paths traced in this pass

- **Signal construction:** `BuildSetup` uses closed-bar structural detection, rejects stale BOS when the age input is enabled, derives entry from both the origin-zone edge and the broken swing, then routes the result through `PreparePendingSetup` for live-market/broker geometry and RR validation. An already-crossed stop trigger is rejected instead of chased.
- **Oscillator data:** RSI/CCI are read from closed bars (`CopyBuffer(..., start_pos=1, count=2)`); the code maps the oldest copied value to shift 2 and the newest closed value to shift 1. If oscillator confirmation is enabled but data is unavailable, it only blocks setup creation when `InpOscillatorHardFilter=true`; the default is false.
- **Pattern inputs:** with the current defaults, `InpRequireFVG=true` and `InpRequireOB=true` do **not** make either pattern mandatory because `InpStrictPatternFilters=false`. In that configuration, found patterns contribute to score, while missing OB uses a structural fallback. This is current documented behavior, not an execution-permission bypass.
- **Candidate execution:** only a `CLEAR` top-candidate confidence state proceeds. If there are no candidates or the top-vs-second gap is too small, the EA intentionally does not place an order. Each candidate is revalidated against fresh data, direction permissions, rebuilt setup time, and pending geometry before the final AUTO/permission/exposure checks.
- **Order creation:** the automatic path validates exposure, cooldown, volume, supported expiration, `OrderCheck`, server retcode, and initial pending SL verification. If the accepted order cannot be verified with an initial SL, it requests rollback rather than counting the setup as successfully placed.
- **Risk sizing:** risk mode uses `OrderCalcProfit` for one lot from planned entry to SL, scales by equity risk, respects the configured volume cap, and rejects rather than rounding upward to the broker minimum when that would exceed the configured limit. This does not include a guaranteed allowance for commission, slippage, gaps, or stop execution differences; those require runtime/broker validation.
- **Adaptive outcome lifecycle:** the transaction handler filters adaptive learning to this EA's magic and excludes hedge comments. It accumulates realized P/L across partial closes and handles `DEAL_ENTRY_INOUT` separately. Netting accounts with mixed/manual additions, broker-specific deal histories, and restart/recovery scenarios still need targeted fixtures before the outcome accounting can be certified.
- **Protection/execution permissions:** the central position-modification writer rechecks live position geometry, symbol lease, terminal/program/account permissions, TP snapshot, retcode, and resulting SL. These are static-path observations only; they do not establish broker acceptance under freeze/stops-level constraints.

### Confirmed CI result

GitHub Actions run **38065393299** for source commit `84d1a46a28d214a2e0e3f006706ee19f57f33c8d` completed successfully; the `static-guardrails` job and “Run static guardrails” step both report success. This validates the repository's static guardrail script for that source revision, not compilation or runtime behavior.

### Remaining audit work

This pass did not establish a new confirmed source-level blocker requiring another trading-logic edit. The intentional conservative gates above can reduce order count, but loosening them without a controlled baseline/candidate backtest would not be a safe fix. Remaining priorities are full manual review of structure/swing/FVG/OB calculations, pending-trail restart and lease ownership, manual-order ownership rules, all input boundary cases, and a repeatable MT5 compile + Strategy Tester + demo-terminal regression suite. The source remains **not release-verified**.


## Root-cause finding and scoped fix — scanner cadence

### Confirmed blocker

The scanner previously returned immediately whenever the chart symbol's last closed M15 bar was unchanged:

`if(cycleBar<=0 || cycleBar==g_scannerLastCycleBar) return;`

Both `OnTick` and `OnTimer` only called the scanner when `NewM15Bar()` on the **chart symbol** changed. Therefore `InpScanSeconds=10` controlled timer events but did not actually schedule a scan every ten seconds. In a multi-symbol watchlist, a quiet/closed chart symbol could prevent fresh candidates on other active symbols from being evaluated; the candidate list could remain stale until the chart symbol printed a new M15 bar. This is a genuine scanner scheduling defect, not a strategy-quality opinion.

### Change made

- The scanner now runs when either the chart's closed M15 bar changes **or** the configured `InpScanSeconds` interval elapses.
- The interval fallback permits a scan even if the chart symbol's last closed-bar timestamp is unavailable, provided the scanner's symbol universe itself can be read.
- `OnTimer` now calls the scanner on each timer event; the scanner applies its own cadence gate.
- `OnTick` also asks the scanner to run, but candidate execution happens only when `g_scannerCycle` proves a new scan completed. This avoids re-executing an old top-candidate list on a throttled call.
- Added static guardrails for the timer-based cadence and execution-after-new-cycle contract.
- Adaptive profile probes already deduplicate by each symbol's closed M15 bar, so repeating scans within that bar should not inflate that specific attempt counter.

### Validation and caveats

The source and static-check script were updated on the audit branch. The new static guardrail has not yet been confirmed by a fresh CI run in this note. No local Python checker execution, MetaEditor compilation, Strategy Tester run, or demo-terminal test was available at the time of this edit. In particular, verify timer behavior in Strategy Tester and confirm that repeated scans at the configured interval do not create excessive CPU/log load on a large symbol universe. The change addresses scanner scheduling only; it does not loosen strategy, AUTO, risk, broker-permission, or candidate-confidence gates.


### Follow-up CI result for the cadence fix

The first CI attempt for this change failed because the newly added Python guard had a mismatched parenthesis (workflow run `38073710433`). The guard syntax was corrected in commit `885c32b06e7d7bfa77735330018d66eb316a5875`. The subsequent workflow run **38073755753** completed successfully, including the `static-guardrails` job. The initial failure is recorded here rather than hidden. This still does not establish MQL5 compilation or timer behavior in MT5.
