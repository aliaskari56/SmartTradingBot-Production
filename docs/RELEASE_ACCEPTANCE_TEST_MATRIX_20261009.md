# Release Acceptance Test Matrix — SmartTradingBot FINAL
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`
Scope: test plan for the current source; this document records required tests, not tests already executed.

## Release rule

Do not label the build production-ready until the exact source revision has a recorded successful MetaEditor compile, the applicable Strategy Tester suite passes, demo-account scenarios pass on each supported account mode, and source-to-EX5 provenance plus dependency/license review are documented. Static CI success alone is insufficient.

## A. Build and artifact provenance — release blockers

| ID | Scenario | Procedure / evidence required | Expected result | Status |
|---|---|---|---|---|
| BLD-01 | Exact-source compile | Compile the current source Git blob `17059923ccb18e1b717947e4581d9790df26a368` (Git blob ID, not raw-file SHA-256) using the supported MetaEditor build; archive full log and compiler version | 0 errors; all warnings reviewed and dispositioned | NOT RUN |
| BLD-02 | Artifact provenance | Record SHA-256 of source, includes, compiler log and produced EX5; record build environment | Reproducible manifest maps EX5 to exact source and dependency set | NOT RUN |
| BLD-03 | Include closure | Resolve every `#include` transitively; inventory source, origin, version and license for shipped dependencies | Every shipped dependency has traceable origin and compatible license | NOT VERIFIED |
| BLD-04 | Package audit | Extract and inspect release ZIP; compare contents to manifest; remove stale binaries/backups if not intended for release | Package contains only reviewed release artifacts and complete notices | NOT RUN |

## B. Order creation and exposure controls — high priority

| ID | Scenario | Procedure | Expected result | Status |
|---|---|---|---|---|
| ORD-01 | Direction volume at limit | Set test symbol/account so same-direction open positions plus pending orders equal broker `SYMBOL_VOLUME_LIMIT`; attempt each of the four creation paths | All four paths reject additional exposure and log a clear reason | NOT RUN |
| ORD-02 | Direction volume below limit | Repeat with requested volume strictly within limit and valid margin | Request reaches normal broker validation; no false rejection by guard | NOT RUN |
| ORD-03 | Concurrent exposure change | Change position/order exposure between guard snapshot and server request; repeat with two charts/instances | Server-side rejection is handled safely; no claim of atomic client-side protection | NOT RUN |
| ORD-04 | Volume-step/bounds | Exercise min/max/step and zero/negative/NaN-like invalid configuration inputs where applicable | Invalid volume is rejected; accepted volume conforms to broker constraints | NOT RUN |
| ORD-05 | Hedging/netting modes | Test on each supported account mode with existing same-symbol exposure | Position/order selection and exposure accounting are correct for that mode | NOT RUN |

## C. Pending-order deletion authorization — high priority

| ID | Scenario | Procedure | Expected result | Status |
|---|---|---|---|---|
| DEL-01 | Valid automatic rollback | Trigger setup failure immediately after creating an EA-tagged pending order | Only the order created by that operation is eligible for rollback | NOT RUN |
| DEL-02 | Hedge rollback tag | Exercise `OneClickHedge` rollback using `STB|HEDGE|` family | Creator-specific authorization succeeds only for the matching recent hedge order | NOT RUN |
| DEL-03 | Manual pending order | Create manual EA-tagged order and trigger unrelated setup failure | Manual order is not removed as an unrelated rollback | NOT RUN |
| DEL-04 | Foreign/untagged order | Present a foreign/manual order and invoke rollback paths | Delete is refused and order remains | NOT RUN |
| DEL-05 | Wrong source/tag pair | Deliberately pair each rollback source with another creator's comment family | Delete is refused | NOT RUN |
| DEL-06 | Expired order | Test actual server expiry and local-age expiry independently | Only an order meeting the explicit expiry policy is deleted | NOT RUN |
| DEL-07 | Stale rollback request | Attempt rollback outside the permitted fresh-setup window | Delete is refused | NOT RUN |
| DEL-08 | Broker response ambiguity | Simulate timeout/rejection/transaction delay around deletion | Logs include retcode; subsequent state is re-read; no false success claim | NOT RUN |

## D. Stop-loss and position management — release-critical

