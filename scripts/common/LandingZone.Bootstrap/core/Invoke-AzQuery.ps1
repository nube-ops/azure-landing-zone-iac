function Invoke-AzQuery {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Arguments)

    $out    = & az @Arguments --output json 2>&1
    $errors = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    if ($LASTEXITCODE -ne 0) {
        throw "az $($Arguments -join ' ') failed (exit $LASTEXITCODE): $($errors -join ' ')"
    }
    $json = ($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
    if ($json) { $json | ConvertFrom-Json }
}