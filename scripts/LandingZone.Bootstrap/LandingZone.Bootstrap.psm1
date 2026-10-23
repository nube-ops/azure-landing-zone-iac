#Requires -Version 7.4
# Loader only. No logic and no state live here.
#   Private/ = internal helpers (not exported)
#   Public/  = every function defined here is exported automatically

$publicFunctions = @()

foreach ($folder in 'Private', 'Public') {
    $files = Get-ChildItem -Path (Join-Path $PSScriptRoot $folder) -Filter '*.ps1' -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        try { . $file.FullName }
        catch { throw "LandingZone.Bootstrap: failed to load '$($file.FullName)': $_" }

        if ($folder -eq 'Public') {
            # Parse instead of trusting file names, so multi-function files like Preflight.Checks.ps1 work.
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $publicFunctions += $ast.FindAll(
                { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false).Name
        }
    }
}

Export-ModuleMember -Function $publicFunctions