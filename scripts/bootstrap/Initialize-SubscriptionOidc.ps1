#Requires -Version 7.4
[CmdletBinding()]
param(
    [string]$BicepParamPath = (Join-Path $PSScriptRoot '../../environments/prod/main.bicepparam'),
    [string[]]$Workload,                       # default: every workload in the param file
    [string]$GitHubOwner,
    [string]$GitHubRepository
)
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../LandingZone.Bootstrap') -Force

# --- Stage 1: Environment & Tooling Gate ---
$stage1Checks = @(
    Test-Tooling
    Test-BicepParamFile -Path $BicepParamPath
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

if (-not $Workload) { $Workload = @($config.Subscriptions.Keys | Sort-Object) }
$unknown = @($Workload | Where-Object { -not $config.Subscriptions.ContainsKey($_) })
if ($unknown) { throw "Unknown workload(s): $($unknown -join ', '). Available: $($config.Subscriptions.Keys -join ', ')." }

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
Assert-Preflight $stage2Checks -Title 'AZURE TARGET & RBAC PREFLIGHT'

Write-Host "Preflight complete for: $($Workload -join ', '). No changes were made." -ForegroundColor Green