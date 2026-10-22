<#
.SYNOPSIS
    Dot-sources every helper in the shared libraries under scripts/common/.
.PARAMETER Library
    Optional subset of library folders to load (default: all).
.EXAMPLE
    . (Join-Path $PSScriptRoot '../common/Import-Libraries.ps1')
.EXAMPLE
    . (Join-Path $PSScriptRoot '../common/Import-Libraries.ps1') -Library LandingZone.Bootstrap
#>
[CmdletBinding()]
param([string[]]$Library)

$libraries = Get-ChildItem -Path $PSScriptRoot -Directory |
    Where-Object { -not $Library -or $_.Name -in $Library }

$unknown = $Library | Where-Object { $_ -and $_ -notin $libraries.Name }
if ($unknown) { throw "Unknown library: $($unknown -join ', ')" }

$loaded = @{}
foreach ($lib in $libraries) {
    $files = Get-ChildItem -Path $lib.FullName -Filter '*.ps1' -File -Recurse |
        Where-Object { $_.Name -notlike '*.Tests.ps1' } |
        Sort-Object FullName

    foreach ($file in $files) {
        if ($loaded.ContainsKey($file.BaseName)) {
            throw "Duplicate helper '$($file.BaseName)': $($loaded[$file.BaseName]) and $($file.FullName)"
        }
        $loaded[$file.BaseName] = $file.FullName
        Write-Verbose "Loading $($file.BaseName)"
        . $file.FullName
    }
}