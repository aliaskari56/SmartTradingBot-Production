# LRN-04 — Crash-consistent adaptive close-event processing design

Status: **DESIGN REQUIRED — IMPLEMENTATION NOT APPROVED**

Scope: `MQL5/Experts/SmartTradingBot_FINAL.mq5`, the existing `SmartTradingBot_FINAL` EA only. This document does not change runtime behavior and does not authorize merging, deployment, or live use.

## Confirmed failure mode

The current `OnTradeTransaction()` close path mutates the accumulated position PnL and adaptive profile aggregates in separate operations. A repeated `DEAL_ENTRY_OUT` / `DEAL_ENTRY_OUT_BY` after the accumulator has been consumed can be interpreted as a new lifecycle; `DEAL_ENTRY_INOUT` also consumes accumulated PnL and records a reversal outcome without a durable per-deal idempotency key. A marker written before or after the existing increments alone is insufficient: a terminal interruption can leave the marker and aggregates inconsistent.

## Required invariants

1. A terminal deal ticket is the stable idempotency key. The same close deal must not add to lifecycle PnL or profile aggregates more than once.
2. A lifecycle is identified by position identifier plus its opening/reversal boundary. `OUT` and `OUT_BY` may be partial exits; do not commit a lifecycle while the position identifier remains open. `INOUT` closes the old side and starts a new side in the same deal, so the close and new lifecycle must be represented separately.
3. Duplicate event delivery, restart recovery, and recovery after interruption at every persistence boundary must converge to the same final state.
4. Do not delete position profile/risk/PnL state until the close outcome is durably committed or can be deterministically reconstructed from history.
5. Unknown profile or unknown initial risk must not be fabricated. Missing risk excludes the R observation but does not suppress a valid win/loss lifecycle observation.
6. Concurrent charts/EA instances sharing the same account+magic state must not overwrite one another's aggregate snapshots. A lock must have bounded acquisition/recovery behavior and be released on all exits.
7. If durable journal creation, write, flush, parsing, or recovery fails, fail closed: do not apply an unjournaled adaptive update; retain recoverable state and emit a clear diagnostic.

## Proposed implementation protocol (not yet implemented)

### A. Deterministic lifecycle reconstruction

For a candidate terminal close/reversal deal, select history by position identifier and build a canonical lifecycle from opening deal through its terminal close boundary. Include each relevant deal's profit, swap, commission and fee exactly once; explicitly define treatment of non-EA/manual exits, hedges, partial closes, and netting reversals. Do not derive the result by incrementing a possibly already-consumed accumulator. Validate deal tickets, entry types, symbol, direction, and chronology before accepting the lifecycle.

### B. Write-ahead journal

Use a versioned, account+magic-scoped journal with one record per terminal close-deal ticket. The record must include at least:
- schema version and checksum;
- close deal ticket, position identifier, lifecycle boundary/type;
- symbol, original direction, resolved profile (or explicit unknown);
- canonical lifecycle PnL and risk-valid R observation (or explicit unavailable);
- the deterministic adaptive aggregate update to apply;
- state `PREPARED` / `COMMITTED`, and enough information to verify replay.

Journal persistence must use a supported MQL5 file API with explicit flush and validated record framing. A truncated final record must be detected and ignored/quarantined, not interpreted as committed. Do not assume that several terminal Global Variables form an atomic transaction.

### C. Serialized, idempotent aggregate application

Acquire an account+magic journal writer lock before reading current aggregate state. For a new close ticket, compute the decayed current values and the exact post-event values for `W`, `L`, `RSUM`, `RCOUNT`, and `T`. Persist and flush a complete `PREPARED` record containing those absolute target values before changing aggregates. Apply target values (not increments), flush terminal Global Variables, then append/flush a `COMMITTED` record. Replaying a prepared record must write the same absolute targets, never add the observation again. If other close events can be committed concurrently, process them under the same lock and in a deterministic order; do not prepare snapshots from stale aggregates.

### D. Recovery and cleanup ordering

On initialization, recover the journal before processing new close events. Validate checksums and record sequence; replay any valid prepared-but-uncommitted target snapshot idempotently, then mark it committed. Verify committed records against applied-state metadata. Only after durable commit may position profile/risk/PnL cleanup proceed. Cleanup itself must be repeatable. If journal and terminal-global state disagree beyond deterministic repair, disable adaptive writes and report the unresolved ticket rather than guessing.

### E. Event handling

`OnTradeTransaction()` should perform bounded intake and schedule/retry close processing through one serialized processor. The processor must deduplicate by deal ticket, reconstruct lifecycle context from history, and distinguish:
- partial `OUT` / `OUT_BY` while position remains open;
- final `OUT` / `OUT_BY`;
- `INOUT` reversal boundary;
- hedges and non-profiled/manual deals.

