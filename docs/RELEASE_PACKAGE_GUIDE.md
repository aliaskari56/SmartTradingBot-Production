# Clean Source Package Guide

## Purpose

Create a source-only ZIP containing `MQL5/Experts/SmartTradingBot_FINAL.mq5` and every recursively referenced `.mqh` dependency. The script does not modify the repository, terminal installation, live EA, settings, or source files.

## Run on Windows PowerShell 5.1

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Package-CleanSource.ps1
```

Default output directory:

```text
%USERPROFILE%\Downloads\SmartTradingBot-Packages
```

To choose another output directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Package-CleanSource.ps1 -RepositoryRoot (Get-Location).Path -OutputDirectory 'E:\Downloads\SmartTradingBot-Packages'
```

## Package contents and safeguards

- Includes the primary EA, recursively discovered include dependencies, and repository README.
- Fails before packaging if a referenced include is missing or resolves outside the repository root.
- Creates a timestamped ZIP and prints its SHA-256 hash.
- Writes `SOURCE_SHA256_MANIFEST.csv` for the copied source/document files.
- Excludes compiled `.ex5` files, terminal data, credentials, `.set` files, logs, backups, and temporary files.
- Does not overwrite an existing package or delete existing output files. It removes only its own temporary staging directory.
- Does not compile, test, or certify the EA.

## Release gate

The ZIP is a clean source handoff, not a validated release. Before deployment, compile the exact packaged source in MetaEditor; preserve the compiler log and EX5 hash; run the project static checks; and perform controlled Strategy Tester and demo checks for UI controls, manual order actions, volume-step validation, order rejection handling, position protection, and pending-order trailing. Keep the local v1.141 source separate unless its exact source hash and dependency set are confirmed against this repository snapshot.

No profitability or live-readiness claim is made by this packaging tool.
