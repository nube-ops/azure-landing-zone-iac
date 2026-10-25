#Requires -Version 7.4
# Loader only. No logic and no state live here.
#   Private/ = internal helpers (not exported)
#   Public/  = every function defined here is exported automatically

$publicFunctions = [System.Collections.Generic.List[string]]::new()

foreach ($folder in 'Private', 'Public') {
    $files = Get-ChildItem -Path (Join-Path $PSScriptRoot $folder) -Filter '*.ps1' -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        try { . $file.FullName }
        catch { throw "LandingZone.Bootstrap: failed to load '$($file.FullName)': $_" }

        if ($folder -eq 'Public') {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $found = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
            foreach ($function in $found) { $publicFunctions.Add($function.Name) }   # an empty file adds nothing
        }
    }
}

if ($publicFunctions.Count -eq 0) {
    throw 'LandingZone.Bootstrap: no functions found in Public/. Refusing to load an empty module.'
}

Export-ModuleMember -Function $publicFunctions.ToArray()