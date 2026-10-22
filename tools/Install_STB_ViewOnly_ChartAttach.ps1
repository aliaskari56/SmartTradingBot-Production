$ErrorActionPreference = 'Stop'

# Installs the latest branch revision that allows normal-chart attachment in
# explicit VIEW ONLY mode. Broker-facing trading remains Strategy-Tester-only.
$TerminalRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87'
$MetaEditor = 'C:\Program Files\Orbex Global MT5\MetaEditor64.exe'
$BranchArchive = 'https://github.com/aliaskari56/SmartTradingBot-Production/archive/refs/heads/fix/pending-stop-trail-geometry-20261022.zip'

$TargetMql5 = Join-Path $TerminalRoot 'MQL5'
$TargetSource = Join-Path $TargetMql5 'Experts\SmartTradingBot_FINAL.mq5'
$TargetEx5 = Join-Path $TargetMql5 'Experts\SmartTradingBot_FINAL.ex5'
$TargetInclude = Join-Path $TargetMql5 'Include\STB'

if (-not (Test-Path -LiteralPath $TerminalRoot -PathType Container)) {
    throw "MT5 terminal data folder was not found: $TerminalRoot"
}
if (-not (Test-Path -LiteralPath $MetaEditor -PathType Leaf)) {
    throw "MetaEditor was not found: $MetaEditor"
}

$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$WorkRoot = Join-Path $env:TEMP "STB_ViewOnly_ChartAttach_$Stamp"
$ArchivePath = Join-Path $WorkRoot 'source.zip'
$ExtractRoot = Join-Path $WorkRoot 'extracted'
$BackupRoot = Join-Path $TargetMql5 "_backups\STB_ViewOnly_ChartAttach_$Stamp"
New-Item -ItemType Directory -Force -Path $WorkRoot, $ExtractRoot, $BackupRoot | Out-Null

$Installed = $false
$HadSource = Test-Path -LiteralPath $TargetSource -PathType Leaf
$HadEx5 = Test-Path -LiteralPath $TargetEx5 -PathType Leaf
$HadInclude = Test-Path -LiteralPath $TargetInclude -PathType Container

