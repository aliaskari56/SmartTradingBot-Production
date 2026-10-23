[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87',
    [string]$MetaEditor = 'C:\Program Files\Orbex Global MT5\metaeditor64.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'aliaskari56/SmartTradingBot-Production'
$Commit = '2ba8ec04a8471091aeb22f6da9c15af3e1be3bf0'
$ExpertPath = Join-Path $DataRoot 'MQL5\Experts\SmartTradingBot_FINAL.mq5'
$Mql5Root = Join-Path $DataRoot 'MQL5'
$Files = @(
    [pscustomobject]@{ Relative='MQL5\Experts\SmartTradingBot_FINAL.mq5'; RepoPath='MQL5/Experts/SmartTradingBot_FINAL.mq5'; BlobSha='0bba0788717bfb6e4bd0c4d3c32100687c2b994a' },
    [pscustomobject]@{ Relative='MQL5\Include\STB\STB_PendingTrail.mqh'; RepoPath='MQL5/Include/STB/STB_PendingTrail.mqh'; BlobSha='c92ff30492932f101d2edc4a6c250d859427a6eb' },
    [pscustomobject]@{ Relative='MQL5\Include\STB\STB_PendingDistanceResolver.mqh'; RepoPath='MQL5/Include/STB/STB_PendingDistanceResolver.mqh'; BlobSha='73c746cf7b79e8fe4c14cc025c40ecdfa6e6165a' }
)

function Get-GitBlobSha1([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $header = [System.Text.Encoding]::ASCII.GetBytes(("blob {0}" -f $bytes.Length) + [char]0)
    $combined = New-Object byte[] ($header.Length + $bytes.Length)
    [System.Buffer]::BlockCopy($header, 0, $combined, 0, $header.Length)
    [System.Buffer]::BlockCopy($bytes, 0, $combined, $header.Length, $bytes.Length)
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($combined))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

if (-not (Test-Path -LiteralPath $DataRoot -PathType Container)) { throw "MT5 DataRoot does not exist: $DataRoot" }
if (-not (Test-Path -LiteralPath $MetaEditor -PathType Leaf)) { throw "MetaEditor was not found: $MetaEditor" }
foreach ($item in $Files) {
    $target = Join-Path $DataRoot $item.Relative
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Expected existing source is missing; refusing deployment: $target" }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path $env:LOCALAPPDATA "SmartTradingBot\Backups\Deploy_UI_Control_Fix_$stamp"
$stageRoot = Join-Path $backupRoot 'staged'
$sourceBackupRoot = Join-Path $backupRoot 'original_sources'
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
New-Item -ItemType Directory -Path $sourceBackupRoot -Force | Out-Null
$ex5Path = [System.IO.Path]::ChangeExtension($ExpertPath, '.ex5')
$compileLog = [System.IO.Path]::ChangeExtension($ExpertPath, '.log')
$ex5BackupPath = Join-Path $backupRoot 'SmartTradingBot_FINAL.ex5.before'
$hadEx5 = Test-Path -LiteralPath $ex5Path -PathType Leaf
if ($hadEx5) { Copy-Item -LiteralPath $ex5Path -Destination $ex5BackupPath -Force }
foreach ($item in $Files) {
    $target = Join-Path $DataRoot $item.Relative
    $backup = Join-Path $sourceBackupRoot $item.Relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination $backup -Force
    Write-Host "BACKUP_SOURCE=$target"
}
$transactionStarted = $false
try {
    Write-Host "REPOSITORY=$Repo"
    Write-Host "COMMIT=$Commit"
    Write-Host "DATA_ROOT=$DataRoot"
    Write-Host "METAEDITOR=$MetaEditor"
    Write-Host "BACKUP=$backupRoot"

    # Download and verify ALL three source files before changing the terminal.
    foreach ($item in $Files) {
        $staged = Join-Path $stageRoot $item.Relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $staged) -Force | Out-Null
        $url = "https://raw.githubusercontent.com/$Repo/$Commit/$($item.RepoPath)"
        Invoke-WebRequest -Uri $url -OutFile $staged -UseBasicParsing -TimeoutSec 60
        $actual = Get-GitBlobSha1 $staged
        if ($actual -ne $item.BlobSha) { throw "Git blob SHA mismatch for $($item.RepoPath): expected $($item.BlobSha), got $actual" }
        Write-Host "VERIFIED_SOURCE=$($item.RepoPath)"
        Write-Host "GIT_BLOB_SHA=$actual"
    }

    # Install as one rollback-protected unit.
    $transactionStarted = $true
    foreach ($item in $Files) {
        $target = Join-Path $DataRoot $item.Relative
        $staged = Join-Path $stageRoot $item.Relative
        Copy-Item -LiteralPath $staged -Destination $target -Force
        $installed = Get-GitBlobSha1 $target
        if ($installed -ne $item.BlobSha) { throw "Installed file SHA mismatch for $($item.Relative): $installed" }
        Write-Host "INSTALLED=$target"
    }

    # Remove old compiler artifacts so the following result must be fresh.
    Remove-Item -LiteralPath $compileLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $ex5Path -Force -ErrorAction SilentlyContinue
    $compileArg = '/compile:"' + $ExpertPath + '"'
    $includeArg = '/include:"' + $Mql5Root + '"'
    $compileArgs = @('/portable', $compileArg, $includeArg, '/log')
    $proc = Start-Process -FilePath $MetaEditor -ArgumentList $compileArgs -Wait -PassThru
    Start-Sleep -Seconds 2
    if (-not (Test-Path -LiteralPath $compileLog -PathType Leaf)) { throw "MetaEditor did not create compile log (process exit $($proc.ExitCode)): $compileLog" }
    Copy-Item -LiteralPath $compileLog -Destination (Join-Path $backupRoot 'MetaEditor_compile.log') -Force
    $logText = Get-Content -LiteralPath $compileLog -Raw
    Write-Host '=== METAEDITOR COMPILE LOG ==='
    Write-Host $logText
    if ($logText -notmatch '(?i)\b0 errors?,\s*0 warnings?\b') { throw 'Compile log does not confirm zero errors and zero warnings.' }
    if (-not (Test-Path -LiteralPath $ex5Path -PathType Leaf)) { throw "Fresh EX5 was not created: $ex5Path" }

    foreach ($item in $Files) {
        $target = Join-Path $DataRoot $item.Relative
        if ((Get-GitBlobSha1 $target) -ne $item.BlobSha) { throw "Post-compile source verification failed: $target" }
    }
    $eaSha = (Get-FileHash -LiteralPath $ExpertPath -Algorithm SHA256).Hash
    $ex5Sha = (Get-FileHash -LiteralPath $ex5Path -Algorithm SHA256).Hash
    Write-Host '=== DEPLOYMENT COMPLETE ===' -ForegroundColor Green
    Write-Host 'COMPILE_RESULT=0 errors, 0 warnings'
    Write-Host "EA_SHA256=$eaSha"
    Write-Host "EX5_SHA256=$ex5Sha"
    Write-Host "BACKUP=$backupRoot"
    Write-Host 'NEXT: Reattach/reinitialize SmartTradingBot_FINAL in MT5. Verify STB UI BUTTONS SUMMARY shows ready=8, then test clicks ONLY in Strategy Tester/demo; watch for STB UI OBJECT_CLICK and STB UI CLICK RECEIVED logs.'
}
catch {
    Write-Host "DEPLOYMENT_FAILED=$($_.Exception.Message)" -ForegroundColor Red
    if ($transactionStarted) {
        Write-Host 'ROLLBACK_STARTING=TRUE' -ForegroundColor Yellow
        foreach ($item in $Files) {
            $target = Join-Path $DataRoot $item.Relative
            $backup = Join-Path $sourceBackupRoot $item.Relative
            if (Test-Path -LiteralPath $backup -PathType Leaf) { Copy-Item -LiteralPath $backup -Destination $target -Force }
        }
        if ($hadEx5) { Copy-Item -LiteralPath $ex5BackupPath -Destination $ex5Path -Force }
        else { Remove-Item -LiteralPath $ex5Path -Force -ErrorAction SilentlyContinue }
        $allRestored = $true
        foreach ($item in $Files) {
            $target = Join-Path $DataRoot $item.Relative
            $backup = Join-Path $sourceBackupRoot $item.Relative
            $same = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash
            Write-Host "SOURCE_RESTORED=$($item.Relative):$same"
            $allRestored = $allRestored -and $same
        }
        if ($hadEx5) {
            $sameEx5 = (Get-FileHash -LiteralPath $ex5Path -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $ex5BackupPath -Algorithm SHA256).Hash
            Write-Host "EX5_RESTORED=$sameEx5"
            $allRestored = $allRestored -and $sameEx5
        }
        Write-Host "ROLLBACK_COMPLETE=$allRestored"
        Write-Host "ROLLBACK_BACKUP=$backupRoot"
    }
    throw
}
