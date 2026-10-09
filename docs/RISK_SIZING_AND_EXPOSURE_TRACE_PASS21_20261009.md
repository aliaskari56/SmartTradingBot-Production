# Pass 21 — Risk Sizing and Exposure Boundary Trace (2026-10-09)

## Status and scope

**Overall status: DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN.**  
This is a static source trace, not a financial-risk certification, compile result, or behavioral test. No executable source changed.

Primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`  
Verified Git blob SHA: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`  
Verified line count: 8,665.

Reviewed regions include `NormalizeVolume` (around line 1510), setup geometry/risk checks (around 2210), `CalculateOrderVolumeByRisk` (around 5956), strategy placement volume checks (around 6061), manual pending creators (around 6434 and 6531), input validation (around 7810), and hedge placement (around 3929).

## Static observations

### RS-01 — Risk-based sizing is opt-in, not the default

- `InpUseRiskSizing` defaults to `false` (line 52).
- The strategy setup placement path uses `CalculateOrderVolumeByRisk(s)` only when that input is enabled (around line 6061).
- When disabled, that path uses `InpBaseLots` multiplied by either `InpTrendLotMultiplier` or `InpUniversalLotMultiplier`.
- This means the presence of a risk-sizing function does not mean the default configuration sizes each strategy setup to a fixed percentage of equity.

**Required disposition:** Confirm the intended deployment configuration and document whether fixed-lot or risk-based sizing is the approved mode. Test both branches explicitly. Do not describe the bot as using percentage-risk sizing unless the exact runtime configuration enables it and tests verify it.

### RS-02 — Risk calculation is based on estimated entry-to-SL loss

`CalculateOrderVolumeByRisk` obtains account equity, calculates `riskMoney = equity * InpRiskPercent / 100`, and uses `OrderCalcProfit` for a one-lot move from the setup entry to its SL. It rejects invalid/non-positive results and rejects volume below broker minimum rather than silently rounding it upward. `InpMaxRiskVolume`, when positive, caps the computed volume.

This is a useful sizing control, but static inspection alone does not establish realized loss at the final fill. Price gaps, slippage, commissions/fees, swap, execution changes, and stop execution behavior need separate treatment in test assumptions and residual-risk documentation.

**Required disposition:** Specify whether the configured risk percentage is a pre-trade estimate or a hard loss limit. Record costs and gap/slippage assumptions. Test failed `OrderCalcProfit`, zero/invalid SL, volume below minimum, volume step rounding, and configured volume cap.

### RS-03 — Explicit direction-volume limit is visible in the strategy setup path only

The strategy placement path checks `SYMBOL_VOLUME_LIMIT` against `DirectionExposureVolume(symbol, direction) + volume` around lines 6079–6086. A text scan of the primary source found these call sites only in that strategy path.

The manual pending stop and limit creation functions independently derive volume from `InpBaseLots` and do not visibly call the same `DirectionExposureVolume` guard in the inspected paths. This is a scope inconsistency to verify against broker enforcement and all downstream checks, not proof that a broker limit can be bypassed.

**Required disposition:** Decide whether symbol-direction exposure limits must be enforced uniformly across strategy pending orders, manual pending stop/limit commands, and hedge commands. If so, define a shared preflight check and preserve emergency/rollback semantics. Add tests for an existing same-direction position plus pending orders and for boundary equality/overflow.

### RS-04 — Manual pending orders do not visibly use the percentage-risk sizing helper

`PlaceManualPendingDirection` and `PlaceManualLimitDirection` each normalize `InpBaseLots` directly. The source contains only one call to `CalculateOrderVolumeByRisk`, in the strategy setup placement branch. The manual functions calculate initial SL separately, so their risk per order may vary with the SL distance even when lots remain fixed.

**Required disposition:** Document manual-order sizing semantics. If manual order sizing is intentionally fixed-lot, expose that clearly in the UI/logs and test the widest supported SL distances. If risk-based sizing is intended for manual commands too, design that as an explicit change and test it separately; do not silently change current behavior during an unrelated fix.

### RS-05 — Input validation is not equivalent to risk-policy validation

The inspected input validator rejects negative `InpRiskPercent` and `InpMaxRiskVolume`, but permits `InpRiskPercent == 0`. When risk sizing is enabled, the sizing helper then returns zero and the strategy placement path rejects the setup as `RISK_VOLUME_INVALID`. This appears fail-closed for that path, but the configuration combination can disable all risk-sized strategy placements without an obvious startup-level configuration error.

**Required disposition:** Decide whether enabling risk sizing with a zero percentage should produce a clear initialization/configuration error. Add a configuration matrix covering disabled sizing, enabled with zero risk, valid risk, negative risk, and cap below broker minimum.

### RS-06 — No account-wide loss circuit breaker established by this trace

This focused trace did not establish a dedicated account-wide daily-loss, maximum-equity-drawdown, or aggregate open-risk circuit breaker. This is a bounded finding about the inspected primary-source paths, not proof that no relevant control exists anywhere in all included dependencies.

**Required disposition:** The release owner must state whether such a circuit breaker is a requirement. If required, inventory every exposure-increasing path and define a centralized fail-closed policy, reset/time-zone semantics, restart persistence, manual-command behavior, and safe handling of already-open exposure. Test threshold crossing, restart, clock/day rollover, rejected close requests, and multiple charts.

## Focused acceptance tests

| Test ID | Scenario | Expected evidence |
|---|---|---|
| RSK-01 | Risk sizing disabled | Strategy path uses fixed-lot branch; logged configuration is captured |
| RSK-02 | Risk sizing enabled with valid equity, SL, and percentage | Computed volume and `OrderCalcProfit` estimate recorded and independently recalculated |
| RSK-03 | Risk sizing enabled with zero percentage | Setup is rejected; behavior is explicit and diagnostic |
| RSK-04 | Estimated risk volume below broker minimum | No upward clamp into a larger trade |
| RSK-05 | Volume step/max and `InpMaxRiskVolume` boundaries | Result never exceeds configured cap or broker constraints |
| RSK-06 | Strategy order at `SYMBOL_VOLUME_LIMIT` boundary | Correct accept/reject and exposure snapshot |
| RSK-07 | Manual pending order with existing directional exposure | Actual intended policy is verified for stop and limit commands |
| RSK-08 | Hedge command while source exposure and pending exposure coexist | No unintended over-hedge; rejected/accepted volume and resulting exposure recorded |
| RSK-09 | Gap/slippage/cost scenario | Difference between estimated and realized loss documented |
| RSK-10 | Restart/multiple charts around any aggregate risk control | Persistence, duplicate prevention, and enforcement scope verified |

## Evidence and limitations

- The source contains a risk-sizing helper and several volume guards, but their existence does not establish realized risk bounds.
- This pass did not run MetaEditor, Strategy Tester, a demo account, or a broker simulation.
- The trace does not certify profitability, suitability, or safe deployment.
- No executable source was changed. Findings RS-01..RS-06 require explicit disposition and acceptance evidence before closure.
