<#
.SYNOPSIS
    Shared reusable retry wrapper helper for transient fault handling.
#>
function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 3,
        [string]$ErrorMessage = 'Operation failed after multiple attempts.'
    )
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $global:LASTEXITCODE = 0
            $result = & $ScriptBlock
            if ($LASTEXITCODE -ne 0) { throw "Native command exited with code $LASTEXITCODE." }
            return $result
        } catch {
            if ($attempt -eq $MaxRetries) { throw "$ErrorMessage $_" }
            Write-Warning "Attempt $attempt failed: $_. Retrying in $($DelaySeconds * $attempt)s..."
            Start-Sleep -Seconds ($DelaySeconds * $attempt)
        }
    }
}