| ID | Scenario | Procedure | Expected result | Status |
|---|---|---|---|---|
| SL-01 | Initial SL on newly opened managed position | Open managed position without SL in a controlled test environment | Valid protective SL is added or failure is clearly reported/retried | NOT RUN |
| SL-02 | Profit protection and trailing same cycle | Configure price/profit so both profit-lock and trailing candidates qualify in one management cycle | A single resolved candidate is chosen according to documented priority/geometry policy; no order-dependent result | IMPLEMENTED STRUCTURALLY; FUNCTIONAL TEST NOT RUN |
| SL-03 | Initial protection and trailing contention | Make a newly discovered position qualify for initial protection and trailing during one cycle | No candidate overwrites a stronger protective candidate; arbitration is deterministic | IMPLEMENTED STRUCTURALLY; FUNCTIONAL TEST NOT RUN |
| SL-04 | Buy monotonicity | Repeatedly propose weaker and stronger buy SLs | SL never loosens; stronger valid SL can be applied | NOT RUN |
| SL-05 | Sell monotonicity | Repeat SL-04 for sell position | SL never loosens; stronger valid SL can be applied | NOT RUN |
| SL-06 | TP changes before modify | Change TP externally between snapshot and SL modification | EA aborts stale combined request when detected; fresh TP is not overwritten by old snapshot | NOT RUN |
| SL-07 | TP race after final read | Coordinate an external TP change in the narrow window after final read and before request | Document platform limitation and observed behavior; no claim of compare-and-swap atomicity | NOT RUN |
| SL-08 | Stops/freeze constraints | Test symbols with nonzero stop/freeze levels and variable tick size | Invalid requests are rejected safely and retried according to policy | NOT RUN |
| SL-09 | Broker modify failures | Test invalid-stops, no-changes, market-closed, off-quotes, timeout/requote retcodes where reproducible | Cache reconciles to terminal state; failures are observable; retry policy is bounded | NOT RUN |
| SL-10 | Manual override | Apply manual override and issue AUTO/manual SAVE commands | Automatic managers honor override; explicit user action behaves as documented | NOT RUN |
| SL-11 | Partial close and lock-state lifetime | Partially close a managed position by EA and manually; also test full close and netting reversal. Include close deals whose magic differs from the EA's magic | A partial OUT/OUT_BY retains per-ticket lock/failure state while the position remains; full close clears it; INOUT reversal clears the old-direction lock. Confirm actual state after every transaction burst | NOT RUN |

## E. Lifecycle, event ordering, and resilience

| ID | Scenario | Procedure | Expected result | Status |
|---|---|---|---|---|
| EVT-01 | Tick/timer overlap | Generate activity around OnTick and OnTimer management | Per-cycle guard works as intended; no unsupported claim of global deduplication across cycles | NOT RUN |
| EVT-02 | Trade transaction bursts | Open/modify/delete while multiple trade transaction events arrive | State is reselected from terminal; event ordering assumptions do not corrupt state | NOT RUN |
| EVT-03 | Restart recovery | Restart terminal/EA with managed positions, pending orders and persisted state | State is rebuilt safely; no duplicate or unauthorized write | NOT RUN |
| EVT-04 | Chart removal / lease release | Remove one instance while another manages the same symbol | Lease is released/taken over without two simultaneous authorized writers | NOT RUN |
| EVT-05 | Stale lease takeover | Leave an expired management lease and start a new instance | CAS takeover succeeds safely; live owner is not displaced | NOT RUN |
| EVT-06 | Disconnect/reconnect | Interrupt connection during modify/delete and restore it | EA reconciles live state; does not assume timed-out requests failed or succeeded without checking | NOT RUN |
| EVT-07 | Multi-chart/multi-symbol | Run supported combinations concurrently | No cross-symbol state leakage or ticket mix-up | NOT RUN |

## F. Strategy behavior and operational guardrails

| ID | Scenario | Procedure | Expected result | Status |
|---|---|---|---|---|
| STR-01 | Tester trading permission | Record tester settings and `OnInit` outcome | Test cannot be marked valid unless auto-trading gate is explicitly enabled and logged | NOT RUN |
| STR-02 | Risk sizing disabled (default) | Test default `InpUseRiskSizing=false` and fixed-lot behavior | Effective volume and risk mode are explicit in logs/report | NOT RUN |
| STR-03 | Risk sizing enabled, zero risk percent | Enable risk sizing with `InpRiskPercent=0` | Setup is rejected safely with explicit reason; no unintended minimum-lot substitution | NOT RUN |
| STR-04 | Daily loss / drawdown circuit breaker | Inspect full code and test account equity/balance thresholds if supported | Any claimed account-wide circuit breaker has a proven implementation and repeatable test; otherwise release docs state it is absent | NOT VERIFIED |
| STR-05 | Regression baseline | Run identical historical data/model/settings on baseline and candidate | Differences are explained; no claim of profitability based on code review alone | NOT RUN |
| STR-06 | Forward demo run | Run pre-agreed duration/instruments with detailed logs and no live funds | No unexplained critical errors, unauthorized writes, or state corruption | NOT RUN |

## G. Evidence to attach before approval

- [ ] Exact source commit and raw-file SHA-256 (current Git blob ID: `17059923ccb18e1b717947e4581d9790df26a368`)
- [ ] MetaEditor version/build and complete compile log
- [ ] EX5 SHA-256 and source-to-binary provenance manifest
- [ ] Strategy Tester configuration, data range, modelling mode, report and journal
- [ ] Demo account type, broker/server, symbol specification and observed logs
- [ ] Pass/fail result for every applicable test ID, with defect links
- [ ] Dependency/include inventory and license/attribution review
- [ ] Independent review sign-off and explicit release decision

## Current evidence summary

- Current source blob: `17059923ccb18e1b717947e4581d9790df26a368` (Git blob identifier, not raw-file SHA-256).
- Latest static CI run `37935834667`: **SUCCESS**, 24 static checks passed, including the partial-exit lock-state lifecycle guard. The run checks source structure only.
- The cycle-scoped candidate queue and per-ticket flush are present, with shared tick snapshot validation, deterministic tie-break, allocation-failure handling, producer write boundaries, and confirmation of a nonzero live SL.
- Functional tests for SL-01 through SL-11 remain **NOT RUN**; static checks do not execute the MQL resolver or prove runtime behavior.
- The position-modify recheck narrows the stale-TP window but is not an atomic compare-and-swap.
- MetaEditor compile, Strategy Tester, demo tests, exact-source EX5 provenance, and package/license review remain unverified.
- Release decision: **BLOCKED / NOT VERIFIED**.
