# LRN-04 Journal Lock and Writer-Ownership Contract — Proposal

**Status: proposal only; not implemented or runtime-verified.**  
**Applies to:** future LRN-04 persistence for `SmartTradingBot_FINAL`.  
**Branch:** `fix/structure-first-fvg-trailing-20261020`

## Objective

Prevent two EA instances or callbacks from selecting the same next sequence, interleaving records, or applying the same committed outcome twice. Existing symbol-management leases are not a journal-wide lock and must not be reused as if they were one.

## Required lock scope

The lock namespace must uniquely identify the journal being protected. Before implementation, freeze canonicalization for:
- terminal environment (live terminal vs tester/optimization);
- server identity;
- account identity;
- EA magic number;
- journal/schema version.

The lock key must not depend only on symbol: a single journal may contain events for multiple symbols. Do not include secrets or raw account credentials in the key. Namespace collision behavior must be tested.

## Acquisition and ownership

1. Acquire the journal lock using an atomic compare-and-set primitive, not a read-then-write sequence.
2. Store an owner token that is unique for this process/session and a monotonic lease generation or equivalent fencing value. A timestamp alone is not a unique owner identity.
3. After acquisition, verify ownership before reading the journal tail, before every append phase, and before publishing any in-memory projection.
4. Only the current owner may release the lock; release must compare the stored owner/generation and must never blindly set the lock to zero.
5. If ownership changes or cannot be verified, stop writes and enter a fail-closed error state.
6. Define the behavior when Global Variables are unavailable, full, or cannot be flushed. No silent fallback to an unlocked writer is allowed.

## Stale-owner recovery

Do not steal a lock solely because its timestamp appears old. A recovery protocol must establish that the prior owner is no longer active or use a proven lease/fencing design that makes writes from an old owner harmless. The chosen protocol must account for terminal restart, clock changes, suspended/stalled processes, and multiple charts in one terminal.

If safe stale-owner detection cannot be established with supported MQL5 primitives, require operator intervention rather than automatically reclaiming the lock.

## Critical section

Under the lock:
1. Validate the existing complete journal history and tail.
2. Determine the next sequence and previous-record digest.
3. Write and flush PREPARED.
4. Verify lock ownership again.
5. Write and flush COMMITTED referencing PREPARED.
6. Update the committed in-memory projection only after the chosen durability boundary is confirmed.
7. Release by compare-and-set against the exact owner token/generation.

The implementation must freeze and document the platform-specific meaning and limits of FileFlush and GlobalVariablesFlush. A successful API return must not be described as stronger physical durability than the platform guarantees.

## Required contention and failure tests

- Two writers acquire at the same instant: at most one succeeds.
- Non-owner attempts release: owner lock remains intact.
- Owner token changes before PREPARED, between PREPARED and COMMITTED, and before projection update: writer stops and recovery decides the outcome.
- Old owner resumes after stale-lock recovery: fencing prevents its writes.
- Terminal restart and clock rollback/forward do not cause unsafe lock theft.
- Lock storage missing/full/unwritable: writes fail closed.
- Repeated transaction event from two chart instances produces at most one committed event identity.
- A failure at every boundary leaves a history that recovery either validates deterministically or rejects without silent repair.

## Integration gate

Do not wire journal writes into `OnTradeTransaction()` until the scope/key format, ownership primitive, fencing/stale-owner protocol, and flush semantics are approved and covered by executable tests. The current V1 codec and Python reference tests do not implement this lock. This document does not enable journal persistence.

**Release status remains BLOCKED / NOT VERIFIED.**
