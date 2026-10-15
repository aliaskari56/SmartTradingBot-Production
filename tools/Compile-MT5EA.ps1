[CmdletBinding()]
param(
    [string] $RepoRoot = (Get-Location).Path,
    [string] $MetaEditorPath,
    [string] $OutputDirectory = (Join-Path $env:TEMP 'SmartTradingBot-MetaEditor-Builds')
)

$ErrorActionPreference = 'Stop'

function Read-TextFileAutoEncoding {
    param([Parameter(Mandatory = $true)][string] $Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    return [System.Text.Encoding]::Default.GetString($bytes)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$RelativeSource = 'MQL5/Experts/SmartTradingBot_FINAL.mq5'
$SourcePath = Join-Path $RepoRoot 'MQL5\Experts\SmartTradingBot_FINAL.mq5'
$MqlRoot = Join-Path $RepoRoot 'MQL5'

if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw "EA source not found: $SourcePath"
}
$RequiredIncludes = @(
    'Include\Trade\Trade.mqh',
    'Include\STB\STB_PendingDistanceResolver.mqh',
    'Include\STB\STB_PendingTrail.mqh'
)
foreach ($RelativeInclude in $RequiredIncludes) {
    $IncludePath = Join-Path $MqlRoot $RelativeInclude
    if (-not (Test-Path -LiteralPath $IncludePath -PathType Leaf)) {
        throw "Required include missing: $IncludePath"
    }
}

$GitBranch = (& git -C $RepoRoot branch --show-current | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($GitBranch)) {
    throw 'Could not determine Git branch. Run this script from a Git checkout.'
}
$GitCommit = (& git -C $RepoRoot rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not determine Git commit.' }
$SourceBlob = (& git -C $RepoRoot rev-parse "HEAD:$RelativeSource" | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not determine source blob at HEAD.' }
$GitStatus = @(& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Git working-tree status.' }
if ($GitStatus.Count -gt 0) {
    $GitStatus | ForEach-Object { Write-Host $_ }
    throw 'Working tree is dirty. Commit, stash, or review local changes before a provenance build.'
}

if ([string]::IsNullOrWhiteSpace($MetaEditorPath)) {
    $EditorCommand = Get-Command 'metaeditor64.exe' -ErrorAction SilentlyContinue
    if (-not $EditorCommand) {
        $EditorCommand = Get-Command 'metaeditor.exe' -ErrorAction SilentlyContinue
    }
    if ($EditorCommand) {
        $MetaEditorPath = $EditorCommand.Source
    } else {
        $Roots = @(
            $env:ProgramFiles,
            [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

        $Candidates = @()
        foreach ($Root in $Roots) {
            foreach ($Name in @('metaeditor64.exe', 'metaeditor.exe')) {
                $Candidates += Get-ChildItem -LiteralPath $Root -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty FullName
            }
        }
        $Candidates = @($Candidates | Select-Object -Unique)
        if ($Candidates.Count -ne 1) {
            throw "Expected one MetaEditor executable, found $($Candidates.Count). Pass -MetaEditorPath with its exact path."
        }
        $MetaEditorPath = $Candidates[0]
    }
}
if (-not (Test-Path -LiteralPath $MetaEditorPath -PathType Leaf)) {
    throw "MetaEditor executable not found: $MetaEditorPath"
}
$MetaEditorPath = (Resolve-Path -LiteralPath $MetaEditorPath).Path

$SourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
$BuildId = '{0}_{1}' -f $GitCommit.Substring(0, 12), (Get-Date -Format 'yyyyMMdd_HHmmss')
$BuildDirectory = Join-Path $OutputDirectory $BuildId
New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null

$StagedSource = Join-Path $BuildDirectory 'SmartTradingBot_FINAL.mq5'
$StagedLog = Join-Path $BuildDirectory 'SmartTradingBot_FINAL.log'
$StagedEx5 = Join-Path $BuildDirectory 'SmartTradingBot_FINAL.ex5'
Copy-Item -LiteralPath $SourcePath -Destination $StagedSource

$StagedHash = (Get-FileHash -LiteralPath $StagedSource -Algorithm SHA256).Hash
if ($StagedHash -ne $SourceHash) {
    throw 'Staged source SHA-256 differs from the repository source; compilation aborted.'
}

# MetaEditor creates <source-name>.log beside the staged source when /log is enabled.
$ArgumentString = '/compile:"{0}" /include:"{1}" /log' -f $StagedSource, $MqlRoot
$StartedAt = Get-Date
$Process = Start-Process -FilePath $MetaEditorPath -ArgumentList $ArgumentString -Wait -PassThru

if (-not (Test-Path -LiteralPath $StagedLog -PathType Leaf)) {
    throw "MetaEditor produced no log. Process exit code: $($Process.ExitCode). Build directory: $BuildDirectory"
}
$LogText = Read-TextFileAutoEncoding -Path $StagedLog
Write-Host '========== COMPLETE METAEDITOR LOG =========='
Write-Output $LogText
Write-Host '========== END METAEDITOR LOG =========='

$Summaries = [regex]::Matches($LogText, '(?i)(\d+)\s+errors?,\s*(\d+)\s+warnings?')
if ($Summaries.Count -eq 0) {
    throw "Could not parse an errors/warnings summary. Inspect: $StagedLog"
}
$Summary = $Summaries[$Summaries.Count - 1]
$ErrorCount = [int]$Summary.Groups[1].Value
$WarningCount = [int]$Summary.Groups[2].Value
if (-not (Test-Path -LiteralPath $StagedEx5 -PathType Leaf)) {
    throw "Compiler output EX5 is missing. Inspect: $StagedLog"
}
$Ex5Hash = (Get-FileHash -LiteralPath $StagedEx5 -Algorithm SHA256).Hash

$Manifest = [ordered]@{
    status = if ($Process.ExitCode -eq 0 -and $ErrorCount -eq 0 -and $WarningCount -eq 0) { 'COMPILE_PASS' } else { 'COMPILE_FAIL' }
    started_at = $StartedAt.ToString('o')
    completed_at = (Get-Date).ToString('o')
    git_branch = $GitBranch
    git_commit = $GitCommit
    source_path = $RelativeSource
    source_git_blob = $SourceBlob
    source_sha256 = $SourceHash
    staged_source_sha256 = $StagedHash
    metaeditor_path = $MetaEditorPath
    process_exit_code = $Process.ExitCode
    compiler_errors = $ErrorCount
    compiler_warnings = $WarningCount
    ex5_sha256 = $Ex5Hash
    build_directory = $BuildDirectory
    log_path = $StagedLog
}
$ManifestPath = Join-Path $BuildDirectory 'build-manifest.json'
$Manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Manifest.GetEnumerator() | ForEach-Object { Write-Host ('{0}: {1}' -f $_.Key, $_.Value) }

if ($Process.ExitCode -ne 0 -or $ErrorCount -ne 0 -or $WarningCount -ne 0) {
    throw "Compile gate failed. No EX5 was installed into MetaTrader. Review $StagedLog"
}

Write-Host 'Compile gate passed. The EX5 remains isolated in the build directory; no live terminal files were overwritten.'
Write-Host "EX5: $StagedEx5"
