function Invoke-Preflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Scenario,
        [Parameter(Mandatory)][hashtable]$Context
    )

    $plans = Import-PowerShellDataFile (Join-Path $script:ModuleRoot 'config/preflight.scenarios.psd1')
    $plan  = $plans[$Scenario]
    if (-not $plan) { throw "Unknown preflight scenario '$Scenario'." }

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($step in $plan) {
        if (-not $script:CheckRegistry.ContainsKey($step.Check)) {
            throw "Scenario '$Scenario' references unregistered check '$($step.Check)'."
        }
        $targets     = if ($step.PerWorkload) { $Context.Workload } else { @($null) }
        $stepResults = foreach ($t in $targets) { & $script:CheckRegistry[$step.Check] $Context $t }
        $results.AddRange(@($stepResults))

        if ($step.Gate -and @($stepResults).Where({ -not $_.Passed -and $_.Severity -eq 'Error' })) { break }
    }
    Assert-Preflight -Results $results
}