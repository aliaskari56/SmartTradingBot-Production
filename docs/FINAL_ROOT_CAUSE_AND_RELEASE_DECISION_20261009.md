# Final Integrated Root-Cause Audit and Release Decision

Last integrated review: 2026-10-09  
Repository: aliaskari56/SmartTradingBot-Production  
Audit branch: audit/expose-cleaned-source-20261009  
Primary source: MQL5/Experts/SmartTradingBot_FINAL.mq5

## 1. Final decision

**Release status: BLOCKED / NOT VERIFIED.**

The highest-priority source-structure findings tracked in earlier root-cause reports have been remediated on the audit branch in the areas of delete authorization, shared directional-volume preflight, and same-cycle SL arbitration. A verified source/checker GitHub Actions run, [37950552410](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37950552410), passed 26 static checks on the current source/checker content.

That is not a compiler result or runtime test. MetaEditor is not available in this execution environment. No fresh compile, Strategy Tester run, demo test, broker compatibility test, package extraction, licensing decision, or independent release sign-off was performed in this pass. The checked-in EX5 is not proven to come from the source revision below.

No repository paths were added by this integration. The source and existing audit/checklist documents were updated on the audit branch only; main remains untouched.

## 2. Frozen revision and evidence

- Source file: MQL5/Experts/SmartTradingBot_FINAL.mq5
- Current source Git blob: 6bca33bc8e0c961f317b0828e46faf7a6b9929b4 (Git blob identifier, not raw-file SHA-256)
- Source-changing commit: 30d683029158bc4a1cab64e8d3d190af04b07479
- Static checker: tools/audit_static_checks.py
- Static checker Git blob: 7f5092f1663f8a899449a16f3b6588df80c19bef
- Latest checked static run: [37950552410](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37950552410) — 24 PASS checks
- Source tree reports 9,208 decoded lines; Git tree records a 305,927-byte source blob. A Git blob identifier must not be reported as a raw SHA-256.
- Existing tracked EX5: MQL5/Experts/SmartTradingBot_FINAL.ex5, blob 348bb13126ba73b9502f82466f2d1a2bea1e8f6f. Its source/build provenance is unknown; the compile runbook does not overwrite it.

The source and checker checks establish only the properties encoded by the static checker. They do not execute functions in the EA, validate MQL compiler semantics, or establish account/server behavior.

## 3. Root-cause findings and present disposition

### RC-01 — SL proposals were previously resolved one at a time
**Prior severity: HIGH | Source structure: REMEDIATED | Functional proof: OPEN**

The original flaw was not that a validator existed, but that callers submitted each management candidate in isolation. Initial protection, profit protection, and trailing therefore did not reach a single arbiter as a complete same-cycle set.

Current implementation:
- Automatic candidates are queued by ticket and cycle.
- The central flush gathers the full candidate set for each ticket.
- BUY positions select the highest valid improving SL; SELL positions select the lowest valid improving SL.
- Equal-price ties use stable source ordering.
- Candidate geometry is tested against one shared tick/stops/freeze snapshot; the selected candidate and final broker write are validated again against live terminal state.
- When the universal profit-lock trigger has been reached, arbitration enforces the configured lock target as a floor so trailing cannot replace it with a weaker stop. If no SL is installed and broker geometry prevents placing that target, the strongest valid non-profit-lock candidate may be used as an emergency protective fallback.
- Lock-pips state is only persisted after the final terminal SL is verified to meet the normalized lock target. Partial OUT/OUT_BY events retain lock state while the position remains; full close and INOUT reversal clear the old state.
- Queue-allocation failure aborts the whole automatic batch; per-ticket temporary-array failure skips that ticket rather than silently resolving a truncated candidate set.
- Initial protection, profit protection, and trailing share one collection/flush path. Explicit user SAVE and the initial-protection lifecycle fallback remain deliberate synchronous exceptions.

Functional permutation tests and BUY/SELL broker tests remain NOT RUN. Static structure does not prove the winner is correct in a live MQL runtime.

### RC-02 — Aggregate directional volume was not guarded in every creator
**Prior severity: HIGH | Source structure: REMEDIATED | Broker proof: OPEN**

The shared STB_DirectionVolumeWithinLimit preflight is now present in four order-creation paths: PlaceSetup, PlaceManualPendingDirection, PlaceManualLimitDirection, and OneClickHedge. It considers same-direction position plus pending-order exposure against SYMBOL_VOLUME_LIMIT.

