# LRN-04 Record Contract Gap Review — 2026-10-21

## Scope

Review of `MQL5/Include/STB/STB_LRN04Journal.mqh` against `docs/LRN_04_CRASH_CONSISTENT_DESIGN.md` and `docs/LRN04_IMPLEMENTATION_PLAN_20261021.md`.

This is a source/design review only. It does not implement persistence, change EA runtime behavior, or authorize deployment.

## Findings

### R1 — PREPARED/COMMITTED linkage is not representable (blocking)

The codec has a `state` field and a `record_seq`, but no explicit prepared-record sequence or prepared-record digest reference. The design requires COMMITTED to reference the matching PREPARED record. A state change also changes the serialized body/checksum, so the current format does not itself prove that a COMMITTED record commits one specific PREPARED snapshot.

**Required correction:** version the schema before persistence is implemented. Define a stable operation/event ID, the PREPARED sequence and digest referenced by COMMITTED, and unambiguous rules for whether both records share an operation ID or have distinct journal sequence numbers. Add golden vectors and negative tests for orphan, duplicate, mismatched, and out-of-order commit records.

### R2 — Namespace does not encode environment (blocking)

The record contains `account_scope` and `magic`, but no explicit environment field. The design requires terminal/tester environment separation. An account hash alone is not a sufficient discriminator if the same account and magic are used in different execution environments.

**Required correction:** add a canonical environment identifier and specify how the file path and Global Variable lock namespace include account/server, magic, environment, and schema. Keep tester data isolated from terminal data by default.

### R3 — Hash-chain field is syntactically under-validated (blocking)

`previous_record_hash` is validated only as a generic token. There is no enforced digest encoding/length, genesis rule, or chain validation in the codec. CRC32 detects accidental corruption of an individual record; it does not validate journal ordering or link continuity.

**Required correction:** define the exact digest algorithm and canonical fixed-width encoding, the genesis value, and rules for sequence/hash continuity. Implement chain validation in recovery, not only token validation.

### R4 — Numeric scales and aggregate bounds are unspecified (blocking)

The codec accepts signed integers for PnL, R, and R-sum, but does not define their scales or enforce semantic bounds among `risk_state`, `r_scaled`, `rsum_scaled`, and `rcount`. It also cannot validate whether a value was scaled without overflow or unacceptable rounding.

**Required correction:** specify units and scale constants for monetary PnL and R observations; specify rounding/overflow policy and semantic consistency rules. Unknown risk must have a documented sentinel representation and must never become an R observation.

### R5 — Sequence and state-transition validation are not part of the current codec

The current codec validates individual record syntax and CRC. It does not check monotonic sequence progression, legal PREPARED→COMMITTED transitions, duplicate deal tickets, conflicting records for one event, or bounded recovery scan behavior.

**Required correction:** keep record decoding separate from a journal-state validator and test both. Recovery must reject interior corruption and conflicting transitions, while distinguishing an incomplete final append from corruption in the middle.

## Safe implementation order

1. Approve a corrected versioned schema covering R1–R4.
2. Add Python reference tests for record relationships and full journal transition validation; these remain specification tests, not MQL5 runtime proof.
3. Implement the MQL5 codec against the exact golden vectors.
4. Implement persistence, dedicated locking, bounded recovery, and absolute-snapshot replay in a separate module.
5. Only after those layers are verified, connect the journal to the existing `SmartTradingBot_FINAL` close-event path.
6. Run MetaEditor compile, CI, controlled terminal/Strategy Tester restart and fault-injection tests.

## Status

The current codec is a useful record-level prototype, not a persistence journal. LRN-04 remains **NOT FIXED / NOT RUN**. Runtime restart/fault-injection evidence is absent, and release remains **BLOCKED / NOT VERIFIED**. No changes to `SmartTradingBot_FINAL.mq5` are made by this review.
