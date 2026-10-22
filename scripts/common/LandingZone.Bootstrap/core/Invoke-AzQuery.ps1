function Invoke-AzQuery {
    <#
    .SYNOPSIS
        Runs an az command and returns parsed JSON, or $null on any failure.
    .NOTES
        Never throws, so every preflight check can report instead of aborting.
        Takes an argument array (not free-form args) so '--flags' bind safely.
    .EXAMPLE
        Invoke-AzQuery -Argument 'account', 'show', '--subscription', $id
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Argument)

    $global:LASTEXITCODE = 0
    $raw = az @Argument --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace("$raw")) { return $null }
    $raw | ConvertFrom-Json
}