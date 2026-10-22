#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TerminalData = "$env:APPDATA\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87",
    [string]$MetaEditor = "C:\Program Files\Orbex Global MT5\MetaEditor64.exe"
)

$ErrorActionPreference = "Stop"
$Commit = "0c79439a09df38aab9fe4b417f8632fa0a9f9f81"
$SourceRelative = "MQL5/Experts/SmartTradingBot_FINAL.mq5"
$IncludeNames = @(
    "STB_LRN04Journal.mqh",
    "STB_PendingDistanceResolver.mqh",
    "STB_PendingTrail.mqh"
)
$Source = Join-Path $TerminalData "MQL5\Experts\SmartTradingBot_FINAL.mq5"
$IncludeRoot = Join-Path $TerminalData "MQL5\Include\STB"
$Ex5 = [IO.Path]::ChangeExtension($Source, ".ex5")
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $TerminalData "MQL5\_backups\STB_LiveEnabledDeploy_$Stamp"
$Work = Join-Path $env:TEMP "STB_LiveEnabledDeploy_$Stamp"
$Log = Join-Path $Backup "MetaEditorCompile.log"
$RawRoot = "https://raw.githubusercontent.com/aliaskari56/SmartTradingBot-Production/$Commit"

if (-not (Test-Path -LiteralPath $TerminalData -PathType Container)) {
    throw "MT5 terminal data directory not found: $TerminalData"
}
if (-not (Test-Path -LiteralPath (Split-Path -Parent $Source) -PathType Container)) {
    throw "EA Experts directory not found."
}
if (-not (Test-Path -LiteralPath $MetaEditor -PathType Leaf)) {
    throw "MetaEditor not found: $MetaEditor"
}

New-Item -ItemType Directory -Path $IncludeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $Backup -Force | Out-Null
New-Item -ItemType Directory -Path $Work -Force | Out-Null

