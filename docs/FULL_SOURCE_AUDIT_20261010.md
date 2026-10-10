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
