@{
    PowerShell = @{ Minimum = '7.4.0'; Fix = 'winget install --id Microsoft.PowerShell' }
    Tools = @(
        @{ Name = 'az';    Minimum = '2.20.0'; Fix = 'winget install --id Microsoft.AzureCLI' }
        @{ Name = 'bicep'; Minimum = '0.20.0'; Fix = 'az bicep install' }
        @{ Name = 'gh';    Minimum = '2.0.0';  Fix = 'winget install --id GitHub.Cli' }
        @{ Name = 'git';   Minimum = '2.30.0'; Fix = 'winget install --id Git.Git' }
    )
}