<#
.SYNOPSIS
    Bootstraps the Azure environment for Contoso management group deployments.
.DESCRIPTION
    Creates a bootstrap resource group, a User-Assigned Managed Identity (UMI), 
    configures OIDC federated credentials for GitHub Actions, and assigns 
    Management Group Contributor permissions at the tenant root. Automatically 
    discovers your Azure subscription and GitHub repository context if not supplied.

    If you want to autosave secrets to GitHub automatically, perform the following 
    authentication steps first:
    
    1. If the GitHub CLI ('gh') is not installed, install it via:
        winget install --id GitHub.Cli
    
    2. Run `gh auth login` and select the following options:
        - Where do you use GitHub? -> GitHub.com
        - Preferred protocol -> HTTPS
        - Authenticate Git with your credentials? -> Yes
        - How would you like to authenticate? -> Login with a web browser
        - Follow the generated link, enter your one-time device code, authorize, and complete MFA if prompted
    
    Once authenticated, the script will automatically synchronize the required configuration 
    secrets directly to your repository and verify them. If unauthenticated, it gracefully 
    warns you and outputs the configuration values to the terminal for manual setup.
.EXAMPLE
    # Run with fully automated local context discovery:
    .\New-ContosoManagementGroupDeployer.ps1

.EXAMPLE
    # Or run with explicit parameters:
    .\New-ContosoManagementGroupDeployer.ps1 `
        -BootstrapSubscriptionId "11111111-2222-3333-4444-555565555555" `
        -ResourceGroupName "rg-mgmt-identity-cus-01" `
        -Location "centralus" `
        -IdentityName "id-alz-deployer-cus-01" `
        -GitHubOwner "your-github-username" `
        -GitHubRepository "your-repo-name"
#>
[CmdletBinding()]
param(
    [string]$BootstrapSubscriptionId,
    [string]$ResourceGroupName = "rg-mgmt-identity-cus-01",
    [string]$Location = "centralus",
    [string]$IdentityName = "id-alz-deployer-cus-01",
    [string]$GitHubOwner,
    [string]$GitHubRepository,
    [string]$GitHubBranch = 'main',
    [string]$TenantRootManagementGroupId
)

$ErrorActionPreference = 'Stop'

# 1. Auto-discover Subscription ID if not provided
if ([string]::IsNullOrWhiteSpace($BootstrapSubscriptionId)) {
    Write-Output "Subscription ID not provided. Auto-discovering from active Azure session..."
    $BootstrapSubscriptionId = (az account show --query id --output tsv 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($BootstrapSubscriptionId)) {
        throw "Could not determine active Azure subscription. Please run 'az login' or pass -BootstrapSubscriptionId."
    }
}

Write-Output "Setting active subscription to $BootstrapSubscriptionId..."
az account set --subscription $BootstrapSubscriptionId

# 2. Auto-discover GitHub Owner and Repository from local git config if not provided
if ([string]::IsNullOrWhiteSpace($GitHubOwner) -or [string]::IsNullOrWhiteSpace($GitHubRepository)) {
    Write-Output "GitHub owner/repository not fully specified. Inspecting local git remote config..."
    $remoteUrl = (git config --get remote.origin.url 2>$null).Trim()
    if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/.]+)(\.git)?$') {
        if ([string]::IsNullOrWhiteSpace($GitHubOwner)) { $GitHubOwner = $Matches[1] }
        if ([string]::IsNullOrWhiteSpace($GitHubRepository)) { $GitHubRepository = $Matches[2] }
        Write-Output "Discovered GitHub Owner: $GitHubOwner, Repository: $GitHubRepository"
    } else {
        if ([string]::IsNullOrWhiteSpace($GitHubOwner)) { throw "GitHubOwner is required. Pass it as a parameter or configure a GitHub remote." }
        if ([string]::IsNullOrWhiteSpace($GitHubRepository)) { throw "GitHubRepository is required. Pass it as a parameter or configure a GitHub remote." }
    }
}

# 3. Resolve Tenant Root Management Group ID
if ([string]::IsNullOrWhiteSpace($TenantRootManagementGroupId)) {
    $TenantRootManagementGroupId = "/providers/Microsoft.Management/managementGroups/$((az account show --query tenantId --output tsv).Trim())"
}

if ($TenantRootManagementGroupId -notmatch '^/providers/Microsoft\.Management/managementGroups/[^/]+$') {
    throw 'TenantRootManagementGroupId must be a management-group resource ID.'
}

# 4. Bootstrap Resource Group
Write-Output "Ensuring resource group '$ResourceGroupName' exists in location '$Location'..."
az group create --name $ResourceGroupName --location $Location --output none

# 5. Bootstrap User-Assigned Managed Identity (Safe null-handled check)
Write-Output "Checking for existing User-Assigned Managed Identity '$IdentityName'..."
$rawIdentityId = az identity list --resource-group $ResourceGroupName --query "[?name=='$IdentityName'].id" --output tsv
$existingIdentityId = if ($rawIdentityId) {$rawIdentityId.Trim() } else { "" }

