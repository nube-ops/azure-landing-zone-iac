# Drop into LandingZone.Bootstrap (e.g. Public/WorkloadManifest.ps1) and export both functions.
#
# Assumed environments/<env>/workloads.json shape (keyed object: O(1) lookup, duplicate keys impossible):
# {
#   "workloads": {
#     "identity":     { "owner": "Identity Core", "costCenter": "CC-3000" },
#     "connectivity": { "owner": "Networking",    "costCenter": "CC-1000" }
#   }
# }

function Get-WorkloadTags {
    <#
    .SYNOPSIS
        Single owner of workloads.json semantics: resolves and validates a workload's tags.
        Throws a descriptive error if the entry is missing or incomplete.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Environment,
        [Parameter(Mandatory)][string]$Path
    )

    $manifest = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable

    if (-not $manifest.ContainsKey('workloads') -or -not $manifest.workloads.ContainsKey($Workload)) {
        throw "Workload '$Workload' is not defined under 'workloads' in $Path."
    }

    $entry   = $manifest.workloads[$Workload]
    $missing = @('owner', 'costCenter') | Where-Object { [string]::IsNullOrWhiteSpace($entry[$_]) }
    if ($missing) {
        throw "Workload '$Workload' in $Path is missing required field(s): $($missing -join ', ')."
    }

    # Keys mirror the tag-guard initiative (Owner, Environment, CostCenter) plus Domain (as in connectivity.bicep).
    @{
        Owner       = $entry.owner
        Environment = $Environment
        CostCenter  = $entry.costCenter
        Domain      = $Workload
    }
}

function Test-WorkloadTags {
    <#
    .SYNOPSIS
        Thin preflight adapter over Get-WorkloadTags. No validation logic lives here (DRY).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Environment,
        [Parameter(Mandatory)][string]$Path
    )

    # NOTE: New-PreflightResult stands in for however your module builds check objects
    # (I haven't seen LandingZone.Bootstrap). Match the shape Test-JsonFile already returns.
    try {
        $null = Get-WorkloadTags @PSBoundParameters
        New-PreflightResult -Name "Workload '$Workload' tag metadata" -Passed $true
    }
    catch {
        New-PreflightResult -Name "Workload '$Workload' tag metadata" -Passed $false -Message $_.Exception.Message
    }
}