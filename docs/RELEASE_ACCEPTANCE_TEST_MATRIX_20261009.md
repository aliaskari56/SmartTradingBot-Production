# Release Acceptance Test Matrix — SmartTradingBot FINAL
Date: 2026-10-21
Branch: `fix/structure-first-fvg-trailing-20261020`
Scope: test plan for the current source; this document records required tests, not tests already executed.

## Latest CI verification (2026-10-21)

Latest branch commit at verification time: `e8faa080a4742e4666ede2da3c60eab4763a0865`. All three required CI workflows completed successfully on this commit: MetaEditor compile run `39535710438` (MetaEditor `5.0.0.6274`, 0 errors/0 warnings, 3390 ms; artifact ID `12317348477`), static audit run `39535710529`, and trading-safety-defaults run `39535710556`. Downloaded artifact ZIP digest independently matched the GitHub artifact digest; archive contains only `provenance.json`, `SmartTradingBot_FINAL.ex5`, and `SmartTradingBot_FINAL.compile.log`. Source code was unchanged by this documentation-only commit; these checks do not resolve the runtime test blockers or `LRN-04`.

## Release rule

Do not label the build production-ready until the exact source revision has a recorded successful MetaEditor compile, the applicable Strategy Tester suite passes, demo-account scenarios pass on each supported account mode, and source-to-EX5 provenance plus dependency/license review are documented. Static CI success alone is insufficient.

## A. Build and artifact provenance — release blockers

| ID | Scenario | Procedure / evidence required | Expected result | Status |
|---|---|---|---|---|
| BLD-01 | Exact-source compile | Compile exact branch revision `e8faa080a4742e4666ede2da3c60eab4763a0865` using MetaEditor 5.0.0.6274; retain compiler log and provenance artifact | 0 errors, 0 warnings; confirmed by workflow run `39535710438` | PASS — CI COMPILE |
| BLD-02 | Artifact provenance | Retain workflow artifact `metaeditor-build-e8faa080a4742e4666ede2da3c60eab4763a0865` (artifact ID `12317348477`) containing compiler log, EX5 and `provenance.json`; independently inspect manifest hashes before release | ZIP SHA-256 `0887ec4d6a8089220b3aa15776e5c1de63e6c7f8a88ac515bc13083dd0addc82` matches GitHub artifact digest; EX5 SHA-256 `DD973F94CCDD2E1104233F9954C688F086FB9B49FF24873E4DBBE908A3A16C13` matches manifest; source SHA-256 `66E30E79D5ED15CCD970AAE5534F603A52A319F30473EA0C568439107F1A8E60`; manifest commit/compiler match workflow | PASS — ARTIFACT INTEGRITY CHECKS |
| BLD-03 | Include closure | Resolve every `#include` transitively; inventory source, origin, version and license for shipped dependencies | Source-level closure is enumerated; origin, license and redistribution terms for every component are evidenced and reviewed | SOURCE CLOSURE TRACED — LICENSE REVIEW OPEN |
| BLD-04 | Package audit | Extract and inspect CI artifact ZIP; separately assemble and inspect intended release package with applicable notices | CI artifact contains exactly provenance.json, compile log and EX5, with no extra files; intended distributable release package and notices are separately reviewed | CI ARTIFACT INSPECTED — RELEASE PACKAGE NOT ASSEMBLED/REVIEWED |

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
| DEL-09 | Expiry writer ownership gate | Request expiry while another chart owns the symbol lease or ownership is stale; compare with the valid owner | Final writer rejects wrong-source/unverified-owner requests; eligible expiry succeeds only through the managed owner | NOT RUN |

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
| SL-12 | Active +50/+20 profit-lock floor under contention | For BUY and SELL, reach the +50-pip net-profit trigger while trailing/initial proposals compete; set stop/freeze geometry so the normalized +20-pip target fails validation. Repeat with an installed SL and with no SL | An installed SL is never replaced by a weaker-than-+20 automatic proposal. Lock-pips state is not credited unless the verified actual SL meets the target. With no SL, the strongest valid non-profit-lock candidate may be used as an emergency stop but must not be recorded as a completed +20-pip lock | NOT RUN |

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

