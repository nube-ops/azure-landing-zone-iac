function Write-BootstrapLog {
    <#
    .SYNOPSIS
        The single place bootstrap output is formatted. Prints only; never throws.
    .NOTES
        Stopping is the caller's decision (see Assert-Preflight). In GitHub Actions,
        Warning and Error levels also emit workflow annotations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Message,
        [ValidateSet('Header', 'Info', 'Success', 'Warning', 'Error')][string]$Level = 'Info'
    )

    $style = @{
        Header  = @{ Tag = '';          Color = 'Cyan'   }
        Info    = @{ Tag = '[INFO]';    Color = 'Gray'   }
        Success = @{ Tag = '[SUCCESS]'; Color = 'Green'  }
        Warning = @{ Tag = '[WARNING]'; Color = 'Yellow' }
        Error   = @{ Tag = '[ERROR]';   Color = 'Red'    }
    }[$Level]

    if ($Level -eq 'Header') {
        $bar = '=' * 40
        Write-Host "`n$bar`n $Message`n$bar" -ForegroundColor $style.Color
        return
    }

    Write-Host "$($style.Tag) $Message" -ForegroundColor $style.Color

    if ($env:GITHUB_ACTIONS -eq 'true' -and $Level -in 'Warning', 'Error') {
        Write-Host "::$($Level.ToLower())::$($Message -replace '\r?\n', '%0A')"
    }
}