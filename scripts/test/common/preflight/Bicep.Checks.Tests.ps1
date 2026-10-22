BeforeAll {
    . (Join-Path $PSScriptRoot '../../../common/Import-Libraries.ps1')
    $path = Join-Path $TestDrive 'main.bicepparam'
    Set-Content -Path $path -Value @'
param subscriptionAssociations = [
  {
    mgName: '${rootMgName}-corp'
    subscriptionIds: [
      'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' // real
    ]
  }
  {
    mgName: '${rootMgName}-online'
    subscriptionIds: [
      '22222222-2222-2222-2222-222222222222'
    ]
  }
]
'@
}

Describe 'Get-BicepSubscriptionId' {
    It 'returns the mapped ID' {
        Get-BicepSubscriptionId -BicepParamPath $path -Workload corp | Should -Be 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    }
    It 'returns $null for an unmapped workload or missing file' {
        Get-BicepSubscriptionId -BicepParamPath $path -Workload identity | Should -BeNullOrEmpty
        Get-BicepSubscriptionId -BicepParamPath (Join-Path $TestDrive 'nope') -Workload corp | Should -BeNullOrEmpty
    }
}

Describe 'Test-BicepParamFile' {
    It 'reports every problem in one pass' {
        $r = Test-BicepParamFile -Path $path -Workload corp, online, identity
        ($r | Where-Object Name -eq 'BicepSubscription:corp').Ok     | Should -BeTrue
        ($r | Where-Object Name -eq 'BicepSubscription:online').Ok   | Should -BeFalse   # placeholder
        ($r | Where-Object Name -eq 'BicepSubscription:identity').Ok | Should -BeFalse   # unmapped
    }
    It 'fails when the file is missing' {
        (Test-BicepParamFile -Path (Join-Path $TestDrive 'nope')).Ok | Should -BeFalse
    }
}