#Requires -Version 7.4
<#
.SYNOPSIS
    Phase 0: verifies local tooling against scripts/LandingZone.Bootstrap/prerequisites.psd1.
.DESCRIPTION
    Read-only. Needs no Azure or GitHub login, so it can run on a fresh machine.
    Exits non-zero when a tool is missing or older than the manifest minimum.
.EXAMPLE
    pwsh -File ./scripts/bootstrap/Test-Prerequisites.ps1
#>
[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '../LandingZone.Bootstrap') -Force -ErrorAction Stop
Assert-Preflight (Test-Tooling)