function Test-TargetSubscription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$TenantId
    )
    $name = "TargetSubscription:$SubscriptionId"
    $sub  = Invoke-AzQuery -Argument 'account', 'show', '--subscription', $SubscriptionId

    if (-not $sub) {
        return New-CheckResult $name $false 'not visible to the signed-in account' `
            'Confirm the ID with: az account list --all'
    }
    $tenantMatch = $sub.tenantId -eq $TenantId
    New-CheckResult $name ($sub.state -eq 'Enabled' -and $tenantMatch) `
        "state=$($sub.state), tenantMatch=$tenantMatch" `
        'Enable the subscription, or sign in to its tenant: az login --tenant <tenant-id>'
}

function Test-ProviderRegistered {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string[]]$Namespace
    )
    foreach ($ns in $Namespace) {
        $provider = Invoke-AzQuery -Argument 'provider', 'show', '--namespace', $ns, '--subscription', $SubscriptionId
        $state    = if ($provider.registrationState) { $provider.registrationState } else { 'unknown' }
        New-CheckResult "Provider:${ns}:$SubscriptionId" ($state -eq 'Registered') "state=$state" `
            "az provider register --namespace $ns --subscription $SubscriptionId --wait"
    }
}

function Test-AzureActionAllowed {
    <# Pure function: does any permission entry allow the action and not exclude it? #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object[]]$Permission,
        [Parameter(Mandatory)][string]$Action
    )
    foreach ($p in $Permission) {
        $allowed = @($p.actions)    | Where-Object { $_ -and $Action -like $_ }
        $denied  = @($p.notActions) | Where-Object { $_ -and $Action -like $_ }
        if (@($allowed).Count -gt 0 -and @($denied).Count -eq 0) { return $true }
    }
    $false
}

function Test-CanWriteRoleAssignments {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Scope)

    $action = 'Microsoft.Authorization/roleAssignments/write'
    $url    = "https://management.azure.com$Scope/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"
    $perm   = Invoke-AzQuery -Argument 'rest', '--method', 'get', '--url', $url, '--query', 'value'

    $ok = [bool]$perm -and (Test-AzureActionAllowed -Permission @($perm) -Action $action)
    New-CheckResult "CanWriteRoleAssignments:$Scope" $ok `
        $(if ($ok) { 'roleAssignments/write is allowed' } else { 'roleAssignments/write not granted' }) `
        "Need Owner or User Access Administrator at $Scope (activate PIM first if eligible)"
}