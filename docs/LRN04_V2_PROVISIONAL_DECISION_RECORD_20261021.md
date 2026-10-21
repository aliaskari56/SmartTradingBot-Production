# LRN-04 V2 Provisional Decision Record — 2026-10-21

**Status: engineering recommendations for review only. Nothing in this record is approved for runtime use.**  
**Primary EA:** `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
**Branch:** `fix/structure-first-fvg-trailing-20261020`

## Purpose

The V2 schema and implementation plan intentionally leave platform- and data-semantics decisions open. This record proposes conservative defaults to make each decision reviewable. It does not silently approve the schema, alter the V1 codec, or authorize connection to `OnTradeTransaction()`.

## Provisional recommendation table

| Gate | Provisional recommendation | Reason / acceptance evidence required |
|---|---|---|
| Environment | Fail closed if terminal/tester/optimization cannot be distinguished; use separate namespace for each | Prove detection for supported terminal builds and tests; never let tester records replay in terminal context |
| Server scope | Normalize only a documented allowlist of ASCII characters; reject empty, overlong, or lossy/ambiguous values | Golden vectors for aliases, punctuation, case handling and collision rejection; do not silently strip meaningful characters |
| Account scope | Use account login plus normalized server scope as identity inputs; store no credentials; if hashing is used, freeze algorithm and canonical input bytes | Verify isolation across accounts and servers and document any privacy tradeoff |
| Record digest | Prefer a collision-resistant digest supported by the minimum supported MQL5 build; verify API availability and golden vectors before selection | CRC32 remains only an accidental-corruption checksum, never the identity digest |
| Checksum | Keep fixed-width uppercase CRC32 over exact canonical ASCII body bytes, if cross-language golden vectors agree | Detect accidental corruption; do not claim adversarial integrity |
| Numeric PnL | Do not guess account-currency precision. Freeze a documented currency-to-scale mapping or revise the field semantics to a fixed-point scale before schema approval; unsupported currency/precision fails closed | Test positive/negative half-way rounding, negative values, overflow, and currency edge cases |
| R values | Use an explicitly documented fixed-point scale; unknown risk has a reserved sentinel and contributes no R sample | Cross-field tests prove unknown risk cannot increment `rcount` or change `rsum_scaled` |
| Aggregates | Store absolute post-event snapshots; reject negative counts, non-finite source values, out-of-range scaled values, and inconsistent win/loss or R-count state | Boundary vectors and overflow tests; never wrap or saturate silently |
| Sequence | Unsigned canonical decimal; start from an explicitly defined genesis sequence; strictly increasing, no gaps/reuse in accepted history | Golden vectors for genesis, maximum value, leading zeros, overflow and gaps |
| PREPARED/COMMITTED | Require immediate adjacency under one writer lock; COMMITTED references the exact PREPARED sequence and full-record digest | Negative tests for interleaving, orphan commit, snapshot mismatch and stale reference |
| Duplicate committed event | Return idempotently only when the existing committed identity and canonical payload match exactly; any conflicting identity/payload is an integrity failure | Tests for same deal/same lifecycle, same deal/different lifecycle, and conflicting operation IDs |
| Duplicate COMMITTED record | Reject duplicate serialized records in history; do not normalize or skip them | Deterministic recovery and corruption tests |
| Torn tail | Reject by default; preserve source bytes and emit a distinct diagnostic | Fault injection at every byte/write boundary; no automatic truncation in initial version |
| File semantics | Treat write/flush/close failures and ambiguous outcomes as failed/unknown; reopen and validate according to a specified protocol, without claiming physical-media durability | Verify behavior on every supported build; test open/write/flush/close failures and terminal restart |
| Locking | Use one account/server/environment/magic/schema-scoped lock, atomic acquisition, unique owner token, fencing generation, bounded wait, compare-and-set release | Multi-instance tests including owner pause/resume; if stale-owner safety cannot be proven, require operator recovery |
| Recovery budget | Freeze maximum bytes and record count; exceedance rejects recovery with a distinct status | Large-file and adversarial-input tests establish bounded CPU/memory use |
| Diagnostics | Distinct machine-readable states for unsupported schema, malformed tail, interior corruption, digest mismatch, lock failure, ambiguous I/O, and budget exceeded | Tests assert both state and no aggregate mutation on each failure |
| Projection updates | Rebuild or publish only from a fully validated committed snapshot; do not rely on independent counter increments as the source of truth | Crash injection before/after commit and projection update proves no double application |

## Blocking issues discovered in the current implementation

1. `STB_LRN04Journal.mqh` is still a V1 codec-only module; it has no durable append, recovery, or journal lock.
2. `OnTradeTransaction()` currently consumes accumulated PnL and updates multiple adaptive profile Global Variables without a durable per-deal idempotency boundary.
3. V2’s proposed currency minor-unit semantics cannot be implemented safely until the currency/scale policy is frozen; silently assuming two decimal places would be incorrect for some account currencies.
4. The Python reference model and source-contract tests are not evidence of MQL5 file durability, multi-writer safety, or crash recovery.

## Approval protocol

For each row, record: **APPROVE**, **REVISE**, or **REJECT**, reviewer, date, rationale, minimum supported terminal build, and evidence link. A provisional recommendation is not an approval. If a decision changes serialized bytes or identity semantics, update the schema proposal and golden vectors before coding.

## Next implementation sequence after review

1. Freeze canonicalization, digest, numeric, sentinel, duplicate and file semantics.
2. Generate golden byte vectors independently of the MQL5 implementation.
3. Implement and test V2 encode/decode parity in a separate module; leave V1 behavior unchanged.
4. Implement bounded file scanning/recovery and journal-wide locking behind a non-integrated interface.
5. Add fault-injection tests and controlled non-live terminal evidence.
6. Only after acceptance, plan a narrowly scoped adapter for `OnTradeTransaction()` and lifecycle state migration. Do not enable live deployment as part of these steps.

**Current result: recommendations documented; schema approval, implementation, runtime verification and release acceptance remain outstanding.**
