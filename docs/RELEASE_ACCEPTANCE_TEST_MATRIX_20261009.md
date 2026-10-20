# Release Acceptance Test Matrix — SmartTradingBot FINAL
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`
Scope: test plan for the current source; this document records required tests, not tests already executed.

## Release rule

Do not label the build production-ready until the exact source revision has a recorded successful MetaEditor compile, the applicable Strategy Tester suite passes, demo-account scenarios pass on each supported account mode, and source-to-EX5 provenance plus dependency/license review are documented. Static CI success alone is insufficient.

## A. Build and artifact provenance — release blockers

| ID | Scenario | Procedure / evidence required | Expected result | Status |
|---|---|---|---|---|
| BLD-01 | Exact-source compile | Compile the current source Git blob `6bca33bc8e0c961f317b0828e46faf7a6b9929b4` (Git blob ID, not raw-file SHA-256) using the supported MetaEditor build; archive full log and compiler version | 0 errors; all warnings reviewed and dispositioned | NOT RUN |
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

- [ ] Exact source commit and raw-file SHA-256 (current Git blob ID: `6bca33bc8e0c961f317b0828e46faf7a6b9929b4`)
- [ ] MetaEditor version/build and complete compile log
- [ ] EX5 SHA-256 and source-to-binary provenance manifest
- [ ] Strategy Tester configuration, data range, modelling mode, report and journal
- [ ] Demo account type, broker/server, symbol specification and observed logs
- [ ] Pass/fail result for every applicable test ID, with defect links
- [ ] Dependency/include inventory and license/attribution review
- [ ] Independent review sign-off and explicit release decision

## Current evidence summary

- Current source blob: `6bca33bc8e0c961f317b0828e46faf7a6b9929b4` (Git blob identifier, not raw-file SHA-256).
- Verified static CI run `37950552410`: **SUCCESS**, 26 static checks passed, including the partial-exit lock-state lifecycle guard. The run checks source structure only.
- The cycle-scoped candidate queue and per-ticket flush are present, with shared tick snapshot validation, deterministic tie-break, allocation-failure handling, producer write boundaries, and confirmation of a nonzero live SL.
- The resolver now enforces the active profit-lock floor, uses a deterministic no-SL fail-safe fallback where appropriate, and the flush only credits saved lock state after the actual SL meets the normalized lock target.
- Functional tests for SL-01 through SL-12 remain **NOT RUN**; static checks do not execute the MQL resolver or prove runtime behavior.
- The position-modify recheck narrows the stale-TP window but is not an atomic compare-and-swap.
- MetaEditor compile, Strategy Tester, demo tests, exact-source EX5 provenance, and package/license review remain unverified.
- Release decision: **BLOCKED / NOT VERIFIED**.


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
| UNIV-01 | Manual/mobile universal management | Create positions/pending orders from phone, terminal UI and EA on symbols not currently selected in Market Watch | Manager subscribes to exposure symbols, obtains the symbol lease, and adds missing protection independent of EA entry AUTO; existing SL/TP are preserved/tightened only under the documented rules | NOT RUN |
| UNIV-02 | Internal AUTO vs terminal permission | Disable the EA's internal AUTO while the terminal's global Algo Trading remains enabled; separately disable global Algo Trading | Internal AUTO disables new EA entries but exposure management remains enabled; global terminal trading permission may block broker modifications and is reported rather than bypassed | NOT RUN |

## Current branch checkpoint — 2026-10-20

- Production main remains at baseline commit `578621216f2f62ade33ab8e341a506e253b22bbf`. Source work is confined to `fix/structure-first-fvg-trailing-20261020`.
- Latest source-code commit: `ea67c43b92cb5b9c65ee7d170de7795561f37672`; source Git blob `40adb7effcdb024be04dd4ecea2048a02d30f0de`; pending-trail include blob `b45952dcb34f854dadfa4059473402ea74b96e41`.
- MetaEditor compile: **0 errors, 0 warnings** ([run 39455177457](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457)); fresh EX5, compiler log and provenance manifest ([artifact 12280695788](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177457/artifacts/12280695788)).
- Provenance: source SHA-256 `EC95BAE59896D1E8227F87A71D299720A8A3571045BEFD4EEEB0A4B3C7B3A259`; EX5 SHA-256 `99229960CD83699225ED6318791B4BB2929CA580AA7B0283130DF4252243B602`; MetaEditor `5.0.0.6274`.
- Static source/invariant audit passed ([run 39455177088](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177088)); trading safety defaults passed ([run 39455177310](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39455177310)).
- The compile artifact is a CI test artifact, not a terminal deployment. Scanner tests SCN-03 through SCN-08 and all Strategy Tester/out-of-sample/demo gates remain NOT RUN. Release decision remains **BLOCKED / NOT VERIFIED**; do not copy this source/EX5 to the active terminal or merge to main before the functional release gates pass.
