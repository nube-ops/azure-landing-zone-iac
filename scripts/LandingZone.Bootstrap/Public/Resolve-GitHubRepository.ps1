function Resolve-GitHubRepository {
    [CmdletBinding()]
    param([string]$Owner, [string]$Repository)

    # Explicit values win; the git remote is only parsed to fill what is missing.
    if ($Owner -and $Repository) { return [pscustomobject]@{ Owner = $Owner; Repository = $Repository } }

    $remoteUrl = "$(git config --get remote.origin.url 2>$null)".Trim()
    if (-not ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?/?$')) {
        throw "Git remote 'origin' is missing or not a GitHub URL (found: '$remoteUrl')."
    }

    [pscustomobject]@{
        Owner      = if ($Owner)      { $Owner }      else { $Matches[1] }
        Repository = if ($Repository) { $Repository } else { $Matches[2] }
    }
}