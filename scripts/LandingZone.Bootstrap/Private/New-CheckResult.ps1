function New-CheckResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Ok,
        [Parameter(Mandatory)][string]$Message,
        [string]$Remediation
    )
    [pscustomobject]@{ Name = $Name; Ok = $Ok; Message = $Message; Remediation = $Remediation; Group = $null }
}