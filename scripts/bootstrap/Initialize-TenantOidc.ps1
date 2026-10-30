#Requires -Version 7.4
<#
.SYNOPSIS
    Bootstraps the tenant-level deployer identity in its own resource group.
.EXAMPLE
    pwsh ./scripts/bootstrap/Initialize-TenantOidc.ps1
#>
[CmdletBinding()]
param(
    [string]$Environment    = 'prod',
    [string]$BicepParamPath = (Join-Path $PSScriptRoot "../../environments/$Environment/main.bicepparam"),
    [string]$WorkloadsPath  = (Join-Path $PSScriptRoot "../../environments/$Environment/workloads.json"),
    [string]$ResourceGroupName,                       # optional override; default is derived
    [string]$GitHubOwner,
    [string]$GitHubRepository,
    [string]$GitHubBranch = 'main'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../LandingZone.Bootstrap') -Force

# --- Stage 1: environment gate (only what this script needs) ---
Assert-Preflight @(
    Test-Tooling
    Test-BicepParamFile  -Path $BicepParamPath
    Test-JsonFile        -Path $WorkloadsPath
    Test-AzureSession
    Test-GitHubSession
    Test-GitHubRemote    -Owner $GitHubOwner -Repository $GitHubRepository
    Test-GitHubRepoAdmin -Owner $GitHubOwner -Repository $GitHubRepository
) -Title 'ENVIRONMENT & ACCESS PREFLIGHT'

# --- Context (safe now) ---
$config            = Get-BicepParamConfig -Path $BicepParamPath
$repo              = Resolve-GitHubRepository -Owner $GitHubOwner -Repository $GitHubRepository
$tenantId          = (az account show --query tenantId --output tsv).Trim()
$tenantWorkload = (Get-Content -LiteralPath $WorkloadsPath -Raw | ConvertFrom-Json).tenantDeployerWorkload
$subscriptionId = $config.Subscriptions[$tenantWorkload]
if (-not $subscriptionId) { throw "No subscription mapped for workload '$tenantWorkload'." }


$code       = $config.PrimaryRegionCode
$rgName     = if ($ResourceGroupName) { $ResourceGroupName } else { "rg-deployer-$Environment-$code-01" }
$identity   = "id-deployer-tenant-$Environment-$code-01"
$tags       = Get-WorkloadTags -Workload $tenantWorkload -Environment $Environment -Path $WorkloadsPath
$rootMgId   = "/providers/Microsoft.Management/managementGroups/$tenantId"

# --- Stage 2: target gate ---
Assert-Preflight @(
    Test-TargetSubscription      -SubscriptionId $subscriptionId -TenantId $tenantId
    Test-ProviderRegistered      -SubscriptionId $subscriptionId -Namespace 'Microsoft.Resources'
    Test-ProviderRegistered      -SubscriptionId $subscriptionId -Namespace 'Microsoft.ManagedIdentity'
    Test-CanWriteRoleAssignments -Scope '/'
    Test-WorkloadTags            -Workload $tenantWorkload -Environment $Environment -Path $WorkloadsPath
) -Title 'AZURE TARGET & RBAC PREFLIGHT'

# --- Provision: RG (get-or-create) -> UMI -> federated credential -> roles ---
$deployer = Initialize-DeployerIdentity `
    -Name              $identity `
    -ResourceGroupName $rgName `
    -SubscriptionId    $subscriptionId `
    -Location          $config.PrimaryLocation `
    -Tags              $tags `
    -Repository        $repo `
    -Branch            $GitHubBranch `
    -RoleAssignment    @(
        @{ Role = 'Contributor';                 Scope = '/' }
        @{ Role = 'Resource Policy Contributor'; Scope = '/' }
        @{ Role = 'User Access Administrator';   Scope = '/' }
    )

# --- Secrets differ per entry point, so they stay here ---
$slug = "$($repo.Owner)/$($repo.Repository)"
Set-GitHubSecret -Repository $slug -Name 'AZURE_CLIENT_ID'                   -Value $deployer.ClientId
Set-GitHubSecret -Repository $slug -Name 'AZURE_TENANT_ID'                   -Value $tenantId
Set-GitHubSecret -Repository $slug -Name 'TENANT_ROOT_MANAGEMENT_GROUP_ID'   -Value $rootMgId

Show-DeployerIdentity -Identity $deployer
Write-BootstrapLog 'Tenant deployer bootstrap complete.' -Level Success