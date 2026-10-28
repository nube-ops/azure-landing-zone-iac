function Get-PlatformTeam {
    <#
    .SYNOPSIS
        The single reader for platform-teams.json. Returns each team plus the governance tags
        its resources must carry (same keys the tag-guard policy and connectivity.bicep use).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Workload
    )

    if (-not (Test-Path -LiteralPath $Path)) { throw "Get-PlatformTeam: file not found: $Path" }
    $environment = Split-Path (Split-Path (Resolve-Path -LiteralPath $Path).Path) -Leaf   # .../environments/<env>/file

    $teams = @((Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json).platformTeams)
    if ($Workload) { $teams = @($teams | Where-Object targetSubscriptionWorkload -eq $Workload) }
    if (-not $teams) { throw "Get-PlatformTeam: no team found$(if ($Workload) { " for workload '$Workload'" }) in '$Path'." }

    foreach ($team in $teams) {
        $missing = @('name', 'slug', 'costCenter', 'targetSubscriptionWorkload') | Where-Object { -not $team.$_ }
        if ($missing) { throw "Get-PlatformTeam: team '$($team.name)' is missing $($missing -join ', ')." }

        $team | Add-Member -NotePropertyName Tags -NotePropertyValue ([ordered]@{
            Owner       = $team.name
            CostCenter  = $team.costCenter
            Environment = $environment
            Domain      = $team.targetSubscriptionWorkload
        }) -Force -PassThru
    }
}