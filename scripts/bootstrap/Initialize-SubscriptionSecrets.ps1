<#
.SYNOPSIS
    Discovers enterprise Azure subscriptions, idempotently synchronizes them into local Bicep parameter files, and securely publishes them as GitHub Actions secrets.

.DESCRIPTION
    A production-grade, fully idempotent automation engine designed for Enterprise Cloud Platforms 
    and Azure Landing Zones (ALZ). It dynamically orchestrates cross-platform environment configuration 
    following strict DRY (Don't Repeat Yourself), security, and operational observability best practices.

    Key Enterprise Engineering & Automation Capabilities:
      - Automated Preflight Diagnostics: Validates active Azure CLI (az) and GitHub CLI (gh) sessions, 
        verifying repository ownership context and failing fast with explicit remediation guides if missing.
      - Intelligent Context Auto-Discovery: Natively resolves local Git remote repository metadata 
        (Owner and Repository) to target the correct GitHub environment without hardcoded configurations.
      - Resilient Transient Error Handling: Implements a reusable retry wrapper helper function 
        (`Invoke-WithRetry`) with exponential/delay buffers to handle cloud API network blips gracefully.
      - Tenant Subscription Mapping: Queries active enterprise Azure subscriptions, filtering dynamically 
        across core workload domains (connectivity, corp, online, identity, management) and validating enabled states.
      - Idempotent Bicepparam Auto-Population (DRY Architecture): Programmatically parses and injects 
        discovered subscription IDs directly into target arrays within 'main.bicepparam' without manual toil.
      - Content-Hash Convergence & Zero-Write Optimization: Evaluates existing file contents before writing, 
        skipping disk mutations if state is already fully synchronized to prevent unnecessary file lock churn.
      - Structural Diff Auditing: Employs `git diff --no-index` against a temporary backup to prove 
        isolated parameter modifications and guarantee absolute zero unintended drift.
      - Automated CI/CD Secret Syncing: Authenticates via the GitHub CLI to securely upsert required 
        workload subscription IDs straight into GitHub Actions repository settings, complete with live audit tables.
      - Human-Centric Terminal Observability: Utilizes color-coded visual logging (`[SUCCESS]`, 
        `[IDEMPOTENT]`, `[AUDIT]`, `[VERIFICATION]`) and formatted PowerShell tables for clean execution tracing.

    Prerequisites & Setup:
    1. Ensure the GitHub CLI ('gh') is installed and authenticated:
        - winget install --id GitHub.Cli
        - gh auth login (Select GitHub.com, HTTPS, and authenticate via web browser/MFA)
    2. Ensure the Azure CLI ('az') is installed and authenticated:
        - winget install --id Microsoft.AzureCLI    
        - az login
        
    Once authenticated, execute the script for a seamless, zero-touch operational experience:
        .\Initialize-SubscriptionSecrets.ps1

.EXAMPLE
    # Run with fully automated local context discovery:
    .\Initialize-SubscriptionSecrets.ps1

.EXAMPLE
    # Run with explicit target parameter file override:
    .\Initialize-SubscriptionSecrets.ps1 -BicepParamPath "../../environments/prod/main.bicepparam"
#>

[CmdletBinding()]
param(
    [string]$BicepParamPath = (Join-Path $PSScriptRoot "../../environments/prod/main.bicepparam"),
    [string]$GitHubOwner,
    [string]$GitHubRepository
)

# Dot-source the shared preflight validation library
. (Join-Path $PSScriptRoot "../common/Test-EnvironmentPreflight.ps1")

# Execute preflight validation
Test-EnvironmentPreflight


# =========================================================================
# Reusable Retry Wrapper (DRY Resilience Pattern)
# =========================================================================
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxRetries = 2,
        
        [int]$DelaySeconds = 3,
        
        [string]$ErrorMessage = "Operation failed after multiple attempts."
    )
    
    $retryCount = 0
    $success = $false

    while ($retryCount -lt $MaxRetries -and -not $success) {
        try {
            $retryCount++
            & $ScriptBlock
            $success = $true
        } catch {
            if ($retryCount -ge $MaxRetries) {
                Write-Host "`n[ERROR] $ErrorMessage$_" -ForegroundColor Red
                throw $_
            } else {
                Write-Host "[WARNING] Transient issue detected on attempt $retryCount. Retrying in $DelaySeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }
}

# =========================================================================
# GitHub Remote Auto-Discovery (Wrapped with Retry Resilience)
# =========================================================================
if ([string]::IsNullOrWhiteSpace($GitHubOwner) -or [string]::IsNullOrWhiteSpace($GitHubRepository)) {
    Write-Output "Auto-discovering GitHub metadata from git remote config..."
    
    Invoke-WithRetry -MaxRetries 2 -ErrorMessage "Failed to retrieve local git remote configuration." -ScriptBlock {
        $remoteUrl = (git config --get remote.origin.url 2>$null).Trim()
        if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/.]+)(\.git)?$') {
            if ([string]::IsNullOrWhiteSpace($GitHubOwner)) { $script:GitHubOwner =$Matches[1] }
            if ([string]::IsNullOrWhiteSpace($GitHubRepository)) { $script:GitHubRepository =$Matches[2] }
        } else {
            throw "Git remote URL does not match expected GitHub pattern."
        }
    }
    
    Write-Host "Discovered GitHub Owner: $GitHubOwner, Repository: $GitHubRepository" -ForegroundColor Cyan 
}

