function Get-BicepParamConfig {
    <#
    .SYNOPSIS
        Reads the values the bootstrap scripts need from a main.bicepparam file.
    .DESCRIPTION
        The single reader for main.bicepparam. The Bicep compiler evaluates the file (variables,
        string interpolation, types) and this function reads the resulting parameters JSON, so no
        text is parsed with regular expressions.

        Returns OrgName, GeoPrefix, PrimaryLocation, PrimaryRegionCode and Subscriptions
        (a hashtable of workload name -> subscription ID). Throws if the file does not compile
        or does not contain what the bootstrap needs.

        Needs the Bicep CLI that 'az bicep' manages (installed automatically on first use).
    .EXAMPLE
        $config = Get-BicepParamConfig -Path ./environments/prod/main.bicepparam
        $config.Subscriptions['corp']
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $outFile = Join-Path ([IO.Path]::GetTempPath()) "bicepparam-$([guid]::NewGuid()).json"
    try {
        $log = az bicep build-params --file $Path --outfile $outFile --no-restore 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outFile)) {
            $problems = @($log | Where-Object { "$_" -notmatch '^WARNING' }) -join "`n"
            throw "Get-BicepParamConfig: 'az bicep build-params' failed for '$Path'.`n$problems"
        }
        $parameters = (Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json).parameters
    }
    finally {
        Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    }

    $primary = @($parameters.regionalConfig.value | Where-Object { $_.isPrimary }) | Select-Object -First 1

    # Workload = last segment of the management group name (mg-<org>-<geo>-<workload>).
    $subscriptions = @{}
    foreach ($association in $parameters.subscriptionAssociations.value) {
        if ($association.subscriptionIds.Count -gt 0) {
            $subscriptions[($association.mgName -split '-')[-1]] = $association.subscriptionIds[0]
        }
    }

    $missing = @(
        if (-not $parameters.orgName.value)   { 'orgName' }
        if (-not $parameters.geoPrefix.value) { 'geoPrefix' }
        if (-not $primary)                    { 'a regionalConfig entry with isPrimary: true' }
        if (-not $subscriptions.Count)        { 'subscriptionAssociations with subscription IDs' }
    )
    if ($missing) { throw "Get-BicepParamConfig: '$Path' is missing $($missing -join ', ')." }

    [pscustomobject]@{
        OrgName                   = $parameters.orgName.value
        GeoPrefix                 = $parameters.geoPrefix.value
        PrimaryLocation           = $primary.location
        PrimaryRegionCode         = $primary.regionCode
        Subscriptions             = $subscriptions
        IdentityResourceGroupName = "rg-mgmt-identity-$($primary.regionCode)-01"
    }
}