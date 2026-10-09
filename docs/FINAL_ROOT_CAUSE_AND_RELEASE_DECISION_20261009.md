# Final Integrated Root-Cause Review and Release Decision — 2026-10-09

Branch: `audit/expose-cleaned-source-20261009`  
Primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
Current source Git blob: `fdce203d23a08eb4ca2966d4a09719c3e4a89397` (Git blob ID; not raw-file SHA-256)  
Latest source-changing commit: `b4c08e84135c0ceb170e5e4b3e996957f3d8ce82`  
Observed source size: 304,511 bytes; 9,156 lines  
Static checker Git blob: `7f5092f1663f8a899449a16f3b6588df80c19bef`  
Latest static run for this source/checker: [37941413234](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37941413234) — success, 26 checks passed.

## 1. Executive decision

**Integration on the audit branch: COMPLETE. Static guardrails: PASS. MetaEditor compile/runtime acceptance: NOT RUN. Release: BLOCKED / NOT VERIFIED.**

This review consolidates the current branch state; it does not claim that this EA compiles, behaves correctly in a trading terminal, is profitable, or is ready for distribution. MetaEditor and Strategy Tester are not available in this execution environment. The PowerShell build procedure has been added to the existing `docs/EXACT_SOURCE_BUILD_PROVENANCE_CHECKLIST_PASS28_20261009.md`; it has not been executed here.

No file or folder was added to the repository. Existing source, checker, issue and documentation paths were updated in-place. The `main` branch was not modified, and no merge into `main` was performed.

## 2. Source-level fixes now integrated

### RC-01 — Order-delete authorization at the write boundary

The central `STB_ExecuteOrderDelete()` checks pending-order type, deletion reason, creator/source-to-comment family and freshness for immediate rollback. Server-expiry requests now additionally require source `ManagePendingOrders`, managed-symbol scope, and a verified symbol-management lease at the final writer boundary. This closes the observed gap where expiry was recalculated but its source/lease were not revalidated inside the writer.

The rollback exception remains deliberately separate: a freshly created invalid order can require immediate rollback before the usual management lifecycle is established, so a blanket lease requirement would break that path.

**Still required:** runtime tests for fresh creator rollback, wrong source/tag, stale rollback, foreign/unmanaged ticket, valid server expiry, local-age expiry, and a stale/competing lease. The static test confirms the intended guard is present; it does not execute the order writer.

### RC-02 — Directional aggregate volume controls

`STB_DirectionVolumeWithinLimit()` is used by all four identified creation families: automatic setup, manual pending stop, manual pending limit, and one-click hedge. The calculation includes same-symbol directional position volume and active pending exposure.

**Boundary:** this is a point-in-time preflight, not an atomic reservation. Another actor can change exposure between the check and server submission. Broker validation and retcodes remain authoritative. Netting and hedging behavior still needs demo/runtime evidence.

### RC-03 — Same-cycle SL proposal arbitration

Initial protection, automatic profit protection and live trailing collect candidates before the central flush. Proposals are grouped by ticket and cycle; the resolver receives the complete candidate set or skips the affected ticket if allocation fails. BUY positions select the highest valid improving SL; SELL positions select the lowest valid improving SL. Equal-price candidates use a deterministic source tie-break.

Candidate geometry uses one shared tick/stops/freeze snapshot. The chosen SL is revalidated against live terminal state and again at the writer boundary. If the market moved enough to invalidate the chosen candidate, the cycle fails closed instead of selecting a fallback against a different snapshot. Automatic profit-lock bookkeeping is deferred until the result can be confirmed; missing live SL is not credited as a successful protection stop.

**Still required:** candidate permutations, BUY/SELL monotonicity, initial+trail contention, profit-lock+trail contention, tick-size and stop/freeze boundaries, retcode failures, and broker runtime checks.

### RC-04 — Stale SL/TP snapshot conflict

`ModifyPositionSL()` reselects the position and compares live side and TP against the earlier snapshot before sending the combined SL/TP modify request. It also rechecks monotonic SL validity and broker geometry.

**Residual race:** MQL5 combined SL/TP modification is not an atomic compare-and-swap. A manual or other-instance TP edit can still race after the final read and before the server request. The implementation narrows this window; it does not eliminate it. Keep concurrent/manual TP tests in the acceptance suite.

### RC-05 — Per-cycle versus cross-event idempotence

The one-write marker is scoped to one invocation of `STB_RunManagementCycle()`, which is called from lifecycle/tick/timer paths. A new invocation creates a new cycle ID, so the per-cycle limit does not prove that events close together cannot request successive changes to a ticket.

**Still required:** tick/timer overlap, transaction bursts, delayed responses, restart/reconnect, manual edit, and multi-instance lease scenarios.

### RC-06 — Partial-close lock-state lifecycle

The close-deal cleanup runs before the deal-magic filter. Partial `OUT`/`OUT_BY` events preserve `LOCK_` and `MODFAIL_` state while the position remains; a full close clears it; `INOUT` reversal clears the old-direction state. This prevents an unrelated/manual-magic closing deal from bypassing cleanup and prevents partial exits from resetting a still-live position's earned-lock state.

**Still required:** runtime partial-close, full-close, reversal, netting and hedging tests. Current evidence is source-structural only.

### RC-13 — Active profit-lock floor under same-cycle contention