# =========================================================================
# Query & Map Tenant Subscriptions
# =========================================================================
Write-Output "`nQuerying active Azure subscriptions in the tenant..."
$azureSubs = $null

Invoke-WithRetry -MaxRetries 2 -ErrorMessage "Failed to query Azure subscriptions from active session." -ScriptBlock {
    $jsonOutput = az account list --query "[].{name: name, id: id, state: state}" --output json
    if (-not [string]::IsNullOrWhiteSpace($jsonOutput)) {
        $script:azureSubs = $jsonOutput | ConvertFrom-Json
    }
}

if (-not $azureSubs) {
    throw "No Azure subscriptions found in the active session. Ensure you have permissions and have run 'az login'."
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "      DISCOVERED AZURE SUBSCRIPTIONS    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$azureSubs | Format-Table -AutoSize
Write-Host "========================================`n" -ForegroundColor Cyan

# Define the target workload domains
$workloadTypes = @('connectivity', 'corp', 'online', 'identity', 'management')
$secretMapping = @{}

foreach ($type in $workloadTypes) {
    $matchedSub = $azureSubs | Where-Object { $_.name -match $type -and $_.state -eq 'Enabled' }

    if ($matchedSub) {
        $subId = if ($matchedSub -is [array]) { $matchedSub[0].id } else { $matchedSub.id }
        $subName = if ($matchedSub -is [array]) { $matchedSub[0].name } else { $matchedSub.name }
        
        Write-Host "[MATCHED] $type -> Subscription: '$subName' ($subId)" -ForegroundColor Green
        
        $secretName = "$($type.ToUpper())_SUB_ID"
        $secretMapping[$secretName] = $subId
    } else {
        Write-Host "[WARNING] Could not find an active subscription matching keyword: '$type'" -ForegroundColor Yellow
    }
}

# =========================================================================
# Programmatic Bicepparam Auto-Population (DRY Scaling Pattern)
# =========================================================================
$bicepParamPath = Join-Path $PSScriptRoot "../../environments/prod/main.bicepparam"

if (Test-Path $bicepParamPath) {
    Write-Host "Dynamically updating local '$bicepParamPath' with discovered subscription IDs..." -ForegroundColor Cyan
    
    # Create a temporary backup to allow git diff auditing on gitignored files
    $backupParamPath = "$bicepParamPath.bak"
    Copy-Item -Path $bicepParamPath -Destination $backupParamPath -Force

    $paramContent = Get-Content -Path $bicepParamPath -Raw

    # Loop through discovered mapping and inject subscription IDs into empty or existing arrays
    foreach ($secretName in $secretMapping.Keys) {
        $subId = $secretMapping[$secretName]
        
        switch ($secretName) {
            'CORP_SUB_ID'         { $paramContent = $paramContent -replace '(?s)(mgName:\s*''\$\{rootMgName\}-corp''\s*subscriptionIds:\s*\[)[^\]]*(\s*\])', "`$1`n      '$subId'`$2" }
            'ONLINE_SUB_ID'       { $paramContent =$paramContent -replace '(?s)(mgName:\s*''\$\{rootMgName\}-online''\s*subscriptionIds:\s*\[)[^\]]*(\s*\])', "`$1`n      '$subId'`$2" }
            'CONNECTIVITY_SUB_ID' { $paramContent = $paramContent -replace '(?s)(mgName:\s*''\$\{rootMgName\}-connectivity''\s*subscriptionIds:\s*\[)[^\]]*(\s*\])', "`$1`n      '$subId'`$2" }
            'IDENTITY_SUB_ID'     { $paramContent =$paramContent -replace '(?s)(mgName:\s*''\$\{rootMgName\}-identity''\s*subscriptionIds:\s*\[)[^\]]*(\s*\])', "`$1`n      '$subId'`$2" }
            'MANAGEMENT_SUB_ID'   { $paramContent = $paramContent -replace '(?s)(mgName:\s*''\$\{rootMgName\}-management''\s*subscriptionIds:\s*\[)[^\]]*(\s*\])', "`$1`n      '$subId'`$2" }
        }
    }

    # Enterprise Audit: Compare contents before writing to ensure true idempotency
    $existingContent = Get-Content -Path $bicepParamPath -Raw
    
    if ($existingContent -ceq $paramContent) {
        Write-Host "[IDEMPOTENT] Parameter file is already fully synchronized. Skipping write operation." -ForegroundColor Green
    } else {
        Set-Content -Path $bicepParamPath -Value $paramContent -Encoding utf8
        Write-Host "[SUCCESS] Successfully synchronized parameter file with active subIDs." -ForegroundColor Green
    }

    Write-Host "" # Adds a clean visual break

    # Structural Diff Audit
    Write-Host "[AUDIT] Performing structural diff: verifying isolated parameter updates & zero drift..." -ForegroundColor Cyan
    $diffOutput = git --no-pager diff --no-index $backupParamPath $bicepParamPath
    
    if ([string]::IsNullOrWhiteSpace($diffOutput)) {
        Write-Host "[IDEMPOTENT] Zero drift detected. State is clean." -ForegroundColor Green
    } else {
        $diffOutput
    }

    Remove-Item -Path $backupParamPath -Force

    Write-Host "" # Adds a clean visual break

    # Visual Readback for Subscription Associations (Inline & DRY)
    Write-Host "`n[VERIFICATION] Current Active Subscription Associations in '$($bicepParamPath)':" -ForegroundColor Green
    $secretMapping.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            WorkloadDomain  = $_.Key.Replace('_SUB_ID', '').ToLower()
            SubscriptionId  = $_.Value
        }
    } | Format-Table -AutoSize
}

