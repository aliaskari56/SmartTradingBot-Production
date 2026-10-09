# Pass 23 — Decision on selective reuse of BrokerStructureScanner (2026-10-09)

## Decision

**Do not port the scanner wholesale, and do not replace the existing EA. Reuse only selected ideas after checking them against the existing implementation. Keep executable source unchanged in this pass.**

The source already contains several overlapping building blocks: configurable swing-left/right settings and adaptive profiles; `CollectSwings`; `GetH4Trend`; M15 structure detection; local ATR calculations; existing symbol-selection helpers; and a timer-driven scan/control path. Adding the submitted scanner as a second independent engine would duplicate logic and create two definitions of structure, score, symbol universe, and timing. That raises maintenance and consistency risk without demonstrated performance benefit.

This is a design decision based on static inspection, not a claim that either implementation is behaviorally correct or profitable.

## Existing implementation overlap observed

Primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`, blob SHA `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`, 8,665 lines.

| Scanner idea | Existing EA evidence found | Decision |
|---|---|---|
| Confirmed swing points | `CollectSwings` around line 2474; configurable/adaptive swing settings around lines 696–712 | Do not add a second pivot collector. Compare edge cases and tests first. |
| H4 trend from structure | `GetH4Trend` around line 2556 | Keep existing trend path as the source of truth unless a controlled comparison demonstrates a defect. |
| M15 structure/CHoCH/BOS | `DetectStructure` around line 2749 and callers | Do not replace it with a simpler two-pivot state label. |
| ATR | `LocalATR` around line 2849 and other callers | Do not create per-cycle iATR handles merely to duplicate this calculation. Validate semantic equivalence before any change. |
| ADX score | The focused source scan did not find an iADX/ADX implementation in the primary EA | Potential optional feature only; not justified for insertion until there is a clear decision use and a shadow-mode evaluation. |
| Multi-timeframe H4/H1/M15/M5 ranking | Existing paths focus on H4 trend and M15 structure; this scanner offers an extra cross-timeframe summary | Potentially useful as diagnostic/shadow-only metadata, not a new entry gate initially. |
| Broker symbol discovery | Existing symbol-selection and scan helpers are present around lines 1555, 6406, 7170 and 7193 | Reuse the existing universe/selection policy. Do not introduce unconditional broad SymbolSelect behavior. |
| Timer-driven work | Existing timer initialization around line 7971 and OnTimer around line 8256 | Do not add a second EventSetTimer or independent full-universe scan loop. Schedule any optional analysis through the existing lifecycle. |
| Ranking score | Existing setup/strategy scores and conditions exist | Do not mix scores with different meanings. If a scanner score is later retained, label it separately as a diagnostic feature. |

Line numbers are navigation hints for this source snapshot; they can shift after edits.

## What to reuse from the supplied code

1. **Closed-bar discipline:** use confirmed pivots and closed candles; never let an unfinished bar silently become a confirmed structural signal.
2. **Explicit validity status:** distinguish invalid/incomplete data from a genuine RANGE or low score. Do not convert missing indicator/history data into a neutral market state.
3. **Timestamped multi-timeframe result:** attach the last closed bar time to every timeframe result and reject stale values.
4. **Bounded work per cycle:** preserve a measured processing budget and avoid repeated work on every tick.
5. **Readable diagnostic output:** report per-timeframe state and data availability separately from execution decisions.

These are design patterns, not code copied into the EA. The supplied scanner's rank-before-sort issue, unused MinADXForTrend input, strict equality-based RANGE rule, incomplete numeric validation, and broad SymbolSelect side effects should not be copied.

## Proposed integration boundary

If further evidence supports a cross-timeframe diagnostic, implement it as a small read-only helper that consumes the EA's existing data/structure helpers where their contracts match. It must:

- have no order-send, order-modify, order-delete, or position-modify capability;
- not own or reset the EA's timer, symbol universe, adaptive state, or trading-cycle state;
- return a versioned result with symbol, timeframe, state, score/feature values, validity, and closed-bar timestamp;
- treat missing/stale data as invalid, not as RANGE or score zero without an explicit contract;
- remain disabled from affecting entry/exit decisions during shadow mode;
- be removable by a single feature switch if later enabled;
- not change current setup scoring, volume sizing, SL/TP, order ownership, or exposure controls in the initial integration.

## Evidence gates before any executable edit

- **G1 — Baseline:** capture exact source SHA, compile output, and existing tester results for the same environment.
- **G2 — Behavioral parity:** build deterministic tests for swing confirmation, tied highs/lows, equal pivots, missing history, and closed-bar timestamps.
- **G3 — Shadow comparison:** compare existing H4/M15 decisions with optional H1/M5 diagnostics without placing or modifying trades.
- **G4 — Performance:** measure worst-case cycle duration and history/indicator failures on the actual symbol universe.
- **G5 — Decision value:** define in advance which decision the added feature is expected to improve and evaluate it out of sample.
- **G6 — Review:** independent review of the diff and regression evidence before any feature is allowed to affect live decisions.

A missing artifact means BLOCKED or NOT RUN, never PASS. No source-to-EX5 provenance or release readiness is implied by this plan.

## Pass 23 status

- Chosen direction: selective reuse of engineering ideas; no wholesale port and no replacement.
- Executable source changed: no.
- Build/test/benchmark/demo evaluation: not run in this pass.
- Next concrete task: inspect and test the existing swing/H4/M15 helpers against the scanner's confirmed-pivot edge cases, then decide whether any implementation change is warranted.
- Overall audit status: `DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN`.
