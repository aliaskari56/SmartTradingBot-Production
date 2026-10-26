#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE 'Downloads\SmartTradingBot-Packages')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$main = Join-Path $root 'MQL5\Experts\SmartTradingBot_FINAL.mq5'
$includeRoot = Join-Path $root 'MQL5\Include'

if (-not (Test-Path -LiteralPath $main -PathType Leaf)) {
    throw "Primary EA source not found: $main"
}
if (-not (Test-Path -LiteralPath $includeRoot -PathType Container)) {
    throw "MQL5 Include directory not found: $includeRoot"
}

$includePattern = '^\s*#include\s*([<"])([^>"]+)[>"]'
$pending = [System.Collections.Generic.Stack[string]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$pending.Push((Resolve-Path -LiteralPath $main).Path)

while ($pending.Count -gt 0) {
    $current = $pending.Pop()
    $currentFull = [System.IO.Path]::GetFullPath($current)
    if (-not $seen.Add($currentFull)) { continue }

    $text = Get-Content -LiteralPath $currentFull -Raw
    foreach ($match in [regex]::Matches($text, $includePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
        $kind = $match.Groups[1].Value
        $includeName = $match.Groups[2].Value.Replace('/', '\')
        if ($kind -eq '<') {
            $candidate = Join-Path $includeRoot $includeName
        } else {
            $candidate = Join-Path (Split-Path -Parent $currentFull) $includeName
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                # Some projects use quoted paths rooted at MQL5/Include.
                $candidate = Join-Path $includeRoot $includeName
            }
        }

        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Missing include '$includeName' referenced by '$currentFull'. Package not created."
        }
        $pending.Push((Resolve-Path -LiteralPath $candidate).Path)
    }
}

$files = [System.Collections.Generic.List[string]]::new()
foreach ($path in $seen) {
    $relative = [System.IO.Path]::GetRelativePath($root, $path)
    if ($relative.StartsWith('..')) {
        throw "Dependency resolves outside repository root: $path"
    }
    if ([System.IO.Path]::GetExtension($relative) -notin @('.mq5', '.mqh')) {
        throw "Unexpected dependency type in include closure: $relative"
    }
    $files.Add($relative)
}
$files.Sort([System.StringComparer]::OrdinalIgnoreCase)

$readme = Join-Path $root 'README.md'
if (Test-Path -LiteralPath $readme -PathType Leaf) { $files.Add('README.md') }

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$out = (Resolve-Path -LiteralPath $OutputDirectory).Path
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$packageName = "SmartTradingBot_SourceOnly_$stamp"
$stage = Join-Path $env:TEMP $packageName
$zipPath = Join-Path $out "$packageName.zip"

if (Test-Path -LiteralPath $stage) { throw "Temporary staging path already exists: $stage" }
if (Test-Path -LiteralPath $zipPath) { throw "Output package already exists: $zipPath" }

New-Item -ItemType Directory -Path $stage | Out-Null
try {
    foreach ($relative in $files) {
        $sourcePath = Join-Path $root $relative
        $destPath = Join-Path $stage $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destPath) -Force | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $destPath
    }

    $manifest = foreach ($relative in ($files | Sort-Object)) {
        $copied = Join-Path $stage $relative
        $hash = (Get-FileHash -LiteralPath $copied -Algorithm SHA256).Hash
        [pscustomobject]@{ Path = $relative.Replace('\', '/'); SHA256 = $hash }
    }
    $manifestPath = Join-Path $stage 'SOURCE_SHA256_MANIFEST.csv'
    $manifest | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

    $sourceText = Get-Content -LiteralPath (Join-Path $stage 'MQL5\Experts\SmartTradingBot_FINAL.mq5') -Raw
    $versionMatch = [regex]::Match($sourceText, '(?m)^\s*#property\s+version\s+"([^"]+)"')
    $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { 'unknown' }
    $packageNote = @"
SmartTradingBot source-only package
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')
Source version property: $version

This package contains the primary EA and its recursively discovered .mqh include dependencies.
No .ex5 binary, terminal profile, credentials, .set file, logs, backups, or temporary artifacts are included.
The SHA-256 manifest covers each copied source/document file; the manifest does not hash itself.

Important: source packaging is not a compiler or runtime validation. Compile this exact source in MetaEditor and run the documented controlled tests before any deployment. This package does not certify strategy performance or live-trading readiness.
"@
    Set-Content -LiteralPath (Join-Path $stage 'PACKAGE_README.txt') -Value $packageNote -Encoding UTF8

    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    [pscustomobject]@{
        Package = $zipPath
        SourceVersion = $version
        SourceFiles = $files.Count
        PackageSHA256 = $zipHash
        IncludesEX5 = $false
    } | Format-List
}
finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