try {
    Write-Host "=== 1. DOWNLOAD PINNED GITHUB BUILD ===" -ForegroundColor Cyan
    Invoke-WebRequest -UseBasicParsing -Uri "$RawRoot/$SourceRelative" -OutFile (Join-Path $Work "SmartTradingBot_FINAL.mq5")
    foreach ($name in $IncludeNames) {
        Invoke-WebRequest -UseBasicParsing -Uri "$RawRoot/MQL5/Include/STB/$name" -OutFile (Join-Path $Work $name)
        Write-Host "Downloaded: $name"
    }

    $newSource = Get-Content -LiteralPath (Join-Path $Work "SmartTradingBot_FINAL.mq5") -Raw
    if ($newSource -notmatch 'input bool\s+InpAutoTrading\s*=\s*true\s*;' -or
        $newSource -notmatch 'input bool\s+InpUseRiskSizing\s*=\s*true\s*;' -or
        $newSource -notmatch 'g_autoStateName=ScopedStateName\("AUTO_V2"\);') {
        throw "Downloaded source failed live-enabled configuration checks."
    }
    if ($newSource -match 'STB SAFETY BLOCK|SAFETY_BLOCK_NOT_IN_STRATEGY_TESTER|tester-only safety gate') {
        throw "A tester-only live-chart/order gate remains in downloaded source."
    }
    foreach ($includeName in $IncludeNames) {
        if ($newSource -notmatch [regex]::Escape("#include <STB\$includeName>") -and
            $newSource -notmatch [regex]::Escape("#include <STB\$($includeName -replace '\.mqh$','')")) {
            # Accept the canonical MQL5 backslash include spelling as well.
            $includePattern = '#include\s*[<"]STB[\\/]' + [regex]::Escape($includeName) + '[>"]'
            if ($newSource -notmatch $includePattern) {
                throw "Source does not include expected module: $includeName"
            }
        }
    }
    $resolver = Get-Content -LiteralPath (Join-Path $Work "STB_PendingDistanceResolver.mqh") -Raw
    $trail = Get-Content -LiteralPath (Join-Path $Work "STB_PendingTrail.mqh") -Raw
    if ($resolver -notmatch 'STB_TickAlignPriceDirectional' -or
        $trail -notmatch 'lastProcessedM5Bar' -or
        $trail -notmatch 'STB_PendingTrailRebuildFromTerminal') {
        throw "Downloaded pending-trailing modules failed integrity checks."
    }
    Write-Host "Pinned source and module checks passed: $Commit" -ForegroundColor Green

    Write-Host "=== 2. BACKUP CURRENT SOURCE, EX5 AND MODULES ===" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        Copy-Item -LiteralPath $Source -Destination (Join-Path $Backup "SmartTradingBot_FINAL.before.mq5") -Force
    } else {
        throw "Current EA source is missing: $Source"
    }
    $hadEx5 = Test-Path -LiteralPath $Ex5 -PathType Leaf
    if ($hadEx5) {
        Copy-Item -LiteralPath $Ex5 -Destination (Join-Path $Backup "SmartTradingBot_FINAL.before.ex5") -Force
    }
    $existingModules = @{}
    foreach ($name in $IncludeNames) {
        $target = Join-Path $IncludeRoot $name
        $existingModules[$name] = Test-Path -LiteralPath $target -PathType Leaf
        if ($existingModules[$name]) {
            Copy-Item -LiteralPath $target -Destination (Join-Path $Backup "$name.before") -Force
        }
    }

    Write-Host "=== 3. INSTALL INTO ORIGINAL EA LOCATION ===" -ForegroundColor Cyan
    try {
        Copy-Item -LiteralPath (Join-Path $Work "SmartTradingBot_FINAL.mq5") -Destination $Source -Force
        foreach ($name in $IncludeNames) {
            Copy-Item -LiteralPath (Join-Path $Work $name) -Destination (Join-Path $IncludeRoot $name) -Force
        }

        Write-Host "=== 4. COMPILE ORIGINAL EA ===" -ForegroundColor Cyan
        $compileArgs = '/compile:"' + $Source + '" /log:"' + $Log + '"'
        $proc = Start-Process -FilePath $MetaEditor -ArgumentList $compileArgs -Wait -PassThru -WindowStyle Hidden
        $logText = if (Test-Path -LiteralPath $Log) { Get-Content -LiteralPath $Log -Raw } else { "" }
        if ($logText -notmatch '(?i)\b0 errors?,\s*0 warnings?\b' -or
            -not (Test-Path -LiteralPath $Ex5 -PathType Leaf)) {
            throw "Compile not verified. MetaEditor exit=$($proc.ExitCode); log=$Log"
        }

        Write-Host "=== DEPLOYMENT SUCCESS ===" -ForegroundColor Green
        Write-Host "EA source: $Source"
        Write-Host "Compiled EX5: $Ex5"
        Write-Host "Git commit: $Commit"
        Write-Host "Compile log: $Log"
        Write-Host "Backup: $Backup"
        Write-Host "Defaults: AUTO trading ON; risk-based sizing ON (0.25% target risk, input validation cap 1%)."
        Write-Host "Daily loss guard, quote checks, broker stop validation and initial-SL verification remain active."
        Write-Host "The script did not attach the EA to a chart or submit orders."
    } catch {
        Write-Warning "Install/compile failed. Restoring backed-up files."
        Copy-Item -LiteralPath (Join-Path $Backup "SmartTradingBot_FINAL.before.mq5") -Destination $Source -Force
        foreach ($name in $IncludeNames) {
            $target = Join-Path $IncludeRoot $name
            if ($existingModules[$name]) {
                Copy-Item -LiteralPath (Join-Path $Backup "$name.before") -Destination $target -Force
            } else {
                Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
            }
        }
        if (Test-Path -LiteralPath (Join-Path $Backup "SmartTradingBot_FINAL.before.ex5")) {
            Copy-Item -LiteralPath (Join-Path $Backup "SmartTradingBot_FINAL.before.ex5") -Destination $Ex5 -Force
        } elseif (-not $hadEx5) {
            Remove-Item -LiteralPath $Ex5 -Force -ErrorAction SilentlyContinue
        }
        throw
    }
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
