# LRN-04 V2 Design Decision Checklist — 2026-10-21

**Status: review checklist only. No protocol option is approved by this document.**  
**Primary EA:** `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
**Branch:** `fix/structure-first-fvg-trailing-20261020`

This checklist converts the unresolved items in `LRN04_SCHEMA_V2_PROPOSAL_20261021.md` into explicit decisions and evidence required before implementation. A checked box means the decision has been documented, reviewed, and covered by tests; it must not be checked merely because a candidate value was suggested.

## A. Decisions that block schema approval

- [ ] **Namespace canonicalization:** define environment detection, server identity normalization, account-scope representation, magic encoding, schema namespace, and collision behavior. Do not serialize credentials.
- [ ] **Digest algorithm:** choose an algorithm supported by the minimum supported MQL5 terminal build; define byte input, output encoding, genesis value, and test vectors. CRC32 is a corruption checksum, not a collision-resistant record identity.
- [ ] **Numeric semantics:** define account-currency minor-unit conversion, rounding, R fixed-point scale, aggregate precision, overflow handling, and count bounds.
- [ ] **Sentinels and semantic constraints:** define all sentinel values and cross-field rules, especially the relationship between `risk_state`, `r_scaled`, and `rcount`.
- [ ] **Duplicate COMMITTED policy:** select exactly one policy for byte-identical duplicates; conflicting duplicates must fail closed.
- [ ] **File semantics:** document supported-build behavior and limits for open, append, read, flush, close, and post-write verification. Do not claim physical-media durability without evidence.
- [ ] **Lock and fencing:** define lock key, owner token, generation/fencing behavior, bounded acquisition, stale-owner recovery, and compare-and-set release.
- [ ] **Recovery budget and diagnostics:** set bounded record/byte scan limits and distinct error states for malformed tail, interior corruption, unsupported schema, lock failure, and exhausted budget.

## B. Required verification evidence

- [ ] Golden byte vectors for PREPARED and COMMITTED records, including boundary numeric values and checksum/digest inputs.
- [ ] Negative vectors for malformed encoding, invalid sentinels, overflow, duplicate identities, sequence gaps, broken digest chain, orphan commits, mismatched snapshots, and conflicting commits.
- [ ] Cross-language parity between the approved reference vectors and the actual MQL5 codec.
- [ ] Fault-injection coverage at each write, flush, close, ownership-check, and projection-update boundary.
- [ ] Multi-instance contention evidence showing only the current fenced owner can append or publish state.
- [ ] Controlled terminal/Strategy Tester restart evidence for every journal state boundary.
- [ ] Review confirms no journal mutation is wired to `OnTradeTransaction()` before the above gates pass.

## C. Approval record

Record the reviewer, date, chosen option, rationale, supported terminal build(s), and evidence links for every item in section A. Unresolved or untested items remain blockers; silence is not approval.

## Current status

The V1 MQL5 module is a codec only. The V2 proposal, Python reference state model, and contract tests do not implement durable persistence, locking, crash recovery, or exactly-once learning updates. No runtime behavior is enabled by this checklist.

**LRN-04: NOT VERIFIED. Release: BLOCKED / NOT VERIFIED.**
