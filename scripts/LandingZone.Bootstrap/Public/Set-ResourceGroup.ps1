function Set-ResourceGroup {
    <#
    .SYNOPSIS
        Ensures a resource group exists. Creates it only when missing; never modifies an existing one.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$Location
    )

    $exists = (az group exists --name $Name --subscription $SubscriptionId) -eq 'true'
    if ($LASTEXITCODE -ne 0) { throw "Could not check resource group '$Name' in $SubscriptionId." }

    if ($exists) {
        Write-Host "Resource group '$Name' already exists. Skipping." -ForegroundColor Green
        return
    }

    Write-Host "Creating resource group '$Name' in $Location..." -ForegroundColor Cyan
    Invoke-WithRetry -ErrorMessage "Could not create resource group '$Name'." -ScriptBlock {
        az group create --name $Name --subscription $SubscriptionId --location $Location --output none
    }
}