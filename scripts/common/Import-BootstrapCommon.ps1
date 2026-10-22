# scripts/common/Import-BootstrapCommon.ps1
<#
.SYNOPSIS
    Centralized recursive loader for all common PowerShell helper functions.
.DESCRIPTION
    Dot-sourced by orchestrators. Evaluates all helper files recursively, 
    filters out test scripts, ensures deterministic execution order, and 
    provides granular error handling and scope hygiene.
#>
[CmdletBinding()]
param()

$loaderPath = $PSCommandPath
Write-Verbose "Discovering shared helper scripts from: $PSScriptRoot"

$helperFiles = Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' -File -Recurse |
    Where-Object { $_.FullName -ne $loaderPath -and $_.Name -notlike '*.Tests.ps1' } |
    Sort-Object FullName

foreach ($helperFile in $helperFiles) {
    try {
        Write-Verbose "Dot-sourcing utility: $($helperFile.Name)"
        . $helperFile.FullName
    } catch {
        Write-Error "Failed to load helper script '$($helperFile.FullName)': $_"
        throw $_
    }
}

Remove-Variable helperFiles, helperFile, loaderPath -ErrorAction SilentlyContinue
Write-Verbose "All common utility functions loaded successfully."