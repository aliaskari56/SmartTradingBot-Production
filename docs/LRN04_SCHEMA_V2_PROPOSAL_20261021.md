# LRN-04 Journal Protocol V2 — Schema Proposal (2026-10-21)

## Status

**Proposal only — not implemented, not approved for runtime use.** This document closes the design questions raised by `LRN04_RECORD_CONTRACT_GAP_REVIEW_20261021.md` sufficiently to support a focused review before changing the current `LRN04V1` codec. Do not append V2 records with the V1 codec.

## Design goals

- One committed observation per closed deal/lifecycle.
- A PREPARED record contains a complete absolute aggregate snapshot, never a delta to replay.
- A COMMITTED record explicitly references exactly one PREPARED record.
- Records are isolated by account/server, EA magic, execution environment, and schema.
- Recovery is deterministic, bounded, and fail-closed on ambiguous history.

## Proposed record envelope

Keep one canonical ASCII line per record, with LF terminator, a fixed field count, a checksum over the exact body bytes, and a maximum encoded size. The exact field order must be pinned by golden vectors before implementation.

Required fields:

1. `schema`: exact version token, proposed `LRN04V2`.
2. `record_seq`: unsigned canonical 64-bit decimal, strictly increasing per journal namespace.
3. `state`: `PREPARED` or `COMMITTED`.
4. `environment`: explicit enum such as `TERMINAL`, `TESTER`, or `OPTIMIZATION`; unsupported values fail closed.
5. `server_scope`: canonical bounded token derived from the broker server identity.
6. `account_scope`: canonical bounded account identifier/hash; do not put credentials in the record.
7. `magic`: unsigned EA magic.
8. `operation_id`: stable ID shared by the PREPARED and COMMITTED pair.
9. `prepared_seq`: zero for PREPARED; exact PREPARED sequence for COMMITTED.
10. `prepared_digest`: genesis/sentinel for PREPARED; exact digest of the PREPARED canonical body for COMMITTED.
11. `deal_ticket`: unsigned deal ticket; zero is allowed only for explicitly documented non-deal snapshots.
12. `position_id`: unsigned position identifier.
13. `lifecycle_id`: stable lifecycle epoch, distinct across a reversal.
14. `symbol_code`: bounded ASCII broker symbol.
15. `direction`: `BUY`, `SELL`, `FLAT`, or `NA`.
16. `entry_kind`: `OUT`, `OUT_BY`, `INOUT`, or an explicitly permitted snapshot kind.
17. `pnl_minor`: signed integer in account-currency minor units; currency precision conversion must be defined from terminal metadata and validated for overflow.
18. `risk_state`: `KNOWN`, `UNKNOWN`, or `NOT_APPLICABLE`.
19. `r_scaled`: signed fixed-point R value when risk is known; otherwise a reserved canonical sentinel.
20. `wins_scaled`, `losses_scaled`: fixed-point absolute post-event aggregate values.
21. `rsum_scaled`, `rcount`: fixed-point absolute post-event R aggregate values.
22. `decay_time`: canonical Unix timestamp in seconds, with explicit zero/sentinel semantics.
23. `previous_record_digest`: digest of the immediately preceding valid record, or a fixed genesis token for the first record.
24. `checksum`: fixed-width uppercase hexadecimal checksum over all preceding fields and separators.

This is a candidate field list, not a claim that the present V1 record already contains these fields.

## State-machine rules

### PREPARED

- Uses a new `record_seq`.
- Has an operation ID not previously used by a different logical event.
- Contains the complete absolute aggregate snapshot that would result if the event were committed.
- Has no commit reference (`prepared_seq=0`, prepared-digest sentinel).
- Must not mutate the active aggregate by itself.

### COMMITTED

- Uses its own new `record_seq`.
- Repeats the same operation ID and event identity as its PREPARED record.
- References the exact PREPARED sequence and digest.
- Must match the referenced PREPARED record on namespace, deal, position, lifecycle, event kind, and aggregate snapshot.
- May not exist without exactly one valid PREPARED record.
- A second conflicting COMMITTED record for the same operation ID is an integrity failure; an identical duplicate is rejected or handled according to one explicitly selected policy before implementation.

### Replay/idempotency

The idempotency key is the tuple:

`(environment, server_scope, account_scope, magic, deal_ticket, lifecycle_id, entry_kind)`

A previously committed key must never update the aggregate a second time. The same deal ticket associated with conflicting lifecycle/event identity is an integrity failure requiring reconciliation, not an automatic second sample.

### Sequence and chain validation

- Sequence numbers must be strictly increasing without reuse.
- The previous-record digest must match the canonical prior record.
- A missing sequence, digest mismatch, impossible state transition, orphan COMMITTED, conflicting operation ID, or interior corrupt record fails closed.
- An incomplete final line may be ignored only if byte-level parsing proves it is the final incomplete append. It must not be silently treated as a valid record.
- Recovery must enforce a maximum record count/byte budget and report a distinct diagnostic if the budget is exceeded.

## Values that must be frozen before coding

1. Exact server/account scope canonicalization and hash method.
2. Environment discovery and the behavior when environment cannot be identified.
3. Exact digest algorithm and whether the required MQL5 terminal build supports it; CRC32 alone is not a collision-resistant identity.
4. Currency minor-unit conversion, rounding mode, R fixed-point scale, aggregate precision, and overflow behavior.
5. Reserved sentinels and semantic consistency rules for unknown risk.
6. Policy for byte-identical duplicate COMMITTED records.
7. File append/read/flush/close semantics on each supported terminal build and how post-write verification is performed.
8. Lock namespace, bounded acquisition, stale-owner recovery, and safe release semantics.

Do not infer that a successful `FileFlush` guarantees physical-media durability. Confirm actual terminal semantics and document the residual guarantee.

## Required verification

- Golden vectors for each state and boundary value.
- Negative tests for orphan/mismatched/out-of-order COMMITTED records, duplicate event IDs, conflicting deal identity, sequence gaps, digest-chain mismatch, malformed final record, and interior corruption.
- MQL5 codec parity against the approved vectors.
- Fault-injection tests at each write/flush/close boundary.
- Multi-instance lock contention and timeout tests.
- Controlled terminal/Strategy Tester restart evidence.

## Integration gate

Do not wire this protocol into `OnTradeTransaction()` until the schema is approved, persistence/recovery is implemented, and failure behavior is verified. The current `STB_LRN04Journal.mqh` remains a V1 record codec only. LRN-04 remains **NOT VERIFIED**, and release remains **BLOCKED / NOT VERIFIED**.
