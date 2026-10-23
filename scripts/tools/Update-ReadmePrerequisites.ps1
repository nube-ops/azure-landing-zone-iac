#Requires -Version 7.4
<#
.SYNOPSIS
    Renders the prerequisites manifest into README.md between marker comments.
.DESCRIPTION
    Single source of truth: scripts/common/LandingZone.Bootstrap/prerequisites.psd1.
    Idempotent: writes only when the rendered block differs from what is in the README.
    Standalone by design (does not load the shared libraries), so it runs in a bare CI job.
.PARAMETER Check
    Read-only mode for CI. Exits 1 when the README is out of date.
.EXAMPLE
    pwsh ./scripts/tools/Update-ReadmePrerequisites.ps1
.EXAMPLE
    pwsh ./scripts/tools/Update-ReadmePrerequisites.ps1 -Check
#>
[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '../LandingZone.Bootstrap/prerequisites.psd1'),
    [string]$ReadmePath   = (Join-Path $PSScriptRoot '../../README.md'),
    [switch]$Check
)

$startMarker = '<!-- prerequisites:start -->'
$endMarker   = '<!-- prerequisites:end -->'

if (-not (Test-Path $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
if (-not (Test-Path $ReadmePath))   { throw "README not found: $ReadmePath" }

$manifest = Import-PowerShellDataFile -Path $ManifestPath

# 1. Render: manifest data -> markdown rows
$rows = @(
    '| Tool | Minimum version | Install |'
    '| :--- | :--- | :--- |'
    "| PowerShell | $($manifest.PowerShell.Minimum) | ``$($manifest.PowerShell.Fix)`` |"
)
$rows += foreach ($tool in $manifest.Tools) {
    "| $($tool.Name) | $($tool.Minimum) | ``$($tool.Fix)`` |"
}

# 2. Splice into the README, preserving its existing line endings
$readme  = Get-Content -Path $ReadmePath -Raw
$newline = if ($readme.Contains("`r`n")) { "`r`n" } else { "`n" }
$block   = $startMarker + $newline + ($rows -join $newline) + $newline + $endMarker
$pattern = '(?s)' + [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)

if ($readme -notmatch $pattern) {
    throw "Markers not found in $ReadmePath. Add '$startMarker' and '$endMarker' where the table belongs."
}
$updated = [regex]::Replace($readme, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block })

# 3. Check or write
if ($Check) {
    if ($updated -cne $readme) {
        Write-Error 'README prerequisites are out of date. Run: pwsh ./scripts/tools/Update-ReadmePrerequisites.ps1'
        exit 1
    }
    Write-Host '[OK] README prerequisites match the manifest.'
    return
}

if ($updated -ceq $readme) {
    Write-Host '[IDEMPOTENT] README already current.'
} else {
    Set-Content -Path $ReadmePath -Value $updated -NoNewline -Encoding utf8
    Write-Host '[UPDATED] README.md prerequisites table regenerated.'
}