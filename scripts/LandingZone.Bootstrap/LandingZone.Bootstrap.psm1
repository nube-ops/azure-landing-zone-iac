#Requires -Version 7.4
<#
.SYNOPSIS
    Root module loader for LandingZone.Bootstrap.
.DESCRIPTION
    Dot-sources Private/ then Public/, and exports every function defined at the top
    level of a Public/ file. Function names are discovered from the script AST, so a
    single file may define several functions (e.g. Preflight.Checks.ps1) and nothing
    needs to be listed twice. Add a function = drop it in Public/; no manifest edit.
#>

$ErrorActionPreference = 'Stop'

function Import-ModuleScript {
    <# Dot-sources one file and returns the names of the top-level functions it defines. #>
    param([Parameter(Mandatory)][string]$Path)

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw "Syntax error in '$Path': $($parseErrors[0].Message) (line $($parseErrors[0].Extent.StartLineNumber))"
    }

    # $false = top-level definitions only, so nested helper functions stay private
    $names = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false).Name

    . $Path
    return $names
}

# 1. Private helpers: loaded first, never exported
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name) {
    $null = Import-ModuleScript -Path $file.FullName
}

# 2. Public API: loaded second, exported
$publicFunctions = foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name) {
    Import-ModuleScript -Path $file.FullName
}

Export-ModuleMember -Function @($publicFunctions)