A final review found that a queued profit-protection proposal could pass producer-time validation, then fail the shared resolver snapshot while a weaker trailing candidate remained selectable. The flush previously used the presence of any queued profit candidate as a reason to persist the actual SL as locked pips, even when that actual stop did not reach the mandatory +20-pip target.

The resolver now checks current net profit against the +50-pip trigger and enforces the normalized +20-pip target as a floor for automatic candidates whenever the position already has an SL. If no candidate satisfies that floor, it does not replace the existing stop with a weaker one. Only when the position has no SL at all may the resolver use the strongest valid non-profit-lock proposal as an emergency fallback; that fallback is not credited as a confirmed +20-pip lock. Lock-state persistence after the flush now requires the verified actual SL to satisfy the normalized policy target.

**Still required:** run SL-12 with BUY and SELL positions, competing trail/initial candidates, live stop/freeze constraints that reject the +20-pip target, and both existing-SL and no-SL cases. Static CI checks code structure only; it does not simulate broker behavior.

## 3. Remaining root causes and release blockers

| ID | Area | Current status | What closes the gap |
|---|---|---|---|
| RC-07 | Exact source-to-EX5 provenance | OPEN | Freeze local commit; record raw SHA-256, MetaEditor/compiler version, full log, exit code and new EX5 SHA-256 from the same build |
| RC-08 | Package and dependency provenance | OPEN | Extract the actual release ZIP using a binary-capable checkout; inventory all members/hashes and compare against the release manifest |
| RC-09 | Source attribution / distribution rights | OPEN | Confirm actual rights-holder details and source/license provenance for the EA and both custom STB includes; do not invent attribution |
| RC-10 | End-to-end runtime correctness | OPEN | Execute acceptance matrix and independent review; static CI cannot establish trading correctness or profitability |
| RC-11 | Cross-event/instance lifecycle | OPEN | Execute overlap, restart, reconnect, transaction-order and multi-chart tests |
| RC-12 | Swing/scanner algorithm parity | DEFERRED BY DESIGN | Preserve current EA logic; use fixed fixtures and regression evidence before any pivot tie-policy change |

The current EA header still contains generic `ProjectName`, `CompanyName` and `companyname.net` placeholders. They must not be replaced until the owner confirms accurate attribution. The repository also contains ALGLIB-family headers with GPL v2-or-later notices, but the traced EA include closure did not show ALGLIB use. Repository presence alone does not prove that those files are shipped or compiled into the EA. Actual ZIP membership and distribution rights remain to be established.

Other configuration caveats remain: `InpUseRiskSizing` defaults to `false`; the fixed-lot mode is the default. No independent evidence establishes an account-wide daily-loss/max-drawdown circuit breaker or strategy profitability. Do not claim these controls/outcomes without locating and testing them.

## 4. Verification evidence

The latest static run [37941413234](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37941413234) completed successfully with 26 passing source-structure checks, including:

- one central order-delete writer and one central position-modify writer;
- all four order-creation paths using shared directional-volume preflight;
- rollback source/comment checks and the final expiry writer source/scope/lease gate;
- TP snapshot conflict check;
- complete per-ticket SL proposal collection, shared tick snapshot, deterministic tie-break, fail-closed allocation handling and final SL confirmation;
- deferred/confirmed profit-lock bookkeeping;
- partial-exit lock-state lifecycle; and
- lexical balance.

The CI output explicitly does **not** cover MetaEditor compilation, Strategy Tester, demo/broker compatibility, EX5 provenance, package/license review, or profitability.

## 5. Prepared compile procedure

The existing build provenance checklist now contains a copy/paste PowerShell procedure that:
1. requires the designated audit branch and the expected Git blobs for the EA plus all traced direct/transitive compile includes;
2. refuses a local modification of any checked compile input;
3. finds MetaEditor or stops for an explicit path if multiple installations are present;
4. stages the exact source outside the repository and confirms raw SHA-256 equality;
5. calls MetaEditor with the documented `/compile`, `/include`, and `/log` options;
6. checks the compiler summary and EX5 existence; and
7. prints source hash, commit, editor version, compiler result, log path, staging path and EX5 SHA-256.

This is preparation only. No PowerShell or MetaEditor execution occurred in this environment. An actual Windows run and a human review of compiler warnings/log are still required. The source's raw SHA-256 cannot be inferred from its Git blob SHA.

## 6. Required acceptance before release

1. Run the prepared PowerShell preflight/build from the exact checkout and preserve the complete compiler log, raw source SHA-256, raw EX5 SHA-256, toolchain version and process/compiler result.
2. Review every compiler warning; do not treat merely producing EX5 as a pass.
3. Execute the SL, delete authorization, volume guard, lifecycle, restart/reconnect, manual override, partial-close, netting/hedging and multi-instance tests in `docs/RELEASE_ACCEPTANCE_TEST_MATRIX_20261009.md`.
4. Extract and inventory the actual distributable ZIP; determine dependency membership, notices, ownership and license status.
5. Obtain independent review against the frozen source and evidence bundle.
6. Keep Issue #5 open until functional SL acceptance and the build gate have evidence.

## Final conclusion

The same-cycle SL arbitration, shared directional-volume guard, final expiry-delete ownership check and partial-close lock-state handling are integrated in the audit branch and covered by 26 passing static checks. That is a material source-level improvement, but not a compiler/runtime certification.

**Final static status: PASS FOR THE CHECKS ENCODED.**  
**Final technical status: OPEN.**  
**Final release status: BLOCKED / NOT VERIFIED.**  
`main` remains untouched.
