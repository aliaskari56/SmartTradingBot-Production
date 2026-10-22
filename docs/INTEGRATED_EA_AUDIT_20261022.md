# Integrated EA Audit Checkpoint — 2026-10-22

## Status

**Audit checkpoint only — NOT a production release approval.** The EA remains deliberately restricted to MetaTrader Strategy Tester by the `OnInit()` gate. This checkpoint does not enable live or demo chart initialization.

- Repository: `aliaskari56/SmartTradingBot-Production`
- Primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
- EA version after the source corrections in this checkpoint: `1.133`
- Source-changing commit for the quote-age correction: `51ba1c570d0cc65a697de0883b54d908933e2e6a`
- Main HEAD when this checkpoint was written: `9a9fc92c2931cca80406c67ecb631ea363983646`
- Scope: source integration, execution-boundary review, scanner data integrity, build provenance, and CI regression checks.
- Not performed: a full Strategy Tester scenario suite, terminal restart/fault-injection tests, demo account execution, or broker-specific validation.

## Corrections made in this checkpoint

### 1. Scanner quote-age configuration is now authoritative

Previously, quote validation used `MathMax(30, InpScannerMaxQuoteAgeSec)`, which silently accepted quotes up to 30 seconds old even when a lower limit was configured. The market-quality freshness score repeated the same floor, so eligibility and scoring did not fully honor the input.

Changes:
- `InpScannerMaxQuoteAgeSec` is validated to the range **1–3600 seconds**.
- The shared quote validator rejects quotes older than the configured value.
- Market-quality freshness scoring uses that same configured value.
- The hidden 30-second floor was removed from both paths.
- Regression checks were added to both the static audit and safety-defaults suite.
- The input comment for `InpScannerSymbols` was de-duplicated and the EA version was advanced to 1.133.

This change affects data freshness gating, not the strategy's entry thresholds or scoring weights.

### 2. Build provenance metadata corrected

The MetaEditor workflow's provenance manifest previously recorded `riskSizingDefault = false`, while the source declares `InpUseRiskSizing = true`. The workflow metadata now reports `riskSizingDefault = true`; `liveAutoTradingDefault = false` remains consistent with `InpAutoTrading = false`.

A safety-defaults regression check now compares the source defaults with the build manifest so this mismatch is less likely to recur.

### 3. Previously integrated execution safeguards retained

The current source retains the following architecture:
- Pending-order geometry is routed through a central writer with preflight checks, server-retcode classification, and post-write geometry verification.
- Pending-order deletion has one direct broker writer and authorization checks.
- Position SL modification has one direct broker writer and shared SL proposal arbitration.
- Automatic and manual pending-order creation paths perform preflight checks, validate server results, and verify initial SL protection.
- Pending trailing is isolated in `STB_PendingTrail.mqh`; distance resolution and directional tick alignment are in `STB_PendingDistanceResolver.mqh`.
- Newly selected scanner symbols request M15/H4 history through `CopyRates` before incomplete history is rejected.
- The tester-only `OnInit()` gate remains unchanged.

## Integrated component map

| Component | Responsibility | Current status |
|---|---|---|
| `SmartTradingBot_FINAL.mq5` | Scanner, setup construction, execution gates, position/pending managers, lifecycle handoff, dashboard | Primary EA; Strategy Tester only |
| `STB_PendingDistanceResolver.mqh` | Broker limits, tick-size alignment, pending entry/SL distance resolution | Included and used by pending geometry paths |
| `STB_PendingTrail.mqh` | Pending-order trail state, closed-M5 structure for stop orders, retry/backoff, restart reconstruction | Included and used by the management cycle |
| `STB_LRN04Journal.mqh` | Canonical record codec and CRC validation | Codec only; durable persistence is intentionally not wired into `OnTradeTransaction()` |
| `tools/audit_static_checks.py` | Source-level invariants and include/delimiter checks | Static regression guard; not a compiler |
| `tools/test_trading_safety_defaults.py` | Conservative defaults, trade gates, quote-age contract, provenance consistency | Regression guard; not runtime proof |
| `tools/test_lrn04_journal_contract.py` | Python reference model and codec-parity tests | Reference contract only; not an MQL5 storage/runtime test |

## Professional documentation reviewed

The execution checks were reviewed against the official MQL5 reference:
- `OrderCheck()`: https://www.mql5.com/en/docs/trading/ordercheck
- `OrderSend()`: https://www.mql5.com/en/docs/trading/ordersend
- Trade-server return codes: https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes

These references make an important distinction: a preflight check does not guarantee that a later server operation will succeed, and the Boolean result from `OrderSend()` is not by itself proof of final execution. The EA therefore must continue checking trade-server return codes and verifying terminal-visible postconditions. These checks reduce known failure modes; they do not guarantee fills, bounded losses, or profitable results.

