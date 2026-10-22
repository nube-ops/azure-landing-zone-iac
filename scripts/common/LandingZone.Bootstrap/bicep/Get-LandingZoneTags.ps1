function Get-LandingZoneTags {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Workload)
    # Source of Owner/CostCenter: platform-teams.json, matched on targetSubscriptionWorkload.
    $team = $Config.PlatformTeams | Where-Object targetSubscriptionWorkload -eq $Workload
    @{ Owner = $team.name; CostCenter = $team.costCenter; Environment = $Config.Environment; Domain = $Workload }
}

function Test-RequiredTagsCovered {
    [CmdletBinding()] param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Workload)
    $tags    = Get-LandingZoneTags -Config $Config -Workload $Workload
    $missing = @($Config.RequiredTags | Where-Object { [string]::IsNullOrWhiteSpace($tags[$_]) })
    New-CheckResult -Name "Tags[$Workload]" -Passed ($missing.Count -eq 0) `
        -Message $(if ($missing) { "No value for: $($missing -join ', ')" } else { 'All policy-required tags have values.' }) `
        -Remediation 'Add the team to platform-teams.json or extend Get-LandingZoneTags; tag-guard will Deny untagged resources.'
}