This is a local snapshot check, not an atomic reservation. Another chart, EA, terminal, or server-side exposure change can race the check. Broker OrderCheck and the server result remain authoritative. Netting/hedging and concurrent exposure scenarios remain NOT RUN.

### RC-03 — The final pending-delete writer lacked the complete authorization contract
**Prior severity: HIGH | Source structure: REMEDIATED FOR CURRENT CALLERS | Runtime proof: OPEN**

STB_ExecuteOrderDelete is the single direct OrderDelete writer. It validates pending-order type and validates rollback against creator source, ticket comment family, and freshness. Expiry deletion also requires source ManagePendingOrders, an IsManagedOrder(ticket) result, and a verified symbol-management lease at the writer boundary before recalculating server/local expiration. It checks the server retcode and requires the ticket to disappear before logging confirmation.

Current callers use creator rollback for OneClickHedge, PlaceSetup, and PlaceManual, plus server-expiration cleanup from ManagePendingOrders. The enum values for explicit-user-delete and explicit-cleanup are declared but have no current call sites and do not authorize a request by themselves. Do not assume a UI delete feature exists from those enum labels alone. Any future delete path must be explicitly authorized and tested. Runtime tests for wrong source/tag, stale rollback, manual/foreign order, and server response ambiguity remain NOT RUN.

### RC-04 — SL modification could restore a stale TP snapshot
**Source mitigation: PRESENT | Atomicity: NOT AVAILABLE | Functional proof: OPEN**

The central position writer reselects the position before submission, rejects changed position side or TP relative to the earlier snapshot, and rechecks current SL monotonicity and SL validity immediately before PositionModify.

This narrows the stale-TP window; it is not an atomic compare-and-swap. Another actor can still change TP between the final read and server request. This race must remain documented and tested rather than described as fully eliminated.

### RC-05 — Partial-close events could clear the position's stored profit-lock state
**Source mitigation: PRESENT | Functional proof: OPEN**

Per-ticket lock/failure cleanup now runs before filtering deal events by this EA's magic number. OUT/OUT_BY events preserve the stored lock while the position ticket still exists; a confirmed full close clears it. INOUT direction reversal clears the previous directional lock.

