function New-CheckResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Message = '',
        [string]$Remediation = '',
        [ValidateSet('Error', 'Warning', 'Info')][string]$Severity = 'Error'
    )
    [pscustomobject]@{
        PSTypeName  = 'LandingZone.CheckResult'
        Name        = $Name
        Passed      = $Passed
        Severity    = $Severity
        Message     = $Message
        Remediation = $Remediation
    }
}