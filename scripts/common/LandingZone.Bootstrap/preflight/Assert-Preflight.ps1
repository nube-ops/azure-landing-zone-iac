function Assert-Preflight {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results)

    foreach ($r in $Results) {
        $tag, $color = if ($r.Passed)                { 'OK',   'Green'  }
                       elseif ($r.Severity -eq 'Error') { 'FAIL', 'Red'    }
                       else                          { 'WARN', 'Yellow' }
        Write-Host ("[{0}] {1}: {2}" -f $tag, $r.Name, $r.Message) -ForegroundColor $color
        if (-not $r.Passed -and $r.Remediation) {
            Write-Host "       -> $($r.Remediation)" -ForegroundColor Cyan
        }
    }

    $blocking = @($Results | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })
    if ($blocking.Count -gt 0) {
        throw "Preflight failed: $($blocking.Count) blocking check(s): $($blocking.Name -join ', ')"
    }
}