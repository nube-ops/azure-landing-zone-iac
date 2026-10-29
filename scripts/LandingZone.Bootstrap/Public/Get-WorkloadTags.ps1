function Get-WorkloadTags {
    <#
    .SYNOPSIS
        Builds the governance tag set for a workload from workloads.json.
    .DESCRIPTION
        Mirrors resolveTags() in modules/resource-groups/tags.bicep: tag values from the
        file, then Environment and Domain injected (these win on a clash).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Environment,
        [Parameter(Mandatory)][string]$Path
    )

    $entry = (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json).workloads.$Workload
    if (-not $entry) { throw "No entry for workload '$Workload' in $Path. Add one with a 'tags' block." }

    $tags = @{ Owner = $entry.team.name }                         # default: accountable team
    foreach ($p in $entry.tags.PSObject.Properties) { $tags[$p.Name] = $p.Value }   # explicit tags win
    $tags['Environment'] = $Environment
    $tags['Domain']      = $Workload
    $tags
}