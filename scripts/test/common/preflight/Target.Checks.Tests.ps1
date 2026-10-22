BeforeAll { . (Join-Path $PSScriptRoot '../../../common/Import-Libraries.ps1') }

Describe 'Test-AzureActionAllowed' {
    $write = 'Microsoft.Authorization/roleAssignments/write'
    It 'allows a wildcard grant' {
        Test-AzureActionAllowed -Permission @(@{ actions = @('*'); notActions = @() }) -Action $write | Should -BeTrue
    }
    It 'denies when notActions excludes it (Contributor-style)' {
        $p = @{ actions = @('*'); notActions = @('Microsoft.Authorization/*/write') }
        Test-AzureActionAllowed -Permission @($p) -Action $write | Should -BeFalse
    }
}

Describe 'Test-TargetSubscription' {
    It 'passes for an enabled subscription in the right tenant' {
        Mock Invoke-AzQuery { [pscustomobject]@{ state = 'Enabled'; tenantId = 't1' } }
        (Test-TargetSubscription -SubscriptionId s -TenantId t1).Ok | Should -BeTrue
    }
    It 'fails on tenant mismatch' {
        Mock Invoke-AzQuery { [pscustomobject]@{ state = 'Enabled'; tenantId = 'other' } }
        (Test-TargetSubscription -SubscriptionId s -TenantId t1).Ok | Should -BeFalse
    }
    It 'fails when the subscription is not visible' {
        Mock Invoke-AzQuery { $null }
        (Test-TargetSubscription -SubscriptionId s -TenantId t1).Ok | Should -BeFalse
    }
}

Describe 'Test-ProviderRegistered' {
    It 'returns one result per namespace' {
        Mock Invoke-AzQuery { [pscustomobject]@{ registrationState = 'NotRegistered' } }
        $r = Test-ProviderRegistered -SubscriptionId s -Namespace 'Microsoft.Resources', 'Microsoft.ManagedIdentity'
        $r.Count | Should -Be 2
        $r.Ok    | Should -Not -Contain $true
    }
}

Describe 'Test-CanWriteRoleAssignments' {
    It 'fails when the permissions call fails' {
        Mock Invoke-AzQuery { $null }
        (Test-CanWriteRoleAssignments -Scope '/subscriptions/s').Ok | Should -BeFalse
    }
}