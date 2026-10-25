# scripts/LandingZone.Bootstrap/prerequisites.psd1
@{
    PowerShell = @{ Minimum = '7.4'; Fix = 'winget install --id Microsoft.PowerShell' }
    Tools = @(
        @{ Name = 'az';  Minimum = '2.60'; Fix = 'winget install --id Microsoft.AzureCLI' }
        @{ Name = 'gh';  Minimum = '2.50'; Fix = 'winget install --id GitHub.Cli' }
        @{ Name = 'git'; Minimum = '2.40'; Fix = 'winget install --id Git.Git' }
    )
}