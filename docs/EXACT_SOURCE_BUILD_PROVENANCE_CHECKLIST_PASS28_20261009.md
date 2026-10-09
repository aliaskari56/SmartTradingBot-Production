# Exact-Source Build Provenance Checklist — PowerShell / MetaEditor

Date: 2026-10-09  
Branch: `audit/expose-cleaned-source-20261009`  
Status: **PREPARED FOR LOCAL METAEDITOR BUILD; NOT EXECUTED IN THIS ENVIRONMENT**

## Exact source and include identity

- Repository: `aliaskari56/SmartTradingBot-Production`
- Primary source: `MQL5/Experts/SmartTradingBot_FINAL.mq5`
- Current source Git blob: `fdce203d23a08eb4ca2966d4a09719c3e4a89397` (Git blob SHA; not raw-file SHA-256)
- Latest source-changing commit: `b4c08e84135c0ceb170e5e4b3e996957f3d8ce82`
- Observed source size: 304,511 bytes; 9,156 lines
- Direct/transitive compile closure found by source trace: primary EA, standard `Trade/Trade.mqh` family, and two repository-owned-path STB includes. The STB modules have no further include directives in the inspected source. The resolver now enforces the configured +20-pip lock floor once net profit reaches the +50-pip trigger: weaker competing candidates are skipped while an SL already exists. If an unprotected position has no candidate that can satisfy the floor under current broker geometry, the strongest valid non-profit-lock stop may be applied as an emergency fallback; that fallback is not credited as a successful +20-pip lock.

Expected tracked Git blobs used by the automated preflight:

| Repository-relative path | Expected Git blob |
|---|---|
| `MQL5/Experts/SmartTradingBot_FINAL.mq5` | `fdce203d23a08eb4ca2966d4a09719c3e4a89397` |
| `MQL5/Include/Trade/Trade.mqh` | `37cfd4c3fc15c6de9aec7390287c95530d3d31cb` |
| `MQL5/Include/Trade/OrderInfo.mqh` | `104444612778249ff7c0abe2aa6d8f51135cc1ad` |
| `MQL5/Include/Trade/HistoryOrderInfo.mqh` | `f570b65d72f35061ed45c5bce4dfa62d1093edd5` |
| `MQL5/Include/Trade/PositionInfo.mqh` | `e4ee0cd008f1fca4daa9a1bcf31aa67dc9c8ed32` |
| `MQL5/Include/Trade/DealInfo.mqh` | `f8d16df5e3f8a20bb344d81a296f23fd33aec9ca` |
| `MQL5/Include/Object.mqh` | `2ad6ca61b3335d4947bfafd89a9fa6dcb77abc6f` |
| `MQL5/Include/StdLibErr.mqh` | `5d96e6dcf235c69272555dc888532ae268c25908` |
| `MQL5/Include/STB/STB_PendingDistanceResolver.mqh` | `2ed3aaefb3a83b7690409f87a3c7e428c35a895` |
| `MQL5/Include/STB/STB_PendingTrail.mqh` | `bdb827e7871960f88f5bf9593f1e4efcc7797367` |

## Automated PowerShell preflight and compile

Run this block **from a PowerShell window opened anywhere inside the Git checkout**. It creates its staging directory, the staged `.mq5`, compiler log and resulting `.ex5` under the user's system `TEMP` directory—not inside the repository. It does not modify, rename or delete repository files. Keep the staged source, full log and EX5 together as build evidence.

The script deliberately stops if it is on the wrong branch, if any source/include blob differs, if those files have local modifications, if MetaEditor cannot be identified unambiguously, or if the compiler log lacks an interpretable result. A successful script run is compile evidence only; it is not Strategy Tester or release approval.