## CI evidence — refreshed 2026-10-22

Latest reviewed HEAD: `75ad6055dfed3f323484bd193fb80141d6983a5c`.
- MQL5 static audit: **passed** — run [39736355470](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736355470)
- Trading safety defaults: **passed** — run [39736355417](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736355417)
- LRN-04 journal contract tests: **passed** — run [39736355473](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736355473)
- MetaEditor compile: **passed** — run [39736355430](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736355430). Both `SmartTradingBot_FINAL.mq5` and the isolated LRN-04 SHA-256 golden-vector script completed successfully. The compile job uploaded the compiler log, EX5, and provenance manifest.

The latest compile is tied to HEAD `75ad6055dfed3f323484bd193fb80141d6983a5c`; the intervening source change corrected comments in the daily-risk guard and the test changes passed in the same revision. Clean compilation and source-level tests do not establish Strategy Tester correctness, crash recovery, broker compatibility, or profitability.

## Follow-up source change — adaptive INOUT reversal lifecycle

After the checkpoint above, commit `ea9da7a4cd22285cd0ca10db86624be338c90bbf` updated the `DEAL_ENTRY_INOUT` branch in `OnTradeTransaction()`. It now clears the old adaptive position state, checks whether an active position remains in the incoming deal direction, and transfers a valid order profile plus risk estimate to the new lifecycle. If the active exposure/profile cannot be confirmed, it logs the condition and retains order state for reconciliation instead of claiming initialization succeeded.

Regression guards were added in commit `93425dad9203179d493b78e58c76cb1a341b0fa7`:
- The safety-defaults suite checks ordering of old-state deletion and new-state initialization.
- It checks that the reverse position direction is validated and order state is retained when transfer cannot be confirmed.

CI for the latest HEAD `93425dad9203179d493b78e58c76cb1a341b0fa7`:
- MetaEditor compile: **passed**, run [39736851164](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736851164); both the EA and isolated SHA-256 golden-vector script reported **0 errors, 0 warnings**. Build artifacts were uploaded.
- Trading safety defaults: **passed**, run [39736851179](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736851179).
- MQL5 static audit: **passed**, run [39736851031](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736851031).
- LRN-04 journal contract tests: **passed**, run [39736851053](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39736851053).

These checks verify compilation and source-level contracts, not the runtime semantics of a netting reversal. In particular, the branch still requires Strategy Tester coverage for broker event ordering, position-identifier behavior, missing order metadata, absent SL, and restart/reconciliation paths.

## Remaining release blockers and test gaps

### A. LRN-04 durable journal is not integrated

The MQL5 module currently implements record encoding/decoding and checksum validation; it does not implement durable append/recovery, writer locking/fencing, transaction idempotency, or aggregate projection recovery. The primary transaction handler is deliberately not wired to this codec.

Do not wire it into the live learning path until the schema, lock/fencing contract, recovery policy, and numeric semantics are approved and the terminal-level fault-injection suite is implemented. The Python tests are an in-memory reference model, not evidence of file durability or crash consistency.

### B. Strategy-contract decisions remain open

Do not silently change strategy semantics while doing structural refactoring. The older strategy-to-manager audit identified contracts requiring explicit decisions and/or regression fixtures, including:
- Whether the structure detector represents one fresh break or a separately ordered CHoCH-then-BOS sequence.
- Whether Universal mode can override a required H4-alignment rejection.
- Whether local FVG and Order Block must share a displacement/BOS event identity.
- Whether automatic protection is intended to cover every account position or only positions within the managed-symbol scope.
- Whether stability is historical persistence or a current-state score component.

Some earlier findings have since received source corrections; re-audit the current implementation before treating an old finding as still open or fully closed.

### C. Runtime tests still required

At minimum, exercise:
- Quote ages just below, at, and above the configured threshold; future timestamps; unavailable server clock; missing M15/H4 history; newly selected symbols.
- Pending order accepted, initial SL verified, partial fill, remainder trailing, full fill, order disappearance, and restart reconstruction.
- Broker rejections around tick-size, stops level, freeze level, and changing quotes between preflight and write.
- Duplicate/delayed trade-transaction events, partial closes, INOUT reversal, restart between PnL accumulation and adaptive-stat update.
- Multiple EA instances competing for a symbol-management lease and entry lock.
- Daily-loss guard behavior when state is missing/corrupt, server time regresses, a close is rejected, or the terminal restarts.

## Release decision

**BLOCKED / NOT VERIFIED for production use.** Keep the Strategy Tester-only gate. Do not infer profitability or broker compatibility from a clean compile or static tests. The latest MetaEditor run is complete and passed. The next safe step is to add controlled non-live tests for the specific lifecycle and broker-edge cases above before considering any deployment change.