A processed-deal marker is an index/cache only, never the source of truth. The durable journal plus deterministic target-state replay is the source of truth.

## Required tests before implementation approval

| Test | Fault/invocation | Required result |
|---|---|---|
| LRN-04-A | Same final `OUT` ticket delivered twice in one session | One lifecycle outcome and one aggregate update |
| LRN-04-B | Duplicate `OUT_BY` ticket | One update only |
| LRN-04-C | Duplicate `INOUT` reversal ticket | Old lifecycle closes once; new-side state is retained/reconstructed |
| LRN-04-D | Restart after `PREPARED` flush, before aggregate writes | Recovery applies target snapshot once |
| LRN-04-E | Restart after some aggregate writes, before `COMMITTED` flush | Recovery converges to target snapshot without incrementing twice |
| LRN-04-F | Restart after `COMMITTED`, before profile/risk cleanup | No repeated learning update; cleanup completes |
| LRN-04-G | Truncated/corrupt journal tail | Tail rejected safely; earlier committed records retained |
| LRN-04-H | Two charts attempt close processing concurrently | Serialization prevents lost updates and duplicate outcomes |
| LRN-04-I | Partial close followed by final close, with restart between events | Partial PnL included once; lifecycle committed only at the correct boundary |
| LRN-04-J | Missing initial-risk state | Win/loss observation handled per policy; no invented R sample |
| LRN-04-K | Journal write/flush/lock failure | No unjournaled profile mutation; actionable diagnostic and retry path |
| LRN-04-L | Account/magic separation and Strategy Tester namespace | No cross-account, cross-magic, or tester/live state contamination |

## Approval gate

Do not implement this as a marker-only patch. Before source changes, confirm MQL5 file/flush semantics and cross-chart locking behavior against the target terminal, implement the journal as a separately reviewable unit, add repeatable tests for every fault boundary, then compile the exact commit and rerun static/safety CI. Strategy Tester and terminal restart/fault-injection tests remain mandatory. Until those steps pass, LRN-04 remains **NOT FIXED / NOT RUN**, and release remains **BLOCKED / NOT VERIFIED**.


## Codebase feasibility audit (2026-10-21)

Inspection of the current EA confirms the following implementation constraints:

- The EA already uses `FileOpen`, `FileWrite`, `FileFlush`, and `FileClose` for adaptive CSV logging. This proves those APIs are already used by this source, but the CSV logger is append-only telemetry and is **not** a journal: it does not validate records, persist target aggregate snapshots, or recover interrupted updates.
- The existing cross-chart broker-writer lease uses `GlobalVariableSetOnCondition` (CAS), but its ownership key is scoped by purpose and symbol and is designed for broker writes. It is not an account+magic-wide learning-journal lock and must not be repurposed without a separate lock contract.
- The existing entry lock uses a short time-based token with a chart-derived fractional tag. It is also not an appropriate durable journal lock.
- Existing adaptive profile aggregates are stored as separate terminal Global Variables. Therefore the current implementation does not provide an atomic multi-key commit for `W`, `L`, `RSUM`, `RCOUNT`, and `T`.
- Current source uses terminal Global Variables for position risk/profile/PnL state. The journal must define restart recovery and cleanup ordering across those state keys, not only deduplicate the final deal ticket.
- The current CI compile/static checks do not substitute for terminal-level restart and injected-failure tests. A passing compile cannot prove crash consistency.

### Implementation consequence

Do not wire the existing CSV logger into the close-event path as if it were a transaction log. Implement a separate versioned journal abstraction with validated records and explicit recovery, and use a dedicated lock namespace. Verify file location/namespace separation between live terminal and Strategy Tester before writing code. Add deterministic unit-style checks for record encoding/checksum/truncated tails where feasible, plus terminal integration tests for restart/fault boundaries. Keep the adaptive learner fail-closed if journal recovery cannot be proven safe.


## MQL5 persistence-semantics audit (2026-10-21)

Official MQL5 reference checked before selecting an implementation strategy:

- `FileFlush(handle)` flushes the MQL file I/O buffer to disk, but returns no status value. Therefore callers cannot treat its return value as a success signal, and a successful call alone is not proof against every OS, storage-device, or power-loss failure mode. The implementation must validate the bytes/records on the next read and must state the durability guarantee narrowly. Reference: https://www.mql5.com/en/docs/files/fileflush
- `GlobalVariablesFlush()` forces terminal global-variable contents to disk, also with no return value. It improves persistence but does not make a group of separate global-variable writes atomic. Reference: https://www.mql5.com/en/docs/globals/globalvariablesflush
- `FileOpen()` confines files to the terminal's file sandbox unless `FILE_COMMON` is specified. `FILE_COMMON` shares files across client terminals; Strategy Tester uses its own agent sandbox by default, and common-folder use changes that isolation. Journal naming and mode must be chosen deliberately so tester data cannot be confused with terminal/account state. References: https://www.mql5.com/en/docs/files/fileopen and https://www.mql5.com/en/docs/runtime/testing
- `FILE_SHARE_READ` / `FILE_SHARE_WRITE` are sharing flags, not a journal transaction lock. They must not be treated as cross-instance serialization.

