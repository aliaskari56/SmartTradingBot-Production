# LRN-04 EA Integration Audit — 2026-10-21

## Status

**Source audit only. No runtime code changed. LRN-04 remains NOT IMPLEMENTED for persistence and NOT VERIFIED.**

Branch: `fix/structure-first-fvg-trailing-20261020`  
Primary EA: `MQL5/Experts/SmartTradingBot_FINAL.mq5`

## Findings from the current source

### A1 — Journal module is included but not called

The EA includes `<STB\\STB_LRN04Journal.mqh>` at approximately line 10504. A source-wide search of the fetched EA text found no `STB_LRN04_` calls. The include therefore does not establish that the codec participates in runtime processing.

### A2 — Close-event processing still uses the legacy mutation path

In `OnTradeTransaction()` (approximately lines 10787–11006):

- The callback accepts `TRADE_TRANSACTION_DEAL_ADD` and selects the deal history record.
- It processes `DEAL_ENTRY_OUT`, `DEAL_ENTRY_OUT_BY`, and `DEAL_ENTRY_INOUT`.
- For `INOUT`, it reads and consumes accumulated position PnL, calls `STB_AdaptiveRecordClosedDeal(...)`, then deletes position profile/risk state.
- For `OUT/OUT_BY`, it adds deal PnL to accumulated PnL, writes that accumulator, checks whether the position remains open, consumes the accumulator after final close, calls `STB_AdaptiveRecordClosedDeal(...)`, and deletes profile/risk state.

No durable PREPARED/COMMITTED journal operation appears in this callback. Consequently, the current callback is not protected by the proposed LRN-04 transaction protocol.

### A3 — Current safeguards do not prove journal idempotency

The source contains per-ticket protection-state cleanup and adaptive-state helpers, but the inspected close path does not consult a durable LRN-04 committed-deal index before mutating adaptive aggregates. Existing protections must be preserved and evaluated separately; they are not substitutes for a crash-consistent journal.

### A4 — Integration ordering is a correctness gate

The journal must not be inserted as a marker-only call around `STB_AdaptiveRecordClosedDeal()`. Before integration, the implementation needs deterministic lifecycle reconstruction, a stable event identity, absolute aggregate snapshots, a serialized writer lock, strict recovery validation, and repeatable handling of every failure boundary.

The V2 proposal currently specifies 26 serialized fields including checksum, but its digest algorithm, namespace canonicalization, fixed-point scales, sentinels, duplicate-commit policy, and persistence/locking semantics remain open gates. Do not implement or emit V2 records until those decisions and golden vectors are frozen.

## Required next steps

1. Freeze V2 canonicalization, digest, namespace, numeric scales, sentinel semantics, and duplicate policy.
2. Add reference tests for full journal transitions, not only individual record encoding.
3. Implement a separately testable MQL5 journal/persistence module.
4. Verify the actual MetaTrader file and lock semantics on supported builds.
5. Recover/validate the journal before processing close events; only then integrate it with the existing EA close-event path.
6. Add fault-injection and controlled Strategy Tester/terminal restart evidence.
7. Compile the exact resulting commit and rerun CI.

## Release decision

**BLOCKED / NOT VERIFIED.** The prior successful compile confirms syntax/build success for the previous commit only. It does not prove durable persistence, recovery, idempotency, or restart safety. No changes to `SmartTradingBot_FINAL.mq5` or live runtime behavior were made by this audit.