- [ ] Exact source commit and raw-file SHA-256, verified against the provenance manifest for the exact source revision under review
- [ ] MetaEditor version/build and complete compile log
- [ ] EX5 SHA-256 and source-to-binary provenance manifest
- [ ] Strategy Tester configuration, data range, modelling mode, report and journal
- [ ] Demo account type, broker/server, symbol specification and observed logs
- [ ] Pass/fail result for every applicable test ID, with defect links
- [ ] Dependency/include inventory and license/attribution review
- [ ] Independent review sign-off and explicit release decision

## Current evidence summary — refreshed 2026-10-21

- Current exact source revision: `79e5f892a906b9f07270ef59afc9964fc4f3aae1`; working branch: `fix/structure-first-fvg-trailing-20261020`. The primary EA remains `MQL5/Experts/SmartTradingBot_FINAL.mq5`.
- Latest overall commit `1bdabe0137331f99f80d84587867b99a391e0e8a` changes documentation only; the primary EA source and include files are unchanged from `79e5f892a906b9f07270ef59afc9964fc4f3aae1`. A fresh MetaEditor workflow run `39535400589` on that latest commit completed **SUCCESS** using MetaEditor `5.0.0.6274`, with **0 errors and 0 warnings** (5332 ms). Build artifact `metaeditor-build-1bdabe0137331f99f80d84587867b99a391e0e8a`, ID `12316444523`; GitHub artifact ZIP SHA-256 `07601bce9900eefb96e1634095973879c7b5b2e173d81440ba3a6e7bc235b0b8`, independently matched after download. Its `provenance.json` matches commit `1bdabe0137331f99f80d84587867b99a391e0e8a`, compiler `5.0.0.6274`, source SHA-256 `66E30E79D5ED15CCD970AAE5534F603A52A319F30473EA0C568439107F1A8E60`, and EX5 SHA-256 `B724106BB8C3C4FE2D074E7FCB188E1ED100B13AE2B144594955443568FB16B9`. Artifact contents are exactly `provenance.json`, `SmartTradingBot_FINAL.compile.log`, and `SmartTradingBot_FINAL.ex5`.
- MetaEditor workflow run `39534764998`: **SUCCESS**, MetaEditor 5.0.0.6274, **0 errors and 0 warnings** (compile log reports 5514 ms). The log confirms compilation of `SmartTradingBot_FINAL.mq5` and its included dependencies.
- Exact-revision build artifact: `metaeditor-build-79e5f892a906b9f07270ef59afc9964fc4f3aae1`, artifact ID `12316433503`; includes compiler log, EX5, and `provenance.json`. Artifact ZIP SHA-256: `f0140a0f19f951774b19591ec0545664f116f51066d19c977d9976bbab676be9`; this matches the artifact digest reported by GitHub. EX5 SHA-256 `38B184E745786EEC73D16625095F19CCE50BCA88983B7393D3B5F4808CDE91C0` matches the manifest. The manifest source SHA-256 `66E30E79D5ED15CCD970AAE5534F603A52A319F30473EA0C568439107F1A8E60` independently matches the source file fetched from the exact commit after normalizing LF checkout content to Windows CRLF, consistent with the Windows MetaEditor build environment. Manifest commit and compiler version match the workflow run. ZIP contents are exactly `provenance.json`, `SmartTradingBot_FINAL.compile.log`, and `SmartTradingBot_FINAL.ex5`.
- Static audit run `39534765097`: **SUCCESS**. Trading safety-defaults run `39534764966`: **SUCCESS**. The latest commit adds static assertions for trade-transaction intake failure paths, position handoff on exposure-allocation failure, partial-close lock-state lifetime, and pending-trail fill transition ordering. These are source-level checks, not functional tests.
- The current build is newer than the previously recorded `12380f2aa7c34ae23ca02ce8728e6fb9c528a7b5` checkpoint. Do not treat the old checkpoint as the current compiled source.
- Latest lifecycle ordering change: on a newly detected M15 bar, `OnTick()` calls `STB_ReconcileTradeRegistry()` before `STB_RunManagementCycle()`; the static audit explicitly checks this order. This reduces recovery latency in the code path but does not prove terminal runtime behavior.
- Pending-trail retry, partial-fill handoff, registry reconciliation, scanner quote validation, final scanner-to-manager checks, and fallback-candidate confidence guard have static assertions. Their runtime behavior remains unproven.
- Functional tests for SL-01 through SL-12, EVT-01 through EVT-07, SCN/TRL/PTRL cases, Strategy Tester regression, demo lifecycle, include/license review, and package inspection remain **NOT RUN or NOT VERIFIED** as indicated by their individual rows.
- Adaptive-learning close-event idempotency is a confirmed code-review finding: the OUT/OUT_BY path adds the current deal PnL to accumulated position PnL before checking whether the position remains open; a repeated processing of the same final close after the accumulator has been consumed can record the same close again. INOUT similarly consumes accumulated PnL and records the reversal outcome without a durable per-deal idempotency key. No speculative marker-only patch was applied because a crash between marker/state/stat updates can itself lose or duplicate learning outcomes. The proposed write-ahead journal, deterministic target-state replay, recovery protocol, and fault-injection cases are documented in `docs/LRN_04_CRASH_CONSISTENT_DESIGN.md`; this is a design artifact only, not a code fix or test result. LRN-04 remains open.
- The position-modify recheck narrows the stale-TP window but is not an atomic compare-and-swap.
- Release decision: **BLOCKED / NOT VERIFIED**. Do not merge to `main` or treat the compiled artifact as production-approved.
## H. Structure-first strategy upgrade — added 2026-10-20

