# Exact-Source Build Provenance and PowerShell Compile Runbook

Last integrated review: 2026-10-09  
Branch: audit/expose-cleaned-source-20261009  
EA source: MQL5/Experts/SmartTradingBot_FINAL.mq5

## Frozen source identity for this audit

- Repository: aliaskari56/SmartTradingBot-Production
- Reviewed source Git blob: 6bca33bc8e0c961f317b0828e46faf7a6b9929b4 (Git blob ID, **not** raw-file SHA-256)
- Source-changing commit: 30d683029158bc4a1cab64e8d3d190af04b07479
- Static checker blob: 7f5092f1663f8a899449a16f3b6588df80c19bef
- Static CI run for this source/checker combination: [37949430269](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/37949430269) — 26 structural checks passed.
- The current resolver also enforces the active profit-lock floor and only persists lock-pips after the final terminal SL meets the normalized target. The current delete writer rechecks expiry source, managed-order scope and symbol lease at the final writer boundary.
- The previously tracked MQL5/Experts/SmartTradingBot_FINAL.ex5 is **not** proven to correspond to this source. Do not treat it as the output of the build below.

A fresh local compile has **not** been performed here because MetaEditor is not available in this execution environment. The automation below is designed for the Windows machine that has MetaEditor installed. It does not add a .ps1 file to the repository and does not overwrite the tracked EX5 or compile directly into the terminal's live Experts folder.

## What the PowerShell automation does

1. Requires the audit branch, exact source Git blob, and a clean working tree.
2. Confirms the current source's direct STB/Trade includes exist.
3. Finds MetaEditor or accepts an explicit executable path.
4. Copies the exact source bytes to an isolated temporary build directory outside the repository; resolves includes from the reviewed MQL5 tree.
5. Invokes MetaEditor with /compile, /include, and /log.
6. Prints and preserves the full compiler log plus source SHA-256, EX5 SHA-256, compiler exit code, and output paths.
7. Fails closed if the compiler log is absent, has no parseable summary, reports errors or warnings, the EX5 is missing, or the process exit code is nonzero. Warnings must be triaged rather than silently accepted.

MetaEditor command-line options are documented by MetaQuotes: [Compiling MQL programs in other development environments](https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide). The /include argument is the MQL5 root directory containing the Include folder; the checked source has no #resource directives.

## Run it in Windows PowerShell

Open PowerShell in the local Git checkout or use the full repository path below. Paste this function into the interactive PowerShell session; it is not a new project script or repository file.

