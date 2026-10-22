function Test-Tooling {
    [CmdletBinding()]
    param(
        [string]$ManifestPath = (Join-Path $PSScriptRoot '../prerequisites.psd1'),
        [string[]]$Tool        # optional subset, e.g. -Tool az,bicep
    )
    $manifest = Import-PowerShellDataFile -Path $ManifestPath

    $pwshMin = [version]$manifest.PowerShell.Minimum
    New-CheckResult 'PowerShell' ($PSVersionTable.PSVersion -ge $pwshMin) `
        "found $($PSVersionTable.PSVersion), need >= $pwshMin" $manifest.PowerShell.Fix

    foreach ($t in $manifest.Tools | Where-Object { -not $Tool -or $_.Name -in $Tool }) {
        $found = Get-ToolVersion -Name $t.Name
        $ok    = $null -ne $found -and $found -ge [version]$t.Minimum
        New-CheckResult $t.Name $ok `
            "found $(if ($found) { $found } else { 'none' }), need >= $($t.Minimum)" $t.Fix
    }
}