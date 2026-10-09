# Exact-Source Build Provenance Checklist — Pass 28
Date: 2026-10-09
Branch: `audit/expose-cleaned-source-20261009`

## Objective

Define the evidence required to determine whether a compiled EX5 was built from the exact SmartTradingBot source reviewed on this branch. This is a checklist, not a claim that a build has occurred.

## Frozen source identity

The last static audit re-fetch recorded:

- Repository: `aliaskari56/SmartTradingBot-Production`
- Branch: `audit/expose-cleaned-source-20261009`
- Source path: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
- Git blob SHA recorded: `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`
- Reported line count: 8,665
- Current audit status: `DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN`

Important: Git blob SHA is not the raw file SHA-256. Calculate and record the raw SHA-256 from the exact file copied into the build workspace. Record the commit SHA as well as the blob SHA.

## Pre-build checklist

1. Check out the exact reviewed commit, not a moving branch head.
2. Confirm the primary source file and all direct/transitive includes match the reviewed tree.
3. Record `git rev-parse HEAD`, `git status --short`, and the raw SHA-256 of the source file.
4. Confirm the workspace is clean; document any generated/local files and do not silently substitute them.
5. Record MetaEditor executable/version, terminal build, operating system, compiler options, include search paths, and exact build command or GUI procedure.
6. Record account-independent compile inputs, including any custom include directories or environment-dependent files.
7. Preserve the complete compiler output verbatim. Do not report only the final summary line.
8. Capture exit status and distinguish compiler diagnostics from wrapper/CI job status.
9. Calculate raw SHA-256 of the resulting EX5 and preserve the artifact without post-build modification.
10. Repeat the build from a clean workspace if reproducibility is a release requirement; compare outputs and document any expected nondeterminism.

## Evidence table

| Evidence ID | Required item | Required value/file | Current status |
|---|---|---|---|
| BP-01 | Exact commit | Full commit SHA | NOT RECORDED FOR A NEW LOCAL BUILD |
| BP-02 | Clean checkout | Full `git status` output | NOT RUN |
| BP-03 | Source raw SHA-256 | SHA-256 of local source bytes | NOT RUN |
| BP-04 | Git blob identity | Blob SHA compared to reviewed value | Prior Git blob SHA recorded; local comparison NOT RUN |
| BP-05 | Compiler/toolchain | MetaEditor/compiler and terminal versions | NOT RECORDED |
| BP-06 | Build invocation | Exact command or GUI steps/options | NOT RUN |
| BP-07 | Full build log | Unedited raw output | NOT RUN |
| BP-08 | Build exit status | Numeric status and interpretation | NOT RUN |
| BP-09 | EX5 raw SHA-256 | Hash of newly produced EX5 | NOT RUN |
| BP-10 | Artifact custody | Location, timestamp, transfer method | NOT RUN |
| BP-11 | Reproducibility | Second clean build and comparison, if required | NOT RUN |
| BP-12 | Reviewer sign-off | Independent comparison of evidence | NOT RUN |

## Interpretation rules

- A pre-existing EX5 in Git does not prove it came from the current source.
- A manifest assertion or historical CI log for another commit/file name does not prove the current source builds.
- “0 errors, 0 warnings” is not accepted without the full log and exact source/toolchain mapping.
- A successful compile proves neither trading correctness nor profitability.
- A missing CI status is “no status evidence received,” not pass or fail.
- If the exact build cannot be performed in the current environment, mark the build gate BLOCKED and assign it to an operator with the required MetaEditor environment. Do not infer a build result.

## Gate decision

**BL-01 / BL-02 remain OPEN.** Do not claim the checked-in EX5 matches the reviewed source until the source, toolchain, full build log, and output artifact hashes are linked in one evidence bundle. No executable source changed in this pass. No compile, runtime, Strategy Tester, or demo test was run as part of creating this checklist.
