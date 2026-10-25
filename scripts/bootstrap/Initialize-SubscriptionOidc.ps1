Import-Module (Join-Path $PSScriptRoot '../LandingZone.Bootstrap') -Force -ErrorAction Stop
Assert-Preflight @( Test-Tooling; Test-AzureSession; Test-GitHubSession; Test-BicepParamFile -Path $BicepParamPath )
$config  = Get-BicepParamConfig -Path $BicepParamPath
$targets = $Workload | ForEach-Object { [pscustomobject]@{ Workload = $_; SubscriptionId = $config.Subscriptions[$_] } }

# Stage 1: environment-level checks (nothing below can run if these fail)
$checks  = @()
$checks += Test-Tooling
$checks += Test-AzureSession
$checks += Test-GitHubSession
$checks += Test-BicepParamFile -Path $BicepParamPath
Assert-Preflight $checks

# Derive context now that it is safe to
$repo     = Resolve-GitHubRepository -Owner $GitHubOwner -Repository $GitHubRepository
$tenantId = (az account show --query tenantId --output tsv).Trim()
$subIds   = $Workload | ForEach-Object { Get-BicepSubscriptionId -BicepParamPath $BicepParamPath -Workload $_ }

# Stage 2: target-specific checks
$checks  = @()
$checks += Test-GitHubRepoAdmin -Owner $repo.Owner -Repository $repo.Repository
foreach ($id in $subIds) {
    $checks += Test-TargetSubscription -SubscriptionId $id -TenantId $tenantId
    $checks += Test-ProviderRegistered -SubscriptionId $id -Namespace 'Microsoft.Resources'
    $checks += Test-CanWriteRoleAssignments -Scope "/subscriptions/$id"
}
Assert-Preflight $checks