if ([string]::IsNullOrWhiteSpace($existingIdentityId)) {
    Write-Output "Creating User-Assigned Managed Identity '$IdentityName'..."
    az identity create `
        --name $IdentityName `
        --resource-group $ResourceGroupName `
        --location $Location `
        --output none
} else {
    Write-Output "Managed Identity '$IdentityName' already exists. Skipping creation."
}

# 6. Configure OIDC Federated Credentials (Idempotent list-based check)
$federatedCredentialName = 'github-main'
$subject = 'repo:{0}/{1}:ref:refs/heads/{2}' -f $GitHubOwner, $GitHubRepository, $GitHubBranch

Write-Output "Checking for existing federated credential '$federatedCredentialName'..."
$existingCred = az identity federated-credential list --identity-name $IdentityName --resource-group $ResourceGroupName --query "[?name=='$federatedCredentialName'].name" --output tsv

if ([string]::IsNullOrWhiteSpace($existingCred)) {
    Write-Output "Creating OIDC federated credential for branch '$GitHubBranch'..."
    az identity federated-credential create `
        --name $federatedCredentialName `
        --identity-name $IdentityName `
        --resource-group $ResourceGroupName `
        --issuer 'https://token.actions.githubusercontent.com' `
        --subject $subject `
        --audiences 'api://AzureADTokenExchange' `
        --output none
} else {
    Write-Output "Federated credential already exists. Skipping creation."
}

# 7. Assign Tenant Root Management Group Contributor Role (Safe null-handled retrieval)
Write-Output "Retrieving Principal ID and Client ID for User-Assigned Managed Identity '$IdentityName'..."
$rawPrincipalId = az identity show --name $IdentityName --resource-group $ResourceGroupName --query principalId --output tsv
$principalId = if ($rawPrincipalId) { $rawPrincipalId.Trim() } else { "" }

$rawClientId = az identity show --name $IdentityName --resource-group $ResourceGroupName --query clientId --output tsv
$clientId = if ($rawClientId) { $rawClientId.Trim() } else { "" }

if (-not $existingRole) {
    Write-Output "Assigning 'Management Group Contributor' role at tenant root scope..."
    az role assignment create `
        --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal `
        --role 'Management Group Contributor' `
        --scope $TenantRootManagementGroupId `
        --output none
} else {
    Write-Output "Role assignment already exists. Skipping assignment."
}

# 8. Output Required GitHub Secrets & Optional Auto-Configuration
$tenantId = ((az account show --query tenantId --output tsv).Trim())

# Check if authenticated with GitHub CLI first
$isLoggedIn = $false
if (Get-Command gh -ErrorAction SilentlyContinue) {
    try {
        $null = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $isLoggedIn = $true
        }
    } catch {
        $isLoggedIn = $false
    }
}

if ($isLoggedIn) {
    Write-Host "`nSyncing secrets to GitHub repository: $GitHubOwner/$GitHubRepository..." -ForegroundColor Cyan
    
    $clientId | gh secret set AZURE_CLIENT_ID --repo "$GitHubOwner/$GitHubRepository"
    $tenantId | gh secret set AZURE_TENANT_ID --repo "$GitHubOwner/$GitHubRepository"
    $TenantRootManagementGroupId | gh secret set TENANT_ROOT_MANAGEMENT_GROUP_ID --repo "$GitHubOwner/$GitHubRepository"
    
    Write-Host "Successfully synchronized secrets to $GitHubOwner/$GitHubRepository!" -ForegroundColor Green
    
    Write-Host "`nVerifying active GitHub repository secrets..." -ForegroundColor Cyan
    gh secret list --repo "$GitHubOwner/$GitHubRepository"
} else {
    Write-Host "`n[WARNING] GitHub CLI is not authenticated." -ForegroundColor Red
    Write-Host "If 'gh' is not installed, review the script description (Get-Help .\New-ContosoManagementGroupDeployer.ps1) for installation steps." -ForegroundColor Yellow
    Write-Host "To enable automatic secret syncing, run 'gh auth login' using the following options:" -ForegroundColor Yellow
    Write-Host "  1. Where do you use GitHub? -> GitHub.com" -ForegroundColor Cyan
    Write-Host "  2. Preferred protocol -> HTTPS" -ForegroundColor Cyan
    Write-Host "  3. Authenticate Git with your credentials? -> Yes" -ForegroundColor Cyan
    Write-Host "  4. How would you like to authenticate? -> Login with a web browser" -ForegroundColor Cyan
    Write-Host "     (Follow the link, enter your one-time code, authorize, and complete MFA if prompted)" -ForegroundColor Cyan
    Write-Host "`nExecute this script again after logging in to automatically sync secrets." -ForegroundColor Yellow
    
    Write-Host "`nManual Secret Configuration Values:" -ForegroundColor Yellow
    Write-Output "AZURE_CLIENT_ID=$clientId"
    Write-Output "AZURE_TENANT_ID=$tenantId"
    Write-Output "TENANT_ROOT_MANAGEMENT_GROUP_ID=$TenantRootManagementGroupId"
}

# Visual Azure Resource Verification
Write-Host "`nVerifying deployed Azure Resource Group and Managed Identity..." -ForegroundColor Cyan
az group list --query "[?name=='$ResourceGroupName']" --output table
az identity list --resource-group $ResourceGroupName --output table

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "Bootstrap complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green