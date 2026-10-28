#Requires -Version 7.4
$ErrorActionPreference = 'Stop'

# Parse each file to learn which functions it defines (so one file may hold several).
function Get-DefinedFunctionName {
    param([Parameter(Mandatory)][string]$Path)
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) { throw "Syntax error in '$Path' (line $($parseErrors[0].Extent.StartLineNumber)): $($parseErrors[0].Message)" }
    $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
        ForEach-Object Name
}

$exported = [System.Collections.Generic.List[string]]::new()

foreach ($scope in 'Private', 'Public') {
    $dir = Join-Path $PSScriptRoot $scope
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File | Sort-Object Name) {
        $names = @(Get-DefinedFunctionName -Path $file.FullName)
        if ($names.Count -eq 0) { Write-Verbose "Skipping '$($file.Name)': defines no functions."; continue }
        . $file.FullName            # dot-source at MODULE scope, not inside a helper function
        if ($scope -eq 'Public') { $exported.AddRange([string[]]$names) }
    }
}

Export-ModuleMember -Function $exported.ToArray()