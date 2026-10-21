# LRN-04 Implementation Plan — 2026-10-21

## Status and scope

This plan concerns persistence correctness and deterministic recovery in the existing `MQL5/Experts/SmartTradingBot_FINAL.mq5`. It does not change the primary EA identity or authorize deployment. It is a staged implementation plan, not a claim that the journal has already been implemented.

## Phase 0 — Freeze invariants

Before source changes, preserve these invariants:
- One canonical close outcome per deal/lifecycle; replay is idempotent.
- A partial exit does not close the lifecycle while the position remains open.
- An INOUT reversal closes the old lifecycle and starts a distinct new lifecycle.
- Missing/invalid initial risk stays unknown and does not generate a fabricated R sample.
- If durable state is ambiguous, learning updates fail closed rather than applying an uncertain aggregate.
- Journal namespace must isolate account/server, EA magic, environment/tester context, and schema version.

## Phase 1 — Explicit identity and codec

Create a separate journal module with a versioned ASCII record format and strict bounds. Each logical close event must carry at least:
- schema version and monotonic sequence;
- account/environment namespace and magic;
- deal ticket, position identifier, and lifecycle epoch;
- event kind (partial OUT, final OUT/OUT_BY, reversal close);
- signed scaled PnL and explicit risk-validity state;
- scaled R sample only when initial risk is valid;
- previous-record digest and CRC32;
- PREPARED/COMMITTED state.

Reject non-canonical numbers, unknown enums, invalid encoding, oversized records, malformed checksums, sequence gaps, and digest-chain mismatch. Use explicit documented sentinels rather than conflating missing values with zero.

## Phase 2 — Durable commit protocol

Do not treat multiple independent Global Variable writes as a transaction. Persist an absolute snapshot through a journal protocol:
1. Acquire an account/magic/schema-scoped writer lock with bounded wait.
2. Recover and validate the last committed sequence.
3. Detect an already committed deal/lifecycle identity and return idempotently.
4. Append a PREPARED record with a complete absolute aggregate snapshot.
5. Flush and close, then verify according to the supported MQL5 file semantics.
6. Append a COMMITTED record referencing the prepared sequence/digest.
7. Flush and close.
8. Only after recovery can establish the committed snapshot, perform safe cleanup of temporary per-position state.

If any stage fails, release the lock safely, do not advance learning aggregates, and set a visible diagnostic status. Validate exact FileOpen/FileFlush behavior on supported terminal builds; do not assume a successful call alone proves physical-media durability.

## Phase 3 — Transaction intake and lifecycle rules

The transaction callback should capture stable identifiers and bounded event data, then delegate state mutation to a serialized processor. The processor must:
- process duplicate transaction callbacks idempotently;
- sum each deal ticket once;
- preserve accumulators on partial closes;
- finalize the old lifecycle on full close;
- create a distinct lifecycle epoch on INOUT reversal;
- avoid magic-filter ordering that loses protection-state cleanup for foreign/manual deals;
- never delete recoverable state before a durable commit is discoverable.

## Phase 4 — Recovery

On startup and on controlled reconciliation:
- validate the journal from its last known checkpoint within a bounded scan budget;
- ignore only a clearly incomplete final append if the format makes that unambiguous;
- treat interior corruption, impossible sequence transitions, or conflicting committed records as a hard integrity failure;
- rebuild absolute aggregates from the last valid committed snapshot;
- reconcile open positions and recent deal history without double-applying committed tickets;
- isolate tester/demo namespaces from other environments.

## Phase 5 — Tests required before acceptance

Implement deterministic tests for:
- duplicate OUT and OUT_BY notifications;
- partial OUT followed by final OUT;
- INOUT reversal with distinct lifecycle epochs;
- restart after PREPARED append, after flush, after COMMITTED append, and before cleanup;
- torn final record versus interior corruption;
- duplicate deal ticket after restart;
- simultaneous chart writers and lock timeout;
- unavailable/invalid initial risk;
- account, server, magic, symbol, schema and tester namespace separation;
- file-open/write/flush failure and bounded recovery scan.

The Python reference codec tests are necessary but do not replace tests of the MQL5 implementation or terminal runtime.

## Acceptance gate

LRN-04 stays NOT VERIFIED until the MQL5 implementation exists, MetaEditor compiles it, contract and fault-injection tests pass, and controlled terminal/Strategy Tester restart evidence is attached. No live deployment is part of this plan.
