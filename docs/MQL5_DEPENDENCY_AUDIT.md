# MQL5 Include Dependency Audit

## Scope

- Candidate source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
- Reviewed branch: `audit/expose-cleaned-source-20261009`
- Cleanup commit: `b13f1a22ce4e49a892c6372966e55e98ed00eae2`
- Method: recursively follow source-level `#include` directives from the primary EA and every reachable header; quoted includes resolve relative to the including header's directory and angle-bracket includes resolve from `MQL5/Include/`.

## Direct includes from the EA

- `Trade/Trade.mqh`
- `STB/STB_PendingDistanceResolver.mqh`
- `STB/STB_PendingTrail.mqh`

## Retained transitive include closure

1. `MQL5/Include/Object.mqh`
2. `MQL5/Include/StdLibErr.mqh`
3. `MQL5/Include/Trade/DealInfo.mqh`
4. `MQL5/Include/Trade/HistoryOrderInfo.mqh`
5. `MQL5/Include/Trade/OrderInfo.mqh`
6. `MQL5/Include/Trade/PositionInfo.mqh`
7. `MQL5/Include/Trade/Trade.mqh`
8. `MQL5/Include/STB/STB_PendingDistanceResolver.mqh`
9. `MQL5/Include/STB/STB_PendingTrail.mqh`

## Cleanup result

- Before cleanup: 241 `.mqh` files and 25 `.bmp`/`.hlsl` assets under `MQL5/Include/`.
- Retained: 9 headers in the recursive include closure.
- Removed from the review branch: 257 files under `MQL5/Include/` not reachable from the current EA include graph.
- Preserved: the EA source, the existing `.ex5` snapshot, root ZIP backup, audit materials, documentation, CI workflow, and static-audit script.

## Limits and recovery

A source-level include graph cannot prove all MetaEditor build behavior, terminal-specific implicit dependencies, future feature dependencies, or runtime correctness. This cleanup is therefore intentionally confined to the review branch. Compile the exact branch in MetaEditor before merging. If a missing dependency is identified, restore it from the verified all-refs bundle/ZIP backup and update this record. Do not use a green static-audit workflow as a substitute for compiler or Strategy Tester evidence.
