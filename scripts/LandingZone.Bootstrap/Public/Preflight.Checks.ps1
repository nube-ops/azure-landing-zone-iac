#Requires -Version 7.4
<#
.SYNOPSIS
    Preflight checks for the bootstrap entry points.
.DESCRIPTION
    Every Test-* function is read-only and returns a result object
    (Name, Ok, Message, Remediation, optional Group). None of them throw.
    Entry points choose which checks to run and in what order, then pass the
    results to Assert-Preflight, which prints one report and throws once if
    anything failed. Use Get-Help <function> for what each check verifies.

    Tool names and minimum versions live only in prerequisites.psd1;
    scripts/tools/Update-ReadmePrerequisites.ps1 renders the README table from it.
    New-CheckResult is defined once in Private/.
#>

# ---------------------------------------------------------------- Local environment
#   Test-Tooling, Test-BicepParamFile, Test-Json, Test-WorkloadTags

function Test-Tooling {
    <#
    .SYNOPSIS
        Checks that PowerShell and the required CLI tools meet their minimum versions.
    .DESCRIPTION
        Reads prerequisites.psd1, compares the running PowerShell version and the
        '--version' output of each listed tool (az, gh, git) against its minimum, and
        returns one result per tool with an install hint on failure.
    #>
    [CmdletBinding()]
    param([string]$ManifestPath = (Join-Path $PSScriptRoot '../prerequisites.psd1'))

    try {
        $manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
    } catch {
        return New-CheckResult -Name 'Tool:manifest' -Ok $false -Message "Tooling: cannot read manifest '$ManifestPath'" `
            -Remediation 'Restore scripts/LandingZone.Bootstrap/prerequisites.psd1 or pass -ManifestPath.'
    }

    # PowerShell is read from the running session; every other tool is probed via '<tool> --version'.
    $ps = $PSVersionTable.PSVersion
    $required = @(@{
        Name    = 'PowerShell'
        Minimum = $manifest.PowerShell.Minimum
        Fix     = $manifest.PowerShell.Fix
        Actual  = [version]"$($ps.Major).$($ps.Minor).$($ps.Patch)"
    })

    foreach ($t in $manifest.Tools) {
        $actual = $null
        if (Get-Command $t.Name -ErrorAction SilentlyContinue) {
            $text = & $t.Name --version 2>&1 | Out-String
            if ($text -match '\d+\.\d+(\.\d+)?') { $actual = [version]$Matches[0] }
        }
        $required += @{ Name = $t.Name; Minimum = $t.Minimum; Fix = $t.Fix; Actual = $actual }
    }

    foreach ($r in $required) {
        $check = "Tool:$($r.Name)"
        if (-not $r.Actual) {
            New-CheckResult -Name $check -Ok $false -Message "Tooling: '$($r.Name)' not found or version unreadable" `
                -Remediation $r.Fix
        } elseif ($r.Actual -lt [version]$r.Minimum) {
            New-CheckResult -Name $check -Ok $false `
                -Message "Tooling: $($r.Name) $($r.Actual) is older than the required $($r.Minimum)" `
                -Remediation $r.Fix
        } else {
            New-CheckResult -Name $check -Ok $true -Message "Tooling: $($r.Name) $($r.Actual) (>= $($r.Minimum))"
        }
    }
}

