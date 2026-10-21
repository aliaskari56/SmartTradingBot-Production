# LRN-04 Current-Code Gap Review — 2026-10-21

## Scope

This is a code-review note for reliability and test planning. It does not implement a journal and is not a release approval. The primary Expert Advisor remains `MQL5/Experts/SmartTradingBot_FINAL.mq5`.

## Verified CI result

For commit `524b1c50dbe3df08b189877c0729afdaa9e2718f`:
- The reference Python contract suite completed successfully: 10 tests, `OK`.
- The static guardrail workflow completed successfully.
- The trading-safety-defaults workflow completed successfully.
- MetaEditor compiled `SmartTradingBot_FINAL.mq5` with 0 errors and 0 warnings.
- These results do not demonstrate crash consistency or runtime behavior of an MQL5 journal.

## Current code path reviewed

In `SmartTradingBot_FINAL.mq5`:
- `GetAccumulatedPositionPnl(positionId)` reads a terminal Global Variable.
- `SetAccumulatedPositionPnl(positionId,value)` writes that value.
- `TakeAccumulatedPositionPnl(positionId)` reads and then deletes it.
- `OnTradeTransaction()` calculates deal PnL for OUT, OUT_BY and INOUT events and passes the lifecycle aggregate to `STB_AdaptiveRecordClosedDeal(...)`.
- `STB_AdaptiveRecordClosedDeal(...)` updates multiple profile Global Variables (including W/L and RSum/RCount) and logs the event. These separate writes are not a single atomic durable transaction.
- The call to `STB_AdaptiveRecordClosedDeal` does not include a deal ticket or durable idempotency key in its current signature.
- The existing CSV adaptive log is telemetry and is not, by itself, a transaction journal with a verified PREPARED/COMMITTED recovery protocol.

## Reliability gaps that remain open

1. **Idempotency:** duplicate delivery/replay of a close transaction must not update learning aggregates more than once.
2. **Crash windows:** interruption between PnL accumulation, lifecycle close processing, multiple aggregate writes, logging and cleanup must recover to one deterministic state.
3. **Lifecycle identity:** partial exits, final OUT/OUT_BY, and INOUT reversals must have unambiguous lifecycle boundaries.
4. **Recovery:** startup recovery must distinguish a torn final record from corruption in the middle of the journal and must fail closed when integrity cannot be established.
5. **Concurrency:** multiple charts/EA instances must not append conflicting records or apply the same deal concurrently.
6. **Risk integrity:** unknown or invalid initial risk must remain unknown; recovery must not fabricate an R-multiple.
7. **Runtime proof:** the Python tests validate a reference record format only. They do not exercise MQL5 FileOpen/FileFlush semantics, terminal restarts, or multi-instance contention.

## Required implementation and validation sequence

1. Define the durable record and recovery state machine, including sequence, lifecycle identity, deal-ticket idempotency, checksum/hash validation, and explicit record-length limits.
2. Implement the MQL5 codec and append/recovery routines separately from the existing telemetry logger.
3. Serialize journal writers with a scoped lock and a documented timeout/failure policy.
4. Apply absolute aggregate snapshots only after a recoverable commit protocol; do not rely on independent increments as the journal of record.
5. Add deterministic tests for duplicate OUT/OUT_BY/INOUT, partial close, restart at each persistence boundary, torn tail, interior corruption, lock failure, and concurrent writers.
6. Run MetaEditor compile, static checks, and a controlled Strategy Tester/restart test suite; record exact build and test evidence.

## Release gate

LRN-04 remains **NOT IMPLEMENTED / NOT VERIFIED**. The successful compile and reference-contract tests are necessary but insufficient. Do not treat this review note as a production release artifact. No live deployment or live trading was performed.
