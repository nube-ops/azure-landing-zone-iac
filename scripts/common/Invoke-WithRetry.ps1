<#
.SYNOPSIS
    Shared reusable retry wrapper helper for transient fault handling.
#>
function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 3, [string]$ErrorMessage = "Operation failed after multiple attempts."
    )
    
    $retryCount = 0
    $success =$false

    while ($retryCount -lt $MaxRetries -and -not$success) {
        try {
            $retryCount++
            & $ScriptBlock
            $success =$true
        } catch {
            if ($retryCount -ge$MaxRetries) {
                Write-Host "`n[ERROR] $ErrorMessage $_" -ForegroundColor Red
                throw $_
            } else {
                Write-Host "[WARNING] Transient issue on attempt $retryCount. Retrying in $DelaySeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }
}