# Pass 17 — Mutation-boundary trace and testable remediation design (2026-10-09)

## Status

**DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN**

Reviewed against branch `audit/expose-cleaned-source-20261009`, primary source `MQL5/Experts/SmartTradingBot_FINAL.mq5`, Git blob SHA `955d9961e3da1d855a162ac6f4acf7bf7fc852b8` (8,665 lines). This pass re-read specific source ranges. It is static analysis only: no source code was changed, no compiler or MetaTrader runtime was invoked, and no broker/demo behavior was tested.

## Verified source anchors

| Concern | Source anchor | Direct observation | Audit implication |
|---|---|---|---|
| Pending modify | `STB_ModifyPendingOrderGeometry()`, around line 1868; lease check around 1879 | Checks `STB_SymbolManagementOwnedVerified(symbol)` before pending modification | Writer has a visible symbol-lease barrier |
| Position SL modify | `ModifyPositionSL()`, around line 4665; lease check around 4665; server call around 4694 | Selects the position, validates allowed symbol/managed position, checks verified lease, then calls `trade.PositionModify(ticket,newSL,tp)` | Lease barrier exists, but SL/TP snapshot freshness and combined-modify semantics still need testing |
| Position SL proposal | `STB_ResolvePositionSL()` and `STB_SubmitPositionSL()`, around line 4654 | Submit creates a one-element array and invokes resolver with count=1 | Resolver can compare a list, but this call path does not demonstrate cross-manager arbitration of simultaneous proposals |
| Delete writer | `STB_ExecuteOrderDelete()`, around line 8135; actual request around line 8145 | Selects ticket and verifies trade retcode and ticket disappearance; no visible call to `STB_SymbolManagementOwnedVerified(symbol)` at this boundary | Server-result checking is present; a writer-level ownership/authorization contract is not visibly enforced here |
| Delete wrapper | `STB_RequestOrderDelete()`, around line 8181 | Directly delegates to `STB_ExecuteOrderDelete()` | Wrapper adds no visible authorization decision |
| Expiration caller | `ManagePendingOrders()`, around lines 5693 and 5737 | Checks verified symbol lease before requesting expiration deletion | This caller has a pre-check; it does not close the boundary gap for other callers |
| Automatic setup rollback | `PlaceSetup()`, around line 6176 | Requests rollback deletion if accepted order's initial SL is not confirmed | Cleanup must remain possible after partial creation failure |
| Manual STOP rollback | `PlaceManualPendingDirection()`, around line 6504 | Requests rollback deletion if initial SL is not confirmed | Same rollback exception needs explicit policy |
| Manual LIMIT rollback | `PlaceManualLimitDirection()`, around line 6602 | Requests rollback deletion if initial SL is not confirmed | Same rollback exception needs explicit policy |
| HEDGE rollback | `OneClickHedge()`, around line 4047 | Requests rollback deletion | Must be traced through its creation and ownership lifecycle before changing the gate |

Line numbers are approximate anchors from the reviewed blob and can move if the file changes. Re-run the trace against the exact source hash before implementation or retest.

## Refined finding: delete authorization at the mutation boundary

The delete writer currently has two important properties:
1. It checks that the ticket can be selected before sending the request.
2. It requires an accepted server retcode and checks that the active order ticket is no longer selectable before reporting confirmed deletion.

However, those checks establish request/result handling, not authorization to delete. The writer receives a `reason` and `source`, but the inspected body does not visibly enforce an authorization policy based on them or verify the symbol-management lease.

A blanket lease check added without design work could break the rollback path: the EA may need to remove an order that the server accepted but whose initial protection was not verified. The correct fix must define a narrow, auditable exception for a just-created ticket while preventing that exception from becoming a general bypass.

### Required design before any source edit

- Resolve the ticket and read its actual symbol and current order properties before authorization.
- Define a small explicit authorization policy at the writer boundary, keyed by delete reason and verified ownership/lifecycle state—not by caller-supplied source text alone.
- Normal lifecycle/expiry deletes should require the verified symbol lease and the applicable bot-management scope.
- Rollback should be allowed only for a ticket demonstrably created by the current operation and only within a bounded creation/verification window; a reason enum alone must not authorize arbitrary tickets.
- If the required proof cannot be established, fail closed, log a distinct reason, and leave a reconciliation task rather than silently deleting.
- After the server request, preserve the current retcode/disappearance checks and reconcile the final account state.
- Verify whether explicit user-delete and housekeeping paths exist elsewhere before finalizing the policy; the enum names alone do not prove that those paths are called.