All rows below are **functional tests**. Passing CI compilation or static string/invariant checks does not satisfy any row in this section.

| ID | Scenario | Procedure | Expected result | Status |
|---|---|---|---|---|
| HTF-01 | Closed-bar/no-lookahead timing | Replay an H1 FVG/OB while the H1 candle is forming; compare before and after the relevant H1 candle closes relative to the M15 decision timestamp | No setup uses an H1 candle/zone that was not confirmed by the decision timestamp | NOT RUN |
| HTF-02 | FVG age and mitigation | Present fresh, stale, untouched, partly mitigated and fully mitigated bullish/bearish FVGs | Only zones meeting age and mitigation rules qualify; rejection reason identifies the failed condition | NOT RUN |
| HTF-03 | Order Block structural validation | Present an opposite candle followed by displacement that does and does not close beyond the last already-confirmed H1 swing | Only a directional displacement with a confirmed pre-impulse swing break can qualify as OB | NOT RUN |
| HTF-04 | Zone confluence | Test H1 FVG/OB and M15 origin zones inside and outside the ATR-normalized max gap | Directionally valid, fresh zones inside the threshold may pass; missing or distant zones reject | NOT RUN |
| ENT-01 | Hard entry gates | Test H4 trend aligned, opposite, unavailable; local M15 FVG/OB present/absent | H4 alignment and configured FVG/OB hard gates cannot be bypassed by a high score or oscillator bonus | NOT RUN |
| ENT-02 | Stale setup rejection | Hold a valid M15 BOS/CHoCH beyond the configured 4-bar maximum before final revalidation | Stale setup is rejected deterministically and cannot become a late pending entry | NOT RUN |
| SCN-01 | Relative spread cap | Replay spread-to-M15-ATR values just below, equal to and above InpMaxRelativeSpreadPct | Above-limit cases reject before ranking with REJECT_RELATIVE_SPREAD; the cap is logged and finite/range-validated | NOT RUN |
| SCN-02 | Scanner funnel and diagnostics | Exercise stale quote, missing history, unusable regime, excessive spread, score rejection and clean candidate | Funnel counters and reject reasons agree with each intentionally induced condition | NOT RUN |
| SCN-03 | Quote integrity: crossed/non-finite/future/stale | Exercise missing/non-finite/non-positive bid or ask, ask < bid, unavailable clock, future-dated quote beyond the allowed 2-second skew, and stale quotes in both eligibility and market-quality paths | Reject with a specific reason; invalid quotes cannot reach ranking or produce a positive quality score | NOT RUN |
| SCN-04 | Top-N does not bypass competition gap | Provide at least two fully revalidated candidates below the required score gap; run with InpScannerTopN=1 and then TopN>=2 | Confidence is WEAK in both configurations; no candidate submission from a score-only pass | NOT RUN |
| SCN-05 | Single-candidate policy | Test zero valid candidates, one valid candidate below the score floor, and one candidate at/above the score floor | Zero => NO_CLEAR_WINNER; below floor => WEAK; one candidate meeting floor may be CLEAR because no runner-up exists | NOT RUN |
| SCN-06 | Runner-up threshold boundary | Test two valid candidates with score gaps just below, exactly at, and above InpScannerMinTopGap | Below => WEAK; equal/above => CLEAR when the top score meets InpScannerMinScore | NOT RUN |
| SCN-07 | Final revalidation changes the shortlist | Make a high-ranked candidate fail final data/quality/setup revalidation, leaving two or more valid candidates | Invalid candidate is absent from final watchlist; gap is computed from remaining fully revalidated/reranked candidates | NOT RUN |
| SCN-08 | Valid-quote regression | Run frozen baseline and candidate on identical data/settings with only valid quotes | Valid-quote candidate/order decisions and financial results remain identical except for the documented Top-N gap correction; reconcile deal history | NOT RUN |
| TRL-01 | Structural BUY trailing | Move price by less than and more than activation ATR, then form/confirm new M15 swing lows | No activation before threshold; only confirmed valid swing lows can tighten SL; SL never widens | NOT RUN |
| TRL-02 | Structural SELL trailing | Repeat TRL-01 with swing highs | Only confirmed valid swing highs can tighten SL; SL never widens | NOT RUN |
| TRL-03 | Trail broker rejects | Force/encounter stop-level, freeze-level, market-closed and transient retcode cases | Failed attempts log retcode, reconcile actual state, consume the per-cycle write budget, and retry according to bounded policy | NOT RUN |
| PTRL-01 | BUY STOP same-bar retry | Force the M5 BUY STOP modify to fail on an actionable bearish closed bar, then allow a later retry with the same bar still the latest closed bar | Failed attempt does not consume the actionable bar; retry succeeds or records a bounded explicit reason | NOT RUN |
| PTRL-02 | SELL STOP same-bar retry | Repeat PTRL-01 with bullish bar and SELL STOP | Same-bar retry semantics work in the opposite direction | NOT RUN |
| PTRL-03 | Pending lifecycle while backing off | Cancel or trigger an order during retry backoff | Ticket absence/type/ownership is rechecked before backoff; no stale ticket is modified and lifecycle state is cleaned | NOT RUN |
| TP-01 | Position missing TP | Open a managed position with valid SL and TP=0; test a qualifying M15 swing and no qualifying swing | EA sets the nearest swing target meeting base RR or a logged RR fallback; explicit TP is untouched | NOT RUN |
| TP-02 | Pending missing TP | Create each supported BUY/SELL STOP, LIMIT and STOP-LIMIT order with SL and TP=0 | A broker-valid TP is added through the shared pending geometry writer; unsupported/invalid geometry is reported and retried safely | NOT RUN |
| TP-03 | SL and TP simultaneously absent | Create a managed position without SL or TP; observe the first and subsequent management cycles | SL arbitration and TP repair occur without two uncontrolled writes in one cycle; an eligible SL improvement can include the absent TP in the same verified request | NOT RUN |
| TP-04 | Existing TP preservation | Set an explicit position/order TP, then run automatic management and trailing | EA does not replace or erase explicit TP; only TP=0 is eligible for automatic initialization | NOT RUN |
| TP-05 | Snapshot/race/retcode | Change TP externally around an automatic SL change and exercise a failed position modify | Snapshot change aborts stale request; one central PositionModify writer is used; server retcode and resulting SL/TP are verified | NOT RUN |
| LRN-01 | AP2/AP3 isolation | Start with legacy AP2 terminal global variables and start the upgraded EA | AP3 state is used; old profile statistics cannot leak into the new strategy definition | NOT RUN |
| LRN-02 | Valid R denominator | Close trades with known/unknown initial risk, including break-even | Only finite R with a valid initial-risk denominator contributes to RCOUNT/R expectancy; break-even contributes a neutral half-win/half-loss and R=0 only when risk is known | NOT RUN |
| LRN-03 | Adaptive attribution/out-of-sample | Verify entry comment, position profile, initial monetary risk, partial exits, full closes/reversals; compare fixed profile against adaptive profile on held-out dates | Outcomes map to the correct profile/lifecycle; results are reported in R with sample counts; no profile is called better from in-sample ranking alone | NOT RUN |
| LRN-04 | Duplicate/replayed close-deal idempotency | Deliver or simulate repeated processing of the same OUT/OUT_BY/INOUT deal, including after a completed close and across terminal restart; inject interruption at every persistence boundary. Design and required cases: `docs/LRN_04_CRASH_CONSISTENT_DESIGN.md` | A deal ticket contributes exactly once to lifecycle PnL and adaptive statistics; recovery neither double-counts nor loses a close. Do not approve until crash-consistent implementation and repeatable tests exist | CODE REVIEW FINDING — DESIGN DOCUMENTED; NOT FIXED / NOT RUN |
| UNIV-01 | Manual/mobile universal management | Create positions/pending orders from phone, terminal UI and EA on symbols not currently selected in Market Watch | Manager subscribes to exposure symbols, obtains the symbol lease, and adds missing protection independent of EA entry AUTO; existing SL/TP are preserved/tightened only under the documented rules | NOT RUN |
| UNIV-02 | Internal AUTO vs terminal permission | Disable the EA's internal AUTO while the terminal's global Algo Trading remains enabled; separately disable global Algo Trading | Internal AUTO disables new EA entries but exposure management remains enabled; global terminal trading permission may block broker modifications and is reported rather than bypassed | NOT RUN |

