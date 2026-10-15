[CmdletBinding()]
param(
    [string]$BicepParamPath = (Join-Path $PSScriptRoot "../../environments/prod/main.bicepparam"),
    [string]$ConfigPath = (Join-Path $PSScriptRoot "../../environments/prod/platform-teams.json")
)

# Dot-source preflight validation and retry helper
. (Join-Path $PSScriptRoot "../common/Test-EnvironmentPreflight.ps1")
. (Join-Path $PSScriptRoot "../common/Invoke-WithRetry.ps1") # Assumed path for retry wrapper
Test-EnvironmentPreflight

# 1. Dynamically parse orgName from main.bicepparam
if (Test-Path $BicepParamPath) {
    $bicepParamContent = Get-Content -Path $BicepParamPath -Raw
    
    if ($bicepParamContent -match "param\s+orgName\s*=\s*'([^']+)'") {
        $orgName = $Matches[1]
    }

    # Dynamically extract the primary location and region code where 'isPrimary: true'
    if ($bicepParamContent -match "(?s)location:\s*'([^']+)'[^}]*?regionCode:\s*'([^']+)'[^}]*?isPrimary:\s*true") {
        $primaryLocation = $Matches[1]
        $primaryRegionCode = $Matches[2]
    }
}

if ([string]::IsNullOrWhiteSpace($orgName) -or [string]::IsNullOrWhiteSpace($primaryLocation) -or [string]::IsNullOrWhiteSpace($primaryRegionCode)) {
    throw "Failed to dynamically resolve orgName, primary location, or region code from $BicepParamPath."
}

# 2. Load platform team definitions from the JSON manifest
if (-not (Test-Path $ConfigPath)) {
    throw "Platform identity configuration file not found at: $ConfigPath"
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

# 3. Iterate through each platform team dynamically for Identity & RBAC Provisioning
foreach ($team in $config.platformTeams) {
    Write-Host "`n----------------------------------------" -ForegroundColor Cyan
    Write-Host " Processing Platform Team Identity: $($team.name)" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    $groupName = "SG-$orgName-$($team.slug)-Admins"
    $mailNickname = $team.mailNickname
    $roleName = $team.roleName
    $workloadKey = $team.targetSubscriptionWorkload

    $subIdRegex = "mgName:\s*'[^']*-{0}'\s*subscriptionIds:\s*\[\s*'([^']+)'" -f $workloadKey
    if ($bicepParamContent -match $subIdRegex) {
        $targetSubId = $Matches[1]
    }

    if ([string]::IsNullOrWhiteSpace($targetSubId)) {
        throw "Failed to resolve subscription ID for workload key '$workloadKey' from $BicepParamPath."
    }

    # 4. Idempotent Entra ID Security Group Upsert with Retry Protection
    Write-Host "Checking for existing Entra ID Security Group '$groupName'..." -ForegroundColor Cyan

    $existingGroupId = Invoke-WithRetry -MaxRetries 3 -DelaySeconds 5 -ErrorMessage "Failed to query Entra ID group '$groupName'." -ScriptBlock {
        $result = az ad group list --display-name $groupName --query "[0].id" -o tsv 2>$null
        if (-not [string]::IsNullOrWhiteSpace($result)) {
            $result.Trim()
        } else {
            $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($existingGroupId)) {
        Write-Host "Creating Entra ID Security Group '$groupName'..." -ForegroundColor Cyan
        $groupId = Invoke-WithRetry -MaxRetries 3 -DelaySeconds 5 -ErrorMessage "Failed to create Entra ID group '$groupName'." -ScriptBlock {
            (az ad group create --display-name $groupName --mail-nickname $mailNickname --query id -o tsv).Trim()
        }
    } else {
        Write-Host "Security Group '$groupName' already exists. Skipping creation." -ForegroundColor Green
        $groupId = $existingGroupId
    }

    # 5. Idempotent Subscription-Scope RBAC Assignment with Retry Protection
    $scope = "/subscriptions/$targetSubId"
    Write-Host "Checking existing '$roleName' role assignment at scope..." -ForegroundColor Cyan

    $existingRole = Invoke-WithRetry -MaxRetries 3 -DelaySeconds 5 -ErrorMessage "Failed to check existing role assignment." -ScriptBlock {
        az role assignment list --assignee $groupId --scope $scope --role $roleName --query "[0].id" -o tsv 2>$null
    }

    if ([string]::IsNullOrWhiteSpace($existingRole)) {
        Write-Host "Assigning '$roleName' role to subscription scope..." -ForegroundColor Cyan
        Invoke-WithRetry -MaxRetries 3 -DelaySeconds 5 -ErrorMessage "Failed to assign '$roleName' role." -ScriptBlock {
            az role assignment create --role $roleName --assignee-object-id $groupId --assignee-principal-type Group --scope $scope --output none
        }
    } else {
        Write-Host "Role '$roleName' is already assigned at this scope. Skipping." -ForegroundColor Green
    }

    # ==========================================
    # Visual Terminal Verification Phase (Inside Loop)
    # ==========================================
    Write-Host "`nVerifying Deployed Identity & RBAC Configuration for $($team.name)..." -ForegroundColor Cyan

    Write-Host "[SUCCESS] Entra ID Security Group '$groupName' is ready." -ForegroundColor Green
    az ad group show --group $groupName --output table
    Write-Host ""

    Write-Host "[SUCCESS] Subscription-Scope RBAC Assignment is active." -ForegroundColor Green
    az role assignment list --assignee $groupId --scope $scope --output table

    Write-Host "[SUCCESS] Platform team '$($team.name)' identity and RBAC converged successfully." -ForegroundColor Green
}