# Remediation Implementation and Verification Report — 2026-10-09

## Status

- **Static remediation:** implemented on the audit branch.
- **Static structural checks:** passed.
- **MetaEditor compilation:** NOT RUN.
- **Strategy Tester / demo / live runtime tests:** NOT RUN.
- **Release approval:** **BLOCKED / NOT VERIFIED**.

This report records source changes, not a claim of broker-tested correctness or profitability. The main branch was not modified.

## Source under review

- File: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
- Post-remediation Git blob SHA: `d53f58dc514cb449c80997023275321c166e0d4c`
- Branch: `audit/expose-cleaned-source-20261009`
- Latest source-changing commit: `1dc1234cbfe414f5dd0678a4322894f863ab53e8`

## Implemented changes

### 1. Shared aggregate directional-volume preflight

Added `STB_DirectionVolumeWithinLimit()` and wired it into all four order-creation families:

- `PlaceSetup` — automatic pending orders.
- `PlaceManualPendingDirection` — manual stop orders.
- `PlaceManualLimitDirection` — manual limit orders.
- `OneClickHedge` — hedge pending orders.

The guard uses `DirectionExposureVolume()`, which includes same-symbol directional positions and active pending orders. It rejects a request when current same-direction exposure plus requested volume exceeds a positive `SYMBOL_VOLUME_LIMIT`.

**Boundary:** this is a point-in-time check, not an atomic account reservation. Another EA, terminal, or server-side state change can race the check. Broker validation and server retcodes remain authoritative; runtime concurrency testing is required.

### 2. Central pending-delete authorization

The single `trade.OrderDelete()` writer now:

- rejects non-pending order types;
- allows rollback only when the creator source matches the order's tag family (`STB|B|` / `STB|S|` for `PlaceSetup`, `STB|M|` for manual stop/limit, `STB|HEDGE|` for `OneClickHedge`) and the ticket is fresh (within the 120-second rollback window);
- independently revalidates server expiration or the configured/profile-derived local-age expiration at the delete boundary;
- blocks deletion requests that do not satisfy the reason/source policy and logs the block;
- retains the existing server-retcode and post-delete disappearance checks.

The rollback check intentionally does not rely on magic number alone because UI-created STB pending orders may use magic `0`. Manual-order rollback remains allowed only for the known creator source and fresh STB-tagged order.

**Boundary:** only currently observed callers were reviewed. Any future delete reason or creator path must be explicitly added to the authorization policy and tested; do not bypass the central writer.

### 3. Stale TP snapshot conflict mitigation

Before `trade.PositionModify(ticket,newSL,tp)`, the writer now reselects the position and compares the live TP against the earlier snapshot. If the position side or TP changed, it aborts rather than knowingly submitting the stale TP value. It also rechecks the current SL monotonicity and SL validity immediately before submission.

**Boundary:** MQL5's combined SL/TP modification is not a compare-and-swap operation. A race can still occur between this final read and the server request. The change reduces the stale-snapshot window; it does not prove that concurrent manual/EA TP changes are impossible.

## Static verification performed

Checks were run against the fetched post-remediation source:

- A repeatable static-check script was added at `tools/audit_static_checks.py` and wired into `.github/workflows/mql5-static-audit.yml`.
- GitHub Actions run `37925518037` completed with **success** on workflow commit `0924bba5beae1392b31df82af3ee8cdaa7812904`. The job log shows all nine structural guardrails passed and explicitly reports SL arbitration and all runtime/build/legal checks as still open. This run validated the script and source state at that workflow commit; later report-only commits do not alter the source or script.

- Delimiter/comment/string lexical balance: **PASS** (no unmatched braces, brackets, parentheses, or unterminated comments/literals).
- `trade.OrderDelete(...)` write sites: **1**.
- `trade.PositionModify(...)` write sites: **1**.
- Shared directional-volume guard definition: **1**.
- Guard call sites: **4**, covering all four order-creation families listed above.
- Rollback source-to-comment matching: **PASS** for automatic, manual, and hedge creator tags.
- Delete-writer expiry revalidation present: **PASS**.
- Fresh position TP snapshot check present: **PASS**.
- Source size after final rollback-tag correction: approximately 290 KB / 8,796 lines; re-fetch the exact blob before release and freeze its raw SHA-256.

These are static structural checks only. They are not a substitute for MetaEditor, Strategy Tester, demo, or broker integration testing.

## Root causes still open

1. **SL proposal arbitration:** `STB_SubmitPositionSL` still passes one proposal at a time to `STB_ResolvePositionSL`; no complete same-cycle collection/arbitration across initial protection, profit protection, and trailing was established. Do not mark this item closed.
2. **Cross-event/cross-instance behavior:** per-cycle write deduplication does not by itself prove no duplicate request across `OnTick`, `OnTimer`, restarts, or multiple EA instances.
3. **Build provenance:** the exact post-remediation source has not been compiled into a newly hashed EX5 with a recorded MetaEditor/toolchain version and raw compile log.
4. **Dependency/package provenance:** the backup ZIP has not been extracted and independently inventoried; ALGLIB presence in the repository alone does not establish whether the distributed package uses or ships it. License and attribution review remains open.
5. **Runtime behavior:** no Strategy Tester, demo, reconnect/restart, partial-fill, multi-EA, netting/hedging, or broker-specific validation has been run.
6. **Independent review:** no independent qualified code review has signed off on the trading-safety changes.

## Required acceptance before release

- Compile this exact source blob in the intended MetaEditor/compiler version; preserve raw log, exit code, warnings, and build settings.
- Run the order creation matrix for all four paths, including directional exposure already at/near the broker limit, positions plus pending orders, foreign/manual orders, and concurrent exposure changes.
- Run delete-policy tests for fresh rollback, stale ticket, wrong source, foreign ticket, manually overridden pending, server expiry, and local-age expiry.
- Run SL/TP conflict tests with manual TP edits immediately before modification; verify that conflicts abort and that no TP is overwritten.
- Exercise SL proposal ordering/arbitration and event ordering across tick/timer/trade-transaction events.
- Run restart/reconnect, partial-fill, netting and hedging tests on a demo account.
- Freeze source and EX5 hashes; review the complete distributable package and dependency licenses/attribution.
- Obtain independent review before any production release.

## Final decision

**The code has been upgraded in three bounded safety areas, the creator-specific rollback-tag policy was cross-checked against the actual order comment strings, and static structural checks passed. The overall product is not yet confirmed as a verified final release. Release remains blocked until the open items and acceptance suite above are completed.**
