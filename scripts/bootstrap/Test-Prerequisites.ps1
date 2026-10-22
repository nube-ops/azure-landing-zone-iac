#Requires -Version 7.4
<#
.SYNOPSIS  Phase 0: verifies local tooling against scripts/common/prerequisites.psd1.
#>
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot '../common/Import-BootstrapCommon.ps1')
Assert-Preflight (Test-Tooling)