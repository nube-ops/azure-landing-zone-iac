function Get-TagDrift {
    <#
    .SYNOPSIS
        Pure function: returns the subset of Desired tags that are missing or different in Actual.
        Extra tags in Actual are ignored (merge semantics), so foreign tags are never reported as drift.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable]$Desired,
        [AllowNull()][hashtable]$Actual
    )

    # Azure tag NAMES are case-insensitive; VALUES are case-sensitive.
    $lookup = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ($Actual) {
        foreach ($key in $Actual.Keys) { $lookup[$key] = [string]$Actual[$key] }
    }

    $drift = @{}
    foreach ($key in $Desired.Keys) {
        $current = $null
        if (-not $lookup.TryGetValue($key, [ref]$current) -or $current -cne [string]$Desired[$key]) {
            $drift[$key] = $Desired[$key]
        }
    }
    $drift
}