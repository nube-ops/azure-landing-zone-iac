#Requires -Version 7.4
<#
.SYNOPSIS
    Preflight-only run for the subscription-scope OIDC bootstrap (no changes are made).
.EXAMPLE
    pwsh -File ./scripts/bootstrap/Initialize-SubscriptionOidc.ps1
.EXAMPLE
    pwsh -File ./scripts/bootstrap/Initialize-SubscriptionOidc.ps1 -Workload corp, online
#>
[CmdletBinding()]
param(
    [string]$BicepParamPath = (Join-Path $PSScriptRoot '../../environments/prod/main.bicepparam'),
    [string[]]$Workload,                       # default: every workload in the param file
    [string]$GitHubOwner,
    [string]$GitHubRepository
)

$ErrorActionPreference = 'Stop'                # binding errors now stop the script instead of vanishing
$timer = [System.Diagnostics.Stopwatch]::StartNew()

Import-Module (Join-Path $PSScriptRoot '../LandingZone.Bootstrap') -Force

# Stage 1: environment checks (nothing below is safe if these fail)
Assert-Preflight @(
    Test-Tooling
    Test-AzureSession
    Test-GitHubSession
    Test-BicepParamFile -Path $BicepParamPath
)
Write-Host "[TIMING] Stage 1: $([math]::Round($timer.Elapsed.TotalSeconds, 1))s" -ForegroundColor DarkGray

# Context: read the param file once
$config   = Get-BicepParamConfig -Path $BicepParamPath
$repo     = Resolve-GitHubRepository -Owner $GitHubOwner -Repository $GitHubRepository
$tenantId = (az account show --query tenantId --output tsv).Trim()
Write-Host "[TIMING] Context: $([math]::Round($timer.Elapsed.TotalSeconds, 1))s" -ForegroundColor DarkGray

if (-not $Workload) { $Workload = @($config.Subscriptions.Keys | Sort-Object) }
$unknown = @($Workload | Where-Object { -not $config.Subscriptions.ContainsKey($_) })
if ($unknown) {
    throw "Unknown workload(s): $($unknown -join ', '). Available: $($config.Subscriptions.Keys -join ', ')."
}

# Stage 2: target checks
$checks = @(Test-GitHubRepoAdmin -Owner $repo.Owner -Repository $repo.Repository)
foreach ($name in $Workload) {
    $id = $config.Subscriptions[$name]
    $checks += Test-TargetSubscription      -SubscriptionId $id -TenantId $tenantId
    $checks += Test-ProviderRegistered      -SubscriptionId $id -Namespace 'Microsoft.Resources'
    $checks += Test-CanWriteRoleAssignments -Scope "/subscriptions/$id"
}
Assert-Preflight $checks
Write-Host "[TIMING] Stage 2: $([math]::Round($timer.Elapsed.TotalSeconds, 1))s" -ForegroundColor DarkGray

Write-Host "`nPreflight complete for: $($Workload -join ', '). No changes were made." -ForegroundColor Green