function Test-BicepParamFile {
    <#
    .SYNOPSIS
        Checks that the Bicep parameter file exists.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return New-CheckResult -Name 'BicepParamFile' -Ok $true -Message "Parameter file: $Path"
    }
    New-CheckResult -Name 'BicepParamFile' -Ok $false -Message "Parameter file not found: $Path" `
        -Remediation 'Pass -BicepParamPath or restore environments/<env>/main.bicepparam.'
}

function Test-JsonFile {
    <#
    .SYNOPSIS
        Checks that a JSON file exists and validates against its JSON Schema.
    .DESCRIPTION
        The schema defaults to '<name>.schema.json' beside the file
        (workloads.json -> workloads.schema.json), so callers pass one path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$SchemaPath = ($Path -replace '\.json$', '.schema.json')
    )

    $name = "JsonFile:$(Split-Path $Path -Leaf)"
    foreach ($f in $Path, $SchemaPath) {
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
            return New-CheckResult -Name $name -Ok $false -Message "JSON config: file not found: $f" `
                -Remediation "Restore '$f' from the repository."
        }
    }

    try {
        $null = Test-Json -Json (Get-Content -LiteralPath $Path -Raw) -SchemaFile $SchemaPath -ErrorAction Stop
        New-CheckResult -Name $name -Ok $true -Message "JSON config: $(Split-Path $Path -Leaf) matches $(Split-Path $SchemaPath -Leaf)"
    } catch {
        New-CheckResult -Name $name -Ok $false -Message "JSON config: $(Split-Path $Path -Leaf) is invalid: $($_.Exception.Message)" `
            -Remediation "Fix '$Path' to satisfy '$SchemaPath'."
    }
}

function Test-WorkloadTags {
    <#
    .SYNOPSIS
        Preflight adapter over Get-WorkloadTags; validation logic lives there (DRY).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Environment,
        [Parameter(Mandatory)][string]$Path
    )

    $name = "WorkloadTags:$Workload"
    try {
        $tags = Get-WorkloadTags @PSBoundParameters
        New-CheckResult -Name $name -Ok $true `
            -Message "Workload tags: '$Workload' resolved ($(($tags.Keys | Sort-Object) -join ', '))"
    }
    catch {
        New-CheckResult -Name $name -Ok $false -Message "Workload tags: $($_.Exception.Message)" `
            -Remediation "Add or fix the '$Workload' entry in '$Path'."
    }
}

# ---------------------------------------------------------------- GitHub
#   Test-GitHubSession, Test-GitHubRemote, Test-GitHubRepoAdmin

function Test-GitHubSession {
    <#
    .SYNOPSIS
        Checks that the GitHub CLI is authenticated.
    #>

    [CmdletBinding()]
    param()

    # Success is decided inside the try. If 'gh' is missing the call throws, and a stale
    # $LASTEXITCODE from an earlier command must never be read as "authenticated".
    # A missing 'gh' is reported, with its install hint, by Test-Tooling.
    $authenticated = $false
    try { $null = gh auth status 2>&1; $authenticated = ($LASTEXITCODE -eq 0) } catch { }

    if ($authenticated) {
        return New-CheckResult -Name 'GitHubSession' -Ok $true -Message 'GitHub CLI: authenticated'
    }
    New-CheckResult -Name 'GitHubSession' -Ok $false -Message 'GitHub CLI: not authenticated' `
        -Remediation "Run 'gh auth login' (GitHub.com, HTTPS, web browser, complete MFA)."
}

function Test-GitHubRemote {
    <#
    .SYNOPSIS
        Checks that the owner and repository can be resolved from parameters or the git remote.
    #>
    [CmdletBinding()]
    param([string]$Owner, [string]$Repository)

    try {
        $repo = Resolve-GitHubRepository -Owner $Owner -Repository $Repository
        New-CheckResult -Name 'GitHubRemote' -Ok $true -Message "Git remote: $($repo.Owner)/$($repo.Repository)"
    } catch {
        New-CheckResult -Name 'GitHubRemote' -Ok $false -Message "Git remote: $($_.Exception.Message)" `
            -Remediation 'Check your remotes with: git remote -v'
    }
}

function Test-GitHubRepoAdmin {
    <#
    .SYNOPSIS
        Checks that the signed-in GitHub account has admin on the repository.
    #>
    [CmdletBinding()]
    param([string]$Owner, [string]$Repository)

    try { $repo = Resolve-GitHubRepository -Owner $Owner -Repository $Repository }
    catch {
        return New-CheckResult -Name 'GitHubRepoAdmin' -Ok $false `
            -Message "GitHub repo: cannot determine the repository ($($_.Exception.Message))" `
            -Remediation 'Fix the git remote or pass -GitHubOwner and -GitHubRepository.'
    }

    $isAdmin = $null
    try { $isAdmin = gh api "repos/$($repo.Owner)/$($repo.Repository)" --jq '.permissions.admin' 2>$null } catch { }

    if ($LASTEXITCODE -eq 0 -and "$isAdmin".Trim() -eq 'true') {
        return New-CheckResult -Name 'GitHubRepoAdmin' -Ok $true `
            -Message "GitHub repo: admin access confirmed on $($repo.Owner)/$($repo.Repository)"
    }
    New-CheckResult -Name 'GitHubRepoAdmin' -Ok $false `
        -Message "GitHub repo: admin access not confirmed on $($repo.Owner)/$($repo.Repository)" `
        -Remediation "This gh account needs admin on $($repo.Owner)/$($repo.Repository). Confirm with: gh repo view --json viewerPermission"
}

