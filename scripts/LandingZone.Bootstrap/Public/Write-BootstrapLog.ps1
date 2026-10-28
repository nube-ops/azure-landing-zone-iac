function Write-BootstrapLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Message,
        [ValidateSet('Info','Success','Warning','Error','Idempotent')]
        [string]$Level = 'Info'
    )
    $style = @{
        Info       = @{ Tag = '[INFO]';       Color = 'Cyan'   }
        Success    = @{ Tag = '[SUCCESS]';    Color = 'Green'  }
        Idempotent = @{ Tag = '[IDEMPOTENT]'; Color = 'Green'  }
        Warning    = @{ Tag = '[WARNING]';    Color = 'Yellow' }
        Error      = @{ Tag = '[ERROR]';      Color = 'Red'    }
    }[$Level]
    Write-Host "$($style.Tag) $Message" -ForegroundColor $style.Color
}