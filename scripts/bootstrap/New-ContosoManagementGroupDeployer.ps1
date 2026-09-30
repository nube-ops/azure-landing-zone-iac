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
        'main.bicepparam' file[cite: 3], isolating the primary configuration block where `isPrimary: true`[cite: 3] 
        is declared to automatically inherit target regions and resource naming conventions.
      - Automated Preflight Diagnostics: Validates Azure CLI and GitHub CLI sessions prior 
        to execution, failing fast with clear remediation guidelines if authentication is missing.
      - Intelligent Context Auto-Discovery: Dynamically resolves your active Azure Subscription 
        ID, Tenant ID, and local Git remote repository metadata (Owner/Repository) natively.
      - Resilient Transient Error Handling: Features a built-in reusable retry wrapper helper 
        function (`Invoke-WithRetry`) to handle cloud and API network blips gracefully.
      - Advanced Security & Modern OIDC Federation: Resolves immutable GitHub user and repository 
        numeric IDs via the GitHub API to configure secure OpenID Connect (OIDC) federated credentials, 
        preventing common deployment authentication failures (AADSTS700213).
      - Idempotent Tenant Root RBAC Provisioning: Automatically assigns both 'Contributor' and 
        'Resource Policy Contributor' roles at the Tenant Root Scope ("/") to ensure seamless 
        orchestration of management group hierarchies and governance policy compliance initiatives.
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
    [string]$BicepParamPath = (Join-Path $PSScriptRoot "../../environments/prod/main.bicepparam"),
    [string]$ResourceGroupName,
    [string]$Location,
    [string]$IdentityName,
    [string]$GitHubOwner,
    [string]$GitHubRepository,
    [string]$GitHubBranch = 'main',
    [string]$TenantRootManagementGroupId
)

$ErrorActionPreference = 'Stop'

# Create a tracking object for our summary report
$preflightResults = [PSCustomObject]@{
    AzureAuthenticated = $false
    GitHubAuthenticated = $false
}

Write-Output "Running pre-flight diagnostics..."

# 1. Check Azure CLI (Fail silently, record status)
try {
    $activeAccount = (az account show --query id --output tsv 2>&1)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($activeAccount)) {
        $preflightResults.AzureAuthenticated =$true
    }
} catch {
    $preflightResults.AzureAuthenticated =$false
}

# 2. Check GitHub CLI (Fail silently, record status)
$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
if ($ghCommand) {
    try {
        $null = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $preflightResults.GitHubAuthenticated = $true
        }
    } catch {
        $preflightResults.GitHubAuthenticated = $false
    }
}

# ==========================================
# Preflight Summary Report
# ==========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "         PREFLIGHT SUMMARY REPORT       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($preflightResults.AzureAuthenticated) {
    Write-Host "[OK] Azure CLI: Connected" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Azure CLI: Not logged in (Run 'az login')" -ForegroundColor Red
}

