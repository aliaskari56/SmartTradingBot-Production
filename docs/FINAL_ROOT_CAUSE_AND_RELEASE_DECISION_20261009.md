# Final Root-Cause Audit and Release Decision — 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`
Primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
Primary source Git blob SHA: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`
Source size observed: 8,665 lines; 284,356 characters in retrieved line chunks.

## 1. Executive decision

**Static audit pass: COMPLETE for the repository/source areas inspected. Overall technical verification: OPEN. Release decision: BLOCKED / NOT VERIFIED.**

This is the final static root-cause assessment possible with the available repository interface. It is not an assertion that the EA compiles, behaves correctly in the terminal, is profitable, or is legally cleared. The exact backup ZIP could not be extracted through the available text-only GitHub connector; MetaEditor, a terminal, Strategy Tester and a broker/demo account were not available for this pass. No executable source was changed, and `main` was not modified.

The highest-priority issues are not a single syntax defect. They are gaps between the intended safety architecture and evidence needed to prove it: delete authorization at the final writer, consistent exposure-limit enforcement, single-writer SL/TP semantics, build/package provenance, and unexecuted lifecycle tests.

## 2. Root-cause findings (ranked)

### RC-01 — Final order-delete writer has no local authorization/ownership gate
**Severity: HIGH | Evidence: static source | Runtime consequence: not tested**

At approximately lines 8135–8187, `STB_ExecuteOrderDelete(ticket, reason, source)` selects the supplied ticket and calls `trade.OrderDelete(ticket)`. It checks the request result, server retcode and that the active ticket disappeared, which is useful result verification. However, the writer itself does not visibly verify that the ticket is a managed order, that the reason is permitted for the caller, or that a symbol-scoped lease/rollback capability authorizes this deletion. `STB_RequestOrderDelete` simply delegates to the writer.

Known callers include:
- creator rollback from `OneClickHedge` (around line 4047);
- pending expiration/cleanup from `ManagePendingOrders` (around line 5737);
- creator rollback from `PlaceSetup` (around line 6176);
- manual stop/limit rollback (around lines 6504 and 6602).

Some callers establish context, but that is not enforced at the final write boundary. A simplistic lease check could also break rollback of a newly created invalid order before its normal management registration. The root fix is a ticket-scoped, reason-aware authorization contract that explicitly permits creator-owned rollback and verified expiry while rejecting unrelated/foreign tickets. Do not add a naive lease-only check without rollback tests.

### RC-02 — Directional aggregate volume limit is enforced only on automatic setup path
**Severity: HIGH | Evidence: static source | Actual broker-limit breach: not demonstrated**

The only `SYMBOL_VOLUME_LIMIT` reference found in the primary EA is in `PlaceSetup` (around lines 6079–6087), using `DirectionExposureVolume`. The manual pending stop/limit paths (around lines 6430–6610) and `OneClickHedge` (around lines 3960–4055) do not visibly apply the same aggregate directional limit guard. They normalize per-order volume, which is not equivalent to checking aggregate positions plus pending orders against the symbol limit.

The root fix is one shared preflight used by all order-creation families: automatic setup, manual stop, manual limit, hedge. It must compute directional exposure using broker-correct semantics, include active pending orders and positions, handle zero/unlimited limits, and be repeated as close as possible to submission. Test netting and hedging accounts separately. This finding is a coverage gap, not proof that a live limit was exceeded.

### RC-03 — Position SL “resolver” receives one proposal at a time
**Severity: HIGH | Evidence: confirmed static structure | Collision outcome: not tested**

Around line 4654, `STB_SubmitPositionSL` allocates a proposal array of size one and calls `STB_ResolvePositionSL(ticket, props, 1, ...)`. Callers include initial SL, profit protection and live trailing (around lines 4823, 5011 and 5372). The resolver enforces monotonic improvement relative to current SL, but the observed call pattern does not submit competing sources together. Thus it is a validator for an individual candidate, not evidence of cross-source arbitration.

The root fix is a per-ticket proposal collection and deterministic arbitration point (or an explicit serialized priority contract), followed by one writer request. Re-read terminal position state immediately before writing; define how user overrides, manual commands, initial protection, profit protection and trailing interact. Test same-cycle and adjacent-event conflicts. Do not change strategy behavior before regression cases define the intended winner.

### RC-04 — Position modify preserves a TP snapshot, but the read/write is not atomic
**Severity: HIGH | Evidence: static race window | Actual race: not proven**

`ModifyPositionSL` (around lines 4665–4750) reads the current TP and submits `trade.PositionModify(ticket, newSL, tp)`. This API call supplies both SL and TP, so an external/manual TP update occurring after the snapshot but before the request could be overwritten. Synchronous `CTrade` mode narrows some timing windows but does not establish atomic compare-and-swap semantics against manual actions or another EA/terminal actor.

The root fix is an explicit ownership/write policy and fresh-state conflict detection, plus tests with concurrent/manual TP edits. Do not claim that TP management exists merely because TP is preserved in this call.

### RC-05 — Management-cycle deduplication is invocation-scoped, not global across events
**Severity: MEDIUM-HIGH | Evidence: confirmed call topology | Duplicate broker request: not proven**

`STB_RunManagementCycle` is invoked from `OnInit`, `OnTick` and `OnTimer` (approximately lines 8000, 8222 and 8259). Each call begins a new cycle ID; the one-write guard is therefore per invocation. The per-cycle guard does not by itself prove that tick and timer callbacks cannot request changes to the same ticket in quick succession. Monotonic SL checks, cached geometry and throttle/backoff reduce risk but are not substitutes for event-order testing.

The root fix is to define cross-event serialization/idempotency semantics, including whether a ticket can be modified twice in a short interval and how stale snapshots are rejected. Exercise tick+timer overlap, restart, partial fills, manual edits and delayed server responses.

### RC-06 — Broker and exposure controls are not uniformly proven across all order paths
**Severity: MEDIUM-HIGH | Evidence: bounded static scan**

The EA has a relatively strong automatic setup path with data revalidation, geometry validation, account order-count checking, per-order risk sizing when enabled, and directional `SYMBOL_VOLUME_LIMIT` checking. Manual and hedge paths have separate validation/placement code, however, so safety policy is duplicated rather than uniformly centralized. A static scan found four order-creation families and only one `SYMBOL_VOLUME_LIMIT` use. Per-order normalization and broker rejection are not a substitute for consistent preflight or informative local rejection.

The root fix is shared, read-only preflight plus one auditable submission contract while retaining each path's intended strategy and manual behavior.

### RC-07 — Current source-to-EX5 provenance is unverified
**Severity: RELEASE BLOCKER | Evidence: missing chain of custody**

The tracked EX5 exists (Git blob SHA `348bb13126ba73b9502f82466f2d1a2bea1e8f6f`, 236,764 bytes), but its relationship to the current source blob is not established. The backup manifest contains claimed raw SHA-256 values and a claimed compile result, but the raw source hash, EX5 hash and compiler output were not independently recomputed/linked to this exact commit and toolchain. Historical CI runs concern older commits and an older source filename, and cannot certify the current file.

Required evidence: frozen commit, clean checkout, raw SHA-256 of source, MetaEditor/compiler/terminal versions, exact build command/options, full raw log and exit code, raw SHA-256 of resulting EX5, and preserved artifact custody. Git blob SHA is not interchangeable with raw-file SHA-256.

### RC-08 — Dependency distribution and ownership evidence is incomplete
**Severity: RELEASE BLOCKER | Evidence: repository tree/header inspection**

The tree contains 18 ALGLIB-family `.mqh` files totalling 10,742,550 bytes (10.24 MiB). Previously inspected ALGLIB headers explicitly state GPL v2-or-later. The traced direct/transitive include closure of the current EA did not show ALGLIB usage, so tree presence alone does not prove that ALGLIB is compiled into the EA or shipped in the actual release archive. The ZIP (2,584,569 bytes, Git blob SHA `a57ce1b04d64dfa6b890043098be8a001408b6da`) was not extracted or compared because the available connector does not return binary archive bytes.

The EA header contains generic `ProjectName`, `CompanyName` and `companyname.net` placeholders. The two directly included STB modules' inspected headers do not identify an author, source or license. These are provenance/attribution gaps, not proof of infringement or absence of permission. Confirm ownership and distribution rights, extract the exact package with a binary-capable checkout, produce a complete member/hash manifest, and obtain qualified compliance review before distribution.

### RC-09 — Swing parity differences need an explicit deterministic contract
**Severity: MEDIUM | Evidence: previous static comparison**

The EA swing collector and the separate BrokerStructureScanner use different tie-handling around equal-price pivots. This is a real algorithmic difference, but not proven to be a defect. The EA also uses closed H4 bar shift 1 for trend and a local simple mean true-range calculation that is not guaranteed to match standard `iATR`. Preserve the current EA architecture; do not wholesale-port the scanner. If scanner reuse is ever justified, compare outputs on fixed fixtures and add shadow-mode diagnostics first.

### RC-10 — No test evidence establishes end-to-end trading correctness
**Severity: RELEASE BLOCKER | Evidence: no execution environment used**

No compile of the exact source, Strategy Tester run, broker/demo test, restart test, fault injection, performance benchmark, or independent technical review was performed in this audit. No CI status was present for the latest progress commit when queried. Static code inspection cannot establish profitability, acceptable drawdown, broker compatibility, or correct event behavior.

## 3. Other confirmed source facts and configuration caveats

- `InpUseRiskSizing` defaults to `false`; fixed-lot mode is therefore the default unless enabled. A configured risk percentage is not evidence that all order paths use risk-based sizing.
- `InpRiskPercent == 0` passes the observed nonnegative input validation; with risk sizing enabled this can result in a zero risk volume and setup rejection rather than a minimum-lot trade.
- The source has a tester-specific auto-trading gate and tester chart-symbol isolation input; tester configuration must be explicit and recorded.
- The pending geometry writer has meaningful controls: managed-order check, manual override gate, symbol management ownership check, monotonic entry direction, risk-floor check, OrderCheck, retcode validation and post-write geometry verification. This does not close the separate order-delete authorization gap.
- The position SL writer checks managed position and symbol ownership, enforces monotonic SL and verifies post-write SL. The unresolved concern is multi-source arbitration and stale TP concurrency, not absence of every safety check.
- Pending trail is ticket-based, has cooldown/backoff and restart rebuild logic in the module; actual lifecycle/handoff behavior still requires terminal tests.
- No independently verified account-wide daily-loss or max-drawdown circuit breaker was established by the bounded scan. Do not claim one exists without locating and testing it.

## 4. Closure matrix

| Gate | Current status | Evidence needed to close |
|---|---|---|
| Exact-source compile/provenance | OPEN | Frozen commit, raw hashes, toolchain, raw build log, exit code, EX5 hash |
| Archive/package integrity | OPEN | Extract ZIP; full member list and file hashes; compare to release manifest |
| ALGLIB and third-party license review | OPEN | Package membership, provenance, notices and qualified distribution review |
| STB module ownership/attribution | OPEN | Confirmed author/rights/source records and accurate notices |
| Order-delete authorization | OPEN | Reason-aware ticket capability and tests for rollback, expiry, foreign/unmanaged ticket |
| Shared exposure/volume guard | OPEN | Shared preflight across all creators; netting/hedging tests |
| Position SL arbitration | OPEN | Multi-source proposal contract, same-cycle collision tests |
| SL/TP concurrent update policy | OPEN | Fresh-state/conflict policy and manual/concurrent edit tests |
| Event/restart/idempotence | OPEN | Tick/timer/transaction ordering, restart, partial-fill and delayed-response tests |
| Trading behavior and risk | OPEN | Deterministic Strategy Tester matrix and demo evidence |
| Independent release review | OPEN | Reviewer sign-off on frozen source and evidence bundle |

## 5. Minimum acceptance suite before release

1. Build exact frozen source in MetaEditor; zero errors, all warnings triaged, preserve raw logs and hashes.
2. For each order-creation family, test invalid stops, invalid volume, unsupported expiration, stale quote, order-count cap, aggregate directional volume cap, and server rejection.
3. Delete authorization: auto rollback succeeds for its own just-created ticket; expiration succeeds only for an eligible managed ticket; arbitrary/foreign/unmanaged ticket is rejected; failed delete remains visible and is retried/reconciled safely.
4. Position protection: initial SL, profit protection and trailing propose in the same cycle; only deterministic winner is submitted; SL never loosens; concurrent TP change is not silently overwritten.
5. Pending trail: six supported pending types, tick-size alignment, stop-limit offset, risk floor, freeze/stops-level rejection, throttle/backoff, trigger handoff, restart reconstruction and manual override.
6. Event lifecycle: OnInit/OnTick/OnTimer/OnTradeTransaction interleavings, duplicate/out-of-order transaction notifications, partial fills, terminal reconnect, chart/timeframe reinitialization and multiple EA instances.
7. Account modes: netting and hedging; multiple symbols; broker-specific volume/stops/freeze/expiration modes.
8. Run forward/out-of-sample and demo tests with spread, commission, swap and slippage assumptions; assess drawdown and exposure controls independently from optimization fitness.
9. Independent reviewer signs off source diff, logs, archive manifest, licensing/attribution and release checklist.

## 6. Final conclusion

The root cause is **verification and enforcement gaps across safety boundaries**, not a proven single line that explains every possible failure. The strongest static correctness concern is that the central delete writer does not itself enforce ticket/reason authorization. The strongest exposure-control concern is that aggregate directional volume is checked in automatic setup but not visibly shared by manual pending and hedge creators. The strongest position-management concerns are one-at-a-time SL proposals and a non-atomic SL/TP snapshot/write boundary. Separate release blockers remain source/build provenance, package/dependency licensing, and absent runtime evidence.

Do not ship or claim production readiness based on this audit alone. First close RC-01/RC-02/RC-03/RC-04 in a reviewed implementation, then execute the acceptance suite on a frozen source commit and close the provenance/compliance gates. Preserve existing EA architecture and manual semantics; do not wholesale-port BrokerStructureScanner. No executable source was changed in this pass; `main` remains untouched.

**Final audit status:** STATIC ROOT-CAUSE PASS COMPLETE; TECHNICAL VERIFICATION OPEN  
**Final release status:** **BLOCKED / NOT VERIFIED**
