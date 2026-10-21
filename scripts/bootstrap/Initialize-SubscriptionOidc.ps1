[CmdletBinding()]
param(
    [string]$BicepParamPath = (Join-Path $PSScriptRoot '../../environments/prod/main.bicepparam'),
    # 'identity' is deliberately excluded by default, see "Gotchas" below.
    [ValidateSet('connectivity', 'operations', 'corp', 'online')]
    [string[]]$Workload = @('connectivity', 'operations', 'corp', 'online'),
    [string]$GitHubOwner, [string]$GitHubRepository, [string]$GitHubBranch = 'main'
)
. (Join-Path $PSScriptRoot '../common/Import-BootstrapCommon.ps1')
Test-EnvironmentPreflight

# Data, not code. No User Access Administrator / Resource Policy Contributor: governance is the tenant UMI's job.
$DeployerRoles = @('Contributor')

$repo     = Resolve-GitHubRepository -Owner $GitHubOwner -Repository $GitHubRepository
$tenantId = (az account show --query tenantId --output tsv).Trim()

foreach ($w in $Workload) {
    Write-BootstrapLog "Workload deployer: $w" -Level Header
    $envName = "prod-$w"

    # UMI lives in the existing identity RG; its power comes from where roles are granted, not where it lives.
    $cfg   = Get-BootstrapConfig -BicepParamPath $BicepParamPath -IdentityPrefix "id-alz-res-$w"   # -> id-alz-res-corp-cus-01
    $subId = Get-BicepSubscriptionId -BicepParamPath $BicepParamPath -Workload $w                  # target sub; fails loudly

    az account set --subscription $cfg.IdentitySubscriptionId   # az identity/group calls run in the UMI's home sub

    $subject  = Resolve-GitHubOidcSubject -Repo $repo -Branch $GitHubBranch -Environment $envName
    $identity = Initialize-OidcIdentity -ResourceGroupName $cfg.ResourceGroupName -Location $cfg.Location `
                    -IdentityName $cfg.IdentityName -Subject $subject -CredentialName "github-$envName"

    Grant-RoleAssignments -PrincipalId $identity.PrincipalId -Scope "/subscriptions/$subId" -Roles $DeployerRoles

    Initialize-GitHubEnvironment -Repo $repo -Name $envName -Branch $GitHubBranch
    Sync-GitHubSecrets -Repository $repo.FullName -Environment $envName -Secrets @{
        AZURE_CLIENT_ID       = $identity.ClientId
        AZURE_TENANT_ID       = $tenantId
        AZURE_SUBSCRIPTION_ID = $subId
    }

    Show-OidcVerification -ResourceGroupName $cfg.ResourceGroupName -IdentityName $cfg.IdentityName `
        -PrincipalId $identity.PrincipalId -CredentialName "github-$envName"
}