function Test-BicepParamFile {
    <#
    .SYNOPSIS
        Verifies main.bicepparam exists and maps every requested workload to a real
        (non-placeholder) subscription GUID. One result per finding.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Workload = @()
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return New-CheckResult 'BicepParamFile' $false "not found: $Path" `
            'Copy main.bicepparam.example to main.bicepparam, then run Initialize-SubscriptionSecrets.ps1'
    }
    New-CheckResult 'BicepParamFile' $true $Path ''

    $guid        = '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
    $placeholder = '^(\d)\1{7}-\1{4}-\1{4}-\1{4}-\1{12}$'   # 1111..., 2222..., etc.

    foreach ($w in $Workload) {
        $name = "BicepSubscription:$w"
        $id   = Get-BicepSubscriptionId -BicepParamPath $Path -Workload $w
        if (-not $id) {
            New-CheckResult $name $false 'no subscription ID mapped' `
                "Add a subscriptionIds entry for '$w' in $Path"
        } elseif ($id -notmatch $guid) {
            New-CheckResult $name $false "'$id' is not a GUID" "Fix the '$w' entry in $Path"
        } elseif ($id -match $placeholder) {
            New-CheckResult $name $false "placeholder ID $id" `
                'Run Initialize-SubscriptionSecrets.ps1 to inject real subscription IDs'
        } else {
            New-CheckResult $name $true $id ''
        }
    }
}