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
      - Repository Admin Verification: Resolves owner and repo from the git remote and confirms the logged-in
        GitHub account has admin on it, which is required to create environments and set secrets.
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
    $remotePattern = 'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?/?$'

    $result = [pscustomobject]@{
        AzureAuthenticated  = $false
        TenantId            = $null
        GitHubAuthenticated = $false
        RemoteResolved      = $false
        GitHubOwner         = $null
        GitHubRepository    = $null
        GitHubRepoAdmin     = $false
    }

    Write-Verbose 'Running pre-flight diagnostics...'

    # 1. Azure: request a token so an expired session is detected
    try {
        $tenantId = az account get-access-token --resource https://management.azure.com/ --query tenant --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and $tenantId) {
            $result.AzureAuthenticated = $true
            $result.TenantId = $tenantId.Trim()
        }
    } catch {
        $result.AzureAuthenticated = $false
    }

    # 2. GitHub CLI session
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $null = gh auth status 2>&1
            if ($LASTEXITCODE -eq 0) { $result.GitHubAuthenticated = $true }
        } catch {
            $result.GitHubAuthenticated = $false
        }
    }

    # 3. Git remote -> owner/repo (read $Matches immediately; the next -match overwrites it)
    $remoteUrl = git config --get remote.origin.url 2>$null
    if ($remoteUrl -match $remotePattern) {
        $result.RemoteResolved   = $true
        $result.GitHubOwner      = $Matches[1]
        $result.GitHubRepository = $Matches[2]
    }

    # 4. Repo admin (needed to create environments and set secrets)
    if ($result.GitHubAuthenticated -and $result.RemoteResolved) {
        try {
            $isAdmin = gh api "repos/$($result.GitHubOwner)/$($result.GitHubRepository)" --jq '.permissions.admin' 2>$null
            if ($LASTEXITCODE -eq 0 -and "$isAdmin".Trim() -eq 'true') { $result.GitHubRepoAdmin = $true }
        } catch {
            $result.GitHubRepoAdmin = $false
        }
    }

    # Report: one data-driven loop instead of four copies of if/else
    $report = @(
        @{ Ok = $result.AzureAuthenticated;  Pass = "Azure CLI: live session (tenant $($result.TenantId))"; Fail = "Azure CLI: no live session (run 'az login')" }
        @{ Ok = $result.GitHubAuthenticated; Pass = 'GitHub CLI: authenticated';                           Fail = "GitHub CLI: not authenticated (run 'gh auth login')" }
        @{ Ok = $result.RemoteResolved;      Pass = "Git remote: $($result.GitHubOwner)/$($result.GitHubRepository)"; Fail = "Git remote: 'origin' is missing or not a GitHub URL (found: '$remoteUrl')" }
        @{ Ok = $result.GitHubRepoAdmin;     Pass = 'GitHub repo: admin access confirmed';                 Fail = 'GitHub repo: admin access not confirmed' }
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host '         PREFLIGHT SUMMARY REPORT'          -ForegroundColor Cyan
    Write-Host '========================================'   -ForegroundColor Cyan
    foreach ($line in $report) {
        if ($line.Ok) { Write-Host "[OK] $($line.Pass)" -ForegroundColor Green }
        else          { Write-Host "[FAIL] $($line.Fail)" -ForegroundColor Red }
    }
    Write-Host "========================================`n" -ForegroundColor Cyan

    if ($report | Where-Object { -not $_.Ok }) {
        if (-not $result.AzureAuthenticated) {
            Write-Host "[REMEDIATION] Run 'az login' and retry." -ForegroundColor Yellow
        }
        if (-not $result.GitHubAuthenticated) {
            Write-Host "[REMEDIATION] Run 'gh auth login' (GitHub.com, HTTPS, web browser, complete MFA)." -ForegroundColor Yellow
        } elseif (-not $result.RemoteResolved) {
            Write-Host "[REMEDIATION] Check your remotes with: git remote -v" -ForegroundColor Yellow
        } elseif (-not $result.GitHubRepoAdmin) {
            Write-Host "[REMEDIATION] This gh account lacks admin on $($result.GitHubOwner)/$($result.GitHubRepository). Confirm with: gh repo view --json viewerPermission" -ForegroundColor Yellow
        }
        throw 'Bootstrap aborted: preflight checks failed.'
    }

    Write-Host '[SUCCESS] All critical preflight checks passed.' -ForegroundColor Green
    return $result
}