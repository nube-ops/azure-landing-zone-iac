BeforeAll { . (Join-Path $PSScriptRoot '../../../common/Import-Libraries.ps1') }

Describe 'Write-BootstrapLog' {
    BeforeEach { Mock Write-Host {}; $env:GITHUB_ACTIONS = $null }

    It 'tags errors and never throws' {
        { Write-BootstrapLog 'boom' -Level Error } | Should -Not -Throw
        Should -Invoke Write-Host -ParameterFilter { $Object -eq '[ERROR] boom' }
    }
    It 'emits a workflow annotation in GitHub Actions' {
        $env:GITHUB_ACTIONS = 'true'
        Write-BootstrapLog 'boom' -Level Error
        Should -Invoke Write-Host -ParameterFilter { $Object -eq '::error::boom' }
    }
}