try {
    Write-Host 'Downloading latest chart-attach fix from GitHub...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri $BranchArchive -OutFile $ArchivePath
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $ExtractRoot -Force

    $RepoSource = Get-ChildItem -LiteralPath $ExtractRoot -Filter 'SmartTradingBot_FINAL.mq5' -File -Recurse |
        Where-Object { $_.FullName -match '[\\/]MQL5[\\/]Experts[\\/]SmartTradingBot_FINAL\.mq5$' } |
        Select-Object -First 1
    if (-not $RepoSource) { throw 'SmartTradingBot_FINAL.mq5 was not found in the downloaded repository archive.' }
    $RepoMql5 = Split-Path (Split-Path $RepoSource.FullName -Parent) -Parent
    $RepoInclude = Join-Path $RepoMql5 'Include\STB'
    if (-not (Test-Path -LiteralPath $RepoInclude -PathType Container)) {
        throw "STB include folder is missing from the repository archive: $RepoInclude"
    }

    # Preserve all previous local files before replacing any of them.
    if ($HadSource) { Copy-Item -LiteralPath $TargetSource -Destination (Join-Path $BackupRoot 'SmartTradingBot_FINAL.mq5') -Force }
    if ($HadEx5) { Copy-Item -LiteralPath $TargetEx5 -Destination (Join-Path $BackupRoot 'SmartTradingBot_FINAL.ex5') -Force }
    if ($HadInclude) { Copy-Item -LiteralPath $TargetInclude -Destination (Join-Path $BackupRoot 'STB') -Recurse -Force }

    New-Item -ItemType Directory -Force -Path (Split-Path $TargetSource -Parent), (Split-Path $TargetInclude -Parent) | Out-Null
    Copy-Item -LiteralPath $RepoSource.FullName -Destination $TargetSource -Force
    if (Test-Path -LiteralPath $TargetInclude) { Remove-Item -LiteralPath $TargetInclude -Recurse -Force }
    Copy-Item -LiteralPath $RepoInclude -Destination $TargetInclude -Recurse -Force

    # Remove stale build artifacts so the compile check must produce a fresh EX5/log.
    Remove-Item -LiteralPath $TargetEx5 -Force -ErrorAction SilentlyContinue
    $CompileLog = [IO.Path]::ChangeExtension($TargetSource, '.log')
    Remove-Item -LiteralPath $CompileLog -Force -ErrorAction SilentlyContinue

    $SourceArg = '/compile:"' + $TargetSource + '"'
    $IncludeArg = '/include:"' + $TargetMql5 + '"'
    $CompileProcess = Start-Process -FilePath $MetaEditor -ArgumentList @('/portable', $SourceArg, $IncludeArg, '/log') -Wait -PassThru
    Start-Sleep -Seconds 2

    if (-not (Test-Path -LiteralPath $CompileLog -PathType Leaf)) {
        throw "MetaEditor did not create a compile log. Exit code: $($CompileProcess.ExitCode)"
    }
    $LogText = Get-Content -LiteralPath $CompileLog -Raw
    Write-Host $LogText
    if ($LogText -notmatch '(?i)\b0 errors?,\s*0 warnings?\b') {
        throw "Compile did not verify as 0 errors and 0 warnings. See: $CompileLog"
    }
    if (-not (Test-Path -LiteralPath $TargetEx5 -PathType Leaf)) {
        throw 'Compiler reported success but did not produce a fresh SmartTradingBot_FINAL.ex5.'
    }

    $Installed = $true
    Write-Host ''
    Write-Host 'INSTALLATION AND COMPILE VERIFIED: 0 errors, 0 warnings.' -ForegroundColor Green
    Write-Host "Source: $TargetSource"
    Write-Host "EX5:    $TargetEx5"
    Write-Host "Log:    $CompileLog"
    Write-Host "Backup: $BackupRoot"
    Write-Host 'Mode:   normal chart = VIEW ONLY; trade/order management is Strategy-Tester-only.' -ForegroundColor Yellow
    Write-Host 'The EA has not been attached to a chart by this script.'
}
catch {
    Write-Host "INSTALL FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Restoring previous source/includes/EX5 from backup when available...' -ForegroundColor Yellow

    if ($HadSource -and (Test-Path -LiteralPath (Join-Path $BackupRoot 'SmartTradingBot_FINAL.mq5'))) {
        Copy-Item -LiteralPath (Join-Path $BackupRoot 'SmartTradingBot_FINAL.mq5') -Destination $TargetSource -Force
    } elseif (-not $HadSource) {
        Remove-Item -LiteralPath $TargetSource -Force -ErrorAction SilentlyContinue
    }

    if ($HadEx5 -and (Test-Path -LiteralPath (Join-Path $BackupRoot 'SmartTradingBot_FINAL.ex5'))) {
        Copy-Item -LiteralPath (Join-Path $BackupRoot 'SmartTradingBot_FINAL.ex5') -Destination $TargetEx5 -Force
    } elseif (-not $HadEx5) {
        Remove-Item -LiteralPath $TargetEx5 -Force -ErrorAction SilentlyContinue
    }

    if ($HadInclude -and (Test-Path -LiteralPath (Join-Path $BackupRoot 'STB') -PathType Container)) {
        if (Test-Path -LiteralPath $TargetInclude) { Remove-Item -LiteralPath $TargetInclude -Recurse -Force }
        Copy-Item -LiteralPath (Join-Path $BackupRoot 'STB') -Destination $TargetInclude -Recurse -Force
    } elseif (-not $HadInclude) {
        Remove-Item -LiteralPath $TargetInclude -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Backup: $BackupRoot"
    throw
}
finally {
    if (-not $Installed) {
        Write-Host "Diagnostics retained at: $WorkRoot"
    }
}
