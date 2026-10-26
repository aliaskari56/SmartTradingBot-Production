# SmartTradingBot source audit — 2026-10-26

## Scope

Audited the GitHub candidate `MQL5/Experts/SmartTradingBot_FINAL.mq5` on branch `fix/closed-deal-net-result-diagnostics-20261026` (13,333 lines; 275 detected function definitions). Reviewed the trade-risk guard, volume sizing, broker volume normalization, pending-order geometry and writer ownership, spread gates, structure/FVG/OB scan path, adaptive tester objective, trade-transaction accounting, startup controls, and the tick/timer management cycle. Static pattern checks are supporting evidence only; they are not a substitute for semantic review or Strategy Tester validation.

## Source changes in this candidate

1. **Broker volume-step normalization:** derive decimal precision from `SYMBOL_VOLUME_STEP`, verify the normalized volume lies on the broker's step grid, and fail closed when it cannot be represented.
2. **Pending-trailing writer ownership:** non-owner chart instances return before evaluating/modifying a pending-trail proposal, avoiding false writer failures and wasted retry budget.
3. **Realized result diagnostics:** log each exit/partial-exit deal with gross P/L, commission, swap, fee, and cumulative position net-to-date.
4. **Tester optimization ranking:** require at least 30 trades and positive net profit, profit factor above 1, and positive expected payoff before a pass can receive a normal optimization score. This corrects the prior score's ability to rank a negative-return pass using a smaller negative stability multiplier. This is an optimization-ranking guard only; it is not a live-entry filter and does not establish out-of-sample edge.
5. **Clean-source packaging and hash manifest:** package source and repository include dependencies without EX5, settings, logs, credentials, or terminal data.

## Findings that must not be “fixed” by guessing

- `InpMaxSpreadPips` and `InpMaxRelativeSpreadPct` default to zero, which disables their respective hard caps. This is a material execution-cost exposure on a multi-asset scanner, but setting a universal cap without per-symbol cost/ATR and out-of-sample tests could block all candidates or change the system's trade distribution. Validate candidate caps per symbol and session before changing defaults.
- The saved test evidence in project context shows XAUUSD+ has a positive in-sample baseline, while EURUSD+ OOS is negative. Do not label EURUSD+ profitable or turn on optional risk-normalized protection without new independent OOS evidence.
- No static code scan can prove profitable expectancy. Do not increase risk, loosen daily loss controls, bypass broker checks, remove UI actions, or change SL/TP/trailing policy solely to improve a single backtest.

## Validation gate

The exact candidate must pass:
1. MetaEditor compile with 0 errors and 0 warnings.
2. Repository static checks, trading-safety-default checks, journal contract tests, and clean-source package verification.
3. Same-settings regression against the known XAUUSD+ baseline (trade count, PF, net P/L, equity DD, expectancy, Sharpe, order rejects, and pending-trail changes).
4. OOS testing across multiple periods and symbols, including costs/commission/swap and realistic spread/slippage; reject configurations that only improve the optimization interval.
5. Manual UI checks for all eight buttons, AUTO state, manual pending placement, SAVE +20, hedge controls, and pending BUY_STOP/SELL_STOP trailing.
6. Demo-forward validation before any live deployment.

## Status

This is an engineering audit and a candidate source change, not a profitability certification. Compilation/static checks cannot replace the Strategy Tester, UI, and demo gates above.
