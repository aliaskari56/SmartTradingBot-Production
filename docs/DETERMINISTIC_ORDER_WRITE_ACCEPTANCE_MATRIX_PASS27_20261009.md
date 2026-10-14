# Deterministic Order-Write Acceptance Matrix — Pass 27
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`

## Purpose and limits

This is a test specification derived from the static audit. It does not claim that tests have run or that any issue is reproduced. The executable source remains unchanged. Run only in a controlled Strategy Tester or demo environment with recorded terminal/server build, symbol specifications, account mode, test data, and source/build hashes.

## Required evidence bundle for every test

Record: test ID; source commit and raw SHA-256; EX5 SHA-256 and build log; MetaEditor/terminal versions; account mode (netting/hedging); symbol and symbol properties; initial account/order/position state; event sequence and timestamps; inputs; expected result; observed result; trade-server retcode and description; final server-side orders/positions; relevant journal/expert logs; PASS/FAIL/BLOCKED/NOT RUN; operator and run date.

A test is not PASS if only a local function return value is captured. Verify final server state and reconcile it with EA state.

## A. Order creation and exposure controls

| ID | Scenario | Setup / action | Acceptance criteria |
|---|---|---|---|
| OW-01 | Strategy setup within volume limit | Create a valid setup below symbol directional volume limit | Correct normalized volume; order geometry accepted; final exposure matches expected |
| OW-02 | Strategy setup exceeds volume limit | Seed directional exposure near limit and request setup that would exceed it | New order rejected or safely reduced according to documented policy; no limit overshoot |
| OW-03 | Manual pending STOP at limit | Seed exposure near limit; invoke manual STOP command | Same documented exposure policy as other creation paths; no unintended order |
| OW-04 | Manual pending LIMIT at limit | Repeat for manual LIMIT | Same documented exposure policy; no unintended order |
| OW-05 | OneClickHedge at limit | Test intended hedge policy in hedging and netting account modes where applicable | Policy is explicit; exposure and margin consequences match policy; no accidental bypass |
| OW-06 | Invalid volume/step/min/max | Supply edge values around min, max and volume step | Rejected or normalized only according to documented rules; no volume rounded upward beyond risk/limit |
| OW-07 | Trade disabled / direction prohibited | Disable terminal/account trading or prohibit symbol direction | No server-side order is created; error is visible and state remains consistent |
| OW-08 | Risk sizing enabled, zero risk percent | Enable risk sizing with zero percentage | Safe explicit rejection; no silent fixed-lot fallback |

## B. Delete authorization and rollback

| ID | Scenario | Setup / action | Acceptance criteria |
|---|---|---|---|
| OW-09 | Normal expiry cleanup with valid lease | Create owned pending order, let expiry policy request deletion | Delete is authorized; server confirms; ticket disappearance is reconciled |
| OW-10 | Normal delete without verified lease | Present an order for which the manager lacks verified authorization | Delete is refused; order remains untouched; reason is logged |
| OW-11 | Setup rollback after initial protection failure | Force the initial pending SL/protection validation to fail after order creation | Newly created order is cleaned up through a narrowly scoped rollback capability; no orphan order |
| OW-12 | Manual STOP rollback | Force post-create validation failure in manual STOP path | Rollback cleans only the order created by this operation; unrelated orders remain untouched |
| OW-13 | Manual LIMIT rollback | Same for manual LIMIT | Same as OW-12 |
| OW-14 | OneClickHedge rollback | Force post-create validation failure for hedge order | Only newly created ticket is removed; cleanup does not depend on unrelated lease state |
| OW-15 | Delete race: ticket disappears first | Remove ticket externally between selection and delete | No false success assumptions; final state is reconciled and duplicate cleanup is harmless |
| OW-16 | Delete server rejection / timeout | Simulate or reproduce a rejected/uncertain delete result | No success is recorded without evidence; bounded retry/reconciliation follows documented policy |
| OW-17 | Foreign/unmanaged ticket | Seed unrelated ticket outside configured management scope | Manager does not delete it |

## C. SL/TP writer consistency and arbitration

| ID | Scenario | Setup / action | Acceptance criteria |
|---|---|---|---|
| OW-18 | SL update with unchanged TP | Start with known SL/TP; request SL-only improvement | SL changes as intended; existing server TP is preserved |
| OW-19 | TP changes between snapshot and SL write | Change TP externally after EA snapshot but before writer action | Stale snapshot cannot overwrite the newer TP; stale request is refreshed/rejected/reconciled |
| OW-20 | Competing initial-SL and trailing proposals | Make two valid SL proposals in one management cycle | Documented priority/arbitration is deterministic; final write follows policy |
| OW-21 | Competing profit-protection and trailing proposals | Trigger both proposal sources | One final write or explicitly documented serialization; no weaker SL overwrites a stronger valid SL |
| OW-22 | Invalid/stale proposal | Submit invalid price, wrong side, or stale ticket state | Proposal rejected; no broker write; diagnostic reason available |
| OW-23 | Server accepts request but state differs | Modify request where server normalization/behavior changes observed geometry | Read back actual SL/TP and reconcile registry to server truth |
| OW-24 | Manual override during management | Change SL/TP manually while EA cycle is active | Defined MANUAL HOLD/override policy is honored; no silent immediate overwrite |

## D. Pending-trail lifecycle and event reconciliation

| ID | Scenario | Setup / action | Acceptance criteria |
|---|---|---|---|
| OW-25 | Pending trail normal update | Attach trail state to eligible pending order and advance price | Only valid geometry is proposed; accepted changes reconcile to server state |
| OW-26 | Pending trail modify failure | Force broker rejection or invalid stops | Retry/backoff is bounded; state does not claim a modification succeeded |
| OW-27 | Restart with pending trail active | Restart EA/terminal with active trail-managed pending order | State is rebuilt from persisted/observable truth; no duplicate or lost trail state |
| OW-28 | Pending triggers into position | Trigger order while trail state exists | Pending state hands off or is retired correctly; position manager takes over once |
| OW-29 | Cancel/recreate with changed ticket | Cancel order and create replacement | Old ticket state is retired; new ticket is independently registered |
| OW-30 | Duplicate/out-of-order transaction events | Replay or observe repeated/reordered transaction notifications | Idempotent reconciliation; no duplicate state transitions or writes |
| OW-31 | Tick and timer same-cycle overlap | Cause OnTick and OnTimer management close together | No conflicting duplicate writes; per-ticket arbitration/lease behavior remains deterministic |
| OW-32 | Partial close / position reversal | Exercise partial close or reversal where supported | Position/deal accounting and protection state match final server position |

## E. Release and risk validation

| ID | Scenario | Acceptance criteria |
|---|---|---|
| OW-33 | Exact-source build | Raw compiler output, compiler version, source hash and resulting EX5 hash are recorded and linked |
| OW-34 | Dependency inventory | Every distributed dependency has provenance, version, license/notice disposition |
| OW-35 | Historical/out-of-sample Strategy Tester | Reproducible settings/data; spread, commission, swaps and relevant execution assumptions documented; results are not represented as proof of future profitability |
| OW-36 | Demo forward test | No unexplained orphan orders, stale state, authorization bypass or exposure-limit breach in agreed observation period |
| OW-37 | Independent review | Reviewer inspects source/build evidence and test artifacts; high/critical blockers are closed or explicitly rejected by release owner |
| OW-38 | Release decision | Signed decision records scope, known limitations, unresolved risks, artifact hashes and rollback plan |

## Execution order

1. Establish exact-source build provenance (OW-33) before treating any runtime result as representative of the reviewed source.
2. Review intended authorization and exposure policy before OW-01–OW-17; do not add a blanket delete guard without testing rollback semantics.
3. Test SL/TP writer consistency and proposal policy (OW-18–OW-24).
4. Test pending-trail lifecycle and event ordering (OW-25–OW-32).
5. Complete dependency review, Strategy Tester, demo validation, independent review, and release decision (OW-34–OW-38).

## Current status

All cases are **NOT RUN**. No executable source change is included in this pass. No compile, Strategy Tester, demo test, benchmark, or independent review was performed. The release gate remains **BLOCKED / NOT VERIFIED** until evidence is collected and evaluated.
