#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TerminalData = "$env:APPDATA\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87",
    [string]$MetaEditor = "C:\Program Files\Orbex Global MT5\MetaEditor64.exe"
)
$ErrorActionPreference = "Stop"
$Branch = "pending-trail-investigation-20261022"
$ExpectedHash = "221B02552C38A1E3380B0CACC2617976577F55553B863D5FA5C981056F6E9F03"
$Source = Join-Path $TerminalData "MQL5\Experts\SmartTradingBot_FINAL.mq5"
$Recovered = Join-Path $TerminalData "MQL5\_recovered_original\STB_Trail_20261022_065649\SmartTradingBot_FINAL.mq5"
$IncludeRoot = Join-Path $TerminalData "MQL5\Include\STB"
$Ex5 = [IO.Path]::ChangeExtension($Source, ".ex5")
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $TerminalData "MQL5\_backups\STB_PendingTrailFix_$Stamp"
$Work = Join-Path $env:TEMP "STB_PendingTrailFix_$Stamp"
$Log = Join-Path $Backup "MetaEditorCompile.log"
$Names = @("STB_PendingDistanceResolver.mqh", "STB_PendingTrail.mqh")

foreach ($p in @($Recovered, $Source, $MetaEditor, (Join-Path $IncludeRoot $Names[0]), (Join-Path $IncludeRoot $Names[1]))) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Required file missing: $p" }
}
$hash = (Get-FileHash -LiteralPath $Recovered -Algorithm SHA256).Hash.ToUpperInvariant()
if ($hash -ne $ExpectedHash) { throw "Recovered-original hash mismatch; nothing changed. Actual=$hash" }
$originalText = Get-Content -LiteralPath $Recovered -Raw
if ($originalText -notmatch 'SAFETY_BLOCK_NOT_IN_STRATEGY_TESTER' -or
    $originalText -notmatch 'STB MANUAL PENDING REJECTED: tester-only safety gate\.' -or
    $originalText -notmatch 'STB HEDGE REJECTED: tester-only safety gate\.') {
    throw "Expected Strategy-Tester-only safeguards were not verified; nothing changed."
}
if ($originalText -notmatch '(?i)#include\s*[<"]STB[\\/]+STB_PendingTrail\.mqh[>"]' -or
    $originalText -notmatch '(?i)#include\s*[<"]STB[\\/]+STB_PendingDistanceResolver\.mqh[>"]') {
    throw "Recovered source doesn't include both pending-trail modules; nothing changed."
}

New-Item -ItemType Directory -Path $Backup -Force | Out-Null
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Raw = "https://raw.githubusercontent.com/aliaskari56/SmartTradingBot-Production/$Branch/MQL5/Include/STB"
foreach ($name in $Names) {
    Invoke-WebRequest -UseBasicParsing -Uri "$Raw/$name" -OutFile (Join-Path $Work $name)
}
$trailText = Get-Content -LiteralPath (Join-Path $Work "STB_PendingTrail.mqh") -Raw
$resolverText = Get-Content -LiteralPath (Join-Path $Work "STB_PendingDistanceResolver.mqh") -Raw
if ($trailText -notmatch 'Keep the anchor reconstructed from the CURRENT order geometry' -or
    $trailText -notmatch 'extreme=\(orderType==\(long\)ORDER_TYPE_BUY_STOP\s*\?\s*barLow:barHigh\)' -or
    $resolverText -notmatch 'STB_TickAlignPriceDirectional' -or
    $resolverText -notmatch 'BUY_STOP_NO_FAVORABLE_VALID_ENTRY' -or
    $resolverText -notmatch 'SELL_STOP_NO_FAVORABLE_VALID_ENTRY') {
    throw "Downloaded patch failed integrity checks; nothing changed."
}

Copy-Item -LiteralPath $Source -Destination (Join-Path $Backup "SmartTradingBot_FINAL.before.mq5") -Force
$hadEx5 = Test-Path -LiteralPath $Ex5 -PathType Leaf
if ($hadEx5) { Copy-Item -LiteralPath $Ex5 -Destination (Join-Path $Backup "SmartTradingBot_FINAL.before.ex5") -Force }
foreach ($name in $Names) {
    Copy-Item -LiteralPath (Join-Path $IncludeRoot $name) -Destination (Join-Path $Backup "$name.before") -Force
}
try {
    Copy-Item -LiteralPath $Recovered -Destination $Source -Force
    foreach ($name in $Names) { Copy-Item -LiteralPath (Join-Path $Work $name) -Destination (Join-Path $IncludeRoot $name) -Force }
    $compileArgs = '/compile:"' + $Source + '" /log:"' + $Log + '"'
    $proc = Start-Process -FilePath $MetaEditor -ArgumentList $compileArgs -Wait -PassThru -WindowStyle Hidden
    $logText = if (Test-Path -LiteralPath $Log) { Get-Content -LiteralPath $Log -Raw } else { "" }
    if ($logText -notmatch '(?i)\b0 errors?,\s*0 warnings?\b' -or -not (Test-Path -LiteralPath $Ex5 -PathType Leaf)) {
        throw "Compile not verified. MetaEditor exit=$($proc.ExitCode); log=$Log"
    }
    Write-Host "FIX INSTALLED; COMPILE VERIFIED: 0 errors, 0 warnings." -ForegroundColor Green
    Write-Host "Original source restored: $Source"
    Write-Host "Patched includes: $IncludeRoot"
    Write-Host "Backup: $Backup"
    Write-Host "Compile log: $Log"
    Write-Host "The script did not attach the EA to a chart or submit orders."
} catch {
    Write-Warning "Installing/compiling failed. Restoring all files backed up by this script."
    Copy-Item -LiteralPath (Join-Path $Backup "SmartTradingBot_FINAL.before.mq5") -Destination $Source -Force
    foreach ($name in $Names) { Copy-Item -LiteralPath (Join-Path $Backup "$name.before") -Destination (Join-Path $IncludeRoot $name) -Force }
    if (Test-Path -LiteralPath (Join-Path $Backup "SmartTradingBot_FINAL.before.ex5")) {
        Copy-Item -LiteralPath (Join-Path $Backup "SmartTradingBot_FINAL.before.ex5") -Destination $Ex5 -Force
    } elseif (-not $hadEx5) {
        Remove-Item -LiteralPath $Ex5 -Force -ErrorAction SilentlyContinue
    }
    throw
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