```powershell
$ErrorActionPreference = 'Stop'

# Optional override when MetaEditor is installed in a non-standard directory:
$MetaEditorExe = $null

$RepoRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) {
    throw 'Run this block inside a Git checkout of SmartTradingBot-Production.'
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot.Trim()).Path
$ExpectedBranch = 'audit/expose-cleaned-source-20261009'
$Branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $Branch -ne $ExpectedBranch) {
    throw "Wrong branch '$Branch'. Expected '$ExpectedBranch'. No compile was started."
}
$Head = (& git -C $RepoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve HEAD.' }

$ExpectedBlobs = [ordered]@{
    'MQL5/Experts/SmartTradingBot_FINAL.mq5' = 'fdce203d23a08eb4ca2966d4a09719c3e4a89397'
    'MQL5/Include/Trade/Trade.mqh' = '37cfd4c3fc15c6de9aec7390287c95530d3d31cb'
    'MQL5/Include/Trade/OrderInfo.mqh' = '104444612778249ff7c0abe2aa6d8f51135cc1ad'
    'MQL5/Include/Trade/HistoryOrderInfo.mqh' = 'f570b65d72f35061ed45c5bce4dfa62d1093edd5'
    'MQL5/Include/Trade/PositionInfo.mqh' = 'e4ee0cd008f1fca4daa9a1bcf31aa67dc9c8ed32'
    'MQL5/Include/Trade/DealInfo.mqh' = 'f8d16df5e3f8a20bb344d81a296f23fd33aec9ca'
    'MQL5/Include/Object.mqh' = '2ad6ca61b3335d4947bfafd89a9fa6dcb77abc6f'
    'MQL5/Include/StdLibErr.mqh' = '5d96e6dcf235c69272555dc888532ae268c25908'
    'MQL5/Include/STB/STB_PendingDistanceResolver.mqh' = '2ed3aaefb3a83b7690409f87a3c7e428c35a895'
    'MQL5/Include/STB/STB_PendingTrail.mqh' = 'bdb827e7871960f88f5bf9593f1e4efcc7797367'
}

foreach ($RelativePath in $ExpectedBlobs.Keys) {
    $AbsolutePath = Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
        throw "Required source/include is missing: $RelativePath"
    }
    $HeadBlob = (& git -C $RepoRoot rev-parse "HEAD:$RelativePath" 2>$null)
    if ($LASTEXITCODE -ne 0 -or $HeadBlob.Trim() -ne $ExpectedBlobs[$RelativePath]) {
        throw "Committed blob mismatch for $RelativePath. No compile was started."
    }
    & git -C $RepoRoot diff --quiet HEAD -- $RelativePath
    if ($LASTEXITCODE -ne 0) {
        throw "Working-tree/index modification detected in $RelativePath. No compile was started."
    }
}

$SourcePath = Join-Path $RepoRoot 'MQL5/Experts/SmartTradingBot_FINAL.mq5'
$IncludeRoot = Join-Path $RepoRoot 'MQL5'
$SourceRawHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash

if (-not $MetaEditorExe) {
    $OnPath = Get-Command 'metaeditor64.exe' -ErrorAction SilentlyContinue
    if ($OnPath) { $MetaEditorExe = $OnPath.Source }
}
if (-not $MetaEditorExe) {
    $SearchRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }
    $FoundEditors = @()
    foreach ($SearchRoot in $SearchRoots) {
        $FoundEditors += Get-ChildItem -LiteralPath $SearchRoot -Filter 'metaeditor64.exe' -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    }
    $FoundEditors = @($FoundEditors | Sort-Object -Unique)
    if ($FoundEditors.Count -eq 1) {
        $MetaEditorExe = $FoundEditors[0]
    } elseif ($FoundEditors.Count -gt 1) {
        $FoundEditors | ForEach-Object { Write-Host $_ }
        throw 'More than one MetaEditor was found. Set $MetaEditorExe explicitly, then rerun.'
    }
}
if (-not $MetaEditorExe -or -not (Test-Path -LiteralPath $MetaEditorExe -PathType Leaf)) {
    throw 'MetaEditor 64-bit was not found. Set $MetaEditorExe to the full path of metaeditor64.exe.'
}
$MetaEditorExe = (Resolve-Path -LiteralPath $MetaEditorExe).Path
$EditorVersion = (Get-Item -LiteralPath $MetaEditorExe).VersionInfo.FileVersion

$BuildRoot = Join-Path $env:TEMP ('STB-MetaEditor-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $BuildRoot | Out-Null
$StagedSource = Join-Path $BuildRoot 'SmartTradingBot_FINAL.mq5'
$LogPath = Join-Path $BuildRoot 'SmartTradingBot_FINAL.log'
$Ex5Path = Join-Path $BuildRoot 'SmartTradingBot_FINAL.ex5'
Copy-Item -LiteralPath $SourcePath -Destination $StagedSource

$StagedHash = (Get-FileHash -LiteralPath $StagedSource -Algorithm SHA256).Hash
if ($StagedHash -ne $SourceRawHash) {
    throw 'Staged-source SHA-256 mismatch; compile stopped.'
}

# Official MetaEditor CLI: /compile, /include (custom MQL5 root), /log.
$ArgumentLine = '/compile:"' + $StagedSource + '" /include:"' + $IncludeRoot + '" /log'
$Process = Start-Process -FilePath $MetaEditorExe -ArgumentList $ArgumentLine -Wait -PassThru

for ($Attempt = 0; $Attempt -lt 30 -and -not (Test-Path -LiteralPath $LogPath -PathType Leaf); $Attempt++) {
    Start-Sleep -Seconds 1
}
if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
    throw "MetaEditor produced no compiler log. Process exit code: $($Process.ExitCode). Staging path: $BuildRoot"
}
$LogText = Get-Content -LiteralPath $LogPath -Raw
$Summary = [regex]::Match($LogText, '(?im)^\s*Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?\b')
if (-not $Summary.Success) {
    Write-Host $LogText
    throw "Compiler result could not be parsed; manual log review required. Staging path: $BuildRoot"
}
$ErrorCount = [int]$Summary.Groups[1].Value
$WarningCount = [int]$Summary.Groups[2].Value
$Ex5Exists = Test-Path -LiteralPath $Ex5Path -PathType Leaf
$Ex5Hash = if ($Ex5Exists) { (Get-FileHash -LiteralPath $Ex5Path -Algorithm SHA256).Hash } else { 'NOT PRODUCED' }

Write-Host '=== SMARTTRADINGBOT EXACT-SOURCE BUILD EVIDENCE ==='
Write-Host "Branch:              $Branch"
Write-Host "Repository HEAD:     $Head"
Write-Host "Source Git blob:     $($ExpectedBlobs['MQL5/Experts/SmartTradingBot_FINAL.mq5'])"
Write-Host "Source raw SHA-256:  $SourceRawHash"
Write-Host "MetaEditor:          $MetaEditorExe"
Write-Host "MetaEditor version:  $EditorVersion"
Write-Host "Compiler exit code:  $($Process.ExitCode)"
Write-Host "Compiler summary:    $($Summary.Value.Trim())"
Write-Host "EX5 SHA-256:         $Ex5Hash"
Write-Host "Full compiler log:   $LogPath"
Write-Host "Build staging path:  $BuildRoot"
if ($WarningCount -gt 0) {
    Write-Warning "$WarningCount compiler warning(s) need explicit review; retain the full log."
}
if ($Process.ExitCode -ne 0 -or $ErrorCount -ne 0 -or -not $Ex5Exists) {
    Write-Host $LogText
    throw 'BUILD FAIL/BLOCKED. Do not send this EX5 as an accepted build.'
}
Write-Host 'COMPILE RESULT: PASS (compile only; warnings and runtime acceptance still require review).'
```

