# scripts/LandingZone.Bootstrap/Public/WorkloadManifest.ps1
#
# Single reader of environments/<env>/workloads.json.
# Structure and required keys (team.*, tags.Owner, tags.CostCenter) are enforced by
# workloads.schema.json via Test-JsonFile in preflight Stage 1; this file only resolves data.
# The preflight adapter (Test-WorkloadTags) lives in Preflight.Checks.ps1.

function Get-WorkloadTags {
    <#
    .SYNOPSIS
        Resolves the tag set for a workload from workloads.json.
    .DESCRIPTION
        Returns the workload's 'tags' block verbatim, plus two derived tags:
          Environment : from the -Environment parameter (the environment folder is its source)
          Domain      : the workload name (matches connectivity.bicep)
        Derived values are applied last so a stray key in the JSON can never cause drift.
        Throws a descriptive error if the workload is not defined.
    .EXAMPLE
        Get-WorkloadTags -Workload identity -Environment prod -Path .\environments\prod\workloads.json
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Environment,
        [Parameter(Mandatory)][string]$Path
    )

    $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable

    if (-not $manifest.ContainsKey('workloads') -or -not $manifest.workloads.ContainsKey($Workload)) {
        throw "Workload '$Workload' is not defined under 'workloads' in $Path."
    }

    # Copy into a plain hashtable so the parsed manifest is never mutated.
    $tags = @{}
    foreach ($key in $manifest.workloads[$Workload].tags.Keys) {
        $tags[$key] = $manifest.workloads[$Workload].tags[$key]
    }

    $tags['Environment'] = $Environment
    $tags['Domain']      = $Workload
    $tags
}