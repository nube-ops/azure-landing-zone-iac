#Requires -Version 7.4
[CmdletBinding()]
param(
    [string]$Environment    = 'prod',
    [string[]]$Workload,       # optional subset; default = all    
    [string]$BicepParamPath = (Join-Path $PSScriptRoot "../../environments/$Environment/main.bicepparam"),
    [string]$WorkloadsPath  = (Join-Path $PSScriptRoot "../../environments/$Environment/workloads.json"),
    [string]$GitHubOwner,
    [string]$GitHubRepository
)
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../LandingZone.Bootstrap') -Force

$bootstrapWorkload = 'identity'

# --- Stage 1: Environment & Tooling Gate ---
$stage1Checks = @(
    Test-Tooling
    Test-BicepParamFile -Path $BicepParamPath
    Test-JsonFile       -Path $WorkloadsPath
    Test-AzureSession
    Test-GitHubSession
    Test-GitHubRemote    -Owner $GitHubOwner -Repository $GitHubRepository
    Test-GitHubRepoAdmin -Owner $GitHubOwner -Repository $GitHubRepository
)
Assert-Preflight $stage1Checks -Title 'ENVIRONMENT & ACCESS PREFLIGHT'

# --- Context (safe now that stage 1 passed) ---
$config   = Get-BicepParamConfig -Path $BicepParamPath
$repo     = Resolve-GitHubRepository -Owner $GitHubOwner -Repository $GitHubRepository
$tenantId = (az account show --query tenantId --output tsv).Trim()

# Always include the bootstrap workload, then validate the FULL target list.
if (-not $Workload) { $Workload = @($config.Subscriptions.Keys | Sort-Object) }
$targets = @($Workload + $bootstrapWorkload | Select-Object -Unique)
 
$unknown = @($targets | Where-Object { -not $config.Subscriptions.ContainsKey($_) })
if ($unknown) {
    throw "Unknown workload(s): $($unknown -join ', '). Available: $($config.Subscriptions.Keys -join ', ')."
}

# --- Stage 2: Azure Target & RBAC Gate ---
$stage2Checks = @()
foreach ($name in $Workload) {
    $id = $config.Subscriptions[$name]
    $stage2Checks += @(
        Test-TargetSubscription      -SubscriptionId $id -TenantId $tenantId
        Test-ProviderRegistered      -SubscriptionId $id -Namespace 'Microsoft.Resources'
        Test-CanWriteRoleAssignments -Scope "/subscriptions/$id"
    ) | ForEach-Object { $_.Group = "$name ($id)"; $_ }
}

# Semantic JSON check: only for data this script consumes today (the bootstrap workload's tags).
$stage2Checks += Test-WorkloadTags -Workload $bootstrapWorkload -Environment $Environment -Path $WorkloadsPath |
    ForEach-Object { $_.Group = "$bootstrapWorkload manifest"; $_ }

Assert-Preflight $stage2Checks -Title 'AZURE TARGET & RBAC PREFLIGHT'
Write-BootstrapLog "Preflight complete for: $($targets -join ', ')." -Level Success
Write-Host ''

$tags        = Get-WorkloadTags -Workload $bootstrapWorkload -Environment $Environment -Path $WorkloadsPath
$identitySub = $config.Subscriptions[$bootstrapWorkload]
 
Write-BootstrapLog "Target: $($config.IdentityResourceGroupName) in $($config.PrimaryLocation) (sub $identitySub)"
Set-ResourceGroup -Name $config.IdentityResourceGroupName -SubscriptionId $identitySub `
    -Location $config.PrimaryLocation -Tags $tags