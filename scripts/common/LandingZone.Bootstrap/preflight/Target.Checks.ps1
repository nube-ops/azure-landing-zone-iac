function Test-SubscriptionEnabled {
    [CmdletBinding()] param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Workload)
    $name = "Subscription[$Workload].Enabled"
    $id   = $Config.SubscriptionIds[$Workload]
    try   { $sub = Invoke-AzQuery -Arguments 'account', 'show', '--subscription', $id }
    catch { return New-CheckResult -Name $name -Passed $false -Message "Cannot read $id." `
                -Remediation "Check the ID in main.bicepparam and that your 'az login' tenant can see it." }
    $ok = $sub.state -eq 'Enabled'
    New-CheckResult -Name $name -Passed $ok -Message "$($sub.name) is $($sub.state)." `
        -Remediation 'Re-enable the subscription or fix the ID in main.bicepparam.'
}

function Test-SubscriptionInManagementGroup {
    [CmdletBinding()] param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Workload)
    $name = "Subscription[$Workload].ManagementGroup"
    $mg   = "$($Config.RootMgName)-$Workload"
    try {
        $null = Invoke-AzQuery -Arguments 'account', 'management-group', 'subscription', 'show',
                                          '--name', $mg, '--subscription', $Config.SubscriptionIds[$Workload]
        New-CheckResult -Name $name -Passed $true -Message "Associated with $mg."
    } catch {
        New-CheckResult -Name $name -Passed $false -Message "Not found under $mg." `
            -Remediation 'Re-run the foundation deployment (deploy-foundation.yml); phase 4 did not complete for this subscription.'
    }
}

function Test-CallerCanAssignRoles {
    [CmdletBinding()] param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Workload)
    $name   = "Subscription[$Workload].RoleAssignWrite"
    $id     = $Config.SubscriptionIds[$Workload]
    $action = 'Microsoft.Authorization/roleAssignments/write'
    try {
        $perm = Invoke-AzQuery -Arguments 'rest', '--method', 'get', '--url',
            "https://management.azure.com/subscriptions/$id/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"
    } catch {
        return New-CheckResult -Name $name -Passed $false -Message 'Could not read effective permissions.' `
                   -Remediation 'Needs at least Reader on the subscription.'
    }
    $allowed = [bool](@($perm.value).Where({ Test-AzureActionAllowed -Action $action -Actions $_.actions -NotActions $_.notActions }))
    New-CheckResult -Name $name -Passed $allowed `
        -Message $(if ($allowed) { 'Role assignment write appears allowed (deny assignments and ABAC conditions are not visible here).' }
                   else          { 'Caller cannot write role assignments.' }) `
        -Remediation 'Grant Owner or User Access Administrator on the subscription to the account running the bootstrap.'
}

function Test-ResourceProvidersRegistered {
    [CmdletBinding()] param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Workload)
    $id = $Config.SubscriptionIds[$Workload]
    foreach ($ns in 'Microsoft.ManagedIdentity', 'Microsoft.Authorization') {
        $state = Invoke-AzQuery -Arguments 'provider', 'show', '--namespace', $ns, '--subscription', $id, '--query', 'registrationState'
        New-CheckResult -Name "Subscription[$Workload].Provider.$ns" -Passed ($state -eq 'Registered') `
            -Message "$ns is $state." -Remediation "az provider register --namespace $ns --subscription $id"
    }
}