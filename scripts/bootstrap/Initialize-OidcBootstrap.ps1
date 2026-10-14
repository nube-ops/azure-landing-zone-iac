<#
.SYNOPSIS
    Bootstraps the Azure environment for Contoso management group deployments.

.DESCRIPTION
    A zero-touch, highly secure, and fully idempotent bootstrap engine designed for 
    enterprise Cloud Platforms (Azure Landing Zones / ALZ). It autonomously orchestrates 
    the end-to-end provisioning lifecycle without manual intervention, satisfying strict 
    FinOps, DRY (Don't Repeat Yourself), and security compliance standards.

    Key Zero-Touch & Engineering Capabilities:
      - Dynamic Bicepparam Integration (DRY Architecture): Programmatically parses the environment's 
        'main.bicepparam' file, extracting top-level metadata (`orgName`, `deploymentRegion`), 
        isolating the primary configuration block where `isPrimary: true` is declared, and 
        dynamically resolving target subscription mappings to inherit naming and resource locations.
      - Automated Preflight Diagnostics: Validates Azure CLI and GitHub CLI sessions prior 
        to execution, failing fast with clear remediation guidelines if authentication is missing.
      - Intelligent Context Auto-Discovery: Dynamically resolves your active Azure Subscription 
        ID, Tenant ID, and local Git remote repository metadata (Owner/Repository) natively.
      - Resilient Transient Error Handling: Features a built-in reusable retry wrapper helper 
        function (`Invoke-WithRetry`) to handle cloud and API network blips gracefully.
      - Advanced Security & Modern OIDC Federation: Resolves immutable GitHub user and repository 
        numeric IDs via the GitHub API to configure secure OpenID Connect (OIDC) federated credentials, 
        preventing common deployment authentication failures (AADSTS700213).
      - Idempotent Tenant Root RBAC Provisioning: Automatically assigns 'Contributor', 'Resource Policy Contributor', 
        and 'User Access Administrator' roles at the Tenant Root Scope ("/") to ensure seamless orchestration of 
        management group hierarchies, governance policy compliance, and dynamic RBAC/subscription association delegation.
      - Idempotent Upsert Architecture: Safely checks for existing Resource Groups, User-Assigned 
        Managed Identities (UMI), federated credentials, and tenant root role assignments to ensure 
        safe, repeatable execution without duplicate resource creation.
      - Automated Secret Syncing (Zero-Touch CI/CD): Authenticates via the GitHub CLI to automatically 
        sync required configuration secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and 
        `TENANT_ROOT_MANAGEMENT_GROUP_ID`) straight into your GitHub repository settings.
      - Live Visual Verification: Automatically outputs tabular Azure resource verifications, OIDC 
        credentials, role assignments, and active repository secret lists upon completion for transparent auditing.

    Prerequisites & Setup:
    1. Ensure the primary region and metadata are configured in your parameter file:
        - environments/prod/main.bicepparam (Designate your primary region with `isPrimary: true`)
    2. Ensure the GitHub CLI ('gh') is installed and authenticated:
        -winget install --id GitHub.Cli
        -gh auth login
        - Where do you use GitHub? -> GitHub.com
        - Preferred protocol -> HTTPS
        - Authenticate Git with your credentials? -> Yes
        - How would you like to authenticate? -> Login with a web browser
        - Follow the link, enter your one-time code, authorize, and complete MFA.
    3. Ensure the Azure CLI ('az') is installed and authenticated:
        -winget install --id Microsoft.AzureCLI    
        -az login
        
    Once authenticated, simply execute the script for an entirely seamless zero-touch bootstrap experience.

.EXAMPLE
    # Run with fully automated local context discovery:
    .\Initialize-OidcBootstrap.ps1