# ---------------------------------------------------------------- Azure
#   Test-AzureSession, Test-TargetSubscription, Test-ProviderRegistered, Test-CanWriteRoleAssignments
function Test-AzureSession {
    <#
    .SYNOPSIS
        Checks for a live Azure CLI session by requesting an access token.
    #>
    [CmdletBinding()]
    param()

    # A token request detects an expired session; 'az account show' reads the cache and would not.
    $tenant = $null
    try { $tenant = az account get-access-token --resource https://management.azure.com/ --query tenant --output tsv 2>$null } catch { }

    if ($LASTEXITCODE -eq 0 -and $tenant) {
        return New-CheckResult -Name 'AzureSession' -Ok $true -Message "Azure CLI: live session (tenant $($tenant.Trim()))"
    }
    New-CheckResult -Name 'AzureSession' -Ok $false -Message 'Azure CLI: no live session' -Remediation "Run 'az login' and retry."
}


# ---------------------------------------------------------------- Stage 2

function Test-TargetSubscription {
    <#
    .SYNOPSIS
        Checks that a subscription is visible, enabled and in the session’s tenant.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$TenantId
    )

    $json = $null
    try { $json = az account show --subscription $SubscriptionId --output json 2>$null } catch { }
    if ($LASTEXITCODE -ne 0 -or -not $json) {
        return New-CheckResult -Name "Subscription:$SubscriptionId" -Ok $false `
            -Message "Subscription ${SubscriptionId}: not visible to this session" `
            -Remediation "Confirm the ID in main.bicepparam and that your account has access (az account list)."
    }
    $sub = ($json -join "`n") | ConvertFrom-Json
    if ($sub.state -ne 'Enabled') {
        return New-CheckResult -Name "Subscription:$SubscriptionId" -Ok $false `
            -Message "Subscription ${SubscriptionId}: state is '$($sub.state)', expected 'Enabled'" `
            -Remediation 'Re-enable the subscription or choose another target.'
    }
    if ($sub.tenantId -ne $TenantId) {
        return New-CheckResult -Name "Subscription:$SubscriptionId" -Ok $false `
            -Message "Subscription ${SubscriptionId}: belongs to tenant $($sub.tenantId), session is in $TenantId" `
            -Remediation "Run 'az login --tenant $($sub.tenantId)' or correct the subscription ID."
    }
    New-CheckResult -Name "Subscription:$SubscriptionId" -Ok $true -Message "Subscription ${SubscriptionId}: enabled, tenant matches"
}

function Test-ProviderRegistered {
    <#
    .SYNOPSIS
        Checks that a resource provider is registered in a subscription.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$Namespace
    )

    $state = $null
    try { $state = az provider show --namespace $Namespace --subscription $SubscriptionId --query registrationState --output tsv 2>$null } catch { }

    if ($LASTEXITCODE -eq 0 -and "$state".Trim() -eq 'Registered') {
        return New-CheckResult -Name "Provider:$Namespace" -Ok $true -Message "Provider ${Namespace}: registered in $SubscriptionId"
    }
    New-CheckResult -Name "Provider:$Namespace" -Ok $false `
        -Message "Provider ${Namespace}: state '$("$state".Trim())' in $SubscriptionId" `
        -Remediation "az provider register --namespace $Namespace --subscription $SubscriptionId"
}

function Test-CanWriteRoleAssignments {
    <#
    .SYNOPSIS
        Checks the caller’s effective permissions allow role assignment writes at a scope.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Scope)

    # Effective permissions of the caller at this scope (works for users and service principals).
    $target = 'Microsoft.Authorization/roleAssignments/write'
    $url    = "https://management.azure.com$($Scope.TrimEnd('/'))/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"

    $json = $null
    try { $json = az rest --method get --url $url --query value --output json 2>$null } catch { }
    if ($LASTEXITCODE -ne 0 -or -not $json) {
        return New-CheckResult -Name "RbacWrite:$Scope" -Ok $false -Message "RBAC: could not read effective permissions at '$Scope'" `
            -Remediation 'Confirm you can read the scope (az account show) and re-run.'
    }

    $permissions = ($json -join "`n") | ConvertFrom-Json
    $allowed = $permissions | Where-Object {
        ($_.actions | Where-Object { $target -like $_ }) -and
        -not ($_.notActions | Where-Object { $target -like $_ })
    }

    if ($allowed) {
        return New-CheckResult -Name "RbacWrite:$Scope" -Ok $true -Message "RBAC: can write role assignments at '$Scope'"
    }
    New-CheckResult -Name "RbacWrite:$Scope" -Ok $false -Message "RBAC: cannot write role assignments at '$Scope'" `
        -Remediation "Grant yourself Owner or User Access Administrator at '$Scope'."
}

# ---------------------------------------------------------------- Gate

function Assert-Preflight {
    <#
    .SYNOPSIS
        Prints a titled report of check results and throws if any failed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyCollection()][object[]]$Check,
        [Parameter()][string]$Title = 'PREFLIGHT SUMMARY REPORT'
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "         $Title"          -ForegroundColor Cyan
    Write-Host "========================================"   -ForegroundColor Cyan
    $lastGroup = $null
    foreach ($c in $Check) {
        if ($c.Group -and $c.Group -ne $lastGroup) {
            Write-Host "`n-- $($c.Group) --" -ForegroundColor DarkCyan
            $lastGroup = $c.Group
        }
        if ($c.Ok) { Write-Host "[OK] $($c.Message)"   -ForegroundColor Green }
        else       { Write-Host "[FAIL] $($c.Message)" -ForegroundColor Red }
    }

    Write-Host "========================================`n" -ForegroundColor Cyan

    $failed = @($Check | Where-Object { -not $_.Ok })
    if ($failed.Count -gt 0) {
        $failed.Remediation | Where-Object { $_ } | Select-Object -Unique |
            ForEach-Object { Write-Host "[REMEDIATION] $_" -ForegroundColor Yellow }
        throw "Bootstrap aborted: $($failed.Count) preflight check(s) failed."
    }

    Write-Host "[SUCCESS] All preflight checks passed: $Title." -ForegroundColor Green
}