## Historical branch checkpoint — 2026-10-20 (superseded by the refreshed evidence summary above)

- Production `main` remains at `578621216f2f62ade33ab8e341a506e253b22bbf`. All changes are confined to `fix/structure-first-fvg-trailing-20261020`; nothing was merged to `main` or deployed to the active terminal.
- Latest source-code commit: `5b14166acb84c367bb02b4616a348c0816ab4cc8`; source blob `c8a09e3a05f7ac8aea37ccd421a7aa1012191ffd`.
- MetaEditor compile: **0 errors, 0 warnings** ([run 39457211695](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211695)); fresh EX5/compiler log/provenance: [artifact 12280118878](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211695/artifacts/12280118878).
- Provenance: source SHA-256 `E8AAA1DAD0C3914837D915718D91D4A73D230E6A52EBC1210BB42BBB8E453BC8`; EX5 SHA-256 `7B9DC581BDD9A4091147C9208F652B7E8FABFEB0B0977D6BECD65000DEFCFDAD`; MetaEditor `5.0.0.6274`.
- Static source/invariant audit passed ([run 39457211171](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211171)); trading safety-default checks passed ([run 39457211930](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39457211930)).
- The compiled artifact is a CI test artifact only. Scanner cases SCN-01–SCN-08, structure cases STR-07–STR-12, Strategy Tester, out-of-sample and demo gates remain NOT RUN. Release status remains **BLOCKED / NOT VERIFIED**.


