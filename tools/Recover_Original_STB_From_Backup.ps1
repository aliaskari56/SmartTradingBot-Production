$ErrorActionPreference = 'Stop'

$TerminalRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87'
$OriginalBackup = Join-Path $TerminalRoot 'MQL5\_backups\STB_Trail_20261022_065649'
$RecoveryRoot = Join-Path $TerminalRoot 'MQL5\_recovered_original\STB_Trail_20261022_065649'

if (-not (Test-Path -LiteralPath $OriginalBackup -PathType Container)) {
    throw "Original backup folder not found: $OriginalBackup. No files were changed."
}

$candidates = @(Get-ChildItem -LiteralPath $OriginalBackup -Filter 'SmartTradingBot_FINAL.mq5' -File -Recurse -ErrorAction SilentlyContinue)
if ($candidates.Count -eq 0) {
    Write-Host 'No SmartTradingBot_FINAL.mq5 was found inside the first backup.' -ForegroundColor Red
    Write-Host 'Backup contents:'
    Get-ChildItem -LiteralPath $OriginalBackup -Force -Recurse | Select-Object FullName, Length | Format-Table -AutoSize
    throw 'Recovery stopped without modifying the installed EA.'
}

# Prefer a source file at the backup root; otherwise insist on a single candidate.
$rootCandidate = $candidates | Where-Object { $_.DirectoryName -eq $OriginalBackup } | Select-Object -First 1
if ($rootCandidate) {
    $sourceBackup = $rootCandidate
} elseif ($candidates.Count -eq 1) {
    $sourceBackup = $candidates[0]
} else {
    Write-Host 'Multiple possible original source files were found; nothing was copied.' -ForegroundColor Yellow
    $candidates | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
    throw 'Recovery stopped to avoid choosing the wrong EA file.'
}

if (Test-Path -LiteralPath $RecoveryRoot) {
    $RecoveryRoot = "$($RecoveryRoot)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}
New-Item -ItemType Directory -Force -Path $RecoveryRoot | Out-Null
$recoveredSource = Join-Path $RecoveryRoot 'SmartTradingBot_FINAL.mq5'
Copy-Item -LiteralPath $sourceBackup.FullName -Destination $recoveredSource -Force

# Preserve the complete original backup structure for inspection and matching includes.
$backupSnapshot = Join-Path $RecoveryRoot 'OriginalBackupSnapshot'
New-Item -ItemType Directory -Force -Path $backupSnapshot | Out-Null
Get-ChildItem -LiteralPath $OriginalBackup -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $backupSnapshot -Recurse -Force
}

$sourceHash = (Get-FileHash -LiteralPath $sourceBackup.FullName -Algorithm SHA256).Hash
$recoveredHash = (Get-FileHash -LiteralPath $recoveredSource -Algorithm SHA256).Hash
if ($sourceHash -ne $recoveredHash) {
    Remove-Item -LiteralPath $RecoveryRoot -Recurse -Force -ErrorAction SilentlyContinue
    throw 'SHA-256 verification failed. Recovered copy was removed; installed EA remains unchanged.'
}

$currentSource = Join-Path $TerminalRoot 'MQL5\Experts\SmartTradingBot_FINAL.mq5'
$currentHash = if (Test-Path -LiteralPath $currentSource -PathType Leaf) {
    (Get-FileHash -LiteralPath $currentSource -Algorithm SHA256).Hash
} else { 'CURRENT_SOURCE_NOT_FOUND' }

Write-Host ''
Write-Host 'ORIGINAL EA SOURCE RECOVERED AND HASH-VERIFIED.' -ForegroundColor Green
Write-Host "Source of truth: $($sourceBackup.FullName)"
Write-Host "Recovered copy:  $recoveredSource"
Write-Host "Original SHA256: $sourceHash"
Write-Host "Current SHA256:  $currentHash"
Write-Host "Backup snapshot: $backupSnapshot"
Write-Host ''
Write-Host 'No installed EA source or EX5 was overwritten. No compile was run.' -ForegroundColor Yellow
Write-Host 'The recovered original is separate from the view-only build and includes the backup snapshot.'