The script uses MetaEditor's documented command-line `/compile`, `/include`, and `/log` options. It checks the compiler summary and EX5 existence, and reports both Git blob identity and raw-file SHA-256. If this runs on Windows with the exact checkout and a working MetaEditor installation, preserve the complete console output and the staging directory. Do not copy the EX5 into the repository or label it production-approved solely because compilation passed.

## Evidence table

| Evidence ID | Required item | Current status |
|---|---|---|
| BP-01 | Exact branch/commit and checked-in source/include hashes | EXPECTED BLOBS DEFINED; LOCAL CHECK NOT RUN |
| BP-02 | Working-tree equality for all compile inputs | NOT RUN |
| BP-03 | Raw source SHA-256 | NOT RUN |
| BP-04 | MetaEditor executable and file version | NOT RUN |
| BP-05 | Exact invocation and compiler exit code | COMMAND PREPARED; NOT RUN |
| BP-06 | Complete compiler log | NOT RUN |
| BP-07 | EX5 raw SHA-256 | NOT RUN |
| BP-08 | Warning review and reviewer disposition | NOT RUN |
| BP-09 | Strategy Tester and demo acceptance | NOT RUN |
| BP-10 | Source-to-EX5 custody/reproducibility | NOT RUN |

## Interpretation / gate

- Git blob SHA and raw SHA-256 are different identifiers and must not be substituted for one another.
- A tracked or pre-existing EX5 does not establish that it was built from this source.
- Do not infer success from the PowerShell process exit code alone; verify the parsed log result and preserved EX5 hash.
- Warnings must be reviewed even if the compiler produces EX5.
- Compilation does not establish trading correctness, broker compatibility or profitability.

**Build gate: BLOCKED / NOT VERIFIED until the PowerShell preflight/compile actually runs on Windows and the complete evidence is reviewed.** MetaEditor, Strategy Tester, terminal/demo tests and an independent release review are not available in this execution environment.