This fixes the prior unconditional-cleanup behavior structurally. MQL5 explicitly documents that trade-transaction notifications can arrive while account entities have already changed again, and event properties do not guarantee the current state of the position. Therefore partial close, full close, reversal, manual-close, netting, and hedging cases must still be exercised in the terminal. Reference: [MQL5 OnTradeTransaction documentation](https://www.mql5.com/en/docs/event_handlers/ontradetransaction).

### RC-06 — Per-invocation cycle control is not cross-event proof
**Residual severity: MEDIUM-HIGH | Runtime proof: OPEN**

OnInit, OnTick, and OnTimer route through STB_RunManagementCycle. The one-write marker is cycle-scoped, so it limits duplicate writes within a single cycle but is not a global "one write per ticket for all time" guarantee. Monotonic SL checks, writer ownership checks, state reconciliation and trade retcode verification are present, but tick/timer frequency, subsequent cycles, transaction bursts, and restart/reconnect behavior are not runtime-proven.

### RC-07 — Source-to-EX5 provenance is not established
**Severity: RELEASE BLOCKER | Status: OPEN**

The tracked EX5 was not built by this audit and has not been shown to correspond to the current source. The previously tracked backup manifest contains historical claimed hashes/compile output; those claims have not been independently recomputed for this exact source and toolchain.

The existing build-provenance document now contains a PowerShell function that:
- checks the branch, clean working tree and exact source blob;
- stages a byte-identical source copy outside the repository;
- passes the reviewed MQL5 tree as the include root;
- invokes MetaEditor with compile/log arguments;
- reports the raw source and EX5 SHA-256, exit code, compiler summary, and full log;
- preserves the isolated build directory for inspection and never overwrites the tracked EX5.

This is a procedure for the user's Windows/MetaEditor environment, not evidence that a compile has already passed. Runbook: [Exact-source build and PowerShell compile procedure](EXACT_SOURCE_BUILD_PROVENANCE_CHECKLIST_PASS28_20261009.md). Official command-line reference: [MetaQuotes MetaEditor integration](https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide).

### RC-08 — Package, third-party license, and source attribution remain unresolved
**Severity: RELEASE BLOCKER | Status: OPEN**

The current EA visibly includes Trade.mqh and the two STB pending-trail modules. ALGLIB was not observed in the traced direct EA include closure, but the repository contains ALGLIB-family headers with GPL v2-or-later notices. The actual release ZIP has not been extracted and compared to an exact package manifest, so repository presence alone cannot determine whether those files are distributed.

The EA source header still has generic ProjectName / CompanyName / companyname.net placeholders. The inspected STB module headers do not establish the rights holder or redistribution terms. Do not invent attribution or replace those fields without confirmed owner information. Package inventory, origin/ownership confirmation, notice review and a qualified compliance decision remain required.

### RC-09 — Strategy and operational safety are not verified by static checks
**Severity: RELEASE BLOCKER | Status: OPEN**

- InpUseRiskSizing defaults to false; fixed-lot behavior is the default unless the input is enabled.
- No verified account-wide daily-loss or maximum-drawdown circuit breaker was established by this bounded review. Do not advertise one without finding and testing its implementation.
- The EA's swing tie-handling differs from the separate BrokerStructureScanner in some equal-pivot cases. That is an algorithmic difference, not proof of a defect; avoid a broad strategy rewrite without fixed fixtures and shadow comparisons.
- No Strategy Tester, demo, long-duration soak, profitability, spread/slippage sensitivity, or independent review evidence is available.

## 4. Unified compile and release workflow

1. Sync the local checkout to audit branch audit/expose-cleaned-source-20261009 and ensure the working tree is clean.
2. Open the PowerShell runbook linked above; paste its function into a PowerShell session and invoke it with the actual local checkout and MetaEditor path. Do not add a new script file to the repository.
3. Review the complete compiler log. A clean build check requires process exit code 0, an output EX5, and a parsed summary of 0 errors and 0 warnings. If any warning exists, review it explicitly; the current runbook fails closed on warnings.
4. Preserve the returned raw source SHA-256, Git blob, compiler path/version, complete log, process exit code, and EX5 SHA-256. The staged EX5 is a build candidate only; do not install it into a live terminal as part of the compile check.
5. Execute acceptance tests SL-01 through SL-11, including source permutations, BUY/SELL monotonicity, initial+trailing and profit-lock+trailing contention, TP change races, partial closes, full close, reversal, manual override, restart/reconnect, netting/hedging and multi-instance ownership.
6. Execute the order-volume and delete authorization matrices; retain the tester configuration, reports, journal, trade history and observed expected-versus-actual outcomes.
7. Extract and inventory the intended release package, record every shipped file/hash/license, resolve source ownership/attribution, and obtain independent review before release.

## 5. Gate matrix

| Gate | Current status | Closure evidence |
|---|---|---|
| Static structural checks | PASS — 24 checks in run 37950552410 | Checks only the encoded source properties |
| Exact-source MetaEditor compile | NOT RUN HERE | Full local log, toolchain identity, exit code, raw source and EX5 hashes |
| SL arbitration runtime suite | NOT RUN | SL-01 through SL-11 results, including permutation and lifecycle tests |
| Shared volume limit | STRUCTURALLY PRESENT; NOT RUN | All four creation paths under netting/hedging and race scenarios |
| Pending delete authorization | STRUCTURALLY PRESENT FOR CURRENT CALLERS; NOT RUN | Creator rollback, expiry, stale/mismatched/foreign-ticket scenarios |
| SL/TP concurrency and event lifecycle | NOT RUN | TP race window, tick/timer, transaction bursts, reconnect/restart |
| Package / dependency / license / attribution | OPEN | Exact ZIP manifest, source provenance, ownership and qualified review |
| EX5 provenance | OPEN | Exact source/toolchain/log/EX5 chain of custody |
| Strategy Tester and demo | NOT RUN | Reproducible test configurations, reports and journals |
| Independent release review | OPEN | Reviewer sign-off tied to frozen revision |

## 6. Final decision

The original same-cycle SL root cause has a structural implementation on the audit branch, and the partial-exit state-lifecycle edge was also addressed. The shared volume preflight and delete authorization controls are present at the source level. These improvements reduce the known gaps but do not establish compiler validity or safe runtime behavior.

**Final audit status: STATIC STRUCTURAL CHECKS PASS; TECHNICAL VERIFICATION OPEN.**  
**Final release status: BLOCKED / NOT VERIFIED.**

Do not merge this status into a production-release claim, do not replace the tracked EX5 with an unverified binary, and do not touch main as part of this audit.