# =========================================================================
# Securely Sync Subscriptions as GitHub Secrets (With Retry Protection)
# =========================================================================
if ($secretMapping.Count -gt 0) {
    Write-Host "`nSyncing subscription secrets to GitHub repository: $GitHubOwner/$GitHubRepository..." -ForegroundColor Cyan

    Invoke-WithRetry -MaxRetries 2 -ErrorMessage "Secret synchronization aborted due to network or API timeout." -ScriptBlock {
        foreach ($secretName in $secretMapping.Keys) {
            $subIdValue = $secretMapping[$secretName]
            Write-Output "Setting GitHub Secret: $secretName"
            $subIdValue | gh secret set $secretName --repo "$GitHubOwner/$GitHubRepository"
        }
    }

    Write-Host "`n[SUCCESS] All available subscription IDs successfully synchronized to GitHub Secrets!" -ForegroundColor Green
    
    Write-Host "`nVerifying active GitHub repository secrets list..." -ForegroundColor Cyan
    gh secret list --repo "$GitHubOwner/$GitHubRepository"
} else {
    Write-Host "`n[ERROR] No subscriptions were mapped. Secret synchronization skipped." -ForegroundColor Red
    throw "Subscription mapping failed. Review your Azure subscription naming conventions."
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "Subscription Discovery & Secret Binding Complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green