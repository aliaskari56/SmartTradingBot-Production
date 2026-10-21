# LRN-04 Event/Lifecycle Verification Matrix — 2026-10-21

**Status: acceptance criteria only; none of these terminal/runtime cases is claimed to have passed.**  
**Primary EA:** `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
**Branch:** `fix/structure-first-fvg-trailing-20261020`

This matrix translates the current `OnTradeTransaction()` flow and LRN-04 design gates into testable lifecycle invariants. Python reference-model tests do not satisfy these cases. Every case requires an executable test against the MQL5 implementation or controlled terminal/Strategy Tester evidence.

## Required invariant

For one logical closed lifecycle, learning aggregates are applied exactly once after a recoverable commit. Before a commit is discoverable, no irreversible aggregate mutation or deletion of recoverable per-position state may make recovery ambiguous. If the journal's state is uncertain, learning mutation stops and a diagnostic identifies the failure.

## Event matrix

| ID | Scenario | Expected durable result | Failure/restart assertion |
|---|---|---|---|
| LRN-EVT-01 | Duplicate delivery of the same OUT deal | One event identity and one aggregate application | Replay after restart must not apply it twice |
| LRN-EVT-02 | Duplicate delivery of the same OUT_BY deal | One event identity and one aggregate application | Same idempotency guarantee as OUT |
| LRN-EVT-03 | Partial OUT while position remains open | Accumulate that deal once; lifecycle remains open | Restart preserves accumulated PnL and risk/profile context |
| LRN-EVT-04 | Partial OUT_BY while position remains open | Accumulate that deal once; lifecycle remains open | No premature finalization or state deletion |
| LRN-EVT-05 | Final OUT after one or more partial exits | One finalized lifecycle using all distinct exit-deal PnL | Duplicate final event cannot re-finalize |
| LRN-EVT-06 | Final OUT_BY after partial exits | One finalized lifecycle using all distinct exit-deal PnL | Replay does not double-count prior exit deals |
| LRN-EVT-07 | INOUT reversal | Close old lifecycle once; start distinct new lifecycle | Replayed reversal cannot close old lifecycle twice |
| LRN-EVT-08 | Unknown/invalid initial risk | Outcome may be recorded, but no fabricated R sample | `r_scaled` sentinel and `rcount` semantics remain consistent |
| LRN-EVT-09 | Crash after PREPARED append | PREPARED alone does not mutate committed projection | Recovery either safely resumes the same operation or stops fail-closed |
| LRN-EVT-10 | Crash after PREPARED flush, before COMMITTED | No uncommitted aggregate is applied | No second PREPARED for the same operation is silently created |
| LRN-EVT-11 | Crash during COMMITTED append | History is deterministically validated or rejected | Malformed final record is not silently skipped/repaired |
| LRN-EVT-12 | Crash after COMMITTED, before projection/cleanup | Recovery rebuilds from the committed absolute snapshot | Replayed event does not reapply increments |
| LRN-EVT-13 | Interior record corruption or digest mismatch | Journal is rejected; learning writes stop | No fallback to partial history |
| LRN-EVT-14 | Two EA instances receive same deal | At most one writer commits the event identity | Ownership/fencing prevents stale writer append or projection update |
| LRN-EVT-15 | Lock store unavailable/full or ownership lost | No journal write and no learning aggregate mutation | Visible diagnostic; no unlocked fallback |
| LRN-EVT-16 | Account/server/magic/environment differs | Separate journal namespace | No cross-account or tester/terminal replay |
| LRN-EVT-17 | Sequence gap/reuse or orphan COMMITTED | Reject the history | No silent sequence repair |
| LRN-EVT-18 | Unsupported schema or unknown state | Reject the history | Do not reinterpret as V1 or skip unknown record |
| LRN-EVT-19 | File open/write/flush/close error | Stop the operation and retain recoverable state | Never claim commit without verified protocol boundary |
| LRN-EVT-20 | Recovery scan exceeds configured budget | Fail closed with distinct diagnostic | No unbounded startup scan or partial aggregate publication |

## Evidence required per test

Record the case ID, terminal build, Strategy Tester mode or controlled terminal setup, input/configuration, event sequence, expected and actual journal bytes, aggregate before/after, restart point, diagnostic, and pass/fail. Keep golden journal bytes with the test artifacts. A compile result alone does not pass a lifecycle test.

## Current-code caution

The present `STB_LRN04Journal.mqh` is a V1 codec and has no persistence, lock, or recovery implementation. Current adaptive close handling updates several independent Global Variables; `TakeAccumulatedPositionPnl()` consumes its accumulator, and the close-recording call does not accept a durable deal-ticket idempotency key. Therefore, do not claim exactly-once behavior from the current source. Avoid a marker-only patch: idempotency must be coordinated with the lifecycle aggregate and commit/recovery protocol.

## Integration gate

Do not connect V2 journal mutation to `OnTradeTransaction()` until schema decisions are approved, MQL5 persistence/recovery and locking are implemented, and these tests have executable coverage. No live deployment is authorized by this matrix.

**LRN-04: NOT IMPLEMENTED / NOT VERIFIED. Release: BLOCKED / NOT VERIFIED.**
