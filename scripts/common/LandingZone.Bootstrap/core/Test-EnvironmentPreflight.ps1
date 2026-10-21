<#
.SYNOPSIS
    Performs automated preflight validation checks for Azure Landing Zone (ALZ) bootstrap engines.

.DESCRIPTION
    A robust, zero-touch diagnostic verification library designed for enterprise Cloud Platforms 
    (Azure Landing Zones / ALZ). It validates required CLI authentication states, inspects active 
    session contexts, and enforces strict repository ownership security checks prior to tenant orchestration.

    Key Preflight & Engineering Capabilities:
      - Azure CLI Session Validation: Programmatically verifies active Azure cloud connectivity and authentication.
      - GitHub CLI Authentication Checks: Ensures the GitHub CLI ('gh') is installed and actively authenticated.
      - Repository Ownership Context Matching: Automatically compares the logged-in GitHub user profile against 
        the local Git remote repository owner to prevent multi-tenant deployment errors.
      - Fail-Fast Security Gates: Instantly aborts execution and outputs detailed, color-coded remediation 
        guidelines if any authentication prerequisite or ownership check fails.

    Prerequisites & Setup:
    1. Ensure the GitHub CLI ('gh') is installed and authenticated:
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
        
    Once authenticated, this script can be executed directly for system health checks or dot-sourced 
    seamlessly across all enterprise bootstrap engines.

.EXAMPLE
    # Run independently to check environment health:
    .\Test-EnvironmentPreflight.ps1

.EXAMPLE
    # Or dot-source within your automation scripts:
    . .\Test-EnvironmentPreflight.ps1
    Test-EnvironmentPreflight
#>

function Test-EnvironmentPreflight {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    # Create a tracking object for our summary report.
    $preflightResults = [PSCustomObject]@{
        AzureAuthenticated   = $false
        GitHubAuthenticated  = $false
        GitHubUserMatched    = $false
        MatchedUser          = ""
    }

    Write-Output "Running pre-flight diagnostics..."

    # 1. Check Azure CLI (Fail silently, record status)
    try {
        $activeAccount = (az account show --query id --output tsv 2>&1)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($activeAccount)) {
            $preflightResults.AzureAuthenticated = $true
        }
    } catch {
        $preflightResults.AzureAuthenticated = $false
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

    # 3. Validate Active GitHub User Matches Repository Owner
    if ($preflightResults.GitHubAuthenticated) {
        $remoteUrl = (git config --get remote.origin.url 2>$null)
        if (-not [string]::IsNullOrWhiteSpace($remoteUrl) -and $remoteUrl -match 'github\.com[:/]([^/]+)/([^/.]+)(\.git)?$') {
            $targetOwner = $Matches[1]
            try {
                $rawUserJson = gh api user --jq '.login' 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($rawUserJson)) {
                    $currentGhUser = $rawUserJson.Trim()
                    if ($currentGhUser -eq $targetOwner) {
                        $preflightResults.GitHubUserMatched = $true
                        $preflightResults.MatchedUser = $currentGhUser
                    }
                }
            } catch {
                $preflightResults.GitHubUserMatched = $false
            }
        }
    }

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

    if ($preflightResults.GitHubUserMatched) {
        Write-Host "[OK] GitHub User Context: Verified ($($preflightResults.MatchedUser))" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] GitHub User Context: Logged-in user does not match repository owner" -ForegroundColor Red
    }
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Final Gate: Block execution if any preflight check fails
    if (-not $preflightResults.AzureAuthenticated -or -not $preflightResults.GitHubAuthenticated -or -not $preflightResults.GitHubUserMatched) {
        Write-Host "[ERROR] Preflight failed: Required CLI authentication or repository ownership checks failed." -ForegroundColor Red

        if (-not $preflightResults.GitHubAuthenticated) {
            Write-Host "`n[REMEDIATION] GitHub CLI Setup Guide:" -ForegroundColor Yellow
            Write-Host "To configure OIDC federated credentials, run 'gh auth login' and select these options:" -ForegroundColor Cyan
            Write-Host "  1. Where do you use GitHub? -> GitHub.com" -ForegroundColor Cyan
            Write-Host "  2. Preferred protocol -> HTTPS" -ForegroundColor Cyan
            Write-Host "  3. Authenticate Git with your credentials? -> Yes" -ForegroundColor Cyan
            Write-Host "  4. How would you like to authenticate? -> Login with a web browser" -ForegroundColor Cyan
            Write-Host "     (Follow the link, enter your one-time code, authorize, and complete MFA)" -ForegroundColor Cyan
        }

        if ($preflightResults.GitHubAuthenticated -and -not$preflightResults.GitHubUserMatched) {
            Write-Host "`n[REMEDIATION] GitHub Account Mismatch:" -ForegroundColor Yellow
            Write-Host "You are logged into the wrong GitHub account via 'gh'." -ForegroundColor Cyan
            Write-Host "Run 'gh auth logout' and then re-authenticate with the account that owns this repository." -ForegroundColor Cyan
        }

        Write-Host "`nExecute this script again after completing authentication." -ForegroundColor Yellow
        throw "Bootstrap aborted due to missing authentication prerequisites."
    }

    Write-Host "[SUCCESS] All critical preflight checks passed. Proceeding..." -ForegroundColor Green
}

# ==========================================
# Dual-Mode Execution Support
# ==========================================
# If the script is run directly (not dot-sourced), automatically execute the function.
if ($MyInvocation.InvocationName -ne '.') {
    Test-EnvironmentPreflight
}