## Refined finding: SL modification and proposal arbitration

The inspected SL bridge constructs one proposal and calls the resolver with `count=1`. Separate call sites submit initial SL, profit-protection, and trailing candidates. Therefore, this path does not demonstrate that all candidate proposals are collected and arbitrated together in a single cycle.

The writer also reads the current TP and submits both SL and TP through `trade.PositionModify(ticket,newSL,tp)`. That preserves the TP value read by this invocation, but does not itself prove the snapshot is fresh if another actor or writer changes TP between read and server write. This is a concurrency risk to validate, not proof that an overwrite has occurred.

### Required tests/design decisions

- Specify whether proposals are collected for a position and resolved once per cycle, or whether serial priority is intentional. Document and test the chosen contract.
- Test BUY and SELL positions with existing SL, no SL, invalid candidates, equal candidates, and candidates that do not improve protection.
- Arrange a controlled TP change between snapshot and SL modification in a tester/demo or test harness where feasible; confirm there is no unintended rollback of the newer TP.
- Test server rejection, stale ticket, price movement, stop/freeze-level constraints, and the one-write-per-ticket-per-cycle rule.
- Confirm post-request state from the terminal/server instead of treating the local method return as sufficient evidence.

## Focused acceptance tests for the delete boundary

| ID | Setup | Action | Acceptance condition |
|---|---|---|---|
| DEL-01 | Bot-managed pending order; lease held and verified | Request normal eligible deletion | Request is authorized; success is reported only after server retcode and ticket disappearance are confirmed |
| DEL-02 | Same order but lease absent, expired, or owned by another chart | Request normal lifecycle deletion | Writer refuses the mutation; order remains unchanged; denial is logged |
| DEL-03 | Newly accepted order whose initial SL verification fails, with creation proof available | Invoke the narrow rollback path | Only the ticket created by that operation may be deleted; cleanup succeeds if server permits it |
| DEL-04 | Existing unrelated/foreign order passed with rollback reason but no matching creation proof | Request deletion | Request is denied; reason enum cannot bypass ownership proof |
| DEL-05 | Ticket disappears before writer starts | Request deletion | No false claim of a newly executed deletion; result is classified as already absent/reconciled according to an explicit contract |
| DEL-06 | Server rejects delete or leaves ticket active | Request deletion | Failure is reported, state remains reconcilable, and no success log is emitted |
| DEL-07 | Concurrent chart lease changes around authorization | Request deletion | The documented lease/authorization policy is applied; race limitations are surfaced and tested |
| DEL-08 | Expiration cleanup and all four rollback call families | Exercise each caller | Each path is authorized by the same documented policy; rollback remains functional without broad bypass |

## Focused acceptance tests for SL/TP

| ID | Setup | Action | Acceptance condition |
|---|---|---|---|
| SL-01 | BUY and SELL, current SL absent/present | Submit initial/profit-lock/trailing candidates individually and together | The selected candidate matches the documented arbitration policy |
| SL-02 | Two or more candidates in one management cycle | Trigger multiple managers | Evidence shows whether arbitration is genuinely joint or intentionally serial |
| SL-03 | Position TP changes after local snapshot | Submit SL update | Newer TP is not overwritten unintentionally; any unavoidable platform limitation is documented |
| SL-04 | Broker rejects modification due to stops/freeze/price changes | Submit candidate | Actual position geometry is re-read; no stale proposed geometry is treated as applied |
| SL-05 | A second writer attempts modification in the same cycle | Submit two changes | One-write policy is enforced and final state is reconciled |
| SL-06 | Manual override is active | Trigger automatic manager | Automatic write is blocked according to the current policy; user-action exception is separately tested |

## Scope limits and next step

This pass confirms source structure and call sites in the stated file only. It does not prove all side effects in included libraries, all account event interleavings, or actual broker behavior. No remediation was applied because authorization and rollback semantics require a design decision before code changes.

Next safe step: obtain owner approval for the delete authorization contract and SL arbitration policy; then implement on the audit branch, compile against the exact toolchain, run the focused tests above, and preserve raw evidence. Do not merge or deploy on the basis of this static pass alone.

**Result:** source anchors and testable acceptance criteria are now more precise; technical findings remain open. `main` remains untouched.