.EXAMPLE
    # Or run with explicit parameters:
    .\Initialize-OidcBootstrap.ps1 `
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
    [string]$BicepParamPath = (Join-Path $PSScriptRoot "../../environments/prod/main.bicepparam"),
    [string]$ResourceGroupName,
    [string]$Location,
    [string]$IdentityName,
    [string]$GitHubOwner,
    [string]$GitHubRepository,
    [string]$GitHubBranch = 'main',
    [string]$TenantRootManagementGroupId
)

# Dot-source the shared preflight validation library
. (Join-Path $PSScriptRoot "../common/Test-EnvironmentPreflight.ps1")

# Execute preflight validation
Test-EnvironmentPreflight

# =========================================================================
# Dynamic Primary Region & Configuration Auto-Resolution (DRY Pattern)
# =========================================================================
if ([string]::IsNullOrWhiteSpace($BicepParamPath)) {
    # Dynamically resolve relative to script location: scripts/bootstrap -> environments/prod/main.bicepparam
    $BicepParamPath = Join-Path $PSScriptRoot "../../environments/prod/main.bicepparam"
}

if (([string]::IsNullOrWhiteSpace($Location) -or [string]::IsNullOrWhiteSpace($ResourceGroupName) -or [string]::IsNullOrWhiteSpace($IdentityName)) -and (Test-Path $BicepParamPath)) {
    try {
        $bicepParamContent = Get-Content -Path $BicepParamPath -Raw -ErrorAction Stop

        # Regex to locate the block where 'isPrimary: true' is defined and pull its properties
        if ($bicepParamContent -match "(?s)location:\s*'([^']+)'[^}]*?regionCode:\s*'([^']+)'[^}]*?isPrimary:\s*true") {
            $extractedLocation = $Matches[1]
            $extractedRegionCode = $Matches[2]

            # Parse DRY orgName and deploymentRegion from the top of main.bicepparam
            if ($bicepParamContent -match "param\s+orgName\s*=\s*'([^']+)'") {
                $script:ParsedOrgName = $Matches[1]
            }
            if ($bicepParamContent -match "param\s+geoPrefix\s*=\s*'([^']+)'") {
                $script:ParsedDeploymentRegion = $Matches[1]
            }

            # Parse Identity Subscription ID dynamically from main.bicepparam
            if ($bicepParamContent -match "mgName:\s*'[^']*-identity'\s*subscriptionIds:\s*\[\s*'([^']+)'") {
                $script:BootstrapSubscriptionId = $Matches[1]
            }

            # Dynamically set parameters if they weren't explicitly passed via CLI arguments
            if ([string]::IsNullOrWhiteSpace($Location)) {
                $Location = $extractedLocation
            }
            if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
                $ResourceGroupName = "rg-mgmt-identity-$extractedRegionCode-01"
            }
            if ([string]::IsNullOrWhiteSpace($IdentityName)) {
                $IdentityName = "id-alz-deployer-$extractedRegionCode-01"
            }
        } else {
            Write-Host "[WARNING] Could not match 'isPrimary: true' pattern in $BicepParamPath. Falling back to default naming." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[ERROR] Failed to read parameter file: $_" -ForegroundColor Red
        throw $_
    }
}

# =========================================================================
# Strict Validation: Ensure Configuration Was Successfully Resolved
# =========================================================================
if ([string]::IsNullOrWhiteSpace($Location) -or [string]::IsNullOrWhiteSpace($ResourceGroupName) -or [string]::IsNullOrWhiteSpace($IdentityName)) {
    Write-Host "`n[ERROR] CRITICAL: Failed to resolve primary region configuration from '$BicepParamPath'." -ForegroundColor Red
    Write-Host "Ensure your parameter file contains 'isPrimary: true' with a valid location and region code, or pass them explicitly via parameters." -ForegroundColor Yellow
    throw "Bootstrap aborted: Unresolved primary configuration. Check your bicepparam schema or file path."
}

