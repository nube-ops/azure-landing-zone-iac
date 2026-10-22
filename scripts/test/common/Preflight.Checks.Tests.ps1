BeforeAll { . (Join-Path $PSScriptRoot '../../scripts/common/Import-BootstrapCommon.ps1') }

Describe 'Get-GitHubRepoContext' {
    It 'parses repo names containing dots' {
        Mock git { 'https://github.com/acme/my.repo.name.git' }
        (Get-GitHubRepoContext).Repository | Should -Be 'my.repo.name'
    }
    It 'lets explicit parameters win' {
        (Get-GitHubRepoContext -Owner a -Repository b).FullName | Should -Be 'a/b'
    }
}

Describe 'Assert-Preflight' {
    BeforeAll { Mock Write-BootstrapLog {} }
    It 'throws when any check fails' {
        { Assert-Preflight @((New-CheckResult 'x' $false 'bad' 'fix')) } | Should -Throw
    }
    It 'passes when all checks pass' {
        { Assert-Preflight @((New-CheckResult 'x' $true 'ok' '')) } | Should -Not -Throw
    }
}