~~~powershell
function Invoke-STBMetaEditorCompile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,

        [string] $MetaEditorPath
    )

    $ErrorActionPreference = 'Stop'
    $ExpectedBranch = 'audit/expose-cleaned-source-20261009'
    $ExpectedBlob = '6bca33bc8e0c961f317b0828e46faf7a6b9929b4'
    $RelativeSource = 'MQL5/Experts/SmartTradingBot_FINAL.mq5'

    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $SourcePath = Join-Path $RepoRoot 'MQL5\Experts\SmartTradingBot_FINAL.mq5'
    $MqlRoot = Join-Path $RepoRoot 'MQL5'

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        throw "Source not found: $SourcePath"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $MqlRoot 'Include\Trade\Trade.mqh') -PathType Leaf)) {
        throw 'Expected repository include missing: MQL5\Include\Trade\Trade.mqh'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $MqlRoot 'Include\STB\STB_PendingDistanceResolver.mqh') -PathType Leaf)) {
        throw 'Expected repository include missing: STB_PendingDistanceResolver.mqh'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $MqlRoot 'Include\STB\STB_PendingTrail.mqh') -PathType Leaf)) {
        throw 'Expected repository include missing: STB_PendingTrail.mqh'
    }

    $BranchName = (& git -C $RepoRoot branch --show-current)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to determine current Git branch. Is Git installed and is this a Git checkout?'
    }
    $BranchName = ($BranchName | Out-String).Trim()
    if ($BranchName -ne $ExpectedBranch) {
        throw "Wrong branch '$BranchName'. Check out '$ExpectedBranch' before compiling."
    }

    $ActualBlob = (& git -C $RepoRoot rev-parse "HEAD:$RelativeSource")
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read the source blob from HEAD.'
    }
    $ActualBlob = ($ActualBlob | Out-String).Trim()
    if ($ActualBlob -ne $ExpectedBlob) {
        throw "Source blob mismatch. Expected $ExpectedBlob; HEAD contains $ActualBlob."
    }

    $GitStatus = & git -C $RepoRoot status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read Git working-tree status.'
    }
    if (@($GitStatus).Count -gt 0) {
        $GitStatus | ForEach-Object { Write-Host $_ }
        throw 'Working tree is not clean. Commit/stash/review local changes before the provenance build.'
    }

    if ([string]::IsNullOrWhiteSpace($MetaEditorPath)) {
        $Command = Get-Command 'metaeditor64.exe' -ErrorAction SilentlyContinue
        if (-not $Command) {
            $Command = Get-Command 'metaeditor.exe' -ErrorAction SilentlyContinue
        }
        if ($Command) {
            $MetaEditorPath = $Command.Source
        } else {
            $Roots = @(
                $env:ProgramFiles,
                [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
            ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

            $Found = @()
            foreach ($Root in $Roots) {
                foreach ($Name in @('metaeditor64.exe', 'metaeditor.exe')) {
                    $Found += Get-ChildItem -LiteralPath $Root -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
                              Select-Object -ExpandProperty FullName
                }
            }
            $Found = @($Found | Select-Object -Unique)
            if ($Found.Count -ne 1) {
                throw "Could not select exactly one MetaEditor executable (found $($Found.Count)). Call with -MetaEditorPath 'C:\full\path\metaeditor64.exe'."
            }
            $MetaEditorPath = $Found[0]
        }
    }

    if (-not (Test-Path -LiteralPath $MetaEditorPath -PathType Leaf)) {
        throw "MetaEditor executable not found: $MetaEditorPath"
    }
    $MetaEditorPath = (Resolve-Path -LiteralPath $MetaEditorPath).Path

    $SourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $StageRoot = Join-Path ([IO.Path]::GetTempPath()) ('STB_MetaEditor_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $StageRoot | Out-Null

    $StagedSource = Join-Path $StageRoot 'SmartTradingBot_FINAL.mq5'
    $StagedLog = Join-Path $StageRoot 'SmartTradingBot_FINAL.log'
    $StagedEx5 = Join-Path $StageRoot 'SmartTradingBot_FINAL.ex5'

    try {
        Copy-Item -LiteralPath $SourcePath -Destination $StagedSource
        $StagedHash = (Get-FileHash -LiteralPath $StagedSource -Algorithm SHA256).Hash
        if ($StagedHash -ne $SourceHash) {
            throw 'Staged source SHA-256 differs from the repository source; compile aborted.'
        }

        $Arguments = ('/compile:"{0}" /include:"{1}" /log' -f $StagedSource, $MqlRoot)
        $StartedAt = Get-Date
        $Process = Start-Process -FilePath $MetaEditorPath -ArgumentList $Arguments -Wait -PassThru

        if (-not (Test-Path -LiteralPath $StagedLog -PathType Leaf)) {
            throw "MetaEditor did not produce the expected log. Exit code: $($Process.ExitCode). Stage retained at: $StageRoot"
        }

        $LogText = Get-Content -LiteralPath $StagedLog -Raw
        Write-Host ([Environment]::NewLine + '========== COMPLETE METAEDITOR LOG ==========') -ForegroundColor Cyan
        Write-Output $LogText
        Write-Host '========== END METAEDITOR LOG ==========' -ForegroundColor Cyan

        $SummaryMatches = [regex]::Matches(
            $LogText,
            '(?i)(\d+)\s+errors?,\s*(\d+)\s+warnings?'
        )
        if ($SummaryMatches.Count -eq 0) {
            throw "No compiler summary could be parsed. Review the raw log: $StagedLog"
        }

        $Summary = $SummaryMatches[$SummaryMatches.Count - 1]
        $ErrorCount = [int]$Summary.Groups[1].Value
        $WarningCount = [int]$Summary.Groups[2].Value
        if (Test-Path -LiteralPath $StagedEx5 -PathType Leaf) {
            $Ex5Hash = (Get-FileHash -LiteralPath $StagedEx5 -Algorithm SHA256).Hash
        } else {
            $Ex5Hash = 'MISSING'
        }

        $BuildStatus = 'BLOCKED'
        if ($Process.ExitCode -eq 0 -and $ErrorCount -eq 0 -and
            $WarningCount -eq 0 -and $Ex5Hash -ne 'MISSING') {
            $BuildStatus = 'PASS'
        }

        $Result = [pscustomobject]@{
            Status             = $BuildStatus
            Branch             = $BranchName
            SourceGitBlob      = $ActualBlob
            SourceSHA256       = $SourceHash
            MetaEditorPath     = $MetaEditorPath
            MetaEditorExitCode = $Process.ExitCode
            CompilerErrors     = $ErrorCount
            CompilerWarnings   = $WarningCount
            EX5SHA256          = $Ex5Hash
            StageDirectory     = $StageRoot
            CompilerLog        = $StagedLog
            StartedAt          = $StartedAt
            FinishedAt         = Get-Date
        }
        $Result | Format-List | Out-String | Write-Host

        if ($Result.Status -ne 'PASS') {
            throw 'Build is BLOCKED: require exit code 0, a generated EX5, and a compiler summary of 0 errors / 0 warnings. Preserve the stage directory for diagnosis.'
        }

        Write-Host 'Build PASS. This is a compile check only; it does NOT validate Strategy Tester, broker behavior, profitability, or release readiness.' -ForegroundColor Green
        return $Result
    }
    catch {
        Write-Host "BUILD BLOCKED: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Staged source/log/EX5 (if generated) retained for review: $StageRoot" -ForegroundColor Yellow
        throw
    }
}
~~~

Call the function with the actual local checkout path and, if automatic discovery finds zero/multiple installations, the exact MetaEditor executable path:

~~~powershell
Invoke-STBMetaEditorCompile -RepoRoot 'C:\path\to\SmartTradingBot-Production' -MetaEditorPath 'C:\path\to\metaeditor64.exe'
~~~

Use the exact directory shown by your installation. Do not guess a terminal hash or copy the output into the live MQL5\Experts folder as part of this compile check. After a PASS, the generated EX5 and raw log are retained under the reported OS temporary stage directory for inspection; no repository EX5 is overwritten. Delete that temporary directory manually only after preserving the evidence you need.

## Interpreting the result

- PASS means the specified MetaEditor returned exit code zero, the log summary reports zero errors and zero warnings, and a new EX5 exists in the isolated staging directory.
- BLOCKED means the run cannot be accepted as a clean build. Inspect the preserved raw log and toolchain path; do not infer success from an EX5 file alone.
- This is a local Windows procedure; it was **not executed from this assistant environment**.
- A successful compile does not establish broker compatibility, runtime safety, strategy performance, or release readiness.

## Evidence still required after a successful compile

- Save the exact commit, source raw SHA-256, Git blob, MetaEditor/compiler version, full log, process exit code, and generated EX5 raw SHA-256.
- Run the applicable Strategy Tester acceptance scenarios, followed by demo-account lifecycle cases.
- Complete include/package inventory, attribution/license review, and independent code review.
- Keep the release decision **BLOCKED / NOT VERIFIED** until these gates are evidenced.
