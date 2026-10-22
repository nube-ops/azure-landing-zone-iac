BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../../common/LandingZone.Bootstrap') -Force
}

Describe 'Assert-Preflight' {
    It 'throws on a failed Error check' {
        $r = New-CheckResult -Name 'x' -Passed $false -Message 'bad'
        { Assert-Preflight -Results $r } | Should -Throw '*blocking*'
    }
    It 'does not throw on a failed Warning check' {
        $r = New-CheckResult -Name 'x' -Passed $false -Severity Warning
        { Assert-Preflight -Results $r } | Should -Not -Throw
    }
}

Describe 'Invoke-Preflight' {
    It 'stops at the first failed gate (no cascade)' {
        Mock Test-Tooling       -ModuleName LandingZone.Bootstrap { New-CheckResult -Name 'Tooling' -Passed $false }
        Mock Test-AzureSession  -ModuleName LandingZone.Bootstrap { New-CheckResult -Name 'Az' -Passed $true }
        { Invoke-Preflight -Scenario Tenant -Context @{} } | Should -Throw
        Should -Invoke Test-AzureSession -ModuleName LandingZone.Bootstrap -Times 0
    }
    It 'rejects a scenario referencing an unregistered check' { <# fixture plan #> }
}

Describe 'Test-CallerCanAssignRoles' {
    It 'fails for Contributor-style permissions' {
        Mock Invoke-AzQuery -ModuleName LandingZone.Bootstrap {
            [pscustomobject]@{ value = @([pscustomobject]@{ actions = @('*'); notActions = @('Microsoft.Authorization/*/write') }) } }
        $cfg = [pscustomobject]@{ SubscriptionIds = @{ corp = '00000000-0000-0000-0000-000000000001' } }
        (Test-CallerCanAssignRoles -Config $cfg -Workload corp).Passed | Should -BeFalse
    }
}