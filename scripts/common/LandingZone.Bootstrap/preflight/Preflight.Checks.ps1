function New-CheckResult {
    param([string]$Name, [bool]$Ok, [string]$Detail, [string]$Fix, [hashtable]$Data = @{})
    [pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail; Remediation = $Fix; Data = $Data }
}

function Test-AzureSession {
    [CmdletBinding()] param()
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        return New-CheckResult 'AzureSession' $false 'az not installed' 'winget install --id Microsoft.AzureCLI'
    }
    $tenant = az account get-access-token --resource https://management.azure.com/ --query tenant -o tsv 2>$null
    $ok = ($LASTEXITCODE -eq 0 -and [bool]$tenant)
    New-CheckResult 'AzureSession' $ok $(if ($ok) { "live session (tenant $($tenant.Trim()))" } else { 'no live session' }) `
        "az login" @{ TenantId = "$tenant".Trim() }
}

function Test-GitHubSession {
    [CmdletBinding()] param()
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        return New-CheckResult 'GitHubSession' $false 'gh not installed' 'winget install --id GitHub.Cli'
    }
    $null = gh auth status 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    New-CheckResult 'GitHubSession' $ok $(if ($ok) { 'authenticated' } else { 'not authenticated' }) `
        'gh auth login (GitHub.com, HTTPS, web browser, complete MFA)'
}

function Get-GitHubRepoContext {   # one shared regex; explicit parameters win over the git remote
    [CmdletBinding()]
    param([string]$Owner, [string]$Repository)
    if (-not ($Owner -and $Repository)) {
        $remoteUrl = git config --get remote.origin.url 2>$null
        if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?/?$') {
            if (-not $Owner)      { $Owner      = $Matches[1] }
            if (-not $Repository) { $Repository = $Matches[2] }
        }
    }
    if ($Owner -and $Repository) {
        [pscustomobject]@{ Owner = $Owner; Repository = $Repository; FullName = "$Owner/$Repository" }
    }
}

function Test-GitHubRepoAdmin {
    [CmdletBinding()]
    param([object]$Repo)
    if (-not $Repo) {
        return New-CheckResult 'GitHubRepoAdmin' $false 'repo not resolved' `
            "Pass -GitHubOwner/-GitHubRepository or fix 'git remote -v'"
    }
    $admin = gh api "repos/$($Repo.FullName)" --jq '.permissions.admin' 2>$null
    New-CheckResult 'GitHubRepoAdmin' ($LASTEXITCODE -eq 0 -and "$admin".Trim() -eq 'true') `
        $Repo.FullName "Need admin on $($Repo.FullName) to create environments and set secrets"
}

function Assert-Preflight {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][object[]]$Result)
    Write-BootstrapLog 'PREFLIGHT' -Level Header
    foreach ($r in $Result) {
        if ($r.Ok) { Write-BootstrapLog "$($r.Name): $($r.Detail)" -Level Success }
        else       { Write-BootstrapLog "$($r.Name): $($r.Detail) -> $($r.Remediation)" -Level Error }
    }
    if ($Result | Where-Object { -not $_.Ok }) { throw 'Bootstrap aborted: preflight checks failed.' }
}