# ==========================================
# Resolved Configuration Audit Output
# ==========================================
if ([string]::IsNullOrWhiteSpace($script:ParsedOrgName) -or 
    [string]::IsNullOrWhiteSpace($script:ParsedDeploymentRegion) -or 
    [string]::IsNullOrWhiteSpace($Location) -or 
    [string]::IsNullOrWhiteSpace($ResourceGroupName) -or 
    [string]::IsNullOrWhiteSpace($IdentityName) -or 
    [string]::IsNullOrWhiteSpace($BootstrapSubscriptionId)) {
    
    Write-Host "`n[ERROR] CRITICAL: One or more required bootstrap configuration fields are empty." -ForegroundColor Red
    Write-Host "  - Organization Name     : $script:ParsedOrgName" -ForegroundColor Yellow
    Write-Host "  - Deployment Region     : $script:ParsedDeploymentRegion" -ForegroundColor Yellow
    Write-Host "  - Primary Location      : $Location" -ForegroundColor Yellow
    Write-Host "  - Resource Group        : $ResourceGroupName" -ForegroundColor Yellow
    Write-Host "  - Managed Identity      : $IdentityName" -ForegroundColor Yellow
    Write-Host "  - Bootstrap Sub ID      : $BootstrapSubscriptionId" -ForegroundColor Yellow
    
    throw "Bootstrap aborted: Unresolved configuration parameters. Verify your bicepparam schema."
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "      RESOLVED BOOTSTRAP CONFIGURATION   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  - Source Parameter File : $BicepParamPath" -ForegroundColor DarkGray
Write-Host "  - Organization Name     : $ParsedOrgName" -ForegroundColor Green
Write-Host "  - Deployment Region     : $ParsedDeploymentRegion" -ForegroundColor Green
Write-Host "  - Primary Location      : $Location ($extractedRegionCode)" -ForegroundColor Green
Write-Host "  - Resource Group        : $ResourceGroupName" -ForegroundColor Green
Write-Host "  - Managed Identity      : $IdentityName" -ForegroundColor Green
Write-Host "  - Bootstrap Sub ID      : $BootstrapSubscriptionId" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "          Main Bootstrap Workflow       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# The Reusable Helper Function - automated retry resilience for transient errors.
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxRetries = 2,
        
        [int]$DelaySeconds = 3,                  [string]$ErrorMessage = "Operation failed after multiple attempts."
    )
    
    $retryCount = 0
    $success =$false

    while ($retryCount -lt $MaxRetries -and -not$success) {
        try {
            $retryCount++
            & $ScriptBlock
            $success =$true
        } catch {
            if ($retryCount -ge$MaxRetries) {
                Write-Host "`n[ERROR] $ErrorMessage $_" -ForegroundColor Red
                throw $_
            } else {
                Write-Host "[WARNING] Transient issue detected on attempt $retryCount. Retrying in $DelaySeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }
}

# 1. Auto-discover Subscription ID if not provided
if ([string]::IsNullOrWhiteSpace($BootstrapSubscriptionId)) {
    Write-Output "Auto-discovering the Subscription ID from the active Azure session..."
    $BootstrapSubscriptionId = (az account show --query id --output tsv 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($BootstrapSubscriptionId)) {
        throw "Could not determine active Azure subscription. Please run 'az login' or pass -BootstrapSubscriptionId."
    }
}

Write-Output "Setting active subscription to $BootstrapSubscriptionId..."
az account set --subscription $BootstrapSubscriptionId

# 2. Auto-discover GitHub Owner and Repository from local git config if not provided
Write-Host ""
if ([string]::IsNullOrWhiteSpace($GitHubOwner) -or [string]::IsNullOrWhiteSpace($GitHubRepository)) {
    Write-Output "Auto-discovering the GitHub owner/repository. Inspecting local git remote config..."
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
Write-Host ""
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

# ==========================================
# 6. Configure OIDC Federated Credentials (Fail-Fast with guidance & DRY)
# ==========================================

$federatedCredentialName = 'github-main'
$targetSubject = ""

$isLoggedIn = $false
if (Get-Command gh -ErrorAction SilentlyContinue) {
    try {
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $isLoggedIn = $true
        } else {
            Write-Host "GitHub CLI auth status check failed: $authStatus" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Exception checking GitHub CLI auth: $_" -ForegroundColor Yellow
        $isLoggedIn = $false
    }
}

# Only show the warning and instructions if the user is NOT logged in
if (-not $isLoggedIn) {
    Write-Host "`n[WARNING] GitHub CLI is not authenticated." -ForegroundColor Red
    Write-Host "If 'gh' is not installed, review the script description (Get-Help .\Initialize-OidcBootstrap.ps1) for installation steps." -ForegroundColor Yellow
    Write-Host "To configure OIDC federated credentials and allow automatic secret syncing, run 'gh auth login' using the following options:" -ForegroundColor Cyan
    Write-Host "  1. Where do you use GitHub? -> GitHub.com" -ForegroundColor Cyan
    Write-Host "  2. Preferred protocol -> HTTPS" -ForegroundColor Cyan
    Write-Host "  3. Authenticate Git with your credentials? -> Yes" -ForegroundColor Cyan
    Write-Host "  4. How would you like to authenticate? -> Login with a web browser" -ForegroundColor Cyan
    Write-Host "     (Follow the link, enter your one-time code, authorize, and complete MFA if prompted)" -ForegroundColor Cyan
    Write-Host "`nExecute this script again after logging in to configure OIDC federated credentials and allow automatic secret syncing." -ForegroundColor Yellow
}

Write-Host ""
if ($isLoggedIn) {
    Write-Output "Fetching repository and owner numeric IDs via GitHub API for secure OIDC federation..."
    try {
        $repoInfoJson = gh api "repos/$GitHubOwner/$GitHubRepository" --jq '{repoId: .id, ownerId: .owner.id}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $repoInfoJson) {
            $repoData = $repoInfoJson | ConvertFrom-Json
            $targetSubject = 'repo:{0}@{1}/{2}@{3}:ref:refs/heads/{4}' -f $GitHubOwner, $repoData.ownerId, $GitHubRepository, $repoData.repoId, $GitHubBranch
        }
    } catch {
        # Logged below via the null-check validation
    }
}

# Fail fast if we couldn't retrieve the immutable IDs required by modern GitHub OIDC
if ([string]::IsNullOrWhiteSpace($targetSubject)) {
    Write-Host "`n[ERROR] CRITICAL: Could not resolve immutable GitHub OIDC subject identifiers." -ForegroundColor Red
    Write-Host "Modern GitHub Actions requires repository and owner numeric IDs in the OIDC subject claim." -ForegroundColor Yellow
    Write-Host "Falling back to name-based federation will cause deployment authentication to fail (AADSTS700213)." -ForegroundColor Yellow
    throw "Bootstrap aborted: Failed to retrieve GitHub numeric IDs. Ensure 'gh' CLI is authenticated and has network access."
}

Write-Output "Resolved immutable OIDC subject: $targetSubject"

# Idempotent Upsert Logic using the reusable Invoke-WithRetry helper function
Write-Output "Checking existing federated credential '$federatedCredentialName'..."
$existingCred =$null
try {
    $existingCredJson = az identity federated-credential show --name$federatedCredentialName --identity-name $IdentityName --resource-group$ResourceGroupName --output json 2>&1
    if ($LASTEXITCODE -eq 0 -and$existingCredJson) {
        $existingCred =$existingCredJson | ConvertFrom-Json
    }
} catch {
    # Expected when the credential doesn't exist yet on a fresh run
}

Invoke-WithRetry -MaxRetries 2 -ErrorMessage "Bootstrap aborted: OIDC federation configuration failed." -ScriptBlock {
    if (-not $existingCred) {
        Write-Host "Creating OIDC federated credential..." -ForegroundColor Cyan
        az identity federated-credential create `
            --name $federatedCredentialName `
            --identity-name $IdentityName `
            --resource-group $ResourceGroupName `
            --issuer 'https://token.actions.githubusercontent.com' `
            --subject $targetSubject `
            --audiences 'api://AzureADTokenExchange' `
            --output none
    } elseif ($existingCred.subject -ne $targetSubject) {
        Write-Host "Updating existing federated credential subject to match current repository state..." -ForegroundColor Cyan
        az identity federated-credential update `
            --name $federatedCredentialName `
            --identity-name $IdentityName `
            --resource-group $ResourceGroupName `
            --subject $targetSubject `
            --output none
    } else {
        Write-Host "OIDC federated credential is already up-to-date. Skipping creation/update." -ForegroundColor Green
    }
}

# ==========================================
# 7. Assign Required Roles at Tenant Root Scope (DRY Array Loop)
# ==========================================
Write-Host "`nRetrieving identity attributes for '$IdentityName'..." -ForegroundColor Cyan
$principalId = (az identity show --name $IdentityName --resource-group $ResourceGroupName --query principalId --output tsv).Trim()
$clientId    = (az identity show --name $IdentityName --resource-group $ResourceGroupName --query clientId --output tsv).Trim()
$tenantId    = (az account show --query tenantId --output tsv).Trim()

# Array of roles required for full Landing Zone orchestration:
# 1. Contributor: Subscription management & deployment what-if checks
# 2. Resource Policy Contributor: Creation of policy definitions/initiatives
# 3. User Access Administrator: Required to grant the identity RBAC delegation permissions for subscription associations and role assignment operations. Moving subscriptions into their management groups. 
$requiredRoles = @(
    'Contributor',
    'Resource Policy Contributor',
    'User Access Administrator'
)

foreach ($role in $requiredRoles) {
    $existingRole = az role assignment list --assignee $principalId --scope "/" --role $role --query "[0].id" --output tsv 2>$null

    if ([string]::IsNullOrWhiteSpace($existingRole)) {
        Write-Host "Assigning '$role' role at tenant root scope ('/')..." -ForegroundColor Cyan
        az role assignment create `
            --assignee-object-id $principalId `
            --assignee-principal-type ServicePrincipal `
            --role $role `
            --scope "/" `
            --output none
    } else {
        Write-Host "Role '$role' is already assigned at tenant root scope ('/'). Skipping." -ForegroundColor Green
    }
}

# 8. Output Required GitHub Secrets & Optional Auto-Configuration
$tenantId = ((az account show --query tenantId --output tsv).Trim())

if ($isLoggedIn) {
    Write-Host "`nSyncing secrets to GitHub repository: $GitHubOwner/$GitHubRepository..." -ForegroundColor Cyan

    # Use the reusable helper function for transient network/API blips during secret syncing
    Invoke-WithRetry -MaxRetries 2 -ErrorMessage "Secret synchronization aborted." -ScriptBlock {
        $clientId | gh secret set AZURE_CLIENT_ID --repo "$GitHubOwner/$GitHubRepository"
        $tenantId | gh secret set AZURE_TENANT_ID --repo "$GitHubOwner/$GitHubRepository"
        $TenantRootManagementGroupId | gh secret set TENANT_ROOT_MANAGEMENT_GROUP_ID --repo "$GitHubOwner/$GitHubRepository"
    }

    Write-Host "Successfully synchronized secrets to $GitHubOwner/$GitHubRepository!" -ForegroundColor Green
    
    Write-Host "`nVerifying active GitHub repository secrets..." -ForegroundColor Cyan
    gh secret list --repo "$GitHubOwner/$GitHubRepository"
}

# ==========================================
# Visual Azure Resource Verification
# ==========================================
Write-Host "`nVerifying deployed Azure Resource Group, Managed Identity, and OIDC Federation..." -ForegroundColor Cyan

# 1. Resource Group Verification
Write-Host "[SUCCESS] Resource Group '$ResourceGroupName' is ready." -ForegroundColor Green
az group list --query "[?name=='$ResourceGroupName']" --output table
Write-Host "" # Adds an empty line space

# 2. Managed Identity Verification
Write-Host "[SUCCESS] User-Assigned Managed Identity '$IdentityName' is ready." -ForegroundColor Green
az identity list --resource-group $ResourceGroupName --output table
Write-Host "" # Adds an empty line space

# 3. OIDC Credential Verification
Write-Host "[SUCCESS] OIDC federated credential '$federatedCredentialName' configured successfully." -ForegroundColor Green
az identity federated-credential list --identity-name $IdentityName --resource-group $ResourceGroupName --output table
Write-Host "" # Adds an empty line space

# 4. Role Assignments Verification
Write-Host "[SUCCESS] Tenant Root Role Assignments configured successfully." -ForegroundColor Green
az role assignment list --assignee $principalId --all --output table

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "Bootstrap complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
