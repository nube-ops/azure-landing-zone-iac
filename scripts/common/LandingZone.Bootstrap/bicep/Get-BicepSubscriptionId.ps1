function Get-BicepSubscriptionId {
    <#
    .SYNOPSIS
        Returns the first subscription ID mapped to a workload in main.bicepparam, or $null.
    .NOTES
        Data only, never throws. Test-BicepParamFile is what reports a missing or
        placeholder mapping, so the pipeline order is: check first, derive after.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BicepParamPath,
        [Parameter(Mandatory)][string]$Workload
    )

    if (-not (Test-Path -LiteralPath $BicepParamPath -PathType Leaf)) { return $null }

    $content = Get-Content -LiteralPath $BicepParamPath -Raw
    $pattern = "mgName:\s*'[^']*-$([regex]::Escape($Workload))'\s*subscriptionIds:\s*\[\s*'([^']+)'"
    if ($content -match $pattern) { $Matches[1] }
}