function Get-ToolVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('az', 'bicep', 'gh', 'git')][string]$Name)

    $binary = if ($Name -eq 'bicep') { 'az' } else { $Name }   # bicep is managed through az
    if (-not (Get-Command $binary -ErrorAction SilentlyContinue)) { return $null }

    $raw = switch ($Name) {
        'az'    { (az version -o json 2>$null | ConvertFrom-Json).'azure-cli' }
        'bicep' { az bicep version 2>$null }
        'gh'    { gh --version 2>$null | Select-Object -First 1 }
        'git'   { git --version 2>$null }
    }
    if ("$raw" -match '(\d+\.\d+\.\d+)') { [version]$Matches[1] }
}