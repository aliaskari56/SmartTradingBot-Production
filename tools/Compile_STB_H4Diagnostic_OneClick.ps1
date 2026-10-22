# SmartTradingBot H4 diagnostic source installer; compile only, no EA attach or order submission.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TerminalRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\3C7BBB4F3CD116F4C39A2AB44A72DD87'
$MetaEditor = 'C:\Program Files\Orbex Global MT5\MetaEditor64.exe'
$Repo = 'aliaskari56/SmartTradingBot-Production'
$Commit = '985ebc67258fdcaf86266c54b0b421ec00d073b7'
$Files = @(
 [pscustomobject]@{RepoPath='MQL5/Experts/SmartTradingBot_FINAL.mq5'; Relative='MQL5\Experts\SmartTradingBot_FINAL.mq5'; Blob='dde006386d29c46729d9372756da9cc59f4a8e83'},
 [pscustomobject]@{RepoPath='MQL5/Include/STB/STB_LRN04Journal.mqh'; Relative='MQL5\Include\STB\STB_LRN04Journal.mqh'; Blob='09533d1ac67a03145d53a5b0d68a6104ea14148d'},
 [pscustomobject]@{RepoPath='MQL5/Include/STB/STB_PendingDistanceResolver.mqh'; Relative='MQL5\Include\STB\STB_PendingDistanceResolver.mqh'; Blob='2fdcbd6414697284d4406d09d30db519a0770f50'},
 [pscustomobject]@{RepoPath='MQL5/Include/STB/STB_PendingTrail.mqh'; Relative='MQL5\Include\STB\STB_PendingTrail.mqh'; Blob='ed4ad0b61a779a50182fd5e9eaa6bbeaaf0fe49f'}
)
function Get-GitBlobSha1([byte[]]$Bytes) {
 $header = [System.Text.Encoding]::ASCII.GetBytes(('blob ' + $Bytes.Length + [char]0))
 $joined = New-Object byte[] ($header.Length + $Bytes.Length)
 [Array]::Copy($header,0,$joined,0,$header.Length); [Array]::Copy($Bytes,0,$joined,$header.Length,$Bytes.Length)
 $sha = [System.Security.Cryptography.SHA1]::Create()
 try { ([BitConverter]::ToString($sha.ComputeHash($joined))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Restore-ItemState($Item,$BackupRoot,$Root) {
 $dest = Join-Path $Root $Item.Relative; $saved = Join-Path $BackupRoot $Item.Relative
 if (Test-Path -LiteralPath $saved) { New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null; Copy-Item -LiteralPath $saved -Destination $dest -Force }
 elseif (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
}
Write-Host '=== PREFLIGHT ===' -ForegroundColor Cyan
if (!(Test-Path -LiteralPath $MetaEditor -PathType Leaf)) { throw "MetaEditor not found: $MetaEditor" }
if (!(Test-Path -LiteralPath $TerminalRoot -PathType Container)) { throw "MT5 data directory not found: $TerminalRoot" }
$Mql5Root = Join-Path $TerminalRoot 'MQL5'
if (!(Test-Path -LiteralPath (Join-Path $Mql5Root 'Experts') -PathType Container)) { throw "MQL5\Experts not found" }
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$BackupRoot = Join-Path $Mql5Root "_backups\STB_H4DiagnosticCompile_$Stamp"
$DownloadRoot = Join-Path $env:TEMP "STB_$Commit"
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $DownloadRoot -Force | Out-Null
Write-Host "Pinned commit: $Commit" -ForegroundColor Gray
Write-Host '=== DOWNLOAD + VERIFY GIT BLOBS ===' -ForegroundColor Cyan
foreach ($item in $Files) {
 $download = Join-Path $DownloadRoot ($item.RepoPath -replace '/','__')
 $uri = "https://raw.githubusercontent.com/$Repo/$Commit/$($item.RepoPath)"
 Invoke-WebRequest -Uri $uri -OutFile $download
 $bytes = [System.IO.File]::ReadAllBytes($download)
 $actual = Get-GitBlobSha1 $bytes
 if ($actual -ne $item.Blob) { throw "Blob verification failed for $($item.RepoPath): $actual" }
 $item | Add-Member -NotePropertyName DownloadPath -NotePropertyValue $download -Force
 Write-Host "OK $($item.RepoPath) ($($bytes.Length) bytes)" -ForegroundColor Green
}
$sourceItem = $Files | Where-Object {$_.RepoPath -eq 'MQL5/Experts/SmartTradingBot_FINAL.mq5'} | Select-Object -First 1
$sourceText = [System.IO.File]::ReadAllText($sourceItem.DownloadPath)
foreach ($inc in @('#include <STB\STB_LRN04Journal.mqh>','#include <STB\STB_PendingDistanceResolver.mqh>','#include <STB\STB_PendingTrail.mqh>')) {
 if (!$sourceText.Contains($inc)) { throw "Source dependency check failed: $inc" }
}
$Ex5Path = Join-Path $Mql5Root 'Experts\SmartTradingBot_FINAL.ex5'
$Ex5Relative = 'MQL5\Experts\SmartTradingBot_FINAL.ex5'
foreach ($item in $Files) {
 $dest = Join-Path $TerminalRoot $item.Relative
 if (Test-Path -LiteralPath $dest) {
  $saved = Join-Path $BackupRoot $item.Relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
  Copy-Item -LiteralPath $dest -Destination $saved -Force
 }
}
if (Test-Path -LiteralPath $Ex5Path) { Copy-Item -LiteralPath $Ex5Path -Destination (Join-Path $BackupRoot $Ex5Relative) -Force }
$installStarted = $false
try {
 Write-Host '=== INSTALL VERIFIED SOURCE/MODULES ===' -ForegroundColor Cyan
 $installStarted = $true
 foreach ($item in $Files | Where-Object {$_.RepoPath -ne 'MQL5/Experts/SmartTradingBot_FINAL.mq5'}) {
  $dest = Join-Path $TerminalRoot $item.Relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
  Copy-Item -LiteralPath $item.DownloadPath -Destination $dest -Force
 }
 $srcDest = Join-Path $TerminalRoot $sourceItem.Relative
 Copy-Item -LiteralPath $sourceItem.DownloadPath -Destination $srcDest -Force
 Write-Host '=== COMPILE ===' -ForegroundColor Cyan
 $log = Join-Path $BackupRoot 'MetaEditorCompile.log'
 $compileArgs = @('/compile:"' + $srcDest + '"','/log:"' + $log + '"')
 $proc = Start-Process -FilePath $MetaEditor -ArgumentList $compileArgs -Wait -PassThru
 Start-Sleep -Seconds 2
 if (!(Test-Path -LiteralPath $log -PathType Leaf)) { throw "Compile log missing; MetaEditor exit=$($proc.ExitCode)" }
 $logText = [System.IO.File]::ReadAllText($log); Write-Host $logText
 $em = [regex]::Match($logText,'(?im)(\d+)\s+errors?'); $wm = [regex]::Match($logText,'(?im)(\d+)\s+warnings?')
 $errors = if ($em.Success) {[int]$em.Groups[1].Value} else {-1}
 $warnings = if ($wm.Success) {[int]$wm.Groups[1].Value} else {-1}
 if ($errors -ne 0 -or !(Test-Path -LiteralPath $Ex5Path -PathType Leaf)) { throw "Compile not verified clean: errors=$errors warnings=$warnings exit=$($proc.ExitCode)" }
 Write-Host '=== SUCCESS ===' -ForegroundColor Green
 Write-Host "Errors=$errors Warnings=$warnings EX5=$Ex5Path"
 Write-Host "Backup and log: $BackupRoot"
 Write-Host 'Not attached to a chart; AutoTrading not enabled; no trades submitted.' -ForegroundColor Yellow
} catch {
 Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
 if ($installStarted) {
  Write-Host 'Rolling back prior files...' -ForegroundColor Yellow
  foreach ($item in $Files) { Restore-ItemState $item $BackupRoot $TerminalRoot }
  $savedEx5 = Join-Path $BackupRoot $Ex5Relative
  if (Test-Path -LiteralPath $savedEx5) { Copy-Item -LiteralPath $savedEx5 -Destination $Ex5Path -Force }
  elseif (Test-Path -LiteralPath $Ex5Path) { Remove-Item -LiteralPath $Ex5Path -Force }
  Write-Host "Rollback done. Backup/log: $BackupRoot" -ForegroundColor Yellow
 }
 throw
}