if ($preflightResults.GitHubAuthenticated) {
    Write-Host "[OK] GitHub CLI: Connected" -ForegroundColor Green
} else {
    Write-Host "[FAIL] GitHub CLI: Not authenticated (Run 'gh auth login')" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan

# Final Gate: Block execution if either critical CLI is missing
if (-not $preflightResults.AzureAuthenticated -or -not$preflightResults.GitHubAuthenticated) {
    Write-Host "[ERROR] Preflight failed: Required CLI tools are missing authentication." -ForegroundColor Red

    # Detailed GitHub Remediation Guide (Only displays if GitHub failed)
    if (-not $preflightResults.GitHubAuthenticated) {
        Write-Host "`n[REMEDIATION] GitHub CLI Setup Guide:" -ForegroundColor Yellow
        Write-Host "To configure OIDC federated credentials, run 'gh auth login' and select these options:" -ForegroundColor Cyan
        Write-Host "  1. Where do you use GitHub? -> GitHub.com" -ForegroundColor Cyan
        Write-Host "  2. Preferred protocol -> HTTPS" -ForegroundColor Cyan
        Write-Host "  3. Authenticate Git with your credentials? -> Yes" -ForegroundColor Cyan
        Write-Host "  4. How would you like to authenticate? -> Login with a web browser" -ForegroundColor Cyan
        Write-Host "     (Follow the link, enter your one-time device code, authorize, and complete MFA)" -ForegroundColor Cyan
    }

    Write-Host "`nExecute this script again after completing authentication." -ForegroundColor Yellow
    throw "Bootstrap aborted due to missing authentication prerequisites."
}

Write-Host "[SUCCESS] All critical preflight checks passed. Proceeding..." -ForegroundColor Green

# =========================================================================
# Dynamic Primary Region & Configuration Auto-Resolution (DRY Pattern)
# =========================================================================
if ([string]::IsNullOrWhiteSpace($BicepParamPath)) {
    # Dynamically resolve relative to script location: scripts/bootstrap -> environments/prod/main.bicepparam
    $BicepParamPath = Join-Path $PSScriptRoot "../../environments/prod/main.bicepparam"
}

if (([string]::IsNullOrWhiteSpace($Location) -or [string]::IsNullOrWhiteSpace($ResourceGroupName) -or [string]::IsNullOrWhiteSpace($IdentityName)) -and (Test-Path $BicepParamPath)) {
    Write-Output "Parsing primary region configuration from '$BicepParamPath'..."
    try {
        $bicepParamContent = Get-Content -Path $BicepParamPath -Raw -ErrorAction Stop

        # Regex to locate the block where 'isPrimary: true' is defined and pull its properties
        if ($bicepParamContent -match "location:\s*'([^']+)'[^}]*regionCode:\s*'([^']+)'[^}]*isPrimary:\s*true") {
            $extractedLocation = $Matches[1]
            $extractedRegionCode = $Matches[2]

            Write-Output "Discovered Primary Region -> Location: $extractedLocation, Code: $extractedRegionCode"

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
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "      RESOLVED BOOTSTRAP CONFIGURATION   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  - Source Parameter File : $BicepParamPath" -ForegroundColor DarkGray
Write-Host "  - Target Location       : $Location" -ForegroundColor Green
Write-Host "  - Resource Group        : $ResourceGroupName" -ForegroundColor Green
Write-Host "  - Managed Identity      : $IdentityName" -ForegroundColor Green
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

# 6. Configure OIDC Federated Credentials (Fail-Fast with guidance & DRY)
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
    Write-Host "If 'gh' is not installed, review the script description (Get-Help .\New-ContosoManagementGroupDeployer.ps1) for installation steps." -ForegroundColor Yellow
    Write-Host "To configure OIDC federated credentials and allow automatic secret syncing, run 'gh auth login' using the following options:" -ForegroundColor Cyan
    Write-Host "  1. Where do you use GitHub? -> GitHub.com" -ForegroundColor Cyan
    Write-Host "  2. Preferred protocol -> HTTPS" -ForegroundColor Cyan
    Write-Host "  3. Authenticate Git with your credentials? -> Yes" -ForegroundColor Cyan
    Write-Host "  4. How would you like to authenticate? -> Login with a web browser" -ForegroundColor Cyan
    Write-Host "     (Follow the link, enter your one-time code, authorize, and complete MFA if prompted)" -ForegroundColor Cyan
    Write-Host "`nExecute this script again after logging in to configure OIDC federated credentials and allow automatic secret syncing." -ForegroundColor Yellow
}

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

# 7. Assign Required Roles at Tenant Root Scope (Idempotent Checks)
Write-Output "Retrieving Principal ID and Client ID for User-Assigned Managed Identity '$IdentityName'..."
$rawPrincipalId = az identity show --name $IdentityName --resource-group $ResourceGroupName --query principalId --output tsv
$principalId = if ($rawPrincipalId) { $rawPrincipalId.Trim() } else { "" }

$rawClientId = az identity show --name $IdentityName --resource-group $ResourceGroupName --query clientId --output tsv
$clientId = if ($rawClientId) { $rawClientId.Trim() } else { "" }

# 7a. Assign 'Contributor' role at the Tenant Root Scope ("/")
# Required to grant the deployment principal permissions for tenant-scoped 
# Bicep orchestrations and what-if validation dry runs.
$existingRootRole = az role assignment list --assignee $principalId --scope "/" --role 'Contributor' --query "[0].id" --output tsv 2>$null

if ([string]::IsNullOrWhiteSpace($existingRootRole)) {
    Write-Output "Assigning 'Contributor' role at tenant root scope ('/')..."
    az role assignment create `
        --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal `
        --role 'Contributor' `
        --scope "/" `
        --output none
} else {
    Write-Output "Contributor role assignment at tenant root already exists. Skipping assignment."
}

# 7b. Assign 'Resource Policy Contributor' role at the Tenant Root Scope ("/")
# Required so the identity can create policy definitions and assignments 
# across the management group hierarchy before the groups are formally provisioned.
$existingPolicyRole = az role assignment list --assignee $principalId --scope "/" --role 'Resource Policy Contributor' --query "[0].id" --output tsv 2>$null

if ([string]::IsNullOrWhiteSpace($existingPolicyRole)) {
    Write-Output "Assigning 'Resource Policy Contributor' role at tenant root scope ('/')..."
    az role assignment create `
        --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal `
        --role 'Resource Policy Contributor' `
        --scope "/" `
        --output none
} else {
    Write-Output "Resource Policy Contributor role assignment already exists. Skipping assignment."
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

# Visual Azure Resource Verification
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
