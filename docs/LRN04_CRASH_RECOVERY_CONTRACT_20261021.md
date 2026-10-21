# LRN-04 V2 Crash-Recovery Contract — Proposal

**Status: design proposal only; not approved or implemented.**  
**Branch:** `fix/structure-first-fvg-trailing-20261020`  
**Scope:** deterministic recovery rules for a future journal implementation. This document does not enable persistence or change `SmartTradingBot_FINAL` runtime behavior.

## Preconditions

Recovery must not begin until the V2 record schema, digest algorithm, canonical account/server scope, numeric scales, and lock ownership/recovery rules are approved. The current `STB_LRN04Journal.mqh` is still a V1 codec-only module; it is not a durable journal.

## Recovery decision matrix

| File/history condition | Required result | Must not happen |
|---|---|---|
| Empty file / no records | Initialize only under an explicit, validated genesis rule | Treat an unreadable file as empty |
| Complete valid records with continuous sequence and digest chain | Replay in sequence, validating every state transition | Apply snapshots before the full prefix is validated |
| Final bytes do not end in LF, or final record is truncated | Fail closed by default; any tail-truncation repair must be a separately approved, tested policy | Silently skip malformed bytes or assume every final corruption is a torn write |
| Checksum/digest mismatch anywhere | Reject the history and preserve the original file for diagnosis | Continue past the bad record |
| Sequence gap, duplicate sequence, or broken previous-digest link | Reject the history | Renumber or rewrite records automatically |
| COMMITTED without its referenced PREPARED record | Reject the history | Apply the COMMITTED snapshot |
| COMMITTED points to a PREPARED record with mismatched operation identity or snapshot | Reject the history | Use either version as a best guess |
| Valid PREPARED without a matching COMMITTED at end of validated history | Treat as an uncommitted operation; do not apply its snapshot. Preserve the record in the chain and allow recovery only under the approved sequence rules | Count the operation as committed or discard the entire history |
| Duplicate operation identity / duplicate committed outcome | Reject history unless a formally specified idempotency rule proves it is the same already-committed operation | Increment aggregate statistics twice |
| Unknown schema version or unknown state enum | Reject history without mutation | Guess compatibility or migrate in place |
| File cannot be opened, read, or exclusively locked | Disable journal-dependent processing and report a clear error | Fall back silently to volatile counters |

## Required ordering and atomicity rules to freeze

1. A writer must hold the approved journal-wide lock before reading the current tail and selecting the next sequence number.
2. Validate the entire existing history before appending. A bad prefix must never be repaired implicitly.
3. Write a complete PREPARED snapshot and flush it before writing COMMITTED.
4. COMMITTED must reference the exact PREPARED sequence and digest, and its operation identity and aggregate snapshot must match the PREPARED payload.
5. The implementation must define whether PREPARED and COMMITTED must be adjacent. The conservative proposal is to require adjacency under a single-writer lock; if so, the validator must enforce it.
6. Update in-memory/global-variable projections only after the committed record is durably accepted according to the chosen platform semantics.
7. If a write or flush result is ambiguous, stop further journal mutation and require recovery. Do not retry by generating a fresh operation ID.
8. Preserve the source journal and emit a diagnostic state on any recovery failure. No automatic truncation, compaction, or migration in the first implementation.

## Test cases required before MQL5 integration

- Crash/failure injection after every write, flush, and close boundary for PREPARED and COMMITTED.
- Partial final line at every byte offset.
- Complete final line with wrong checksum/digest.
- Broken prefix followed by otherwise valid records.
- PREPARED-only history followed by a later valid operation, according to the final adjacency/sequence policy.
- Orphan COMMITTED, wrong PREPARED reference, identity mismatch, snapshot mismatch, duplicate operation, sequence reuse, and digest-chain break.
- Two writer attempts contending for the same journal lock, including stale-owner recovery.
- Restart after successful commit, restart after ambiguous flush, and repeated delivery of the same transaction event.
- Verify that recovery is deterministic: identical file bytes and configuration must yield the same accepted/rejected result and same aggregate snapshot.

## Release gate

This proposal does **not** establish crash consistency, locking correctness, idempotency, or MQL5 runtime correctness. Do not connect LRN-04 to `OnTradeTransaction()` until the schema and recovery rules are approved, the MQL5 persistence implementation exists, fault-injection tests pass, and the relevant non-live terminal tests are recorded. Release remains **BLOCKED / NOT VERIFIED**.