### Consequences for the implementation

1. Use a per-terminal-sandbox journal by default; do not use `FILE_COMMON` unless an explicit multi-terminal coordination design and isolation tests justify it.
2. Treat each flush as a persistence boundary to test, not as proof of atomicity. Recovery must validate framing, version, sequence, checksum, ticket identity, and target-state consistency.
3. The journal writer lock needs an independent CAS-based protocol with a unique account+magic namespace, bounded acquisition, stale-owner recovery rules, and guaranteed release. Since terminal Global Variables are shared among programs in the same terminal, lock identity must include a stable terminal/account context and must not rely on chart ID alone.
4. Since flush APIs return no status, verify post-write state by reopening/reading the journal where practical, and fail closed on any invalid or ambiguous state. This still does not claim hardware-level fsync guarantees.
5. Before source implementation, define deterministic byte/record encoding and checksum implementation supported by MQL5, plus explicit handling of a torn final record. The journal must not depend on CSV locale/string formatting or floating-point serialization that can change the replayed target values.

### Updated approval gate

The official API references clarify available flush and sandbox behavior, but they do not prove crash consistency or inter-instance lock correctness in the target terminal. Source implementation remains gated on a separately reviewable record codec/recovery unit and fault-injection coverage. Status remains **LRN-04 NOT FIXED / NOT RUN**; release remains **BLOCKED / NOT VERIFIED**.


## Proposed journal record contract (design only; not implemented)

To make the next implementation reviewable, use a bounded, canonical record format rather than locale-sensitive CSV:

- Encoding: ASCII bytes, one physical record per line, LF terminator, no free-form strings.
- Fields in fixed order: `schema|record_seq|state|account_scope|magic|deal_ticket|position_id|lifecycle_id|symbol_code|direction|entry_kind|pnl_minor|risk_state|r_scaled|wins_scaled|losses_scaled|rsum_scaled|rcount|decay_time|previous_record_hash|crc32`.
- Numeric identifiers use unsigned decimal digits only; enums use documented uppercase tokens; optional values use a single explicit sentinel token, never an empty field.
- Floating-point values are not serialized as locale-dependent decimal floats. Values must be converted to documented scaled integers with explicit range/overflow checks before journaling. If the chosen scale cannot represent an input without unacceptable loss, reject that record instead of silently rounding it.
- `account_scope` must be a stable, non-secret account/server identity hash, and the namespace also includes `InpMagic` and an explicit environment identifier. Do not write account credentials or other secrets.
- `lifecycle_id` must distinguish a position's opening/reversal epochs; `deal_ticket` is the deduplication key for the terminal event. A reversal may require separate close-outcome and new-side lifecycle-state records linked to the same deal.
- `record_seq` is strictly increasing under the journal lock. `previous_record_hash` chains records so removal/reordering is detectable; `crc32` detects accidental record corruption. These checks detect corruption but are not cryptographic authentication.
- A PREPARED record contains the complete absolute post-event aggregate snapshot plus the source deal/lifecycle identity. COMMITTED references the same sequence and checksum. A COMMITTED record without its matching valid PREPARED record is invalid.
- Impose a maximum record byte length and maximum recovery scan budget. Reject overlong, malformed, out-of-range, duplicate-sequence, or checksum-invalid records. Never parse a partial final line as a complete record.
- The recovery parser must distinguish an incomplete tail from corruption in the middle of the journal. An incomplete final record can be quarantined/truncated only after preserving the last verified byte offset; corruption before that offset disables adaptive writes pending explicit recovery.

### Deterministic codec checks required before MQL5 integration

1. Golden byte vectors for every enum, sentinel, integer boundary, and checksum.
2. Reject altered bytes, missing/extra fields, invalid digits, overflow, invalid scale, and overlong records.
3. Reject a truncated record at every byte offset; retain earlier verified records.
4. Reject duplicate or decreasing sequence numbers and broken previous-record hashes.
5. Round-trip the largest supported PnL/risk/aggregate values without locale dependence.
6. Verify repeated PREPARED replay writes the same absolute snapshot; it never increments an aggregate.
7. Verify environment/account/magic namespaces cannot collide in the test matrix.

This contract is a review target, not evidence that a journal implementation exists or passes. In particular, checksum and hash-chain validation do not replace correct locking, lifecycle reconstruction, or terminal fault-injection tests.