## I. M15 structure-trigger validity — required before release

| ID | Scenario | Procedure | Expected result | Status |
|---|---|---|---|---|
| STR-07 | Fresh BOS crossing, not persistent state | Replay a bullish/bearish pivot with (a) prior close on the original side and current closed bar across it, (b) multiple closes already beyond the level, and (c) a return across then a genuine re-cross | Only the actual close-crossing bar qualifies as a fresh break; sustained closes beyond an old pivot cannot refresh setup age or produce repeat setups; a later genuine re-cross may qualify if all other filters pass | NOT RUN |
| STR-08 | Structure window boundary | Set InpStructureWindowBars at and beyond the available rates-array boundary | No out-of-range access; scan is bounded to bars with a valid immediately older closed bar | NOT RUN |
| STR-09 | CHoCH/BOS semantic distinction | Replay a genuine M15 trend reversal that produces CHoCH then a separate continuation BOS, plus a single-break-only case | Record whether strategy requires both events. Current detector validates one fresh structure break; it does not independently prove a two-event CHoCH-then-BOS sequence. Strategy acceptance requires this policy to be made explicit before release | NOT RUN |

| STR-10 | Strategy-score saturation | Use a fixture with H4 alignment, fresh structure break, RR ≥ 2, FVG+OB, and confirmed default RSI/CCI; record raw component sum and final score distribution across candidates | Saturation/clipping rate is measured; any revised scoring formula is a separate frozen-baseline experiment, not an untested in-place weight change | NOT RUN |
| STR-11 | H4 versus universal-mode precedence | Test all combinations of InpRequireH4TrendAlignment and InpAllowUniversal with aligned, misaligned, and unavailable H4 structure | Observed accept/reject behavior matches the documented precedence; source default semantics are explicitly approved before changing either input | NOT RUN |
| STR-12 | Adaptive profile vs fixed profile | Same symbols, period, data model, costs, deposit and risk settings: compare profile 0 fixed against adaptive selection; attribute outcomes by profile/direction and then repeat out-of-sample | Report trades, expectancy in R, PF, drawdown, score distributions and uncertainty; adaptive mode is not declared better from in-sample ranking alone | NOT RUN |
